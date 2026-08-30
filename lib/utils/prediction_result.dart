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
