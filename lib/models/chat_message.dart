import 'package:uuid/uuid.dart';

enum MessageRole { user, assistant }
enum OutputMode { textOnly, textAndVoice, voiceOnly }

class ChatMessage {
  final String id;
  final MessageRole role;
  final String content;
  final DateTime timestamp;
  final bool isLoading;

  ChatMessage({
    String? id,
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.isLoading = false,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  ChatMessage copyWith({
    String? content,
    bool? isLoading,
  }) {
    return ChatMessage(
      id: id,
      role: role,
      content: content ?? this.content,
      timestamp: timestamp,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role.name,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        role: MessageRole.values.byName(json['role'] as String),
        content: json['content'] as String? ?? '',
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

class ChatSession {
  final String id;
  String title;
  final List<ChatMessage> messages;
  final DateTime createdAt;
  DateTime updatedAt;

  ChatSession({
    String? id,
    String? title,
    List<ChatMessage>? messages,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        title = title ?? 'New Chat',
        messages = messages ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'messages': messages.map((m) => m.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  /// Safely converts a raw dynamic value coming back from Firebase
  /// (which may be Map<Object?, Object?>) into Map<String, dynamic>.
  static Map<String, dynamic> _asStringKeyedMap(dynamic value) {
    return Map<String, dynamic>.from(value as Map);
  }

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    final rawMessages = json['messages'];
    final List<ChatMessage> messages = [];

    if (rawMessages is List) {
      for (final m in rawMessages) {
        if (m == null) continue; // Firebase can leave nulls for gaps
        messages.add(ChatMessage.fromJson(_asStringKeyedMap(m)));
      }
    } else if (rawMessages is Map) {
      // Firebase sometimes returns a Map instead of a List when array
      // indices aren't perfectly sequential (e.g. after certain writes).
      final map = _asStringKeyedMap(rawMessages);
      final sortedKeys = map.keys.toList()
        ..sort((a, b) {
          final ai = int.tryParse(a) ?? 0;
          final bi = int.tryParse(b) ?? 0;
          return ai.compareTo(bi);
        });
      for (final k in sortedKeys) {
        if (map[k] == null) continue;
        messages.add(ChatMessage.fromJson(_asStringKeyedMap(map[k])));
      }
    }

    return ChatSession(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'New Chat',
      messages: messages,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}