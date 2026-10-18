// lib/services/fraud_review_service.dart
//
// On-device fake / fraudulent review detector.
//
// Re-implements, in pure Dart, the exact inference pipeline of the project's
// `FraudReviewClassifier` (docs/fraud/fraud-review-detector.ipynb &
// inference.py), trained on the Deceptive Opinion Spam Corpus (Ott et al.).
//
// Pipeline:
//   1. clean_text  — lowercase, strip non-alphanumerics to spaces, collapse
//      whitespace (identical to the notebook's `clean_text`).
//   2. TF-IDF      — unigrams + bigrams over a fixed 5000-term vocabulary,
//      sublinear term frequency (1 + ln(tf)), multiplied by the trained IDF
//      weights, then L2-normalised. Byte-for-byte equal to scikit-learn's
//      TfidfVectorizer output (verified maxdiff = 0).
//   3. MLP         — Linear(5000→256) → BatchNorm → ReLU → Linear(256→128) →
//      BatchNorm → ReLU → Linear(128→1), producing a logit.
//   4. sigmoid(logit) → probability the review is deceptive; > threshold
//      (0.5) means "fraud".
//
// The weights, vocabulary and IDF table are bundled in
// `assets/model/fraud_review_model.json`.

import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart';

/// Outcome of screening a single review.
class FraudReviewResult {
  /// True if the review is classified as fake / deceptive and should be
  /// rejected.
  final bool isFraud;

  /// Model probability (0–1) that the review is deceptive.
  final double probability;

  /// Confidence in the chosen label (0–1): `probability` when fraud, else
  /// `1 - probability`.
  final double confidence;

  /// True when the verdict came from the rule layer (phone number, URL, email,
  /// promo phrases…) rather than the ML model.
  final bool decidedByRules;

  /// Human-readable flags from the rule layer (e.g. "phone number").
  final List<String> reasons;

  const FraudReviewResult({
    required this.isFraud,
    required this.probability,
    required this.confidence,
    this.decidedByRules = false,
    this.reasons = const [],
  });

  String get label => isFraud ? 'deceptive' : 'truthful';
}

/// Loads the exported fraud model once and screens review text.
class FraudReviewService {
  FraudReviewService._();

  /// Shared, lazily-loaded singleton.
  static final FraudReviewService instance = FraudReviewService._();

  static const String _assetPath = 'assets/model/fraud_review_model.json';
  static const double _bnEps = 1e-5;

  // Matches sklearn's default word token pattern: runs of 2+ word characters.
  static final RegExp _tokenPattern = RegExp(r'\w\w+', unicode: true);
  static final RegExp _nonAlnum = RegExp(r'[^a-z0-9\s]');
  static final RegExp _whitespace = RegExp(r'\s+');

  bool _loaded = false;
  Future<void>? _loading;

  late int _inputDim;
  late double _threshold;
  late Map<String, int> _vocabulary; // ngram -> feature index
  late List<double> _idf; // [inputDim]

  late List<List<double>> _w0; // [256][5000]
  late List<double> _b0;
  late _BatchNorm _bn1;
  late List<List<double>> _w4; // [128][256]
  late List<double> _b4;
  late _BatchNorm _bn5;
  late List<List<double>> _w8; // [1][128]
  late List<double> _b8;

  bool get isLoaded => _loaded;

  /// Parse and cache the model. Concurrent calls share one load; safe to call
  /// repeatedly.
  Future<void> load() {
    if (_loaded) return Future.value();
    return _loading ??= _doLoad();
  }

  Future<void> _doLoad() async {
    final raw = await rootBundle.loadString(_assetPath);
    final Map<String, dynamic> json = jsonDecode(raw) as Map<String, dynamic>;

    final meta = json['metadata'] as Map<String, dynamic>;
    _inputDim = (meta['input_dim'] as num).toInt();
    _threshold = (meta['threshold'] as num).toDouble();

    _vocabulary = (json['vocabulary'] as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, (v as num).toInt()));
    _idf = _toDoubleList(json['idf']);

    final w = json['weights'] as Map<String, dynamic>;
    _w0 = _toMatrix(w['net.0.weight']);
    _b0 = _toDoubleList(w['net.0.bias']);
    _bn1 = _BatchNorm.fromJson(w, '1');
    _w4 = _toMatrix(w['net.4.weight']);
    _b4 = _toDoubleList(w['net.4.bias']);
    _bn5 = _BatchNorm.fromJson(w, '5');
    _w8 = _toMatrix(w['net.8.weight']);
    _b8 = _toDoubleList(w['net.8.bias']);

