// lib/utils/harsh_word_detector.dart
// Rule-based harsh/offensive Sinhala word detection

class WordAnalysis {
  final String word;
  final bool isHarsh;
  const WordAnalysis({required this.word, required this.isHarsh});
}

class HarshWordDetector {
  /// Curated list of known harsh/offensive Sinhala words (Unicode)
  /// Expand this list based on your dataset's hate_speech=1 samples
  static final Set<String> _harshWords = {
    'මෝඩ', 'ගොන', 'ජඩ', 'කෙල', 'හිකා', 'හිකේ',
    'හිකෙන්', 'හූ', 'හාල්', 'කුංකු', 'ගෝනා',
    'පුක', 'ගාන්ඩු', 'ගාඳු', 'පදේ',
    'මරා', 'මරව', 'මරල', 'මරපන්',
    'හෙය', 'හෙව', 'හෙවා', 'හිකන්',
    'පල', 'කප', 'කාල', 'හූකෑල',
    // Add more from your dataset analysis
  };

  /// Analyze each word and flag harsh ones
  static List<WordAnalysis> analyzeWords(List<String> words) {
    return words.map((word) => WordAnalysis(
      word: word,
      isHarsh: _harshWords.contains(word),
    )).toList();
  }

  /// Get only the harsh words found in a word list
  static List<String> getHarshWords(List<String> words) {
    return words.where((w) => _harshWords.contains(w)).toList();
  }

  /// Quick check if any harsh words exist
  static bool containsHarshWords(List<String> words) {
    return words.any((w) => _harshWords.contains(w));
  }

  /// Add a word at runtime
  static void addWord(String word) {
    _harshWords.add(word);
  }
}
