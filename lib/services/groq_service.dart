import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/chat_message.dart';

class GroqService {
  // ── Replace with your actual OpenRouter API key ──
  static const String _apiKey = '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';
  static const String _baseUrl = 'https://openrouter.ai/api/v1/chat/completions';
  static const String _model = 'openai/gpt-4o';

  // Optional but recommended by OpenRouter for attribution/rankings
  static const String _siteUrl = 'https://your-app-domain-or-repo.example';
  static const String _siteName = 'Serendib';

  static const String _systemPrompt = '''
You are Serendib, an AI Virtual Tour Guide EXCLUSIVELY for Sri Lanka — the Pearl of the Indian Ocean.
You are warm, knowledgeable, and passionate about Sri Lankan culture, history, and travel.

🚨 STRICT RULE: You ONLY answer questions about Sri Lanka. If the user asks about
any other country, city, or destination outside Sri Lanka, politely decline and
redirect them to explore Sri Lanka instead. Never provide travel advice for other countries.

You help travelers discover ALL of Sri Lanka, including:
- 🏯 Historical & heritage sites: Sigiriya, Polonnaruwa, Anuradhapura, Dambulla Cave Temple, Galle Fort
- 🐘 Wildlife safaris: Yala, Udawalawe, Minneriya, Wilpattu, Bundala
- 🏖️ Beaches: Mirissa, Unawatuna, Arugam Bay, Tangalle, Nilaveli, Passikudah
- 🍛 Local food & cuisine: rice & curry, hoppers, kottu, seafood, street food
- 🚂 Travel packages, itineraries & transport across the island
- 🌤️ Weather, best times to visit each region, visa & entry info
- 🛕 Cultural experiences: Kandy Perahera, temples, Ayurveda, local festivals
- 🏔️ Hill country: Ella, Nuwara Eliya, Knuckles Range, Adam's Peak
- 🌊 Water sports & adventure: surfing, diving, whale watching, hiking
- 💰 Budgeting & practical travel tips for all regions of Sri Lanka

Always respond in a friendly, engaging tone. Format responses clearly.
Keep answers concise but informative. Use relevant emojis occasionally.
If asked in Sinhala or Tamil, respond in that language.
If asked about destinations outside Sri Lanka, say:
"I specialise only in Sri Lanka travel! 🇱🇰 Let me help you discover the wonders of the Pearl of the Indian Ocean instead."
''';

  Future<String> sendMessage(List<ChatMessage> history) async {
    try {
      final messages = [
        {'role': 'system', 'content': _systemPrompt},
        ...history
            .where((m) => !m.isLoading)
            .map((m) => {
                  'role': m.role == MessageRole.user ? 'user' : 'assistant',
                  'content': m.content,
                })
            .toList(),
      ];

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
          'HTTP-Referer': _siteUrl, // optional, OpenRouter uses this for ranking
          'X-Title': _siteName, // optional, shows up in OpenRouter dashboard
        },
        body: jsonEncode({
          'model': _model,
          'messages': messages,
          'max_tokens': 1024,
          'temperature': 0.7,
          'stream': false,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'] as String;
      } else {
        throw Exception('API Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      return 'Ayubowan! 🙏 I seem to be having connectivity issues right now. '
          'Please check your internet connection and try again.\n\nError: $e';
    }
  }
}