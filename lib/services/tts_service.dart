import 'package:flutter_tts/flutter_tts.dart';
import '../models/travel_models.dart';

class TTSService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isPlaying = false;

  // Callback to update UI when speech starts/stops
  Function(bool isPlaying)? onStateChanged;

  TTSService() {
    _initTts();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(
      0.45,
    ); // Slightly slower for better understanding
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    _flutterTts.setStartHandler(() {
      _isPlaying = true;
      onStateChanged?.call(true);
    });

    _flutterTts.setCompletionHandler(() {
      _isPlaying = false;
      onStateChanged?.call(false);
    });

    _flutterTts.setCancelHandler(() {
      _isPlaying = false;
      onStateChanged?.call(false);
    });
  }

  /// Converts the structured AI response into a natural spoken script
  String _buildScript(RecommendationResponse response) {
    final buffer = StringBuffer();
    buffer.writeln("Here are your top travel recommendations for Sri Lanka.");
    buffer.writeln(" ");

    for (final rec in response.recommendations) {
      buffer.writeln("Option ${rec.rank}: ${rec.destination}.");
      buffer.writeln(rec.whySuitable);
      // 👇 FIXED: Changed to totalCostPerPerson and added "dollars" for natural reading
      buffer.writeln(
        "The estimated total cost per person is ${rec.totalCostPerPerson} dollars.",
      );
      buffer.writeln(" ");
    }

    buffer.writeln("Finally, here are some quick travel tips for your trip.");
    for (final tip in response.travelTips) {
      buffer.writeln(tip);
    }

    buffer.writeln("Enjoy your trip to Sri Lanka!");
    return buffer.toString();
  }

  Future<void> speakRecommendations(RecommendationResponse response) async {
    if (_isPlaying) {
      await stop();
      return;
    }

    final script = _buildScript(response);
    await _flutterTts.speak(script);
  }

  Future<void> stop() async {
    await _flutterTts.stop();
  }

  void dispose() {
    _flutterTts.stop();
  }
}
