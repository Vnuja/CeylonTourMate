// lib/widgets/result_card.dart
import 'package:flutter/material.dart';
import '../theme/ceylon_spice.dart';
import '../utils/model_inference.dart';

class ResultCard extends StatelessWidget {
  final PredictionResult result;
  final List<String> harshWords;

  const ResultCard({
    super.key,
    required this.result,
    required this.harshWords,
  });

  @override
  Widget build(BuildContext context) {
    final isHate      = result.isHateSpeech;
    final accentColor = isHate ? CeylonSpice.danger    : CeylonSpice.deepJungle;
    final bgColor     = isHate ? CeylonSpice.dangerLight : CeylonSpice.cleanBg;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor, width: 1.5),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          // Header bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: accentColor,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Model Result',
                  style: TextStyle(
                    color: CeylonSpice.coconutCream,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Verdict
                Row(
                  children: [
                    Text(isHate ? '🔴' : '🟢', style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Text(
                      isHate ? 'HATE SPEECH' : 'NOT HATE SPEECH',
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),
                Divider(color: isHate ? CeylonSpice.danger : CeylonSpice.creamDarker),
                const SizedBox(height: 14),

                // Stats row
                IntrinsicHeight(
                  child: Row(
                    children: [
                      _StatBox(
                        value: '${(result.confidence * 100).round()}%',
                        label: 'Confidence',
                        color: accentColor,
                      ),
                      VerticalDivider(color: CeylonSpice.creamDarker, width: 1),
                      _StatBox(
                        value: result.rawScore.toStringAsFixed(3),
                        label: 'Raw Score',
                        color: CeylonSpice.cinnamon,
                      ),
                      VerticalDivider(color: CeylonSpice.creamDarker, width: 1),
                      _StatBox(
                        value: '${harshWords.length}',
                        label: 'Harsh Words',
                        color: harshWords.isNotEmpty
                            ? CeylonSpice.cinnamon
                            : CeylonSpice.deepJungle,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),
                Divider(color: CeylonSpice.creamDarker),
                const SizedBox(height: 6),

                Center(
                  child: Text(
                    'Accuracy: 86.6% · F1: 86.6% · Threshold: 0.5',
                    style: TextStyle(color: CeylonSpice.textLight, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatBox({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: CeylonSpice.textLight,
              fontSize: 9,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
