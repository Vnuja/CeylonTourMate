// lib/services/food_identifier_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/food_identification_result.dart';

/// Calls the OpenRouter vision API to identify Sri Lankan food in a photo.
/// Mirrors the Food Scanner web-app's CNN → LLaVA → LLaMA pipeline, but
/// implemented as a single cloud vision call so it works on mobile.
class FoodIdentifierService {
  // Same OpenRouter key already used by GroqService
  static const String _apiKey =
      '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';
  static const String _baseUrl =
      'https://openrouter.ai/api/v1/chat/completions';
  static const String _model = 'openai/gpt-4o'; // vision-capable

  // The 11 class names the Food Scanner was trained on
  static const List<String> _knownFoods = [
    'Dhal Curry',
    'Fried Rice',
    'Hoppers',
    'Katta Sambol',
    'Kawum',
    'Kiribath',
    'Kokis',
    'Kottu Roti',
    'Pittu',
    'Pol Sambol',
    'String Hoppers',
  ];

  static final String _systemPrompt = '''
You are an expert Sri Lankan food identification assistant for tourists.
You will receive a photo of food and must identify it and provide structured information.

Known Sri Lankan foods you may identify: ${_knownFoods.join(', ')}.

You MUST reply with ONLY a valid JSON object — no markdown, no code fences, no extra text.
The JSON must have exactly these keys:
{
  "food_name": "Exact food name (title case)",
  "description": "2-3 sentence description of what this food is and its cultural significance in Sri Lanka",
  "ingredients": ["ingredient1", "ingredient2", ...],
  "allergens": ["Allergen1", ...],
  "dietary": "e.g. Vegan, gluten-free / Contains egg and gluten",
  "how_to_eat": "How a tourist should eat this food",
  "how_to_make": "Brief explanation of how it is made",
  "confidence": "High / Medium / Low",
  "in_database": true/false
}

If the food is NOT a Sri Lankan dish, still describe it but set in_database to false.
If the image does not appear to contain food, set food_name to "Not a food item" and in_database to false.
''';

  /// Identify food from a base64-encoded image.
  /// [base64Image] — pure base64 string (no data-URL prefix).
  /// [mimeType] — e.g. 'image/jpeg' or 'image/png'.
  Future<FoodIdentificationResult> identify({
    required String base64Image,
    required String mimeType,
  }) async {
    final dataUrl = 'data:$mimeType;base64,$base64Image';

    final body = jsonEncode({
      'model': _model,
      'messages': [
        {
          'role': 'system',
          'content': _systemPrompt,
        },
        {
          'role': 'user',
          'content': [
            {
              'type': 'image_url',
              'image_url': {'url': dataUrl, 'detail': 'high'},
            },
            {
              'type': 'text',
              'text':
                  'Please identify this food and return the JSON response as instructed.',
            },
          ],
        },
      ],
      'max_tokens': 1024,
      'temperature': 0.2,
      'stream': false,
    });

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
        'HTTP-Referer': 'https://ceylontourmate.app',
        'X-Title': 'CeylonTourMate',
      },
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception(
          'OpenRouter error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final rawContent =
        data['choices'][0]['message']['content'] as String? ?? '{}';

    // Strip accidental markdown code fences if the model wraps the JSON
    final cleaned = rawContent
        .replaceAll(RegExp(r'```json\s*'), '')
        .replaceAll(RegExp(r'```\s*'), '')
        .trim();

    final Map<String, dynamic> parsed = jsonDecode(cleaned);
    return FoodIdentificationResult.fromJson(parsed);
  }
}
