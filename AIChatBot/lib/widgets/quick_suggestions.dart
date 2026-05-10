import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/chat_provider.dart';
import '../theme/ceylon_theme.dart';

class QuickSuggestions extends StatelessWidget {
  const QuickSuggestions({super.key});

  static const List<Map<String, String>> _suggestions = [
    {'emoji': '🏯', 'text': 'Tell me about Sigiriya'},
    {'emoji': '🏖️', 'text': 'Best beaches in Sri Lanka'},
    {'emoji': '🗺️', 'text': '7-day tour package'},
    {'emoji': '🐘', 'text': 'Wildlife safari options'},
    {'emoji': '🍛', 'text': 'Must-try local foods'},
    {'emoji': '🚂', 'text': 'Getting around Sri Lanka'},
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(builder: (context, provider, _) {
      // Only show suggestions when there's only the welcome message
      final userMessages =
          provider.messages.where((m) => m.role.name == 'user').length;
      if (userMessages > 0) return const SizedBox.shrink();

      return Container(
        height: 40,
        margin: const EdgeInsets.only(bottom: 8),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: _suggestions.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final s = _suggestions[i];
            return GestureDetector(
              onTap: () => provider.sendMessage(s['text']!),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: CeylonSpiceTheme.darkCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: CeylonSpiceTheme.divider),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(s['emoji']!,
                        style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(
                      s['text']!,
                      style: GoogleFonts.lato(
                        fontSize: 12,
                        color: CeylonSpiceTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    });
  }
}
