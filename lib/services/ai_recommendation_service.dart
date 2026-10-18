import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/openrouter_config.dart';
import '../models/travel_models.dart';
import 'destination_image_service.dart';
import 'feedback_service.dart';

/// Simple in-memory cache entry with a timestamp, used for both the
/// weather map and the RAG context so repeat requests (same day / same
/// preferences) don't re-hit Pinecone or Open-Meteo from scratch.
class _CacheEntry<T> {
  final T data;
  final DateTime timestamp;
  _CacheEntry(this.data, this.timestamp);
}

class AIRecommendationService {
  // ── API Keys ───────────────────────────────────────────────────────────────
  // OpenRouter config now lives in one place: OpenRouterConfig.
  static const String _pineconeApiKey =
      'pcsk_2JLnSr_Tr3qeJGrf7nYpgCdimoRsuTxXQqvdfgJBkMb4CwLmfjBzGBabo2wrUhTpKajDck';
  static const String _pineconeHost =
      'https://sri-lanka-destinations-k6urqk3.svc.aped-4627-b74a.pinecone.io';
  static const String _embedModel = 'llama-text-embed-v2';
  // OpenRouter model id — sourced from the shared OpenRouterConfig.
  static const String _llmModel = OpenRouterConfig.defaultModel;

  // Trimmed from 8000 — the schema doesn't need that many tokens and it
  // was the single biggest contributor to slow responses. Bumped back up
  // slightly to fit the 9 hotel suggestions per destination (3 tiers x 3
  // hotels) without truncating the JSON.
  static const int _maxTokens = 6500;

  // Lazy so simply constructing the service (e.g. in a non-Firebase context)
  // doesn't touch FirebaseDatabase until feedback is actually requested.
  FeedbackService? _feedbackServiceInstance;
  FeedbackService get _feedbackService =>
      _feedbackServiceInstance ??= FeedbackService();

  // ── Caches ─────────────────────────────────────────────────────────────────
  static final Map<String, _CacheEntry<Map<String, Map<String, dynamic>>>>
  _weatherCache = {};
  static final Map<String, _CacheEntry<String>> _contextCache = {};
  static const Duration _weatherCacheTtl = Duration(hours: 3);
  static const Duration _contextCacheTtl = Duration(minutes: 30);

  // ── All 20 Sri Lanka locations — matches notebook SL_LOCATIONS exactly ─────
  static const Map<String, Map<String, double>> _slLocations = {
    'Anuradhapura': {'lat': 8.3114, 'lon': 80.4037},
    'Arugam Bay': {'lat': 6.8398, 'lon': 81.8363},
    'Bentota': {'lat': 6.4204, 'lon': 79.9968},
    'Colombo': {'lat': 6.9271, 'lon': 79.8612},
    'Dambulla Cave Temple': {'lat': 7.8675, 'lon': 80.6517},
    'Ella': {'lat': 6.8667, 'lon': 81.0466},
    'Galle Fort': {'lat': 6.0535, 'lon': 80.2210},
    'Horton Plains': {'lat': 6.8009, 'lon': 80.8117},
    'Jaffna': {'lat': 9.6615, 'lon': 80.0255},
    'Knuckles Mountain Range': {'lat': 7.4667, 'lon': 80.7833},
    'Mirissa': {'lat': 5.9483, 'lon': 80.4716},
    'Nuwara Eliya': {'lat': 6.9497, 'lon': 80.7891},
    'Polonnaruwa': {'lat': 7.9403, 'lon': 81.0188},
    'Sigiriya': {'lat': 7.9570, 'lon': 80.7603},
    'Temple of the Tooth Kandy': {'lat': 7.2936, 'lon': 80.6413},
    'Trincomalee': {'lat': 8.5874, 'lon': 81.2152},
    'Udawalawe National Park': {'lat': 6.4744, 'lon': 80.8997},
    'Unawatuna': {'lat': 6.0100, 'lon': 80.2494},
    'Wilpattu National Park': {'lat': 8.4568, 'lon': 80.0408},
    'Yala National Park': {'lat': 6.3728, 'lon': 81.5219},
  };

  // ── Activity → relevant subset of the 20 locations ─────────────────────────
  // Keeps the weather fetch small for the common case, instead of always
  // hitting Open-Meteo for all 20 regardless of what the traveller cares about.
  static const Map<String, List<String>> _activityLocationMap = {
    'religious & heritage': [
      'Anuradhapura',
      'Polonnaruwa',
      'Sigiriya',
      'Dambulla Cave Temple',
      'Temple of the Tooth Kandy',
      'Jaffna',
    ],
    'beach & relaxation': [
      'Bentota',
      'Mirissa',
      'Unawatuna',
      'Trincomalee',
      'Arugam Bay',
      'Galle Fort',
    ],
    'wildlife & nature': [
      'Yala National Park',
      'Udawalawe National Park',
      'Wilpattu National Park',
      'Horton Plains',
      'Knuckles Mountain Range',
      'Sigiriya',
    ],
    'adventure & hiking': [
      'Ella',
      'Knuckles Mountain Range',
      'Horton Plains',
      'Nuwara Eliya',
      'Arugam Bay',
    ],
    'culture & cities': ['Colombo', 'Temple of the Tooth Kandy', 'Galle Fort', 'Jaffna'],
  };

