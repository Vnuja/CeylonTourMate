import 'package:flutter/foundation.dart';
import '../models/chat_message.dart';
import '../services/groq_service.dart';
import '../services/voice_service.dart';
import '../services/session_service.dart';

enum InputMode { textInput, voiceInput }
enum OutputMode { textOnly, textAndVoice, voiceOnly }

class ChatProvider extends ChangeNotifier {
  final GroqService _groqService = GroqService();
  final VoiceService _voiceService = VoiceService();
  final SessionService _sessionService = SessionService();

  String? _uid;
  List<ChatSession> _sessions = [];
  ChatSession? _activeSession;
  bool _isLoading = false;
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _sessionsLoading = false;
  String? _sessionsError;
  String _partialSttText = '';
  InputMode _inputMode = InputMode.textInput;
  OutputMode _outputMode = OutputMode.textOnly;

  // ── Getters ────────────────────────────────────────────
  List<ChatSession> get sessions => _sessions;
  ChatSession? get activeSession => _activeSession;
  List<ChatMessage> get messages => _activeSession?.messages ?? [];
  bool get isLoading => _isLoading;
  bool get isListening => _isListening;
  bool get isSpeaking => _isSpeaking;
  bool get sessionsLoading => _sessionsLoading;
  String? get sessionsError => _sessionsError;
  String get partialSttText => _partialSttText;
  InputMode get inputMode => _inputMode;
  OutputMode get outputMode => _outputMode;

  static const String _welcomeMessage =
      'Ayubowan! 🌴 I\'m **Serendib**, your AI Virtual Tour Guide for Sri Lanka.\n\n'
      'I can help you discover beautiful destinations, cultural experiences, '
      'travel packages, local cuisine, and everything you need for an unforgettable '
      'journey through the Pearl of the Indian Ocean!\n\n'
      '**What would you like to explore?**\n'
      '- 🏯 Historical sites (Sigiriya, Galle Fort)\n'
      '- 🐘 Wildlife safaris (Yala, Udawalawe)\n'
      '- 🏖️ Beaches (Mirissa, Unawatuna)\n'
      '- 🍛 Local food & cuisine\n'
      '- 🚂 Travel packages & itineraries';

  // ── Init (voice only — session loading happens via setUser) ─
  Future<void> init() async {
    await _voiceService.init();

    _voiceService.onSttResult = (text) {
      _partialSttText = '';
      _isListening = false;
      notifyListeners();
      sendMessage(text);
    };

    _voiceService.onSttPartialResult = (text) {
      _partialSttText = text;
      notifyListeners();
    };

    _voiceService.onSttDone = () {
      _isListening = false;
      notifyListeners();
    };

    _voiceService.onTtsDone = () {
      _isSpeaking = false;
      notifyListeners();
    };
  }

