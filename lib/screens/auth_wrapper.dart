import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart' as app_auth;
import '../services/chat_provider.dart';
import '../utils/history_storage.dart';
import 'login_screen.dart';
import 'main_shell.dart';

/// Decides whether to show the logged-out flow (Login/Register) or the
/// main app shell that hosts every merged feature (Explore, Chat, Albums,
/// Recommendations, Harsh-Word Detector, Profile).
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<app_auth.AuthProvider>();

    if (auth.isLoggedIn && auth.firebaseUser != null) {
      // Let the chat feature know which user is active so it can load
      // their saved chat sessions.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<ChatProvider>().setUser(auth.firebaseUser!.uid);

        // One-time migration: move any detection history saved under the
        // old, non-user-scoped storage key into this user's own bucket so
        // history keeps working per-account going forward. No-op once the
        // legacy key has been migrated away.
        HistoryStorage.migrateLegacyGlobalHistory();
      });
      return const MainShell();
    }

    // Logged out — clear any loaded chat history from memory.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().setUser(null);
    });

    return const LoginScreen();
  }
}