  /// Resolves which of the 20 fixed locations are actually worth fetching
  /// weather for, based on the traveller's stated activity preferences.
  /// Falls back to all 20 if nothing matches (keeps old behaviour as a
  /// safety net rather than silently returning nothing).
  Set<String> _relevantLocations(List<String> activityPreferences) {
    if (activityPreferences.isEmpty) return _slLocations.keys.toSet();

    final result = <String>{};
    for (final activity in activityPreferences) {
      final a = activity.toLowerCase().trim();
      for (final entry in _activityLocationMap.entries) {
        if (entry.key.contains(a) || a.contains(entry.key)) {
          result.addAll(entry.value);
        }
      }
    }
    return result.isEmpty ? _slLocations.keys.toSet() : result;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  CURRENT-LOCATION / PROXIMITY SUPPORT  (ported from the updated notebook)
  //
  //  When the traveller selects one of the 25 Sri Lankan districts (instead of
  //  "Outside Sri Lanka"), recommendations are restricted/ranked to
  //  destinations near that district — e.g. someone in Galle gets nearby
  //  south/west-coast spots, not Jaffna or Polonnaruwa. When "Outside Sri
  //  Lanka" is selected, every code path below is a no-op and the original
  //  island-wide behaviour (and output format) is completely unchanged.
  // ═══════════════════════════════════════════════════════════════════════════

  static const String outsideSlOption = 'Outside Sri Lanka';

  // Activity category constants — match the questionnaire labels exactly, so
  // the catalogue categories align with prefs.activityPreferences directly.
  static const String _adv = 'Adventure';
  static const String _rel = 'Religious & Heritage';
  static const String _fun = 'Chilling & Fun';

  // All 25 districts of Sri Lanka (approx. district-centre coordinates) —
  // matches the notebook SL_DISTRICTS exactly.
  static const Map<String, Map<String, double>> _slDistricts = {
    'Ampara': {'lat': 7.2912, 'lon': 81.6724},
    'Anuradhapura': {'lat': 8.3114, 'lon': 80.4037},
    'Badulla': {'lat': 6.9934, 'lon': 81.0550},
    'Batticaloa': {'lat': 7.7102, 'lon': 81.6924},
    'Colombo': {'lat': 6.9271, 'lon': 79.8612},
    'Galle': {'lat': 6.0535, 'lon': 80.2210},
    'Gampaha': {'lat': 7.0873, 'lon': 79.9925},
    'Hambantota': {'lat': 6.1241, 'lon': 81.1185},
    'Jaffna': {'lat': 9.6615, 'lon': 80.0255},
    'Kalutara': {'lat': 6.5854, 'lon': 79.9607},
    'Kandy': {'lat': 7.2906, 'lon': 80.6337},
    'Kegalle': {'lat': 7.2513, 'lon': 80.3464},
    'Kilinochchi': {'lat': 9.3803, 'lon': 80.3770},
    'Kurunegala': {'lat': 7.4863, 'lon': 80.3623},
    'Mannar': {'lat': 8.9810, 'lon': 79.9044},
    'Matale': {'lat': 7.4675, 'lon': 80.6234},
    'Matara': {'lat': 5.9549, 'lon': 80.5550},
    'Monaragala': {'lat': 6.8728, 'lon': 81.3507},
    'Mullaitivu': {'lat': 9.2671, 'lon': 80.8142},
    'Nuwara Eliya': {'lat': 6.9497, 'lon': 80.7891},
    'Polonnaruwa': {'lat': 7.9403, 'lon': 81.0188},
    'Puttalam': {'lat': 8.0362, 'lon': 79.8283},
    'Ratnapura': {'lat': 6.6828, 'lon': 80.3992},
    'Trincomalee': {'lat': 8.5874, 'lon': 81.2152},
    'Vavuniya': {'lat': 8.7514, 'lon': 80.4971},
  };

  /// District names for the questionnaire dropdown (sorted), plus the
  /// "Outside Sri Lanka" option last.
  static List<String> get locationOptions =>
      [...(_slDistricts.keys.toList()..sort()), outsideSlOption];

  // Wider destination catalogue used ONLY for proximity ranking — mirrors the
  // notebook DESTINATION_CATALOG. (lat, lon, categories, keywords used to boost
  // matching knowledge-base chunks.)
  static const Map<String, Map<String, dynamic>> _destinationCatalog = {
    // West & South coast
    'Negombo': {'lat': 7.2083, 'lon': 79.8358, 'categories': [_fun], 'keywords': ['negombo']},
    'Colombo': {'lat': 6.9271, 'lon': 79.8612, 'categories': [_fun, _rel], 'keywords': ['colombo']},
    'Mount Lavinia': {'lat': 6.8307, 'lon': 79.8628, 'categories': [_fun], 'keywords': ['mount lavinia']},
    'Kalutara Bodhiya': {'lat': 6.5854, 'lon': 79.9607, 'categories': [_rel], 'keywords': ['kalutara']},
    'Beruwala': {'lat': 6.4788, 'lon': 79.9828, 'categories': [_fun], 'keywords': ['beruwala']},
    'Bentota': {'lat': 6.4204, 'lon': 79.9968, 'categories': [_fun, _adv], 'keywords': ['bentota']},
    'Kosgoda': {'lat': 6.3500, 'lon': 80.0000, 'categories': [_fun], 'keywords': ['kosgoda']},
    'Hikkaduwa': {'lat': 6.1395, 'lon': 80.1005, 'categories': [_fun, _adv], 'keywords': ['hikkaduwa']},
    'Galle Fort': {'lat': 6.0535, 'lon': 80.2210, 'categories': [_rel, _fun], 'keywords': ['galle']},
    'Unawatuna': {'lat': 6.0100, 'lon': 80.2494, 'categories': [_fun], 'keywords': ['unawatuna']},
    'Weligama': {'lat': 5.9750, 'lon': 80.4297, 'categories': [_fun, _adv], 'keywords': ['weligama']},
    'Mirissa': {'lat': 5.9483, 'lon': 80.4716, 'categories': [_fun], 'keywords': ['mirissa']},
    'Dickwella & Hiriketiya': {'lat': 5.9667, 'lon': 80.6833, 'categories': [_fun, _adv], 'keywords': ['dickwella', 'hiriketiya']},
    'Tangalle': {'lat': 6.0240, 'lon': 80.7970, 'categories': [_fun], 'keywords': ['tangalle']},
    // South-east / East coast
    'Kataragama': {'lat': 6.4137, 'lon': 81.3350, 'categories': [_rel], 'keywords': ['kataragama']},
    'Tissamaharama': {'lat': 6.2833, 'lon': 81.2833, 'categories': [_rel, _fun], 'keywords': ['tissamaharama', 'tissa']},
    'Yala National Park': {'lat': 6.3728, 'lon': 81.5219, 'categories': [_fun, _adv], 'keywords': ['yala']},
    'Arugam Bay': {'lat': 6.8398, 'lon': 81.8363, 'categories': [_adv, _fun], 'keywords': ['arugam']},
    'Pasikuda': {'lat': 7.9274, 'lon': 81.5612, 'categories': [_fun], 'keywords': ['pasikuda', 'passikudah']},
    'Batticaloa': {'lat': 7.7102, 'lon': 81.6924, 'categories': [_fun, _rel], 'keywords': ['batticaloa']},
    'Trincomalee': {'lat': 8.5874, 'lon': 81.2152, 'categories': [_fun, _adv, _rel], 'keywords': ['trincomalee']},
    'Nilaveli': {'lat': 8.6900, 'lon': 81.1900, 'categories': [_fun, _adv], 'keywords': ['nilaveli']},
    // North & North-west
    'Jaffna': {'lat': 9.6615, 'lon': 80.0255, 'categories': [_rel, _fun], 'keywords': ['jaffna']},
    'Kalpitiya': {'lat': 8.2333, 'lon': 79.7667, 'categories': [_adv, _fun], 'keywords': ['kalpitiya']},
    'Wilpattu National Park': {'lat': 8.4568, 'lon': 80.0408, 'categories': [_fun, _adv], 'keywords': ['wilpattu']},
    // Cultural triangle
    'Anuradhapura': {'lat': 8.3114, 'lon': 80.4037, 'categories': [_rel], 'keywords': ['anuradhapura']},
    'Mihintale': {'lat': 8.3500, 'lon': 80.5117, 'categories': [_rel], 'keywords': ['mihintale']},
    'Sigiriya': {'lat': 7.9570, 'lon': 80.7603, 'categories': [_rel, _adv], 'keywords': ['sigiriya']},
    'Dambulla Cave Temple': {'lat': 7.8675, 'lon': 80.6517, 'categories': [_rel], 'keywords': ['dambulla']},
    'Polonnaruwa': {'lat': 7.9403, 'lon': 81.0188, 'categories': [_rel], 'keywords': ['polonnaruwa']},
    'Minneriya National Park': {'lat': 8.0333, 'lon': 80.9000, 'categories': [_fun, _adv], 'keywords': ['minneriya']},
    // Hill country & interior
    'Temple of the Tooth Kandy': {'lat': 7.2936, 'lon': 80.6413, 'categories': [_rel], 'keywords': ['kandy', 'temple of the tooth']},
    'Knuckles Mountain Range': {'lat': 7.4667, 'lon': 80.7833, 'categories': [_adv], 'keywords': ['knuckles']},
    'Nuwara Eliya': {'lat': 6.9497, 'lon': 80.7891, 'categories': [_fun, _adv], 'keywords': ['nuwara eliya']},
    'Horton Plains': {'lat': 6.8009, 'lon': 80.8117, 'categories': [_adv], 'keywords': ['horton']},
    'Ella': {'lat': 6.8667, 'lon': 81.0466, 'categories': [_adv, _fun], 'keywords': ['ella']},
    'Haputale': {'lat': 6.7667, 'lon': 80.9500, 'categories': [_adv, _fun], 'keywords': ['haputale']},
    "Adam's Peak (Sri Pada)": {'lat': 6.8096, 'lon': 80.4994, 'categories': [_adv, _rel], 'keywords': ["adam's peak", 'adams peak', 'sri pada']},
    'Kitulgala': {'lat': 6.9890, 'lon': 80.4170, 'categories': [_adv], 'keywords': ['kitulgala']},
    'Sinharaja Rainforest': {'lat': 6.4020, 'lon': 80.4040, 'categories': [_adv], 'keywords': ['sinharaja']},
    'Udawalawe National Park': {'lat': 6.4744, 'lon': 80.8997, 'categories': [_fun, _adv], 'keywords': ['udawalawe']},
    'Pinnawala Elephant Orphanage': {'lat': 7.3000, 'lon': 80.3850, 'categories': [_fun], 'keywords': ['pinnawala']},
    'Kelaniya Raja Maha Vihara': {'lat': 6.9553, 'lon': 79.9220, 'categories': [_rel], 'keywords': ['kelaniya']},
  };

  static const double _roadFactor = 1.35; // straight-line → approx. road km
  static const double _avgSpeedKmh = 45; // used for travel-time estimates

  /// True only when the traveller selected one of the 25 Sri Lankan districts.
  bool _isLocationActive(TravelPreferences prefs) =>
      _slDistricts.containsKey(prefs.currentLocation);

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final p1 = lat1 * math.pi / 180.0;
    final p2 = lat2 * math.pi / 180.0;
    final dPhi = (lat2 - lat1) * math.pi / 180.0;
    final dLmb = (lon2 - lon1) * math.pi / 180.0;
    final a = math.sin(dPhi / 2) * math.sin(dPhi / 2) +
        math.cos(p1) * math.cos(p2) * math.sin(dLmb / 2) * math.sin(dLmb / 2);
    return 2 * r * math.asin(math.sqrt(a));
  }

