import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../models/chat_message.dart';
import '../services/chat_provider.dart';
import '../theme/ceylon_theme.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;
    final isLoading = message.isLoading;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            _BotAvatar(),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isUser)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: Text(
                      'Serendib',
                      style: GoogleFonts.lato(
                        fontSize: 11,
                        color: CeylonSpiceTheme.saffron,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                GestureDetector(
                  onLongPress: () => _copyToClipboard(context, message.content),
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.78,
                    ),
                    decoration: BoxDecoration(
                      color: isUser
                          ? CeylonSpiceTheme.userBubble
                          : CeylonSpiceTheme.botBubble,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isUser ? 18 : 4),
                        bottomRight: Radius.circular(isUser ? 4 : 18),
                      ),
                      border: Border.all(
                        color: isUser
                            ? CeylonSpiceTheme.deepJungle.withOpacity(0.5)
                            : CeylonSpiceTheme.divider,
                        width: 0.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    child: isLoading
                        ? _LoadingIndicator()
                        : isUser
                            ? Text(
                                message.content,
                                style: GoogleFonts.lato(
                                  fontSize: 15,
                                  color: CeylonSpiceTheme.textPrimary,
                                  height: 1.4,
                                ),
                              )
                            : MarkdownBody(
                                data: message.content,
                                styleSheet: _markdownStyle(),
                                shrinkWrap: true,
                              ),
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('h:mm a').format(message.timestamp),
                      style: GoogleFonts.lato(
                        fontSize: 10,
                        color: CeylonSpiceTheme.textSecondary.withOpacity(0.6),
                      ),
                    ),
                    if (!isUser) ...[
                      const SizedBox(width: 6),
                      _SpeakButton(message: message),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            _UserAvatar(),
          ],
        ],
      ),
    );
  }

  MarkdownStyleSheet _markdownStyle() => MarkdownStyleSheet(
        p: GoogleFonts.lato(
            fontSize: 15,
            color: CeylonSpiceTheme.textPrimary,
            height: 1.5),
        strong: GoogleFonts.lato(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: CeylonSpiceTheme.saffron),
        h1: GoogleFonts.playfairDisplay(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: CeylonSpiceTheme.textPrimary),
        h2: GoogleFonts.playfairDisplay(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: CeylonSpiceTheme.textPrimary),
        h3: GoogleFonts.lato(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: CeylonSpiceTheme.saffron),
        listBullet: GoogleFonts.lato(
            fontSize: 15, color: CeylonSpiceTheme.textPrimary),
        code: GoogleFonts.firaCode(
          fontSize: 13,
          color: CeylonSpiceTheme.saffron,
          backgroundColor: CeylonSpiceTheme.darkBg,
        ),
        blockquoteDecoration: BoxDecoration(
          color: CeylonSpiceTheme.darkBg,
          border: Border(
            left: BorderSide(
              color: CeylonSpiceTheme.saffron,
              width: 3,
            ),
          ),
        ),
      );

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied to clipboard',
            style: GoogleFonts.lato(color: Colors.white)),
        backgroundColor: CeylonSpiceTheme.deepJungle,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _BotAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [CeylonSpiceTheme.deepJungle, CeylonSpiceTheme.saffron],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: CeylonSpiceTheme.saffron.withOpacity(0.3),
            blurRadius: 6,
          ),
        ],
      ),
      child: const Center(
        child: Text('🌴', style: TextStyle(fontSize: 16)),
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: CeylonSpiceTheme.cinnamon.withOpacity(0.3),
        border: Border.all(color: CeylonSpiceTheme.cinnamon, width: 1.5),
      ),
      child: const Icon(Icons.person, color: CeylonSpiceTheme.cinnamon, size: 18),
    );
  }
}

class _LoadingIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: CeylonSpiceTheme.darkCard,
      highlightColor: CeylonSpiceTheme.saffron.withOpacity(0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 200, height: 12,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 150, height: 12,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 180, height: 12,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeakButton extends StatelessWidget {
  final ChatMessage message;
  const _SpeakButton({required this.message});

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, provider, _) {
        return GestureDetector(
          onTap: () {
            if (provider.isSpeaking) {
              provider.stopSpeaking();
            } else {
              provider.speakText(message.content);
            }
          },
          child: Icon(
            provider.isSpeaking ? Icons.stop_circle : Icons.volume_up_outlined,
            size: 14,
            color: CeylonSpiceTheme.saffron.withOpacity(0.7),
          ),
        );
      },
    );
  }
}
