// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../theme/ceylon_spice.dart';
import '../utils/model_inference.dart';
import '../utils/harsh_word_detector.dart';
import '../utils/history_storage.dart';
import '../widgets/mic_button.dart';
import '../widgets/harsh_word_alert.dart';
import '../widgets/result_card.dart';
import '../widgets/word_highlighter.dart';

class DetectorHomeScreen extends StatefulWidget {
  const DetectorHomeScreen({super.key});

  @override
  State<DetectorHomeScreen> createState() => _DetectorHomeScreenState();
}

class _DetectorHomeScreenState extends State<DetectorHomeScreen> {
  // Model
  final ModelInference _model = ModelInference();
  bool _isModelReady = false;

  // Speech
  final SpeechToText _speech = SpeechToText();
  bool _isListening = false;
  String _partialText = '';
  bool _speechAvailable = false;

  // Input
  String _inputMode = 'voice'; // 'voice' or 'manual'
  final TextEditingController _textController = TextEditingController();

  // Results
  bool _isAnalyzing = false;
  String _displayText = '';
  PredictionResult? _result;
  List<String> _harshWords = [];
  List<WordAnalysis> _wordAnalysis = [];
  bool _showAlert = false;

  @override
  void initState() {
    super.initState();
    _initModel();
    _initSpeech();
    _textController.addListener(() => setState(() {})); // ← add this

  }

