import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/chat_provider.dart';
import '../theme/ceylon_theme.dart';

class ChatInputBar extends StatefulWidget {
  const ChatInputBar({super.key});

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulseAnimation = Tween(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _send(ChatProvider provider) {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    provider.sendMessage(text);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, provider, _) {
        final isVoiceInput = provider.inputMode == InputMode.voiceInput;
        final isListening = provider.isListening;

        return Container(
          color: CeylonSpiceTheme.darkSurface,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Partial STT text preview ────────────────
              if (isListening && provider.partialSttText.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  color: CeylonSpiceTheme.deepJungle.withOpacity(0.2),
                  child: Text(
                    provider.partialSttText,
                    style: GoogleFonts.lato(
                      color: CeylonSpiceTheme.textSecondary,
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),

              const Divider(height: 1, color: CeylonSpiceTheme.divider),

              Padding(
                padding: EdgeInsets.only(
                  left: 12,
                  right: 12,
                  top: 8,
                  bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 8 : 20,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // ── Input Mode Toggle ─────────────────
                    _ModeToggle(),

                    const SizedBox(width: 8),

                    // ── Text Field or Voice Indicator ─────
                    Expanded(
                      child: isVoiceInput
                          ? _VoiceInputWidget(
                              isListening: isListening,
                              pulseAnimation: _pulseAnimation,
                              onTap: () => provider.startListening(),
                            )
                          : _TextInputField(
                              controller: _controller,
                              focusNode: _focusNode,
                              onSend: () => _send(provider),
                            ),
                    ),

                    const SizedBox(width: 8),

                    // ── Output Mode Popup ─────────────────
                    _OutputModeButton(),

                    const SizedBox(width: 6),

                    // ── Send / Mic Button ─────────────────
                    _SendButton(
                      isVoiceInput: isVoiceInput,
                      isListening: isListening,
                      controller: _controller,
                      onTap: () {
                        if (isVoiceInput) {
                          provider.startListening();
                        } else {
                          _send(provider);
                        }
                      },
                      onStop: provider.stopListening,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Mode Toggle ───────────────────────────────────────────
class _ModeToggle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, provider, _) {
        final isVoice = provider.inputMode == InputMode.voiceInput;
        return GestureDetector(
          onTap: () => provider.setInputMode(
            isVoice ? InputMode.textInput : InputMode.voiceInput,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isVoice
                  ? CeylonSpiceTheme.cinnamon.withOpacity(0.2)
                  : CeylonSpiceTheme.darkCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isVoice
                    ? CeylonSpiceTheme.cinnamon
                    : CeylonSpiceTheme.divider,
              ),
            ),
            child: Icon(
              isVoice ? Icons.keyboard : Icons.mic_none,
              color: isVoice
                  ? CeylonSpiceTheme.cinnamon
                  : CeylonSpiceTheme.textSecondary,
              size: 18,
            ),
          ),
        );
      },
    );
  }
}

// ── Text Input Field ──────────────────────────────────────
class _TextInputField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;

  const _TextInputField({
    required this.controller,
    required this.focusNode,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CeylonSpiceTheme.inputBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: CeylonSpiceTheme.divider),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        maxLines: 4,
        minLines: 1,
        onSubmitted: (_) => onSend(),
        textInputAction: TextInputAction.send,
        style: GoogleFonts.lato(
          fontSize: 15,
          color: CeylonSpiceTheme.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: 'Ask about Sri Lanka...',
          hintStyle: GoogleFonts.lato(
            color: CeylonSpiceTheme.textSecondary.withOpacity(0.5),
            fontSize: 14,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
        ),
      ),
    );
  }
}

// ── Voice Input Widget ────────────────────────────────────
class _VoiceInputWidget extends StatelessWidget {
  final bool isListening;
  final Animation<double> pulseAnimation;
  final VoidCallback onTap;

