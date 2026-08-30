import 'package:firebase_database/firebase_database.dart';
import '../models/chat_message.dart';

class SessionService {
  final DatabaseReference _sessionsRef = FirebaseDatabase.instance.ref('chat_sessions');
  final DatabaseReference _activeRef = FirebaseDatabase.instance.ref('active_chat_session');

  Future<List<ChatSession>> loadSessions(String uid) async {
    final snapshot = await _sessionsRef.child(uid).get();
    if (!snapshot.exists || snapshot.value == null) return [];

    final map = Map<String, dynamic>.from(snapshot.value as Map);
    final sessions = <ChatSession>[];

    for (final entry in map.entries) {
      try {
        final sessionMap = Map<String, dynamic>.from(entry.value as Map);
        sessions.add(ChatSession.fromJson(sessionMap));
      } catch (e) {
        // Skip a single corrupted session instead of failing the whole load.
        // ignore: avoid_print
        print('Skipping corrupted chat session ${entry.key}: $e');
      }
    }

    sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sessions;
  }

  Future<void> saveSession(String uid, ChatSession session) async {
    await _sessionsRef.child(uid).child(session.id).set(session.toJson());
  }

  Future<void> deleteSession(String uid, String id, List<ChatSession> sessions) async {
    sessions.removeWhere((s) => s.id == id);
    await _sessionsRef.child(uid).child(id).remove();
  }

  Future<void> saveActiveSessionId(String uid, String id) async {
    await _activeRef.child(uid).set(id);
  }

  Future<String?> loadActiveSessionId(String uid) async {
    final snapshot = await _activeRef.child(uid).get();
    if (!snapshot.exists) return null;
    return snapshot.value as String?;
  }
}