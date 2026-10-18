import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/openrouter_config.dart';
import '../models/chat_message.dart';

class GroqService {
  // OpenRouter config (key, endpoint, model, attribution) lives in one place:
  // OpenRouterConfig.
  static const String _baseUrl = OpenRouterConfig.chatCompletionsUrl;
  static const String _model = OpenRouterConfig.defaultModel;

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
                }),
      ];

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: OpenRouterConfig.authHeaders(),
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