  const _VoiceInputWidget({
    required this.isListening,
    required this.pulseAnimation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 44,
        decoration: BoxDecoration(
          color: isListening
              ? CeylonSpiceTheme.cinnamon.withOpacity(0.15)
              : CeylonSpiceTheme.inputBg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isListening
                ? CeylonSpiceTheme.cinnamon
                : CeylonSpiceTheme.divider,
          ),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isListening) ...[
                ScaleTransition(
                  scale: pulseAnimation,
                  child: const Icon(
                    Icons.mic,
                    color: CeylonSpiceTheme.cinnamon,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Listening...',
                  style: GoogleFonts.lato(
                    color: CeylonSpiceTheme.cinnamon,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ] else ...[
                const Icon(
                  Icons.mic_none,
                  color: CeylonSpiceTheme.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Tap to speak',
                  style: GoogleFonts.lato(
                    color: CeylonSpiceTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Send Button ───────────────────────────────────────────
class _SendButton extends StatelessWidget {
  final bool isVoiceInput;
  final bool isListening;
  final TextEditingController controller;
  final VoidCallback onTap;
  final VoidCallback onStop;

  const _SendButton({
    required this.isVoiceInput,
    required this.isListening,
    required this.controller,
    required this.onTap,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, provider, _) {
        final showStop = isListening || provider.isLoading;

        return GestureDetector(
          onTap: showStop ? onStop : onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: showStop
                  ? null
                  : const LinearGradient(
                      colors: [
                        CeylonSpiceTheme.deepJungle,
                        CeylonSpiceTheme.saffron,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              color: showStop ? CeylonSpiceTheme.darkCard : null,
              shape: BoxShape.circle,
              boxShadow: showStop
                  ? null
                  : [
                      BoxShadow(
                        color: CeylonSpiceTheme.saffron.withOpacity(0.3),
                        blurRadius: 8,
                      ),
                    ],
            ),
            child: Icon(
              showStop
                  ? Icons.stop
                  : (isVoiceInput ? Icons.mic : Icons.send_rounded),
              color: showStop
                  ? CeylonSpiceTheme.textSecondary
                  : CeylonSpiceTheme.coconutCream,
              size: 20,
            ),
          ),
        );
      },
    );
  }
}

// ── Output Mode Popup Button ──────────────────────────────
class _OutputModeButton extends StatelessWidget {
  static IconData _iconFor(OutputMode m) {
    switch (m) {
      case OutputMode.textAndVoice:
        return Icons.record_voice_over;
      case OutputMode.voiceOnly:
        return Icons.headphones;
      default:
        return Icons.text_fields;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, provider, _) {
        return GestureDetector(
          onTap: () => _showPopup(context, provider),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: provider.outputMode != OutputMode.textOnly
                  ? CeylonSpiceTheme.cinnamon.withOpacity(0.15)
                  : CeylonSpiceTheme.darkCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: provider.outputMode != OutputMode.textOnly
                    ? CeylonSpiceTheme.cinnamon
                    : CeylonSpiceTheme.divider,
              ),
            ),
            child: Icon(
              _iconFor(provider.outputMode),
              size: 17,
              color: provider.outputMode != OutputMode.textOnly
                  ? CeylonSpiceTheme.cinnamon
                  : CeylonSpiceTheme.textSecondary,
            ),
          ),
        );
      },
    );
  }

  void _showPopup(BuildContext context, ChatProvider provider) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset offset = box.localToGlobal(Offset.zero);

    showMenu<OutputMode>(
      context: context,
      color: CeylonSpiceTheme.darkCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: CeylonSpiceTheme.divider),
      ),
      position: RelativeRect.fromLTRB(
        offset.dx - 120,
        offset.dy - 170,
        offset.dx + 40,
        offset.dy,
      ),
      items: [
        _modeItem(
          OutputMode.textOnly,
          Icons.text_fields,
          'Text only',
          provider,
        ),
        _modeItem(
          OutputMode.textAndVoice,
          Icons.record_voice_over,
          'Text + Voice',
          provider,
        ),
        _modeItem(
          OutputMode.voiceOnly,
          Icons.headphones,
          'Voice only',
          provider,
        ),
      ],
    ).then((selected) {
      if (selected != null) provider.setOutputMode(selected);
    });
  }

  PopupMenuItem<OutputMode> _modeItem(
    OutputMode mode,
    IconData icon,
    String label,
    ChatProvider provider,
  ) {
    final isSelected = provider.outputMode == mode;
    return PopupMenuItem<OutputMode>(
      value: mode,
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected
                ? CeylonSpiceTheme.saffron
                : CeylonSpiceTheme.textSecondary,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: GoogleFonts.lato(
              fontSize: 13,
              color: isSelected
                  ? CeylonSpiceTheme.textPrimary
                  : CeylonSpiceTheme.textSecondary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          if (isSelected) ...[
            const Spacer(),
            const Icon(Icons.check, size: 14, color: CeylonSpiceTheme.saffron),
          ],
        ],
      ),
    );
  }
}
