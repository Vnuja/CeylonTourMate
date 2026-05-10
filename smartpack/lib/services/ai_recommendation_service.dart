import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/travel_models.dart';

class AIRecommendationService {
  // ── API Keys ───────────────────────────────────────────────────────────────
  static const String _groqApiKey =
      '';
  static const String _pineconeApiKey =
      '';
  static const String _pineconeHost =
      '';
  static const String _pineconeIndex = 'sri-lanka-destinations';
  static const String _embedModel = 'llama-text-embed-v2';
  static const String _llmModel = 'llama-3.3-70b-versatile';

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

  // ── 3. Retrieve context from Pinecone ─────────────────────────────────────
  Future<String> _retrieveContext(
    TravelPreferences prefs,
    String activities,
  ) async {
    final queryText = _buildRagQuery(prefs, activities);
    final vector = await _embedQuery(queryText);

    final resp = await http.post(
      Uri.parse('$_pineconeHost/query'),
      headers: {'Api-Key': _pineconeApiKey, 'Content-Type': 'application/json'},
      body: jsonEncode({
        'vector': vector,
        'topK': 6,
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
    return buffer.toString();
  }

  // ── 4. Fetch weather from Open-Meteo for all 20 locations ─────────────────
  Future<Map<String, Map<String, dynamic>>> _getWeatherForDate(
    String dateStr,
  ) async {
    final weatherResults = <String, Map<String, dynamic>>{};

    for (final entry in _slLocations.entries) {
      final loc = entry.key;
      final coords = entry.value;
      try {
        final url = Uri.parse(
          'https://api.open-meteo.com/v1/forecast'
          '?latitude=${coords['lat']}&longitude=${coords['lon']}'
          '&daily=temperature_2m_max,temperature_2m_min,precipitation_sum,'
          'weathercode,windspeed_10m_max'
          '&timezone=Asia/Colombo'
          '&start_date=$dateStr&end_date=$dateStr',
        );
        final resp = await http.get(url).timeout(const Duration(seconds: 10));

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
            if (wcode == 0)
              condition = 'Clear sky ☀️';
            else if (wcode <= 3)
              condition = 'Partly cloudy ⛅';
            else if (wcode <= 49)
              condition = 'Foggy/misty 🌫️';
            else if (wcode <= 69)
              condition = 'Rainy 🌧️';
            else if (wcode <= 79)
              condition = 'Sleet/snow 🌨️';
            else if (wcode <= 99)
              condition = 'Thunderstorm ⛈️';
            else
              condition = 'Unknown';

            String suitability;
            if (wcode <= 3 && precip < 2)
              suitability = 'Excellent';
            else if (wcode <= 3 && precip < 10)
              suitability = 'Good';
            else if (wcode <= 49)
              suitability = 'Fair';
            else
              suitability = 'Poor — heavy rain expected';

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
    return weatherResults;
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

  // ── 5. Build prompt & call Groq ───────────────────────────────────────────
  Future<RecommendationResponse> getRecommendations(
    TravelPreferences prefs,
  ) async {
    // Activities are now strictly the 3 categories passed directly from UI
    final activitiesString = prefs.activityPreferences.join(', ');

    final results = await Future.wait([
      _retrieveContext(prefs, activitiesString),
      _getWeatherForDate(prefs.travelDate),
    ]);

    final context = results[0] as String;
    final weatherMap = results[1] as Map<String, Map<String, dynamic>>;
    final weatherSummary = _buildWeatherSummary(weatherMap);

    const systemPrompt = '''
You are an expert Sri Lanka travel consultant with deep knowledge of destinations,
tour packages, cultural norms, seasonal weather, activities, and pricing.

Your task is to provide TOP 3 personalised travel recommendations based on:
- User travel preferences (group, ages, budget, activity interests, travel date)
- Real-time or seasonal weather data for key Sri Lanka locations
- A knowledge base of Sri Lanka destinations and packages (provided as context)

FORMAT YOUR RESPONSE EXACTLY AS FOLLOWS:

═══════════════════════════════════════════════
🏆 TOP 3 SRI LANKA TRAVEL RECOMMENDATIONS
═══════════════════════════════════════════════

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🥇 RECOMMENDATION 1: [Destination/Route Name]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📍 DESTINATION OVERVIEW
[2-3 sentences describing why this destination suits this traveller]

🌤️ WEATHER ON YOUR TRAVEL DATE
[Weather condition, suitability, and what to expect]

📦 RECOMMENDED TOUR PACKAGE
- Package Name: ...
- Duration: ... days
- Inclusions: ...
- Estimated Package Cost: USD \$X–\$Y per person

🎯 TOP ACTIVITIES & PRICES
- [Activity 1]: USD \$X per person
- [Activity 2]: USD \$X per person
- [Activity 3]: USD \$X per person

🏨 ACCOMMODATION SUGGESTION
- [Property name/type], estimated \$X–\$Y per night

💰 ESTIMATED TOTAL COST FOR YOUR GROUP
- Per person: USD \$X–\$Y
- Full group: USD \$X–\$Y
- Budget assessment: [Fits/Slightly over/Well within] your \$X budget

✅ WHY THIS SUITS YOU
[1-2 sentences specific to their age, group, activity preference]

(Repeat the same structure for Recommendations 2 and 3)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
💡 QUICK TRAVEL TIPS FOR YOUR TRIP
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[3-4 practical tips relevant to the season and their profile]

IMPORTANT RULES:
- ONLY use information from the provided knowledge base context for package/price details
- If prices aren't in the context, provide reasonable USD estimates for Sri Lanka
- You MUST ONLY recommend destinations that directly match the user's
  activity preference. If they selected "Religious & Heritage", recommend ONLY
  heritage/cultural/temple sites (e.g. Anuradhapura, Polonnaruwa, Sigiriya,
  Dambulla, Kandy). NEVER recommend beaches or nature parks for a heritage traveller.
- Consider the weather data when ranking and recommending destinations
- If prices aren't in the context, provide reasonable USD estimates for Sri Lanka
- Keep all recommendations within the stated budget

ADDITIONALLY: After your formatted recommendations, output a JSON block
wrapped in ```json ... ``` with this structure:
{
  "recommendations": [
    {
      "rank": 1,
      "destination": "...",
      "weather_suitability": "...",
      "package_name": "...",
      "package_cost_usd_per_person": "...",
      "activities": [{"name": "...", "price_usd": "..."}],
      "accommodation": "...",
      "total_cost_per_person_usd": "...",
      "why_suitable": "..."
    }
  ],
  "travel_tips": ["...", "..."]
}''';

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

## REQUEST
The user's activity preference is: $activitiesString
You MUST restrict all 3 recommendations strictly to destinations matching
this activity type. Do not suggest unrelated destinations regardless of weather
or popularity.
Based on all the above, please provide the TOP 3 personalised Sri Lanka travel
recommendations following the exact format specified in your instructions.
Prioritise destinations with GOOD or EXCELLENT weather suitability on the travel date.''';

    final resp = await http.post(
      Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $_groqApiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': _llmModel,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userMessage},
        ],
        'temperature': 0.3,
        'max_tokens': 4096,
      }),
    );

    if (resp.statusCode != 200) {
      throw Exception('Groq API error ${resp.statusCode}: ${resp.body}');
    }

    final data = jsonDecode(resp.body);
    final content = data['choices'][0]['message']['content'] as String;

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
