// lib/utils/tokenizer.dart
// Mirrors the Python preprocess_sinhala() function from the training notebook exactly

import 'dart:convert';
import 'package:flutter/services.dart';

class SinhalaTokenizer {
  static const int maxLen    = 100;
  static const int oovIndex  = 1;

  Map<String, int> _wordIndex = {};
  bool _isLoaded = false;

  /// Load word_index.json from assets
  Future<void> load() async {
    if (_isLoaded) return;
    final raw = await rootBundle.loadString('assets/model/word_index.json');
    final Map<String, dynamic> decoded = json.decode(raw);
    _wordIndex = decoded.map((k, v) => MapEntry(k, v as int));
    _isLoaded = true;
  }

  /// Preprocess Sinhala text - mirrors Python training notebook exactly
  String preprocessSinhala(String text) {
    // 1. Trim
    String processed = text.trim();

    // 2. Remove URLs
    processed = processed.replaceAll(RegExp(r'https?://\S+|www\.\S+'), '');

    // 3. Remove emojis
    processed = processed.replaceAll(
      RegExp(
        r'[\u{1F600}-\u{1F64F}]|[\u{1F300}-\u{1F5FF}]|'
        r'[\u{1F680}-\u{1F6FF}]|[\u{1F1E0}-\u{1F1FF}]|'
        r'[\u{2702}-\u{27B0}]|[\u{24C2}-\u{1F251}]',
        unicode: true,
      ),
      '',
    );

    // 4. Keep only Sinhala Unicode range \u0D80–\u0DFF + spaces
    processed = processed.replaceAll(
      RegExp(r'[^\u0D80-\u0DFF\s]'),
      ' ',
    );

    // 5. Collapse whitespace
    processed = processed.replaceAll(RegExp(r'\s+'), ' ').trim();

    return processed;
  }

  /// Convert text → integer sequence using word_index
  List<int> textsToSequences(String text) {
    final cleaned = preprocessSinhala(text);
    final words = cleaned.split(' ').where((w) => w.isNotEmpty).toList();
    return words.map((word) => _wordIndex[word] ?? oovIndex).toList();
  }

  /// Pad/truncate sequence to maxLen (post padding, post truncating)
  List<int> padSequence(List<int> sequence) {
    final padded = List<int>.filled(maxLen, 0);
    final len = sequence.length < maxLen ? sequence.length : maxLen;
    for (int i = 0; i < len; i++) {
      padded[i] = sequence[i];
    }
    return padded;
  }

  /// Full pipeline: raw text → Float32List ready for TFLite input
  List<double> prepareInput(String text) {
    final sequence = textsToSequences(text);
    final padded   = padSequence(sequence);
    return padded.map((i) => i.toDouble()).toList();
  }

  /// Extract individual Sinhala words for harsh word highlighting
  List<String> extractWords(String text) {
    final cleaned = preprocessSinhala(text);
    return cleaned.split(' ').where((w) => w.isNotEmpty).toList();
  }

  bool get isLoaded => _isLoaded;
}
