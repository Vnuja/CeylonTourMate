import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/chat_message.dart';
import '../services/chat_provider.dart';
import '../theme/ceylon_theme.dart';

class SessionsDrawer extends StatelessWidget {
  const SessionsDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, provider, _) {
        return Drawer(
          backgroundColor: CeylonSpiceTheme.darkSurface,
          child: Column(
            children: [
              // Header
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      CeylonSpiceTheme.deepJungle,
                      CeylonSpiceTheme.darkSurface,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(16, 52, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [
                                CeylonSpiceTheme.deepJungle,
                                CeylonSpiceTheme.saffron
                              ],
                            ),
                            border: Border.all(
                                color: CeylonSpiceTheme.saffron, width: 1.5),
                          ),
                          child: const Center(
                            child: Text('🌴', style: TextStyle(fontSize: 20)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Serendib',
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: CeylonSpiceTheme.textPrimary,
                                )),
                            Text('Sri Lanka Tour Guide',
                                style: GoogleFonts.lato(
                                  fontSize: 11,
                                  color: CeylonSpiceTheme.saffron,
                                )),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          provider.createNewSession();
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.add, size: 18),
                        label: Text('New Chat',
                            style: GoogleFonts.lato(
                                fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CeylonSpiceTheme.cinnamon,
                          foregroundColor: CeylonSpiceTheme.coconutCream,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Sessions label
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.history,
                        size: 14, color: CeylonSpiceTheme.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      'Chat History',
                      style: GoogleFonts.lato(
                        fontSize: 11,
                        color: CeylonSpiceTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),

              // Sessions List
              Expanded(
                child: provider.sessions.isEmpty
                    ? Center(
                        child: Text(
                          'No chats yet',
                          style: GoogleFonts.lato(
                              color: CeylonSpiceTheme.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        itemCount: provider.sessions.length,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        itemBuilder: (context, i) {
                          final session = provider.sessions[i];
                          final isActive =
                              session.id == provider.activeSession?.id;
                          return _SessionTile(
                            session: session,
                            isActive: isActive,
                            onTap: () {
                              provider.switchSession(session);
                              Navigator.pop(context);
                            },
                            onDelete: () =>
                                provider.deleteSession(session.id),
                          );
                        },
                      ),
              ),

              // Bottom: version
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Serendib v1.0 • Travel AI',
                  style: GoogleFonts.lato(
                    fontSize: 10,
                    color: CeylonSpiceTheme.textSecondary.withOpacity(0.5),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SessionTile extends StatelessWidget {
  final ChatSession session;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _SessionTile({
    required this.session,
    required this.isActive,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(session.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.red),
      ),
      onDismissed: (_) => onDelete(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          color: isActive
              ? CeylonSpiceTheme.deepJungle.withOpacity(0.3)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isActive
              ? Border.all(
                  color: CeylonSpiceTheme.deepJungle.withOpacity(0.5),
                  width: 0.5)
              : null,
        ),
        child: ListTile(
          dense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          leading: Icon(
            Icons.chat_bubble_outline,
            size: 16,
            color: isActive
                ? CeylonSpiceTheme.saffron
                : CeylonSpiceTheme.textSecondary,
          ),
          title: Text(
            session.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.lato(
              fontSize: 13,
              color: isActive
                  ? CeylonSpiceTheme.textPrimary
                  : CeylonSpiceTheme.textSecondary,
              fontWeight:
                  isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          subtitle: Text(
            _formatDate(session.updatedAt),
            style: GoogleFonts.lato(
              fontSize: 10,
              color: CeylonSpiceTheme.textSecondary.withOpacity(0.6),
            ),
          ),
          onTap: onTap,
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return DateFormat('h:mm a').format(dt);
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return DateFormat('EEEE').format(dt);
    return DateFormat('MMM d').format(dt);
  }
}
