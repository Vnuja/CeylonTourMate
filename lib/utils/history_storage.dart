// lib/utils/history_storage.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HistoryEntry {
  final String id;
  final String text;
  final bool isHateSpeech;
  final double confidence;
  final List<String> harshWords;
  final DateTime timestamp;
  final String inputMode; // 'voice' or 'manual'

  HistoryEntry({
    required this.id,
    required this.text,
    required this.isHateSpeech,
    required this.confidence,
    required this.harshWords,
    required this.timestamp,
    required this.inputMode,
  });

  Map<String, dynamic> toJson() => {
    'id':          id,
    'text':        text,
    'isHateSpeech': isHateSpeech,
    'confidence':  confidence,
    'harshWords':  harshWords,
    'timestamp':   timestamp.millisecondsSinceEpoch,
    'inputMode':   inputMode,
  };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
    id:           json['id'],
    text:         json['text'],
    isHateSpeech: json['isHateSpeech'],
    confidence:   json['confidence'],
    harshWords:   List<String>.from(json['harshWords']),
    timestamp:    DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
    inputMode:    json['inputMode'],
  );
}

class HistoryStorage {
  // Base prefix; the actual key is suffixed with the signed-in user's uid
  // so each account gets its own history instead of sharing one global list.
  static const String _keyPrefix = 'detection_history';
  static const int    _maxSize   = 50;

  /// Returns a storage key unique to the currently signed-in user.
  /// Falls back to a 'guest' bucket if nobody is signed in, so the app
  /// still works before login / for anonymous use.
  static String _keyForCurrentUser() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    return '${_keyPrefix}_$uid';
  }

  static Future<void> save(HistoryEntry entry) async {
    final prefs   = await SharedPreferences.getInstance();
    final key     = _keyForCurrentUser();
    final list    = await load();
    list.insert(0, entry);
    final trimmed = list.take(_maxSize).toList();
    final encoded = json.encode(trimmed.map((e) => e.toJson()).toList());
    await prefs.setString(key, encoded);
  }

  static Future<List<HistoryEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final key   = _keyForCurrentUser();
    final raw   = prefs.getString(key);
    if (raw == null) return [];
    final List<dynamic> decoded = json.decode(raw);
    return decoded.map((e) => HistoryEntry.fromJson(e)).toList();
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    final key   = _keyForCurrentUser();
    await prefs.remove(key);
  }

  /// One-time migration helper: if this device has history saved under the
  /// old global (non-user-scoped) key from before this fix, move it into
  /// the current user's bucket instead of silently losing it. Safe to call
  /// on every app start — it's a no-op once the legacy key is gone.
  static Future<void> migrateLegacyGlobalHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final legacyRaw = prefs.getString(_keyPrefix);
    if (legacyRaw == null) return;

    final newKey = _keyForCurrentUser();
    // Don't overwrite existing per-user data with the legacy blob.
    if (!prefs.containsKey(newKey)) {
      await prefs.setString(newKey, legacyRaw);
    }
    await prefs.remove(_keyPrefix);
  }
}