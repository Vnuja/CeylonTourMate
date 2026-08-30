import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/travel_models.dart';
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
  static const String _openRouterApiKey =
      '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';
  static const String _pineconeApiKey =
      'pcsk_2JLnSr_Tr3qeJGrf7nYpgCdimoRsuTxXQqvdfgJBkMb4CwLmfjBzGBabo2wrUhTpKajDck';
  static const String _pineconeHost =
      'https://sri-lanka-destinations-k6urqk3.svc.aped-4627-b74a.pinecone.io';
  static const String _pineconeIndex = 'sri-lanka-destinations';
  static const String _embedModel = 'llama-text-embed-v2';
  // OpenRouter model id — check https://openrouter.ai/models for the exact
  // current slug; some providers suffix variants like ':free' or '-turbo'.
  static const String _llmModel = 'openai/gpt-4o';

  // Trimmed from 8000 — the schema doesn't need that many tokens and it
  // was the single biggest contributor to slow responses. Bumped back up
  // slightly to fit the 9 hotel suggestions per destination (3 tiers x 3
  // hotels) without truncating the JSON.
  static const int _maxTokens = 6500;

  final FeedbackService _feedbackService = FeedbackService();

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
    return '$activities destinations and tour packages in Sri Lanka '
        'for ${prefs.groupType} travellers aged ${prefs.ageRange}, '
        '${prefs.budgetTier} budget, visiting in ${prefs.travelMonth}, '
        '${prefs.tripDays}-day trip. Activities prices accommodation transport.';
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

    final resp = await http.post(
      Uri.parse('$_pineconeHost/query'),
      headers: {'Api-Key': _pineconeApiKey, 'Content-Type': 'application/json'},
      body: jsonEncode({
        'vector': vector,
        'topK': 10,
        'includeMetadata': true,
        'namespace': '',
      }),
    );

    if (resp.statusCode != 200) {
      throw Exception('Pinecone API Error: ${resp.body}');
    }

    final data = jsonDecode(resp.body);
    final matches = data['matches'] as List<dynamic>? ?? [];
    if (matches.isEmpty) return "";

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
    final weatherMap = results[1] as Map<String, Map<String, dynamic>>;
    final weatherSummary = _buildWeatherSummary(weatherMap);
    final feedbackSummary = results[2] as String;

    const systemPrompt = '''
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
$weatherSummary

## KNOWLEDGE BASE CONTEXT (Sri Lanka Destinations & Packages)
$context

## TRAVELLER FEEDBACK HISTORY (past ratings from this user, if any)
${feedbackSummary.isNotEmpty ? feedbackSummary : 'No prior feedback on record — treat as a first-time traveller.'}

## REQUEST
The user's activity preference is: $activitiesString
You MUST restrict all 5 recommendations strictly to destinations matching
this activity type. Do not suggest unrelated destinations regardless of weather
or popularity.
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

    final headers = {
      'Authorization': 'Bearer $_openRouterApiKey',
      'Content-Type': 'application/json',
      // Optional but recommended by OpenRouter for routing/analytics —
      // replace with your actual app URL/name.
      'HTTP-Referer': 'https://your-app-domain-or-repo-url.com',
      'X-Title': 'Sri Lanka Travel Recommender',
    };

    final content = onPartialResponse != null
        ? await _callOpenRouterStreaming(headers, requestBody, onPartialResponse)
        : await _callOpenRouterOnce(headers, requestBody);

    return _parseRecommendationContent(content);
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