  /// Longer trips can reach further from the user's current location.
  int _maxTravelKm(int tripDays) {
    if (tripDays <= 2) return 80;
    if (tripDays <= 4) return 150;
    if (tripDays <= 7) return 250;
    if (tripDays <= 10) return 350;
    return 500;
  }

  /// Rank catalogue destinations that match the traveller's activity
  /// preference by distance from their current district. Returns [] when the
  /// traveller is outside Sri Lanka. Mirrors the notebook
  /// get_nearby_destinations (max 8, min 4).
  List<Map<String, dynamic>> _getNearbyDestinations(
    TravelPreferences prefs, {
    int maxResults = 8,
    int minResults = 4,
  }) {
    if (!_isLocationActive(prefs)) return [];

    final origin = _slDistricts[prefs.currentLocation]!;
    final wanted = prefs.activityPreferences.toSet();
    final limit = _maxTravelKm(prefs.tripDays);

    final rows = <Map<String, dynamic>>[];
    _destinationCatalog.forEach((name, d) {
      final cats = (d['categories'] as List).cast<String>();
      if (wanted.isNotEmpty && wanted.intersection(cats.toSet()).isEmpty) {
        return;
      }
      final km = _haversineKm(
            origin['lat']!,
            origin['lon']!,
            d['lat'] as double,
            d['lon'] as double,
          ) *
          _roadFactor;
      rows.add({
        'name': name,
        'road_km': km.round(),
        'hours': (km / _avgSpeedKmh),
        'categories': cats,
        'keywords': (d['keywords'] as List).cast<String>(),
        'lat': d['lat'],
        'lon': d['lon'],
      });
    });

    rows.sort((a, b) => (a['road_km'] as int).compareTo(b['road_km'] as int));
    var chosen = rows
        .where((r) => (r['road_km'] as int) <= limit)
        .take(maxResults)
        .toList();
    if (chosen.length < minResults) {
      chosen = rows.take(minResults).toList(); // sparse area → always give a few
    }
    return chosen;
  }

  /// Public: the district-local destination shortlist the planner will pin for
  /// these preferences (nearest first), or [] when the traveller is outside
  /// Sri Lanka. Exposed for diagnostics / tests and UI previews.
  List<String> nearbyDestinationNames(TravelPreferences prefs,
          {int maxResults = 10, int minResults = 6}) =>
      _getNearbyDestinations(prefs, maxResults: maxResults, minResults: minResults)
          .map((r) => r['name'] as String)
          .toList();