  Future<void> _initModel() async {
    final loaded = await _model.load();
    setState(() => _isModelReady = loaded);
    if (!loaded && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to load model. Check assets/model/ folder.'),
          backgroundColor: CeylonSpice.danger,
        ),
      );
    }
  }

  Future<void> _initSpeech() async {
    final available = await _speech.initialize(
      onError: (error) => setState(() => _isListening = false),
    );
    setState(() => _speechAvailable = available);
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    } else {
      _clearResults();
      setState(() { _isListening = true; _partialText = ''; });

      await _speech.listen(
        localeId: 'si_LK', // Sinhala (Sri Lanka)
        onResult: (result) {
          setState(() => _partialText = result.recognizedWords);
          if (result.finalResult && result.recognizedWords.isNotEmpty) {
            setState(() {
              _isListening = false;
              _displayText = result.recognizedWords;
              _partialText = '';
            });
            _runAnalysis(result.recognizedWords);
          }
        },
      );
    }
  }

  Future<void> _runAnalysis(String text) async {
    if (text.trim().isEmpty || !_isModelReady) return;

    setState(() {
      _isAnalyzing = true;
      _result = null;
      _harshWords = [];
      _wordAnalysis = [];
      _showAlert = false;
    });

    // Run model inference
    final prediction = await _model.predict(text);

    // Run harsh word detection
    final words      = _model.tokenizer.extractWords(text);
    final analysis   = HarshWordDetector.analyzeWords(words);
    final detected   = HarshWordDetector.getHarshWords(words);

    setState(() {
      _isAnalyzing = false;
      _result      = prediction;
      _harshWords  = detected;
      _wordAnalysis = analysis;
      _showAlert   = (prediction?.isHateSpeech ?? false) || detected.isNotEmpty;
    });

    // Save to history
    if (prediction != null) {
      await HistoryStorage.save(HistoryEntry(
        id:           DateTime.now().millisecondsSinceEpoch.toString(),
        text:         text,
        isHateSpeech: prediction.isHateSpeech,
        confidence:   prediction.confidence,
        harshWords:   detected,
        timestamp:    DateTime.now(),
        inputMode:    _inputMode,
      ));
    }
  }

  void _clearResults() {
    setState(() {
      _displayText = '';
      _result      = null;
      _harshWords  = [];
      _wordAnalysis = [];
      _showAlert   = false;
      _partialText = '';
    });
    _textController.clear();
  }

  @override
  void dispose() {
    _textController.dispose();
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CeylonSpice.coconutCream,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status badge
            _StatusBadge(isReady: _isModelReady),
            const SizedBox(height: 20),

            // Mode toggle
            _ModeToggle(
              selectedMode: _inputMode,
              onChanged: (mode) {
                setState(() => _inputMode = mode);
                _clearResults();
              },
            ),
            const SizedBox(height: 24),

            // Voice mode
            if (_inputMode == 'voice') _buildVoiceSection(),

            // Manual mode
            if (_inputMode == 'manual') _buildManualSection(),

            // Analyzing spinner
            if (_isAnalyzing) ...[
              const SizedBox(height: 20),
              Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(color: CeylonSpice.cinnamon),
                    const SizedBox(height: 10),
                    
                  ],
                ),
              ),
            ],

            // Analyzed text with highlights
            if (_displayText.isNotEmpty && !_isAnalyzing) ...[
              const SizedBox(height: 16),
              _AnalyzedTextSection(
                wordAnalysis: _wordAnalysis,
                harshWords: _harshWords,
                onClear: _clearResults,
              ),
            ],

            // Alert
            if (_showAlert && _result != null) ...[
              const SizedBox(height: 4),
              HarshWordAlert(
                isHateSpeech: _result!.isHateSpeech,
                harshWords:   _harshWords,
                confidence:   _result!.confidence,
                onDismiss:    () => setState(() => _showAlert = false),
              ),
            ],

            // Result card
            if (_result != null && !_isAnalyzing) ...[
              ResultCard(result: _result!, harshWords: _harshWords),
            ],

            // Clean result
            if (_result != null && !_result!.isHateSpeech &&
                _harshWords.isEmpty && !_isAnalyzing) ...[
              _CleanResult(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceSection() {
    return Column(
      children: [
        Center(
          child: MicButton(
            isListening: _isListening,
            isDisabled:  !_isModelReady || !_speechAvailable,
            onPressed:   _toggleListening,
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            !_isModelReady
                ? 'Waiting for model...'
                : !_speechAvailable
                    ? 'Speech recognition not available'
                    : _isListening
                        ? '🔴 Listening... tap to stop'
                        : 'Tap and speak in Sinhala',
            textAlign: TextAlign.center,
            style: TextStyle(color: CeylonSpice.textMid, fontSize: 13, height: 1.5),
          ),
        ),

        // Live transcription
        if (_isListening && _partialText.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: CeylonSpice.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border(left: BorderSide(color: CeylonSpice.saffron, width: 3)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LIVE TRANSCRIPTION',
                  style: TextStyle(
                    color: CeylonSpice.saffronDark,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _partialText,
                  style: TextStyle(color: CeylonSpice.text, fontSize: 16, height: 1.5),
                ),
              ],
            ),
          ),
        ],

        if (!_speechAvailable) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: CeylonSpice.warnLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: CeylonSpice.cinnamon),
            ),
            child: Text(
              '⚠️ Speech recognition not available on this device. Use "Type Text" mode.',
              style: TextStyle(color: CeylonSpice.cinnamon, fontSize: 12),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildManualSection() {
    final hasText = _textController.text.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ENTER SINHALA TEXT',
          style: TextStyle(
            color: CeylonSpice.textMid,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 8),

        // Text field — now has a visible fill + border so it doesn't
        // blend into the coconutCream background.
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4),
            ],
          ),
          child: TextField(
            controller: _textController,
            maxLines: 4,
            style: TextStyle(color: CeylonSpice.text, fontSize: 16, height: 1.6),
            cursorColor: CeylonSpice.cinnamon,
            decoration: InputDecoration(
              hintText: 'උදා: මේ කෙනා හරිම නරකයි...',
              hintStyle: TextStyle(color: CeylonSpice.textLight, fontSize: 15),
              filled: true,
              fillColor: CeylonSpice.surface,
              contentPadding: const EdgeInsets.all(14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: CeylonSpice.creamDarker, width: 1.2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: CeylonSpice.creamDarker, width: 1.2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: CeylonSpice.cinnamon, width: 1.8),
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Analyze button — explicit colors for both enabled and disabled
        // states so it stays visible even before the user types anything.
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: CeylonSpice.cinnamon,
              foregroundColor: CeylonSpice.coconutCream,
              disabledBackgroundColor: CeylonSpice.creamDark,
              disabledForegroundColor: CeylonSpice.textMid,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: hasText ? 2 : 0,
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            onPressed: (!_isModelReady || !hasText)
                ? null
                : () {
                    setState(() => _displayText = _textController.text);
                    _runAnalysis(_textController.text);
                  },
            child: const Text('🔍  Analyze Text'),
          ),
        ),

        // Small hint under the button so users know why it's disabled.
        if (!hasText) ...[
          const SizedBox(height: 6),
          Text(
            'Type some text above to enable the Analyze button.',
            style: TextStyle(color: CeylonSpice.textLight, fontSize: 11),
          ),
        ],
      ],
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final bool isReady;
  const _StatusBadge({required this.isReady});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isReady)
            const SizedBox(
              width: 12, height: 12,
              child: CircularProgressIndicator(
                color: CeylonSpice.coconutCream, strokeWidth: 2,
              ),
            ),
          
        ],
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  final String selectedMode;
  final ValueChanged<String> onChanged;
  const _ModeToggle({required this.selectedMode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: CeylonSpice.creamDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: ['voice', 'manual'].map((mode) {
          final isActive = selectedMode == mode;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(mode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: isActive ? CeylonSpice.cinnamon : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isActive
                      ? [BoxShadow(color: CeylonSpice.cinnamon.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))]
                      : [],
                ),
                child: Center(
                  child: Text(
                    mode == 'voice' ? '🎤  Voice Input' : '⌨️  Type Text',
                    style: TextStyle(
                      color: isActive ? CeylonSpice.coconutCream : CeylonSpice.textMid,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _AnalyzedTextSection extends StatelessWidget {
  final List<WordAnalysis> wordAnalysis;
  final List<String> harshWords;
  final VoidCallback onClear;

  const _AnalyzedTextSection({
    required this.wordAnalysis,
    required this.harshWords,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ANALYZED TEXT',
              style: TextStyle(
                color: CeylonSpice.textLight,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
            GestureDetector(
              onTap: onClear,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: CeylonSpice.creamDark,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '✕ Clear',
                  style: TextStyle(color: CeylonSpice.textMid, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CeylonSpice.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: CeylonSpice.creamDarker),
          ),
          child: WordHighlighter(wordAnalysis: wordAnalysis),
        ),
        if (harshWords.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            '🔴 Red = harsh words detected',
            style: TextStyle(color: CeylonSpice.danger, fontSize: 11),
          ),
        ],
        const SizedBox(height: 14),
      ],
    );
  }
}

class _CleanResult extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CeylonSpice.cleanBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CeylonSpice.deepJungle, width: 1.5),
      ),
      child: Column(
        children: [
          const Text('✅', style: TextStyle(fontSize: 36)),
          const SizedBox(height: 6),
          Text(
            'No hate speech or harsh words detected.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: CeylonSpice.deepJungle,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),

        ],
      ),
    );
  }
}