import 'dart:async';
import 'tokenizer.dart';
import 'prediction_result.dart';

class ModelInference {
  bool get isLoaded => true;
  final SinhalaTokenizer tokenizer = SinhalaTokenizer();

  Future<bool> load() async {
    print('ONNX model inference is not supported on web. Using stub.');
    return true;
  }

  Future<PredictionResult?> predict(String text) async {
    return const PredictionResult(
      isHateSpeech: false,
      confidence: 1.0,
      rawScore: 0.0,
      label: 'not_hate_speech (Web Stub)',
    );
  }

  void dispose() {}
}