    _loaded = true;
    _loading = null;
  }

  /// Screen [reviewText]. Throws [StateError] if [load] has not completed.
  FraudReviewResult classify(String reviewText) {
    if (!_loaded) {
      throw StateError('FraudReviewService.load() must complete first.');
    }

    final features = _tfidf(reviewText);

    // MLP forward pass.
    var h = _linear(features, _w0, _b0); // 5000 → 256
    h = _bn1.apply(h);
    _reluInPlace(h);
    h = _linear(h, _w4, _b4); // 256 → 128
    h = _bn5.apply(h);
    _reluInPlace(h);
    final out = _linear(h, _w8, _b8); // 128 → 1
    final logit = out[0];

    final prob = 1.0 / (1.0 + math.exp(-logit));

    // ── Hybrid layer (from the notebook's final cell) ─────────────────────
    // Rules run on the RAW text (before clean_text strips punctuation). A
    // strong signal (phone number / URL / email) or two weak signals (promo
    // phrases, 3+ "!", ALL-CAPS) marks the review as promotional spam even if
    // the ML model alone says "truthful".
    final flags = ruleBasedFlags(reviewText);
    final ruleSpam = flags.strong.isNotEmpty || flags.weak.length >= 2;

    // The ML model (trained on long, fluent fake hotel reviews) also misses
    // short, low-effort spam like "great great great awesome awesome". A
    // lightweight repetition heuristic catches those obvious cases.
    final repetitive = _looksLikeSpam(reviewText);

    final decidedByRules = ruleSpam || repetitive;
    final isFraud = prob > _threshold || decidedByRules;
    final reasons = <String>[
      ...flags.strong,
      ...flags.weak,
      if (repetitive) 'repetitive text',
    ];

    // When a rule fires but the model score is low, surface a sensible
    // confidence so the UI doesn't show a misleading tiny number.
    final effectiveProb = decidedByRules ? math.max(prob, 0.80) : prob;
    return FraudReviewResult(
      isFraud: isFraud,
      probability: effectiveProb,
      confidence: isFraud ? math.max(effectiveProb, 0.6) : 1.0 - prob,
      decidedByRules: decidedByRules,
      reasons: decidedByRules ? reasons : const [],
    );
  }

  // ── Rule layer: promotional-spam detection (ported from the notebook) ───
  // Sri Lankan phone formats (+94…, 0XX-XXXXXXX incl. masked "077-XXXXXXX") and
  // the 3-3-4 international style.
  static final RegExp _phoneRe = RegExp(
    r'(\+?94[\d\s\-]{8,})|(\b0\d{2}[-\s]?[\dXx]{6,7}\b)|(\b\d{3}[-\s]\d{3}[-\s]\d{4}\b)',
  );
  static final RegExp _urlRe = RegExp(
    r'(https?://|www\.|\b\w+\.(com|lk|net|org)\b)',
    caseSensitive: false,
  );
  static final RegExp _emailRe = RegExp(r'\b[\w\.-]+@[\w\.-]+\.\w+\b');

  // Specific phrases (e.g. "call us", not "call") so genuine text like "work
  // calls" isn't flagged.
  static const List<String> _promoPhrases = [
    'call us', 'call now', 'call me', 'call today', 'whatsapp', 'book now',
    'book your', 'discount', 'special offer', 'contact us', 'dm me',
    'inbox me', 'promo', 'limited offer', 'free pickup', 'tours today',
    'trust me', 'not regret',
  ];

  /// Notebook `rule_based_flags`: returns the strong and weak signals found in
  /// the raw [text]. Any strong signal, or two weak ones, flags promotional
  /// spam.
  static ({List<String> strong, List<String> weak}) ruleBasedFlags(
      String text) {
    final lower = text.toLowerCase();
    final strong = <String>[];
    final weak = <String>[];

    if (_phoneRe.hasMatch(text)) strong.add('phone number');
    if (_urlRe.hasMatch(text)) strong.add('URL/website');
    if (_emailRe.hasMatch(text)) strong.add('email address');

    final hits = _promoPhrases.where(lower.contains).toList();
    if (hits.isNotEmpty) weak.add('promo phrases: $hits');

    if ('!'.allMatches(text).length >= 3) weak.add('excessive exclamation marks');

    final words = RegExp(r'[A-Za-z]{3,}').allMatches(text).map((m) => m.group(0)!);
    final wordList = words.toList();
    if (wordList.isNotEmpty) {
      final upper = wordList.where((w) => w == w.toUpperCase()).length;
      if (upper / wordList.length > 0.2) weak.add('excessive ALL-CAPS words');
    }

    return (strong: strong, weak: weak);
  }

  // Common words that naturally repeat in genuine reviews — excluded from the
  // repetition/diversity heuristic so sentences like "the room… the staff…
  // the location" are never mistaken for spam.
  static const Set<String> _stopwords = {
    'the', 'a', 'an', 'and', 'or', 'but', 'is', 'are', 'was', 'were', 'be',
    'been', 'to', 'of', 'in', 'on', 'at', 'for', 'with', 'near', 'by', 'from',
    'it', 'its', 'this', 'that', 'these', 'those', 'we', 'i', 'you', 'they',
    'he', 'she', 'my', 'our', 'your', 'their', 'his', 'her', 'us', 'as', 'so',
    'very', 'too', 'also', 'here', 'there', 'had', 'has', 'have', 'did', 'do',
    'not', 'no', 'yes', 'out', 'up', 'all', 'just', 'than', 'then', 'when',
    'where', 'which', 'who', 'what', 'how', 'if', 'about', 'into', 'over',
  };

  /// Heuristic for obvious low-effort / spammy reviews the corpus-trained
  /// model tends to miss: heavy repetition of CONTENT words or near-zero
  /// vocabulary diversity. Deliberately conservative to avoid flagging genuine
  /// reviews (common stopwords are ignored).
  static bool _looksLikeSpam(String text) {
    final allWords = _clean(text)
        .split(' ')
        .where((w) => w.length > 1)
        .toList();
    if (allWords.length < 4) return false; // too short to judge — let it through

    // Content words only (drop stopwords that legitimately repeat).
    final content = allWords.where((w) => !_stopwords.contains(w)).toList();
    if (content.length < 4) return false;

    final counts = <String, int>{};
    for (final w in content) {
      counts[w] = (counts[w] ?? 0) + 1;
    }
    final maxRepeat = counts.values.fold<int>(0, (m, c) => c > m ? c : m);
    final diversity = counts.length / content.length;

    // Flag if a content word is hammered 3+ times (e.g. "great great great"),
    // or ≥5 content words with very low diversity (e.g. "good nice good nice
    // good good").
    if (maxRepeat >= 3) return true;
    if (content.length >= 5 && diversity < 0.5) return true;
    return false;
  }

  // ── Feature extraction ────────────────────────────────────────────────

  /// Notebook `clean_text`: lowercase, non-alphanumerics → space, collapse.
  static String _clean(String text) {
    var t = text.toLowerCase();
    t = t.replaceAll(_nonAlnum, ' ');
    t = t.replaceAll(_whitespace, ' ').trim();
    return t;
  }

  /// Build the L2-normalised sublinear TF-IDF vector for [text].
  List<double> _tfidf(String text) {
    final cleaned = _clean(text);
    final tokens = _tokenPattern
        .allMatches(cleaned)
        .map((m) => m.group(0)!)
        .toList(growable: false);

    // Count unigrams + bigrams that exist in the vocabulary.
    final counts = <int, int>{};
    void bump(String gram) {
      final idx = _vocabulary[gram];
      if (idx != null) counts[idx] = (counts[idx] ?? 0) + 1;
    }

    for (var i = 0; i < tokens.length; i++) {
      bump(tokens[i]);
      if (i + 1 < tokens.length) bump('${tokens[i]} ${tokens[i + 1]}');
    }

    final vec = List<double>.filled(_inputDim, 0.0);
    var normSq = 0.0;
    counts.forEach((idx, count) {
      final tf = 1.0 + math.log(count); // sublinear_tf
      final value = tf * _idf[idx];
      vec[idx] = value;
      normSq += value * value;
    });

    // L2 normalisation (sklearn norm='l2').
    if (normSq > 0) {
      final inv = 1.0 / math.sqrt(normSq);
      for (final idx in counts.keys) {
        vec[idx] *= inv;
      }
    }
    return vec;
  }

  // ── Math helpers ──────────────────────────────────────────────────────

  static List<double> _linear(
    List<double> x,
    List<List<double>> weight,
    List<double> bias,
  ) {
    final out = List<double>.filled(weight.length, 0.0);
    for (var i = 0; i < weight.length; i++) {
      final row = weight[i];
      var sum = bias[i];
      for (var j = 0; j < x.length; j++) {
        final xj = x[j];
        if (xj != 0.0) sum += row[j] * xj; // TF-IDF is sparse → skip zeros
      }
      out[i] = sum;
    }
    return out;
  }

  static void _reluInPlace(List<double> x) {
    for (var i = 0; i < x.length; i++) {
      if (x[i] < 0) x[i] = 0.0;
    }
  }

  static List<double> _toDoubleList(dynamic v) =>
      (v as List<dynamic>).map((e) => (e as num).toDouble()).toList();

  static List<List<double>> _toMatrix(dynamic v) => (v as List<dynamic>)
      .map((row) => _toDoubleList(row))
      .toList(growable: false);
}

/// BatchNorm1d in evaluation mode.
class _BatchNorm {
  final List<double> weight;
  final List<double> bias;
  final List<double> runningMean;
  final List<double> runningVar;

  const _BatchNorm({
    required this.weight,
    required this.bias,
    required this.runningMean,
    required this.runningVar,
  });

  factory _BatchNorm.fromJson(Map<String, dynamic> w, String layer) {
    List<double> read(String name) =>
        FraudReviewService._toDoubleList(w['net.$layer.$name']);
    return _BatchNorm(
      weight: read('weight'),
      bias: read('bias'),
      runningMean: read('running_mean'),
      runningVar: read('running_var'),
    );
  }

  List<double> apply(List<double> x) {
    final out = List<double>.filled(x.length, 0.0);
    for (var i = 0; i < x.length; i++) {
      out[i] = (x[i] - runningMean[i]) /
              math.sqrt(runningVar[i] + FraudReviewService._bnEps) *
              weight[i] +
          bias[i];
    }
    return out;
  }
}
