import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/chat_provider.dart';
import '../theme/ceylon_theme.dart';

class OutputModeSelector extends StatelessWidget {
  const OutputModeSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(builder: (context, provider, _) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: CeylonSpiceTheme.darkCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: CeylonSpiceTheme.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ModeChip(
              icon: Icons.text_fields,
              label: 'Text',
              isActive: provider.outputMode == OutputMode.textOnly,
              onTap: () => provider.setOutputMode(OutputMode.textOnly),
            ),
            _ModeChip(
              icon: Icons.record_voice_over,
              label: 'Text+Voice',
              isActive: provider.outputMode == OutputMode.textAndVoice,
              onTap: () => provider.setOutputMode(OutputMode.textAndVoice),
            ),
            _ModeChip(
              icon: Icons.headphones,
              label: 'Voice',
              isActive: provider.outputMode == OutputMode.voiceOnly,
              onTap: () => provider.setOutputMode(OutputMode.voiceOnly),
            ),
          ],
        ),
      );
    });
  }
}

class _ModeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ModeChip({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: isActive
              ? CeylonSpiceTheme.deepJungle.withOpacity(0.8)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isActive
                  ? CeylonSpiceTheme.saffron
                  : CeylonSpiceTheme.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.lato(
                fontSize: 11,
                color: isActive
                    ? CeylonSpiceTheme.textPrimary
                    : CeylonSpiceTheme.textSecondary,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