  /// Prompt section describing the traveller's location and nearby
  /// destinations ('' when outside Sri Lanka). Mirrors build_location_section.
  String _buildLocationSection(TravelPreferences prefs) {
    if (!_isLocationActive(prefs)) return '';

    final nearby = _getNearbyDestinations(prefs);
    final limit = _maxTravelKm(prefs.tripDays);
    final lines = <String>[];
    for (final r in nearby) {
      final km = r['road_km'] as int;
      final tier = km < 60 ? 'Very close' : (km < 150 ? 'Nearby' : 'Reachable');
      final cats = (r['categories'] as List).cast<String>().join(', ');
      lines.add(
        "  • ${r['name']}: ~$km km by road "
        "(~${(r['hours'] as double).toStringAsFixed(1)} h) [$tier] — $cats",
      );
    }

    return '\n\n## CURRENT LOCATION & PROXIMITY\n'
        "- Traveller's current location: ${prefs.currentLocation} district, Sri Lanka\n"
        '- Max sensible travel distance for a ${prefs.tripDays}-day trip: ~$limit km\n'
        '- Nearest destinations matching the activity preference (closest first):\n'
        '${lines.join('\n')}';
  }

  // ── 1. Embed query via Pinecone Inference API ──────────────────────────────
  Future<List<double>> _embedQuery(String text) async {
    final resp = await http.post(
      Uri.parse('https://api.pinecone.io/embed'),
      headers: {
        'Api-Key': _pineconeApiKey,
        'Content-Type': 'application/json',
        'X-Pinecone-API-Version': '2024-10',
      },
      body: jsonEncode({
        'model': _embedModel,
        'inputs': [
          {'text': text},
        ],
        'parameters': {'input_type': 'query', 'truncate': 'END'},
      }),
    );
    if (resp.statusCode != 200) {
      throw Exception('Embed API error: ${resp.body}');
    }
    final data = jsonDecode(resp.body);
    return List<double>.from(data['data'][0]['values']);
  }

  // ── 2. Build RAG query ─────────────────────────────────────────────────────
  String _buildRagQuery(TravelPreferences prefs, String activities) {
    var query = '$activities destinations and tour packages in Sri Lanka '
        'for ${prefs.groupType} travellers aged ${prefs.ageRange}, '
        '${prefs.budgetTier} budget, visiting in ${prefs.travelMonth}, '
        '${prefs.tripDays}-day trip. Activities prices accommodation transport.';

    // Location-aware addition (only when traveller is inside Sri Lanka) —
    // mirrors the notebook build_rag_query.
    if (_isLocationActive(prefs)) {
      final names = _getNearbyDestinations(prefs)
          .take(6)
          .map((r) => r['name'] as String)
          .join(', ');
      query += ' Traveller is currently in ${prefs.currentLocation} district; '
          'prefer destinations near ${prefs.currentLocation} such as $names.';
    }
    return query;
  }

  // ── 3. Retrieve context from Pinecone (cached) ─────────────────────────────
  Future<String> _retrieveContext(
    TravelPreferences prefs,
    String activities,
  ) async {
    final queryText = _buildRagQuery(prefs, activities);

    // Same preferences → same query → same context. Skip the round trip.
    final cached = _contextCache[queryText];
    if (cached != null &&
        DateTime.now().difference(cached.timestamp) < _contextCacheTtl) {
      return cached.data;
    }

    final vector = await _embedQuery(queryText);

    // When the traveller is in a district, over-fetch then re-rank by
    // proximity so nearby destinations surface (notebook retrieve_context).
    const int topK = 10;
    final bool locationOn = _isLocationActive(prefs);
    final int fetchK = locationOn ? topK * 3 : topK;

    final resp = await http.post(
      Uri.parse('$_pineconeHost/query'),
      headers: {'Api-Key': _pineconeApiKey, 'Content-Type': 'application/json'},
      body: jsonEncode({
        'vector': vector,
        'topK': fetchK,
        'includeMetadata': true,
        'namespace': '',
      }),
    );

    if (resp.statusCode != 200) {
      throw Exception('Pinecone API Error: ${resp.body}');
    }

    final data = jsonDecode(resp.body);
    var matches = (data['matches'] as List<dynamic>? ?? []).toList();
    if (matches.isEmpty) return "";

    // ── Location-aware re-ranking: boost chunks mentioning nearby spots ──
    if (locationOn) {
      final nearby = _getNearbyDestinations(prefs);
      final n = math.max(nearby.length, 1);

      double boosted(dynamic m) {
        final meta = (m['metadata'] as Map<String, dynamic>?) ?? {};
        final text = (meta['text'] ?? meta['content'] ?? '')
            .toString()
            .toLowerCase();
        var bonus = 0.0;
        for (var idx = 0; idx < nearby.length; idx++) {
          final keywords = (nearby[idx]['keywords'] as List).cast<String>();
          if (keywords.any((kw) => text.contains(kw))) {
            bonus += 0.08 * (1 - 0.5 * idx / n); // closer destinations weigh more
          }
        }
        final score = (m['score'] as num?)?.toDouble() ?? 0.0;
        return score + math.min(bonus, 0.25);
      }

      matches.sort((a, b) => boosted(b).compareTo(boosted(a)));
      matches = matches.take(topK).toList();
    }

    final buffer = StringBuffer();
    int chunkIndex = 1;
    for (final m in matches) {
      final meta = m['metadata'] as Map<String, dynamic>? ?? {};
      final text = meta['text'] ?? meta['content'] ?? '';
      final source = meta['source'] ?? 'unknown';
      buffer.writeln('[Chunk $chunkIndex | Source: $source]');
      buffer.writeln(text);
      buffer.writeln();
      chunkIndex++;
    }

    final result = buffer.toString();
    _contextCache[queryText] = _CacheEntry(result, DateTime.now());
    return result;
  }