  /// Call this when the logged-in user changes (login/logout).
  /// Loads that user's chat history from Firebase, or clears state on logout.
  Future<void> setUser(String? uid) async {
    if (_uid == uid) return;
    _uid = uid;
    _sessions = [];
    _activeSession = null;
    _sessionsError = null;

    if (uid == null) {
      _sessionsLoading = false;
      notifyListeners();
      return;
    }

    _sessionsLoading = true;
    notifyListeners();

    try {
      await _loadSessions();
    } catch (e) {
      // Never leave the UI stuck — surface the error and fall back
      // to a fresh session so the chat is always usable.
      _sessionsError = e.toString();
      if (_sessions.isEmpty) {
        await createNewSession();
      }
    } finally {
      _sessionsLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadSessions() async {
    if (_uid == null) return;
    _sessions = await _sessionService.loadSessions(_uid!);
    if (_sessions.isEmpty) {
      await createNewSession();
    } else {
      final activeId = await _sessionService.loadActiveSessionId(_uid!);
      _activeSession = _sessions.firstWhere(
        (s) => s.id == activeId,
        orElse: () => _sessions.first,
      );
    }
  }

  // ── Session Management ─────────────────────────────────
  Future<void> createNewSession() async {
    if (_uid == null) return;
    final session = ChatSession(
      title: 'New Chat',
      messages: [
        ChatMessage(role: MessageRole.assistant, content: _welcomeMessage),
      ],
    );
    _sessions.insert(0, session);
    _activeSession = session;
    await _sessionService.saveSession(_uid!, session);
    await _sessionService.saveActiveSessionId(_uid!, session.id);
    notifyListeners();
  }

  Future<void> switchSession(ChatSession session) async {
    if (_uid == null) return;
    _activeSession = session;
    await _sessionService.saveActiveSessionId(_uid!, session.id);
    if (_isSpeaking) await _voiceService.stop();
    notifyListeners();
  }

  Future<void> deleteSession(String sessionId) async {
    if (_uid == null) return;
    await _sessionService.deleteSession(_uid!, sessionId, _sessions);
    if (_activeSession?.id == sessionId) {
      if (_sessions.isEmpty) {
        await createNewSession();
      } else {
        _activeSession = _sessions.first;
      }
    }
    notifyListeners();
  }

  void _updateSessionTitle(String firstMessage) {
    if (_activeSession == null) return;
    final words = firstMessage.split(' ').take(5).join(' ');
    _activeSession!.title =
        words.length > 30 ? '${words.substring(0, 30)}...' : words;
  }

  // ── Messaging ──────────────────────────────────────────
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || _activeSession == null || _uid == null) return;

    final userMsgs = messages.where((m) => m.role == MessageRole.user).length;
    if (userMsgs == 0) _updateSessionTitle(text);

    final userMsg = ChatMessage(role: MessageRole.user, content: text.trim());
    _activeSession!.messages.add(userMsg);
    _activeSession!.updatedAt = DateTime.now();
    _isLoading = true;
    notifyListeners();

    final loadingMsg = ChatMessage(role: MessageRole.assistant, content: '', isLoading: true);
    _activeSession!.messages.add(loadingMsg);
    notifyListeners();

    final response = await _groqService.sendMessage(
      _activeSession!.messages.where((m) => !m.isLoading).toList(),
    );

    _activeSession!.messages.removeLast();
    final assistantMsg = ChatMessage(role: MessageRole.assistant, content: response);
    _activeSession!.messages.add(assistantMsg);
    _isLoading = false;
    _activeSession!.updatedAt = DateTime.now();

    await _sessionService.saveSession(_uid!, _activeSession!);
    notifyListeners();

    if (_outputMode == OutputMode.textAndVoice || _outputMode == OutputMode.voiceOnly) {
      await speakText(response);
    }
  }

  // ── Voice Input ────────────────────────────────────────
  Future<void> startListening() async {
    if (_isListening) {
      await stopListening();
      return;
    }
    if (_isSpeaking) await _voiceService.stop();

    _isListening = true;
    _partialSttText = '';
    notifyListeners();
    await _voiceService.startListening();
  }

  Future<void> stopListening() async {
    await _voiceService.stopListening();
    _isListening = false;
    _partialSttText = '';
    notifyListeners();
  }

  // ── Voice Output ───────────────────────────────────────
  Future<void> speakText(String text) async {
    _isSpeaking = true;
    notifyListeners();
    await _voiceService.speak(text);
  }

  Future<void> stopSpeaking() async {
    await _voiceService.stop();
    _isSpeaking = false;
    notifyListeners();
  }

  // ── Mode Switching ─────────────────────────────────────
  void setOutputMode(OutputMode mode) {
    _outputMode = mode;
    if (mode == OutputMode.textOnly && _isSpeaking) stopSpeaking();
    notifyListeners();
  }

  void setInputMode(InputMode mode) {
    _inputMode = mode;
    notifyListeners();
  }

  @override
  void dispose() {
    _voiceService.dispose();
    super.dispose();
  }
}