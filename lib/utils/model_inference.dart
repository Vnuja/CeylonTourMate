// lib/utils/model_inference.dart
// Runs the BiLSTM ONNX model for Sinhala hate speech detection

import 'dart:typed_data';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:flutter/services.dart';
import 'tokenizer.dart';

class PredictionResult {
  final bool isHateSpeech;
  final double confidence;
  final double rawScore;
  final String label;

  const PredictionResult({
    required this.isHateSpeech,
    required this.confidence,
    required this.rawScore,
    required this.label,
  });
}

class ModelInference {
  static const double _threshold = 0.5;
  static const String _modelPath =
      'assets/model/sinhala_hate_speech_model.onnx';

  OrtSession? _session;
  final SinhalaTokenizer _tokenizer = SinhalaTokenizer();
  bool _isLoaded = false;
  String? _inputName;

  /// Initialize: load tokenizer + ONNX model
  Future<bool> load() async {
    try {
      print('🔄 Starting model load...');

      // Step 1: Load tokenizer
      print('🔄 Loading tokenizer...');
      await _tokenizer.load();
      print('✅ Tokenizer loaded');

      // Step 2: Initialize ONNX Runtime environment
      OrtEnv.instance.init();

      // Step 3: Load model bytes from assets
      print('🔄 Loading ONNX model from: $_modelPath');
      final rawAssetFile = await rootBundle.load(_modelPath);
      final bytes = rawAssetFile.buffer.asUint8List();

      // Step 4: Create session options
      final sessionOptions = OrtSessionOptions()
        ..setInterOpNumThreads(1)
        ..setIntraOpNumThreads(1);

      // Step 5: Create session from bytes
      _session = OrtSession.fromBuffer(bytes, sessionOptions);

      // Step 6: Cache input name only
      _inputName = _session!.inputNames.first;

      _isLoaded = true;
      print('✅ ONNX model loaded');
      print('   Input  name : $_inputName');
      print('   Output names: ${_session!.outputNames}');
      return true;
    } catch (e, stackTrace) {
      print('❌ LOAD ERROR: $e');
      print('❌ STACK: $stackTrace');
      return false;
    }
  }

  /// Run inference on Sinhala text
  /// Input:  float32[1][100]
  /// Output: float32[1][1]  (sigmoid score)
  Future<PredictionResult?> predict(String text) async {
    if (!_isLoaded || _session == null) {
      print('Model not loaded. Call load() first.');
      return null;
    }

    try {
      // 1. Prepare input: text → float list of length 100
      final inputList = _tokenizer.prepareInput(text);

      // 2. Wrap in Float32List for ONNX tensor
      final inputFloat32 = Float32List.fromList(inputList);

      // 3. Create OrtValueTensor with shape [1, 100]
      final inputTensor = OrtValueTensor.createTensorWithDataList(
        inputFloat32,
        [1, SinhalaTokenizer.maxLen],
      );

      // 4. Build inputs map using cached name
      final inputs = {_inputName!: inputTensor};

      // 5. Run inference
      final runOptions = OrtRunOptions();
      final outputs = await _session!.runAsync(runOptions, inputs);

      // 6. Extract raw score — outputs is a positional list, index 0
      final rawScore =
          ((outputs?[0]?.value) as List<List<double>>?)?[0][0].toDouble() ??
          0.0;

      // 7. Cleanup
      inputTensor.release();
      runOptions.release();

      final isHate = rawScore >= _threshold;

      return PredictionResult(
        isHateSpeech: isHate,
        confidence: isHate ? rawScore : 1.0 - rawScore,
        rawScore: rawScore,
        label: isHate ? 'hate_speech' : 'not_hate_speech',
      );
    } catch (e, stackTrace) {
      print('❌ Inference error: $e');
      print('❌ STACK: $stackTrace');
      return null;
    }
  }

  bool get isLoaded => _isLoaded;
  SinhalaTokenizer get tokenizer => _tokenizer;

  void dispose() {
    _session?.release();
    OrtEnv.instance.release();
  }
}