  // ── 4. Fetch weather from Open-Meteo, only for relevant locations, cached
  //      per date so repeat calls (any user, same day) reuse prior results ──
  Future<Map<String, Map<String, dynamic>>> _getWeatherForDate(
    String dateStr,
    Set<String> locationNames,
  ) async {
    final now = DateTime.now();

    // Pull whatever's already cached for this date.
    Map<String, Map<String, dynamic>> cached = {};
    final entry = _weatherCache[dateStr];
    if (entry != null && now.difference(entry.timestamp) < _weatherCacheTtl) {
      cached = entry.data;
    }

    final missing = locationNames
        .where((loc) => !cached.containsKey(loc))
        .toList();

    final weatherResults = <String, Map<String, dynamic>>{...cached};

    Future<void> fetchOne(String loc, Map<String, double> coords) async {
      try {
        final url = Uri.parse(
          'https://api.open-meteo.com/v1/forecast'
          '?latitude=${coords['lat']}&longitude=${coords['lon']}'
          '&daily=temperature_2m_max,temperature_2m_min,precipitation_sum,'
          'weathercode,windspeed_10m_max'
          '&timezone=Asia/Colombo'
          '&start_date=$dateStr&end_date=$dateStr',
        );
        final resp = await http.get(url).timeout(const Duration(seconds: 8));

        if (resp.statusCode == 200) {
          final d = jsonDecode(resp.body);
          final daily = d['daily'];
          if (daily != null && (daily['time'] as List?)?.isNotEmpty == true) {
            final wcode = (daily['weathercode']?[0] as num?)?.toInt() ?? 0;
            final precip =
                (daily['precipitation_sum']?[0] as num?)?.toDouble() ?? 0.0;
            final tmax =
                (daily['temperature_2m_max']?[0] as num?)?.toDouble() ?? 30.0;
            final tmin =
                (daily['temperature_2m_min']?[0] as num?)?.toDouble() ?? 22.0;
            final wind =
                (daily['windspeed_10m_max']?[0] as num?)?.toDouble() ?? 15.0;

            String condition;
            if (wcode == 0) {
              condition = 'Clear sky ☀️';
            } else if (wcode <= 3) {
              condition = 'Partly cloudy ⛅';
            } else if (wcode <= 49) {
              condition = 'Foggy/misty 🌫️';
            } else if (wcode <= 69) {
              condition = 'Rainy 🌧️';
            } else if (wcode <= 79) {
              condition = 'Sleet/snow 🌨️';
            } else if (wcode <= 99) {
              condition = 'Thunderstorm ⛈️';
            } else {
              condition = 'Unknown';
            }

            String suitability;
            if (wcode <= 3 && precip < 2) {
              suitability = 'Excellent';
            } else if (wcode <= 3 && precip < 10) {
              suitability = 'Good';
            } else if (wcode <= 49) {
              suitability = 'Fair';
            } else {
              suitability = 'Poor — heavy rain expected';
            }

            weatherResults[loc] = {
              'condition': condition,
              'temp_max': tmax,
              'temp_min': tmin,
              'precip_mm': precip,
              'wind_kmh': wind,
              'suitability': suitability,
              'source': 'Open-Meteo',
            };
          } else {
            throw Exception("No daily data");
          }
        } else {
          throw Exception("API Error");
        }
      } catch (_) {
        // Seasonal estimate directly mirroring the Python fallback
        int month = 1;
        try {
          month = DateTime.parse(dateStr).month;
        } catch (_) {}

        String season;
        if ([12, 1, 2, 3].contains(month)) {
          season = 'Dry season (SW coast) — Excellent beach weather';
        } else if ([4, 5].contains(month)) {
          season = 'Inter-monsoon — Warm, occasional showers';
        } else if ([6, 7, 8, 9].contains(month)) {
          season = 'SW Monsoon — East coast ideal; west coast rainy';
        } else if ([10, 11].contains(month)) {
          season = 'NE Monsoon — West coast ideal; east coast rainy';
        } else {
          season = 'Transitional period';
        }

        weatherResults[loc] = {
          'condition': 'Seasonal estimate',
          'suitability': season,
          'source': 'Seasonal estimate',
        };
      }
    }

    if (missing.isNotEmpty) {
      await Future.wait(
        missing.map((loc) => fetchOne(loc, _slLocations[loc]!)),
      );
      _weatherCache[dateStr] = _CacheEntry(
        Map<String, Map<String, dynamic>>.from(weatherResults),
        now,
      );
    }

    // Only return what was actually asked for.
    return {
      for (final loc in locationNames)
        loc: weatherResults[loc] ??
            {
              'condition': 'Unknown',
              'suitability': 'N/A',
              'source': 'N/A',
            },
    };
  }

  // ── Build weather summary string for LLM prompt ───────────────────────────
  String _buildWeatherSummary(Map<String, Map<String, dynamic>> weatherMap) {
    final lines = <String>[];
    for (final entry in weatherMap.entries) {
      final loc = entry.key;
      final w = entry.value;
      if (w.containsKey('temp_max')) {
        lines.add(
          '  • $loc: ${w['condition']}, '
          '${w['temp_min']}–${w['temp_max']}°C, '
          '${w['precip_mm']}mm rain, '
          'Suitability: ${w['suitability']}',
        );
      } else {
        lines.add('  • $loc: ${w['suitability'] ?? 'N/A'}');
      }
    }
    return lines.join('\n');
  }

