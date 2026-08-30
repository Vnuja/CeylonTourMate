import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';

enum TtsState { playing, stopped, paused }

class VoiceService {
  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _stt = stt.SpeechToText();

  TtsState ttsState = TtsState.stopped;
  bool _sttAvailable = false;
  bool _sttListening = false;

  // Callbacks
  Function(String)? onSttResult;
  Function(String)? onSttPartialResult;
  Function()? onSttDone;
  Function()? onTtsDone;

  Future<void> init() async {
    // ── TTS Setup ──────────────────────────────────────────
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    _tts.setStartHandler(() => ttsState = TtsState.playing);
    _tts.setCompletionHandler(() {
      ttsState = TtsState.stopped;
      onTtsDone?.call();
    });
    _tts.setCancelHandler(() => ttsState = TtsState.stopped);
    _tts.setPauseHandler(() => ttsState = TtsState.paused);
    _tts.setContinueHandler(() => ttsState = TtsState.playing);

    // ── STT Setup ──────────────────────────────────────────
    _sttAvailable = await _stt.initialize(
      onError: (error) => print('STT Error: $error'),
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          _sttListening = false;
          onSttDone?.call();
        }
      },
    );
  }

  // ── TTS ────────────────────────────────────────────────

  String _cleanForSpeech(String text) {
    // 1. Strip all emojis (unicode ranges)
    String result = text
        .replaceAll(RegExp(r'[\u{1F000}-\u{1FFFF}]', unicode: true), '')
        .replaceAll(RegExp(r'[\u{2600}-\u{27BF}]', unicode: true), '')
        .replaceAll(RegExp(r'[\u{FE00}-\u{FE0F}]', unicode: true), '')
        .replaceAll(RegExp(r'[\u{20E3}]', unicode: true), '')
        .replaceAll(RegExp(r'[\u{200D}]', unicode: true), '');

    // 2. Strip bold (**text**) — extract inner text
    result = result.replaceAllMapped(
      RegExp(r'\*\*(.+?)\*\*', dotAll: true),
      (m) => m.group(1) ?? '',
    );

    // 3. Strip italic (*text*) — extract inner text
    result = result.replaceAllMapped(
      RegExp(r'\*(.+?)\*', dotAll: true),
      (m) => m.group(1) ?? '',
    );

    // 4. Strip markdown headings (# ## ### etc.)
    result = result.replaceAll(RegExp(r'#{1,6}\s+'), '');

    // 5. Strip numbered list markers (1. 2. 10. etc.)
    result = result.replaceAll(RegExp(r'^\s*\d+\.\s+', multiLine: true), '');

    // 6. Strip bullet/dash list markers
    result = result.replaceAll(RegExp(r'^\s*[-•]\s+', multiLine: true), '');

    // 7. Strip markdown links [label](url) — keep label
    result = result.replaceAllMapped(
      RegExp(r'\[(.+?)\]\(.+?\)'),
      (m) => m.group(1) ?? '',
    );

    // 8. Strip code blocks (```...```)
    result = result.replaceAll(RegExp(r'```[\s\S]*?```'), '');

    // 9. Strip inline code (`code`) — extract inner text
    result = result.replaceAllMapped(
      RegExp(r'`(.+?)`'),
      (m) => m.group(1) ?? '',
    );

    // 10. Strip remaining lone markdown symbols
    result = result.replaceAll(RegExp(r'[*_~`>|]'), '');

    // 11. Collapse multiple spaces/newlines
    result = result.replaceAll(RegExp(r'\n+'), ' ');
    result = result.replaceAll(RegExp(r' {2,}'), ' ').trim();

    return result;
  }

  Future<void> speak(String text) async {
    if (ttsState == TtsState.playing) {
      await stop();
    }
    final cleaned = _cleanForSpeech(text);
    await _tts.speak(cleaned);
  }

  Future<void> stop() async {
    await _tts.stop();
    ttsState = TtsState.stopped;
  }

  Future<void> pause() async {
    await _tts.pause();
    ttsState = TtsState.paused;
  }

  bool get isSpeaking => ttsState == TtsState.playing;

  // ── STT ────────────────────────────────────────────────
  bool get sttAvailable => _sttAvailable;
  bool get isListening => _sttListening;

  Future<void> startListening() async {
    if (!_sttAvailable || _sttListening) return;
    _sttListening = true;

    await _stt.listen(
      onResult: (SpeechRecognitionResult result) {
        if (result.finalResult) {
          onSttResult?.call(result.recognizedWords);
        } else {
          onSttPartialResult?.call(result.recognizedWords);
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 4),
      localeId: 'en_US',
      cancelOnError: true,
      partialResults: true,
    );
  }

  Future<void> stopListening() async {
    await _stt.stop();
    _sttListening = false;
  }

  Future<void> cancelListening() async {
    await _stt.cancel();
    _sttListening = false;
  }

  void dispose() {
    _tts.stop();
    _stt.cancel();
  }
}
