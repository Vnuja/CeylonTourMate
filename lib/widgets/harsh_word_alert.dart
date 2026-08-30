// lib/widgets/harsh_word_alert.dart
import 'package:flutter/material.dart';
import '../theme/ceylon_spice.dart';

class HarshWordAlert extends StatelessWidget {
  final bool isHateSpeech;
  final List<String> harshWords;
  final double confidence;
  final VoidCallback onDismiss;

  const HarshWordAlert({
    super.key,
    required this.isHateSpeech,
    required this.harshWords,
    required this.confidence,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final alertColor  = isHateSpeech ? CeylonSpice.danger    : CeylonSpice.cinnamon;
    final bgColor     = isHateSpeech ? CeylonSpice.dangerLight : CeylonSpice.warnLight;
    final icon        = isHateSpeech ? '🚨' : '⚠️';
    final title       = isHateSpeech
        ? 'Hate Speech Detected!'
        : 'Harsh Language Detected!';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: alertColor, width: 1.5),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: alertColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onDismiss,
                child: Text(
                  '✕',
                  style: TextStyle(
                    color: CeylonSpice.textLight,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          // Confidence bar
          if (isHateSpeech) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  'Confidence:',
                  style: TextStyle(color: CeylonSpice.textMid, fontSize: 12),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: confidence,
                      backgroundColor: CeylonSpice.creamDarker,
                      valueColor: AlwaysStoppedAnimation<Color>(alertColor),
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(confidence * 100).round()}%',
                  style: TextStyle(
                    color: alertColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],

          // Harsh words chips
          if (harshWords.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '🔍 Detected words (${harshWords.length}):',
              style: TextStyle(color: CeylonSpice.textMid, fontSize: 12),
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: harshWords.map((word) => Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: alertColor, width: 1.5),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white.withOpacity(0.5),
                  ),
                  child: Text(
                    word,
                    style: TextStyle(
                      color: alertColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )).toList(),
              ),
            ),
          ],

          // Info text
          const SizedBox(height: 8),
          Text(
            isHateSpeech
                ? 'This content may be offensive or harmful toward others.'
                : 'This content contains language that could be considered offensive.',
            style: TextStyle(
              color: CeylonSpice.textMid,
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
