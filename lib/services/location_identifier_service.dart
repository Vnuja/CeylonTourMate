import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

class PlaceResult {
  final String name;
  final String location;
  final String type;
  final String importance;
  final String bestTimeToVisit;
  final String entryFee;
  final List<String> highlights;
  final List<SimilarPlace> similarPlaces;
  final String confidence;

  PlaceResult({
    required this.name,
    required this.location,
    required this.type,
    required this.importance,
    required this.bestTimeToVisit,
    required this.entryFee,
    required this.highlights,
    required this.similarPlaces,
    required this.confidence,
  });

  factory PlaceResult.fromJson(Map<String, dynamic> json) {
    return PlaceResult(
      name: json['name'] ?? 'Unknown Place',
      location: json['location'] ?? '',
      type: json['type'] ?? '',
      importance: json['importance'] ?? '',
      bestTimeToVisit: json['best_time_to_visit'] ?? 'N/A',
      entryFee: json['entry_fee'] ?? 'N/A',
      highlights: List<String>.from(json['highlights'] ?? []),
      similarPlaces: (json['similar_places'] as List<dynamic>? ?? [])
          .map((e) => SimilarPlace.fromJson(e as Map<String, dynamic>))
          .toList(),
      confidence: json['confidence'] ?? 'low',
    );
  }
}

class SimilarPlace {
  final String name;
  final String location;
  final String reason;

  SimilarPlace({
    required this.name,
    required this.location,
    required this.reason,
  });

  factory SimilarPlace.fromJson(Map<String, dynamic> json) {
    return SimilarPlace(
      name: json['name'] ?? '',
      location: json['location'] ?? '',
      reason: json['reason'] ?? '',
    );
  }
}

class LocationIdentifierService {
  // ── Replace with your actual OpenAI API key ──
  static const String _apiKey =
      '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';
  static const String _baseUrl = 'https://api.openai.com/v1/chat/completions';

  static const String _prompt = '''
You are a knowledgeable travel guide. Analyze this image and identify the tourist place shown.

Return a JSON object with EXACTLY this structure (no markdown, no extra text, pure JSON only):
{
  "name": "Full official name of the place",
  "location": "City, Country",
  "type": "e.g. Temple / Museum / Natural Wonder / Historical Site",
  "importance": "2-3 sentences explaining why this place is historically, culturally or naturally significant.",
  "best_time_to_visit": "e.g. October to March",
  "entry_fee": "e.g. Free / USD 15 / Varies",
  "highlights": ["highlight 1", "highlight 2", "highlight 3"],
  "similar_places": [
    {"name": "Place 1", "location": "City, Country", "reason": "why it is similar"},
    {"name": "Place 2", "location": "City, Country", "reason": "why it is similar"},
    {"name": "Place 3", "location": "City, Country", "reason": "why it is similar"}
  ],
  "confidence": "high / medium / low"
}

If you cannot identify the place, still return JSON but set name to "Unknown Place" and fill other fields with your best guess based on visible features.
''';

  /// ── FIX: Convert any image format → JPEG bytes (same as notebook PIL approach) ──
  /// Runs on a background isolate so it doesn't block the UI thread.
  static Uint8List _convertToJpeg(Uint8List rawBytes) {
    // Decode whatever format the phone gives us (HEIC, PNG, JPEG, WEBP…)
    final decoded = img.decodeImage(rawBytes);
    if (decoded == null) throw Exception('Could not decode image file.');
    // Re-encode as JPEG quality 90 — exactly what the notebook does
    return Uint8List.fromList(img.encodeJpg(decoded, quality: 90));
  }

  Future<PlaceResult> analyzeImage(File imageFile) async {
    // 1. Read raw bytes
    final rawBytes = await imageFile.readAsBytes();

    // 2. Convert to JPEG on a background isolate (matches notebook PIL.Image → JPEG)
    final jpegBytes = await compute(_convertToJpeg, rawBytes);

    // 3. Base64 encode — always jpeg now, same as notebook
    final base64Image = base64Encode(jpegBytes);

    // 4. Call GPT-4o mini with the same payload structure as the notebook
    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode({
        'model': 'gpt-4o-mini',
        'max_tokens': 1000,
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                // FIX: image comes FIRST, then text — exactly like the notebook
                'type': 'image_url',
                'image_url': {
                  'url':
                      'data:image/jpeg;base64,$base64Image', // always jpeg now
                  'detail': 'high',
                },
              },
              {
                'type': 'text',
                'text': _prompt,
              },
            ],
          },
        ],
      }),
    );

    // 5. FIX: check HTTP status FIRST and throw a meaningful error
    if (response.statusCode != 200) {
      throw Exception(
          'OpenAI API error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    String text =
        (data['choices'] as List).first['message']['content'] as String;
    text = text.trim();

    // 6. Strip markdown fences if present (same logic as notebook)
    if (text.startsWith('```')) {
      final parts = text.split('```');
      text = parts.length > 1 ? parts[1] : text;
      if (text.startsWith('json')) text = text.substring(4);
    }

    final json = jsonDecode(text.trim()) as Map<String, dynamic>;
    return PlaceResult.fromJson(json);
  }
}
