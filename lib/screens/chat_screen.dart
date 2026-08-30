import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/chat_provider.dart';
import '../theme/ceylon_theme.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/quick_suggestions.dart';
import '../widgets/sessions_drawer.dart';
import 'location_capture_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().init();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, provider, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: CeylonSpiceTheme.darkBg,
          drawer: const SessionsDrawer(),

          appBar: AppBar(
            backgroundColor: CeylonSpiceTheme.darkSurface,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.menu, color: CeylonSpiceTheme.textSecondary),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            title: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [CeylonSpiceTheme.deepJungle, CeylonSpiceTheme.saffron],
                    ),
                  ),
                  child: const Center(child: Text('🌴', style: TextStyle(fontSize: 16))),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ceylon Travel Planner',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: CeylonSpiceTheme.textPrimary,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: CeylonSpiceTheme.saffron,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Sri Lanka Tour Guide',
                          style: GoogleFonts.lato(fontSize: 10, color: CeylonSpiceTheme.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.travel_explore_rounded, color: CeylonSpiceTheme.saffron),
                tooltip: 'Location Identifier',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LocationCaptureScreen()),
                  );
                },
              ),
              if (provider.isSpeaking)
                IconButton(
                  icon: const Icon(Icons.stop_circle, color: CeylonSpiceTheme.cinnamon),
                  onPressed: provider.stopSpeaking,
                  tooltip: 'Stop speaking',
                ),
            ],
          ),

          body: provider.sessionsLoading && provider.activeSession == null
              ? const Center(child: CircularProgressIndicator(color: CeylonSpiceTheme.saffron))
              : Column(
                  children: [
                    if (provider.activeSession != null && provider.activeSession!.title != 'New Chat')
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        color: CeylonSpiceTheme.darkCard,
                        child: Text(
                          provider.activeSession!.title,
                          style: GoogleFonts.lato(fontSize: 12, color: CeylonSpiceTheme.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    Expanded(
                      child: provider.messages.isEmpty
                          ? _EmptyState()
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              itemCount: provider.messages.length,
                              itemBuilder: (context, i) {
                                return ChatBubble(message: provider.messages[i]);
                              },
                            ),
                    ),
                    const QuickSuggestions(),
                    const ChatInputBar(),
                  ],
                ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [CeylonSpiceTheme.deepJungle, CeylonSpiceTheme.saffron],
              ),
              boxShadow: [
                BoxShadow(color: CeylonSpiceTheme.saffron.withOpacity(0.3), blurRadius: 20),
              ],
            ),
            child: const Center(child: Text('🌴', style: TextStyle(fontSize: 40))),
          ),
          const SizedBox(height: 16),
          Text(
            'Ceylon Travel Planner',
            style: GoogleFonts.playfairDisplay(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: CeylonSpiceTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your AI guide to Sri Lanka 🌴',
            style: GoogleFonts.lato(fontSize: 14, color: CeylonSpiceTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}