  // ── Fetch weather for a single arbitrary coordinate (used for nearby
  //    catalogue destinations that aren't among the fixed 20 locations).
  //    Mirrors the per-location logic in _getWeatherForDate. ────────────────
  Future<Map<String, dynamic>> _getWeatherForCoords(
    String dateStr,
    double lat,
    double lon,
  ) async {
    try {
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$lat&longitude=$lon'
        '&daily=temperature_2m_max,temperature_2m_min,precipitation_sum,'
        'weathercode,windspeed_10m_max'
        '&timezone=Asia/Colombo'
        '&start_date=$dateStr&end_date=$dateStr',
      );
      final resp = await http.get(url).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final d = jsonDecode(resp.body);
        final daily = d['daily'];
        if (daily != null && (daily['time'] as List?)?.isNotEmpty == true) {
          final wcode = (daily['weathercode']?[0] as num?)?.toInt() ?? 0;
          final precip =
              (daily['precipitation_sum']?[0] as num?)?.toDouble() ?? 0.0;
          final tmax =
              (daily['temperature_2m_max']?[0] as num?)?.toDouble() ?? 30.0;
          final tmin =
              (daily['temperature_2m_min']?[0] as num?)?.toDouble() ?? 22.0;
          final wind =
              (daily['windspeed_10m_max']?[0] as num?)?.toDouble() ?? 15.0;

          String condition;
          if (wcode == 0) {
            condition = 'Clear sky ☀️';
          } else if (wcode <= 3) {
            condition = 'Partly cloudy ⛅';
          } else if (wcode <= 49) {
            condition = 'Foggy/misty 🌫️';
          } else if (wcode <= 69) {
            condition = 'Rainy 🌧️';
          } else if (wcode <= 79) {
            condition = 'Sleet/snow 🌨️';
          } else if (wcode <= 99) {
            condition = 'Thunderstorm ⛈️';
          } else {
            condition = 'Unknown';
          }

          String suitability;
          if (wcode <= 3 && precip < 2) {
            suitability = 'Excellent';
          } else if (wcode <= 3 && precip < 10) {
            suitability = 'Good';
          } else if (wcode <= 49) {
            suitability = 'Fair';
          } else {
            suitability = 'Poor — heavy rain expected';
          }

          return {
            'condition': condition,
            'temp_max': tmax,
            'temp_min': tmin,
            'precip_mm': precip,
            'wind_kmh': wind,
            'suitability': suitability,
            'source': 'Open-Meteo',
          };
        }
      }
    } catch (_) {}

    // Seasonal fallback (same rules as _getWeatherForDate).
    int month = 1;
    try {
      month = DateTime.parse(dateStr).month;
    } catch (_) {}
    String season;
    if ([12, 1, 2, 3].contains(month)) {
      season = 'Dry season (SW coast) — Excellent beach weather';
    } else if ([4, 5].contains(month)) {
      season = 'Inter-monsoon — Warm, occasional showers';
    } else if ([6, 7, 8, 9].contains(month)) {
      season = 'SW Monsoon — East coast ideal; west coast rainy';
    } else if ([10, 11].contains(month)) {
      season = 'NE Monsoon — West coast ideal; east coast rainy';
    } else {
      season = 'Transitional period';
    }
    return {
      'condition': 'Seasonal estimate',
      'suitability': season,
      'source': 'Seasonal estimate',
    };
  }

  /// Add weather for shortlisted nearby destinations not already in the fixed
  /// locations. No-op when the traveller is outside Sri Lanka. Mirrors the
  /// notebook add_weather_for_nearby.
  Future<Map<String, Map<String, dynamic>>> _addWeatherForNearby(
    TravelPreferences prefs,
    Map<String, Map<String, dynamic>> weatherMap,
  ) async {
    if (!_isLocationActive(prefs)) return weatherMap;

    final merged = Map<String, Map<String, dynamic>>.from(weatherMap);
    final nearby = _getNearbyDestinations(prefs)
        .where((r) => !merged.containsKey(r['name']))
        .toList();

    await Future.wait(nearby.map((r) async {
      merged[r['name'] as String] = await _getWeatherForCoords(
        prefs.travelDate,
        r['lat'] as double,
        r['lon'] as double,
      );
    }));
    return merged;
  }

  // Appended to the system prompt ONLY when the traveller selected a Sri
  // Lankan district. Adapted from the notebook LOCATION_RULES to keep the
  // app's existing raw-JSON output format intact (no decorative lines).
  static const String _locationRules = '''

LOCATION-AWARE RULES (the traveller's current district in Sri Lanka is known):
- The user message contains a "CURRENT LOCATION & PROXIMITY" section and an
  "ALLOWED DESTINATIONS" list — the nearest places matching the traveller's
  activity preference, with estimated road distance from their district.
- HARD CONSTRAINT: every recommendation's "destination" value MUST be copied
  verbatim from the ALLOWED DESTINATIONS list. Do NOT output any destination
  that is not on that list — no exceptions, no matter how famous or how good the
  weather is elsewhere.
- Rank the allowed destinations using ALL factors together: activity match,
  weather, budget, group profile AND proximity — when everything else is equal,
  the closer destination wins (nearest first).
- Example: a beach-lover currently in Galle district must get south/west-coast
  beaches near Galle (Unawatuna, Hikkaduwa, Mirissa…), NEVER far places like
  Jaffna, Trincomalee, Pasikuda or Nilaveli.
- If the list has fewer entries than requested, return only as many
  recommendations as there are allowed destinations — never invent or substitute
  a far-away one to reach the count.
- Keep the response in the EXACT same JSON structure already specified — do not
  add any extra prose, headers, or fields.''';

  // ── 5. Build prompt & call OpenRouter ─────────────────────────────────────
  /// [uid] is optional — when provided, the traveller's past ratings/feedback
  /// (stored via [FeedbackService]) are folded into the prompt so the model
  /// can favour destinations and activity styles the user has liked before
  /// and steer away from ones they've rated poorly.
  ///
  /// [onPartialResponse], if provided, switches the OpenRouter call to
  /// streaming mode and is invoked with each incremental text chunk as the
  /// model generates it — useful for showing a "typing" progress state in
  /// the UI instead of a blank screen until the whole 5000-token response
  /// finishes. The final parsed [RecommendationResponse] is still returned
  /// only once the full stream completes.
  Future<RecommendationResponse> getRecommendations(
    TravelPreferences prefs, {
    String? uid,
    void Function(String chunk)? onPartialResponse,
  }) async {
    // Activities are the categories passed directly from UI
    final activitiesString = prefs.activityPreferences.join(', ');
    final relevantLocations = _relevantLocations(prefs.activityPreferences);

    final results = await Future.wait([
      _retrieveContext(prefs, activitiesString),
      _getWeatherForDate(prefs.travelDate, relevantLocations),
      // Feedback must never break the whole recommendation flow — if it
      // fails (permissions, network, no data yet), just fall back to ''.
      if (uid != null)
        _feedbackService.buildFeedbackSummary(uid).catchError((e) => '')
      else
        Future.value(''),
    ]);

    final context = results[0] as String;
    var weatherMap = results[1] as Map<String, Map<String, dynamic>>;
    final feedbackSummary = results[2] as String;

    // When the traveller is inside a district, add weather for the nearby
    // shortlisted destinations so the model can weigh them (no-op otherwise).
    final bool locationOn = _isLocationActive(prefs);
    if (locationOn) {
      weatherMap = await _addWeatherForNearby(prefs, weatherMap);
    }
    final weatherSummary = _buildWeatherSummary(weatherMap);

    const baseSystemPrompt = '''
You are an expert Sri Lanka travel consultant with deep knowledge of destinations,
tour packages, cultural norms, seasonal weather, activities, and pricing.

Your task is to provide TOP 5 personalised travel recommendations based on:
- User travel preferences (group, ages, budget, activity interests, travel date)
- Real-time or seasonal weather data for key Sri Lanka locations
- A knowledge base of Sri Lanka destinations and packages (provided as context)
- The traveller's past ratings/feedback on destinations, if available

IMPORTANT RULES:
- ONLY use information from the provided knowledge base context for package/price details
- If prices aren't in the context, provide reasonable USD estimates for Sri Lanka
- You MUST ONLY recommend destinations that directly match the user's
  activity preference. If they selected "Religious & Heritage", recommend ONLY
  heritage/cultural/temple sites (e.g. Anuradhapura, Polonnaruwa, Sigiriya,
  Dambulla, Kandy). NEVER recommend beaches or nature parks for a heritage traveller.
- Consider the weather data when ranking and recommending destinations
- Keep all recommendations within the stated budget
- Provide exactly 5 distinct destinations — never repeat the same destination twice
- For hotel_options, return EXACTLY 3 comfort tiers — Budget, Mid-range, and
  Luxury — and for EACH tier suggest EXACTLY 3 concrete, real-sounding
  hotels/guesthouses/resorts near that destination, each with an estimated
  price per night. That is 9 distinct hotel suggestions total per
  destination (3 tiers × 3 hotels). Never return fewer than 3 hotels in any
  tier, and never fewer than 3 tiers.
- For transport, describe how to get to/around the destination with an
  estimated cost
- For entry_fees, give ticket/entry prices for the main sites, noting local
  vs foreign visitor price differences where relevant
- If TRAVELLER FEEDBACK HISTORY is provided below, use it to personalise ranking:
  favour destinations/activity types the traveller has rated highly in the past,
  and avoid or de-prioritise ones they've rated poorly, while still respecting
  their stated activity preference for this trip

RESPOND WITH RAW JSON ONLY — no markdown headers, no commentary, no decorative
text before or after, no ```json code fences. Output must start with { and end
with } and match this exact structure:
{
  "recommendations": [
    {
      "rank": 1,
      "destination": "...",
      "weather_suitability": "...",
      "package_name": "...",
      "package_cost_usd_per_person": "...",
      "hotel_options": [
        {"tier": "Budget", "hotels": ["Hotel A (\$X/night)", "Hotel B (\$X/night)", "Hotel C (\$X/night)"]},
        {"tier": "Mid-range", "hotels": ["Hotel D (\$X/night)", "Hotel E (\$X/night)", "Hotel F (\$X/night)"]},
        {"tier": "Luxury", "hotels": ["Hotel G (\$X/night)", "Hotel H (\$X/night)", "Hotel I (\$X/night)"]}
      ],
      "transport": "...",
      "entry_fees": "...",
      "activities": [{"name": "...", "price_usd": "..."}],
      "accommodation": "...",
      "total_cost_per_person_usd": "...",
      "why_suitable": "..."
    }
  ],
  "travel_tips": ["...", "..."]
}
Provide exactly 5 objects in "recommendations", ranked 1 to 5, and 3-4 items
in "travel_tips". Every recommendation's "hotel_options" array must contain
EXACTLY 3 tier objects (Budget, Mid-range, Luxury), and each tier's "hotels"
array must contain EXACTLY 3 hotels — 9 hotels total per destination.''';

    // Append location-aware rules only when a Sri Lankan district was chosen.
    final systemPrompt =
        baseSystemPrompt + (locationOn ? _locationRules : '');

    // Location prompt pieces — empty strings when outside Sri Lanka, so the
    // message is byte-for-byte unchanged in the original case.
    final locationSection = _buildLocationSection(prefs);

    // Explicit allow-list of nearby destination NAMES. We request a few more
    // than the 5 recommendations so the model always has enough nearby options
    // and never needs to reach for a far-away place to hit the count.
    final allowedNames = locationOn
        ? _getNearbyDestinations(prefs, maxResults: 10, minResults: 6)
            .map((r) => r['name'] as String)
            .toList()
        : <String>[];
    // Deterministically pick the exact destinations to write up (nearest
    // first). Removing the model's freedom to choose is what actually stops
    // far-away places leaking in. Take up to 5 (the required rec count).
    final chosenNames = allowedNames.take(5).toList();
    final allowedBlock = locationOn
        ? '\n\n## DESTINATIONS TO WRITE UP (use EXACTLY these, in this order — '
            'one recommendation each, nearest first)\n'
            '${_numbered(chosenNames)}'
        : '';
    final locationRequest = locationOn
        ? '\nThe traveller is currently in ${prefs.currentLocation} district. '
            'HARD RULE: produce exactly ${chosenNames.length} recommendations, '
            'one for EACH destination in the "DESTINATIONS TO WRITE UP" list '
            'above, in that order, copying each name verbatim into "destination". '
            'Do NOT add, remove, reorder or substitute any destination, and never '
            'introduce a place outside that list — however famous or however good '
            'the weather is elsewhere.'
        : '';

    final userMessage =
        '''
## TRAVELLER PROFILE
- Group type:          ${prefs.groupType.substring(0, 1).toUpperCase()}${prefs.groupType.substring(1)} (${prefs.groupSize} person(s))
- Gender breakdown:    ${prefs.gender}
- Age range:           ${prefs.ageRange}
- Total budget (USD):  \$${prefs.budgetUsd.toStringAsFixed(0)}  (${prefs.budgetTier} tier)
- Activity interests:  $activitiesString
- Arrival date:        ${prefs.travelDate} (${prefs.travelMonth})
- Trip duration:       ${prefs.tripDays} days

## WEATHER DATA FOR TRAVEL DATE (${prefs.travelDate})
$weatherSummary$locationSection$allowedBlock

## KNOWLEDGE BASE CONTEXT (Sri Lanka Destinations & Packages)
$context

## TRAVELLER FEEDBACK HISTORY (past ratings from this user, if any)
${feedbackSummary.isNotEmpty ? feedbackSummary : 'No prior feedback on record — treat as a first-time traveller.'}

## REQUEST
The user's activity preference is: $activitiesString
You MUST restrict all 5 recommendations strictly to destinations matching
this activity type. Do not suggest unrelated destinations regardless of weather
or popularity.$locationRequest
Based on all the above, please provide the TOP 5 personalised Sri Lanka travel
recommendations following the exact format specified in your instructions.
Prioritise destinations with GOOD or EXCELLENT weather suitability on the travel date,
and weigh the traveller's feedback history when it's available.''';

    final requestBody = jsonEncode({
      'model': _llmModel,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userMessage},
      ],
      'temperature': 0.3,
      'max_tokens': _maxTokens,
      'stream': onPartialResponse != null,
    });

    final headers = OpenRouterConfig.authHeaders();

    final content = onPartialResponse != null
        ? await _callOpenRouterStreaming(headers, requestBody, onPartialResponse)
        : await _callOpenRouterOnce(headers, requestBody);

    final parsed = _parseRecommendationContent(content);

    RecommendationResponse result = parsed;

    if (locationOn && chosenNames.isNotEmpty) {
      // ── Guarantee district-local results ────────────────────────────────
      final filtered = _filterToNearby(parsed, allowedNames);

      debugPrint('[Planner] location=${prefs.currentLocation} '
          'pinned=$chosenNames '
          'llmReturned=${parsed.recommendations.map((r) => r.destination).toList()} '
          'keptAfterFilter=${filtered.recommendations.map((r) => r.destination).toList()}');

      if (filtered.recommendations.length >= (chosenNames.length / 2).ceil()) {
        // Model mostly complied — use its coherent output.
        result = filtered;
      } else {
        // Model ignored the pinned list → force local destinations.
        final forced = <TravelRecommendation>[];
        for (var i = 0; i < chosenNames.length; i++) {
          final base = i < parsed.recommendations.length
              ? parsed.recommendations[i]
              : (parsed.recommendations.isNotEmpty
                  ? parsed.recommendations.last
                  : null);
          if (base == null) break;
          forced.add(_withDestination(base, chosenNames[i], i + 1));
        }
        if (forced.isNotEmpty) {
          result = RecommendationResponse(
            recommendations: forced,
            travelTips: parsed.travelTips,
          );
        } else if (filtered.recommendations.isNotEmpty) {
          result = filtered;
        }
      }
    }

    // Fill in a relevant online image for any recommendation that has no
    // curated local asset, so the UI never shows a wrong/stock photo.
    return _resolveImages(result);
  }

  /// For each recommendation without a local asset image, fetch a relevant
  /// photo online (Wikipedia) and attach it. Runs lookups in parallel.
  Future<RecommendationResponse> _resolveImages(
      RecommendationResponse resp) async {
    final recs = await Future.wait(resp.recommendations.map((r) async {
      final img = r.imageUrl;
      final isLocalAsset = img != null && img.startsWith('assets/');
      if (isLocalAsset) return r;
      final url =
          await DestinationImageService.instance.imageUrlFor(r.destination);
      return r.copyWith(imageUrl: url);
    }));
    return RecommendationResponse(
      recommendations: recs,
      travelTips: resp.travelTips,
    );
  }

  /// Copy a recommendation, overriding its destination name and rank (used to
  /// force district-local destinations when the model ignores the pinned list).
  TravelRecommendation _withDestination(
    TravelRecommendation r,
    String destination,
    int rank,
  ) {
    return TravelRecommendation(
      rank: rank,
      destination: destination,
      weatherSuitability: r.weatherSuitability,
      packageName: r.packageName,
      packageCostPerPerson: r.packageCostPerPerson,
      activities: r.activities,
      accommodation: r.accommodation,
      totalCostPerPerson: r.totalCostPerPerson,
      whySuitable: r.whySuitable,
      imageUrl: TravelRecommendation.imageFor(destination),
      rating: TravelRecommendation.ratingFor(destination),
      hotelOptions: r.hotelOptions,
      transportInfo: r.transportInfo,
      entryFees: r.entryFees,
    );
  }

  /// Keep only recommendations whose destination matches one of the allowed
  /// nearby names (case-insensitive, tolerant of minor wording differences),
  /// re-ranking them in the allow-list's nearest-first order.
  RecommendationResponse _filterToNearby(
    RecommendationResponse resp,
    List<String> allowedNames,
  ) {
    String norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final allowedNorm = allowedNames.map(norm).toList();

    bool isAllowed(String dest) {
      final d = norm(dest);
      for (final a in allowedNorm) {
        if (d == a || d.contains(a) || a.contains(d)) return true;
      }
      return false;
    }

    final kept =
        resp.recommendations.where((r) => isAllowed(r.destination)).toList();

    // Re-rank by proximity order (position in allowedNames), then renumber.
    int order(TravelRecommendation r) {
      final d = norm(r.destination);
      for (var i = 0; i < allowedNorm.length; i++) {
        final a = allowedNorm[i];
        if (d == a || d.contains(a) || a.contains(d)) return i;
      }
      return allowedNorm.length;
    }

    kept.sort((a, b) => order(a).compareTo(order(b)));
    final renumbered = <TravelRecommendation>[];
    for (var i = 0; i < kept.length; i++) {
      renumbered.add(_withRank(kept[i], i + 1));
    }
    return RecommendationResponse(
      recommendations: renumbered,
      travelTips: resp.travelTips,
    );
  }

  /// "  1. Name\n  2. Name" for an ordered prompt list.
  static String _numbered(List<String> names) {
    final b = StringBuffer();
    for (var i = 0; i < names.length; i++) {
      b.writeln('  ${i + 1}. ${names[i]}');
    }
    return b.toString().trimRight();
  }

  /// Copy a recommendation with a new rank (model is immutable otherwise).
  TravelRecommendation _withRank(TravelRecommendation r, int rank) {
    return TravelRecommendation(
      rank: rank,
      destination: r.destination,
      weatherSuitability: r.weatherSuitability,
      packageName: r.packageName,
      packageCostPerPerson: r.packageCostPerPerson,
      activities: r.activities,
      accommodation: r.accommodation,
      totalCostPerPerson: r.totalCostPerPerson,
      whySuitable: r.whySuitable,
      imageUrl: r.imageUrl,
      rating: r.rating,
      hotelOptions: r.hotelOptions,
      transportInfo: r.transportInfo,
      entryFees: r.entryFees,
    );
  }

  // ── Non-streaming call (original behaviour) ────────────────────────────────
  Future<String> _callOpenRouterOnce(
    Map<String, String> headers,
    String body,
  ) async {
    final resp = await http.post(
      Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
      headers: headers,
      body: body,
    );

    if (resp.statusCode != 200) {
      throw Exception('OpenRouter API error ${resp.statusCode}: ${resp.body}');
    }

    final data = jsonDecode(resp.body);
    return data['choices'][0]['message']['content'] as String;
  }

  // ── Streaming call — surfaces partial text as it's generated so the UI
  //     can show progress instead of a blank wait for the full response ────
  Future<String> _callOpenRouterStreaming(
    Map<String, String> headers,
    String body,
    void Function(String chunk) onPartialResponse,
  ) async {
    final client = http.Client();
    try {
      final request = http.Request(
        'POST',
        Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
      );
      request.headers.addAll(headers);
      request.body = body;

      final streamedResponse = await client.send(request);

      if (streamedResponse.statusCode != 200) {
        final errBody = await streamedResponse.stream.bytesToString();
        throw Exception(
          'OpenRouter API error ${streamedResponse.statusCode}: $errBody',
        );
      }

      final buffer = StringBuffer();
      final lines = streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in lines) {
        if (line.isEmpty || !line.startsWith('data: ')) continue;
        final payload = line.substring(6).trim();
        if (payload == '[DONE]') break;

        try {
          final obj = jsonDecode(payload) as Map<String, dynamic>;
          final delta =
              obj['choices']?[0]?['delta']?['content'] as String?;
          if (delta != null && delta.isNotEmpty) {
            buffer.write(delta);
            onPartialResponse(delta);
          }
        } catch (_) {
          // Ignore malformed/partial SSE lines — extremely rare, and the
          // final buffer is validated below via JSON parsing anyway.
        }
      }

      return buffer.toString();
    } finally {
      client.close();
    }
  }

  // ── Shared JSON-cleanup + parse logic for both call paths ─────────────────
  RecommendationResponse _parseRecommendationContent(String content) {
    if (content.contains('```json')) {
      final jsonStr = content.split('```json')[1].split('```')[0].trim();
      try {
        final jsonData = jsonDecode(jsonStr) as Map<String, dynamic>;
        return RecommendationResponse.fromJson(jsonData);
      } catch (_) {}
    }

    var cleaned = content.trim();
    if (cleaned.startsWith('```json')) {
      cleaned = cleaned.substring(7);
      if (cleaned.endsWith('```')) {
        cleaned = cleaned.substring(0, cleaned.length - 3);
      }
      cleaned = cleaned.trim();
    }
    final jsonData = jsonDecode(cleaned) as Map<String, dynamic>;
    return RecommendationResponse.fromJson(jsonData);
  }
}