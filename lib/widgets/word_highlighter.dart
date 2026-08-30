// lib/widgets/word_highlighter.dart
import 'package:flutter/material.dart';
import '../theme/ceylon_spice.dart';
import '../utils/harsh_word_detector.dart';

class WordHighlighter extends StatelessWidget {
  final List<WordAnalysis> wordAnalysis;

  const WordHighlighter({super.key, required this.wordAnalysis});

  @override
  Widget build(BuildContext context) {
    if (wordAnalysis.isEmpty) {
      return Text(
        'No text to display',
        style: TextStyle(
          color: CeylonSpice.textLight,
          fontSize: 14,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return RichText(
      text: TextSpan(
        children: wordAnalysis.asMap().entries.map((entry) {
          final idx  = entry.key;
          final item = entry.value;
          final isLast = idx == wordAnalysis.length - 1;

          if (item.isHarsh) {
            return TextSpan(
              children: [
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                    decoration: BoxDecoration(
                      color: CeylonSpice.danger.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      item.word,
                      style: const TextStyle(
                        color: CeylonSpice.danger,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                        decorationColor: CeylonSpice.danger,
                      ),
                    ),
                  ),
                ),
                if (!isLast)
                  const TextSpan(
                    text: ' ',
                    style: TextStyle(fontSize: 17),
                  ),
              ],
            );
          }

          return TextSpan(
            text: isLast ? item.word : '${item.word} ',
            style: const TextStyle(
              color: CeylonSpice.text,
              fontSize: 17,
              height: 1.7,
            ),
          );
        }).toList(),
      ),
    );
  }
}
