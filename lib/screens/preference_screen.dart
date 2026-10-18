import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart' as app_auth;
import '../theme/app_theme.dart';
import '../models/travel_models.dart';
import '../services/ai_recommendation_service.dart';
import '../services/voice_service.dart';
import 'recommendation_screen.dart';

class PreferenceScreen extends StatefulWidget {
  final bool embeddedMode;
  const PreferenceScreen({super.key, this.embeddedMode = false});

  @override
  State<PreferenceScreen> createState() => _PreferenceScreenState();
}

class _PreferenceScreenState extends State<PreferenceScreen> {
  String _groupType = 'couple';
  int _groupSize = 2;
  String _gender = 'Mixed';
  final Set<String> _selectedAgeRanges = {'25-35'};
  double _budget = 1000;
  String _budgetTier = 'mid-range';
  final Set<String> _selectedActivities = {'Chilling & Fun'};
  DateTime _travelDate = DateTime.now().add(const Duration(days: 30));
  int _tripDays = 7;
  // Traveller's current location: a Sri Lankan district (→ nearby-destination
  // recommendations) or "Outside Sri Lanka" (→ island-wide, default).
  String _currentLocation = AIRecommendationService.outsideSlOption;
  bool _isLoading = false;
  String? _errorMessage;

  // ── Per-field voice input ────────────────────────────────────────────────
  // Each input has its own mic; _activeField tracks which one is listening so
  // the recognised speech is applied to that field only.
  final VoiceService _voice = VoiceService();
  bool _voiceReady = false;
  String? _activeField; // drives the mic UI (which field shows "listening")
  String? _listeningField; // the field we started for (survives UI clears)
  String _lastPartial = ''; // latest partial transcript (fallback for short words)

  @override
  void initState() {
    super.initState();
    _initVoice();
  }

  Future<void> _initVoice() async {
    try {
      await _voice.init();
      _voice.onSttPartialResult = (words) {
        if (words.trim().isNotEmpty) _lastPartial = words;
      };
      _voice.onSttResult = (words) {
        // Use the field we started listening for — _activeField may already be
        // cleared by a 'notListening' status that arrived before this result.
        final field = _listeningField ?? _activeField;
        if (!mounted || field == null) return;
        // Empty final result? Fall back to the last partial ("four", "seven").
        final spoken = words.trim().isNotEmpty ? words : _lastPartial;
        _lastPartial = '';
        _applyFieldVoice(field, spoken);
      };
      _voice.onSttDone = () {
        if (!mounted) return;
        // If the session ended but no FINAL result was applied (common for
        // short single words like "four"/"seven" that only yield partials),
        // fall back to the last partial transcript so the field still fills.
        final field = _listeningField;
        if (field != null && _lastPartial.trim().isNotEmpty) {
          final words = _lastPartial;
          _lastPartial = '';
          _applyFieldVoice(field, words);
        } else {
          _lastPartial = '';
          setState(() => _activeField = null);
        }
      };
      _voice.onSttError = (msg) {
        if (!mounted) return;

        // Short words often produce partials and then error_no_match.
        // Use the partial instead of discarding it.
        final field = _listeningField;
        if (field != null && _lastPartial.trim().isNotEmpty) {
          final words = _lastPartial;
          _lastPartial = '';
          _applyFieldVoice(field, words);
          return;
        }

        _listeningField = null;
        setState(() => _activeField = null);
        final friendly = msg.contains('no_match')
            ? "Didn't catch that — tap the mic and try again."
            : msg.contains('speech_timeout')
                ? 'No speech detected — tap the mic and try again.'
                : 'Voice input error — tap the mic to retry.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendly,
                style: GoogleFonts.nunito(color: AppTheme.coconutCream)),
            backgroundColor: AppTheme.cardMid,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      };
      if (mounted) setState(() => _voiceReady = _voice.sttAvailable);
    } catch (_) {
      if (mounted) setState(() => _voiceReady = false);
    }
  }

  @override
  void dispose() {
    _voice.dispose();
    super.dispose();
  }

  /// Start/stop listening for a specific field. Only one field listens at a
  /// time; starting a new one cancels any previous.
  Future<void> _toggleFieldVoice(String field) async {
    if (!_voiceReady) return;
    if (_activeField == field) {
      _listeningField = null;
      await _voice.stopListening();
      if (mounted) setState(() => _activeField = null);
    } else {
      if (_voice.isListening) await _voice.stopListening();
      _listeningField = field;
      _lastPartial = '';
      setState(() => _activeField = field);
      await _voice.startListening();
    }
  }

  /// Parse a number from speech — digits ("7", "2000", "2,000"), "2k", or
  /// words ("four", "twenty one", "two thousand", "fifteen hundred"). Returns
  /// null if nothing numeric is found.
  int? _spokenNumber(String raw) {
    var text = raw.toLowerCase().replaceAll(',', '');

    // "2k" / "1.5k" → thousands.
    final kMatch = RegExp(r'(\d+(?:\.\d+)?)\s*k\b').firstMatch(text);
    if (kMatch != null) {
      final v = double.tryParse(kMatch.group(1)!);
      if (v != null) return (v * 1000).round();
    }

    // Plain digits.
    final d = RegExp(r'\d+').firstMatch(text);
    if (d != null) return int.tryParse(d.group(0)!);

    // Strip punctuation ("seven." → "seven").
    text = text.replaceAll(RegExp(r'[^a-z\s-]'), ' ').trim();

    // Homophones — only when the WHOLE utterance is that one word, so
    // "for seven days" is not read as "four seven days".
    const homophones = {
      'for': 4, 'fore': 4, 'to': 2, 'too': 2, 'tu': 2,
      'tree': 3, 'free': 3, 'ate': 8, 'won': 1, 'wan': 1,
    };
    if (homophones.containsKey(text)) return homophones[text];

    const units = {
      'zero': 0, 'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5,
      'six': 6, 'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10, 'eleven': 11,
      'twelve': 12, 'thirteen': 13, 'fourteen': 14, 'fifteen': 15,
      'sixteen': 16, 'seventeen': 17, 'eighteen': 18, 'nineteen': 19,
    };
    const tens = {
      'twenty': 20, 'thirty': 30, 'forty': 40, 'fifty': 50, 'sixty': 60,
      'seventy': 70, 'eighty': 80, 'ninety': 90,
    };

    var total = 0, current = 0;
    var found = false;
    for (final w in text.split(RegExp(r'[\s-]+'))) {
      if (units.containsKey(w)) {
        current += units[w]!;
        found = true;
      } else if (tens.containsKey(w)) {
        current += tens[w]!;
        found = true;
      } else if (w == 'hundred') {
        current = (current == 0 ? 1 : current) * 100;
        found = true;
      } else if (w == 'thousand') {
        total += (current == 0 ? 1 : current) * 1000;
        current = 0;
        found = true;
      }
    }
    return found ? total + current : null;
  }

  // Common ways an English speech recogniser mis-hears Sri Lankan district
  // names (e.g. it hears "candy" for Kandy). Maps the mis-heard word → district.
  static const Map<String, String> _districtAliases = {
    'candy': 'Kandy', 'kandi': 'Kandy', 'kandy': 'Kandy',
    'goal': 'Galle', 'gaul': 'Galle', 'gall': 'Galle', 'gaalle': 'Galle',
    'golf': 'Galle',
    'jaffa': 'Jaffna', 'jafna': 'Jaffna', 'jeffna': 'Jaffna', 'jafhna': 'Jaffna',
    'columbo': 'Colombo', 'colomba': 'Colombo', 'colombo': 'Colombo',
    'matara': 'Matara', 'mataara': 'Matara', 'mathara': 'Matara',
    'kaluthara': 'Kalutara', 'kalutara': 'Kalutara', 'kalutura': 'Kalutara',
    'gampaha': 'Gampaha', 'gampha': 'Gampaha', 'gumbaha': 'Gampaha',
    'kurunegala': 'Kurunegala', 'kurunagala': 'Kurunegala',
    'anuradhapura': 'Anuradhapura', 'anuradha pura': 'Anuradhapura',
    'polonnaruwa': 'Polonnaruwa', 'polonaruwa': 'Polonnaruwa',
    'trincomalee': 'Trincomalee', 'trinco': 'Trincomalee',
    'trinkomali': 'Trincomalee',
    'batticaloa': 'Batticaloa', 'batti': 'Batticaloa', 'batikaloa': 'Batticaloa',
    'nuwara eliya': 'Nuwara Eliya', 'nuwaraeliya': 'Nuwara Eliya',
    'nuvara eliya': 'Nuwara Eliya', 'nurelia': 'Nuwara Eliya',
    'ratnapura': 'Ratnapura', 'rathnapura': 'Ratnapura',
    'badulla': 'Badulla', 'badula': 'Badulla', 'badhulla': 'Badulla',
    'hambantota': 'Hambantota', 'hambanthota': 'Hambantota',
    'puttalam': 'Puttalam', 'puttalama': 'Puttalam', 'puttlam': 'Puttalam',
    'vavuniya': 'Vavuniya', 'vavunia': 'Vavuniya',
    'mannar': 'Mannar', 'manar': 'Mannar',
    'kegalle': 'Kegalle', 'kegalla': 'Kegalle', 'kagalle': 'Kegalle',
    'matale': 'Matale', 'mathale': 'Matale', 'matele': 'Matale',
    'monaragala': 'Monaragala', 'moneragala': 'Monaragala',
    'ampara': 'Ampara', 'amparai': 'Ampara',
    'kilinochchi': 'Kilinochchi', 'kilinochi': 'Kilinochchi',
    'killinochchi': 'Kilinochchi',
    'mullaitivu': 'Mullaitivu', 'mullativu': 'Mullaitivu',
  };

  /// Match a spoken phrase to one of the 25 districts, tolerant of how an
  /// English recogniser mis-hears local names: exact substring → alias map →
  /// fuzzy (edit-distance) closest match.
  String? _matchDistrict(String text) {
    final t = text.toLowerCase().trim();
    if (t.isEmpty) return null;
    final districts = AIRecommendationService.locationOptions
        .where((l) => l != AIRecommendationService.outsideSlOption)
        .toList();

    // 1. Exact substring.
    for (final d in districts) {
      if (t.contains(d.toLowerCase())) return d;
    }
    // 2. Known mis-hearings.
    for (final e in _districtAliases.entries) {
      if (RegExp('\\b${RegExp.escape(e.key)}\\b').hasMatch(t)) return e.value;
    }
    // 3. Fuzzy: closest district to the whole phrase or any spoken word.
    String? best;
    var bestScore = 0.0;
    final candidates = <String>[t, ...t.split(RegExp(r'\s+'))];
    for (final d in districts) {
      final dl = d.toLowerCase();
      for (final cand in candidates) {
        if (cand.length < 3) continue;
        final dist = _levenshtein(cand, dl);
        final maxLen = cand.length > dl.length ? cand.length : dl.length;
        final score = 1 - dist / maxLen;
        if (score > bestScore) {
          bestScore = score;
          best = d;
        }
      }
    }
    return bestScore >= 0.6 ? best : null;
  }

  /// Classic Levenshtein edit distance.
  int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    var prev = List<int>.generate(b.length + 1, (i) => i);
    var curr = List<int>.filled(b.length + 1, 0);
    for (var i = 0; i < a.length; i++) {
      curr[0] = i + 1;
      for (var j = 0; j < b.length; j++) {
        final cost = a[i] == b[j] ? 0 : 1;
        final del = prev[j + 1] + 1;
        final ins = curr[j] + 1;
        final sub = prev[j] + cost;
        curr[j + 1] = del < ins ? (del < sub ? del : sub) : (ins < sub ? ins : sub);
      }
      final tmp = prev;
      prev = curr;
      curr = tmp;
    }
    return prev[b.length];
  }

  /// Apply recognised speech to a single field only.
  void _applyFieldVoice(String field, String transcript) {
    debugPrint('[Voice] field=$field heard="$transcript"');
    final text = transcript.toLowerCase();
    String? change;

    setState(() {
      _activeField = null;
      _listeningField = null;
      switch (field) {
        case 'group':
          if (RegExp(r'\bsolo\b|\balone\b|by myself|just me|myself|one person')
              .hasMatch(text)) {
            _groupType = 'solo';
            _groupSize = 1;
            change = 'Solo';
          } else if (RegExp(r'couple|partner|honeymoon|wife|husband|girlfriend|boyfriend|spouse')
              .hasMatch(text)) {
            _groupType = 'couple';
            if (_groupSize < 2) _groupSize = 2;
            change = 'Couple';
          } else if (RegExp(r'family|kids|children|parents')
              .hasMatch(text)) {
            _groupType = 'family';
            change = 'Family';
          } else if (RegExp(r'group|friends|team|colleagues|everyone')
              .hasMatch(text)) {
            _groupType = 'group';
            change = 'Group';
          }
          break;
        case 'size':
          final n = _spokenNumber(text);
          if (n != null && n >= 1) {
            _groupSize = n.clamp(1, 20); // matches the stepper's max
            change = '$_groupSize ${_groupSize == 1 ? 'person' : 'people'}';
          }
          break;
        case 'gender':
          if (RegExp(r'all male|all men').hasMatch(text)) {
            _gender = 'All Male';
            change = 'All Male';
          } else if (RegExp(r'all female|all women').hasMatch(text)) {
            _gender = 'All Female';
            change = 'All Female';
          } else if (RegExp(r'mixed|both').hasMatch(text)) {
            _gender = 'Mixed';
            change = 'Mixed';
          }
          break;
        case 'age':
          // Voice adds to the multi-select set (say several, e.g. "kids and
          // thirties"). Matches ranges, decades, and "under 18".
          final picks = <String>{};
          final m = RegExp(r'(\d{2})\s*(?:-|to)\s*(\d{2})').firstMatch(text);
          if (m != null && _ageRanges.contains('${m.group(1)}-${m.group(2)}')) {
            picks.add('${m.group(1)}-${m.group(2)}');
          }
          if (RegExp(r'under 18|below 18|under eighteen|kid|child|teen')
              .hasMatch(text)) {
            picks.add('Under 18');
          }
          if (RegExp(r'twenties').hasMatch(text)) picks.add('25-35');
          if (RegExp(r'thirties').hasMatch(text)) picks.add('36-45');
          if (RegExp(r'forties|fifties').hasMatch(text)) picks.add('46-60');
          if (RegExp(r'sixties|senior|elder|retire').hasMatch(text)) {
            picks.add('60+');
          }
          // A bare age number ("30", "I'm 42") → bucket into a range.
          if (picks.isEmpty) {
            final age = _spokenNumber(text);
            if (age != null && age > 0 && age < 120) {
              if (age < 18) {
                picks.add('Under 18');
              } else if (age <= 24) {
                picks.add('18-24');
              } else if (age <= 35) {
                picks.add('25-35');
              } else if (age <= 45) {
                picks.add('36-45');
              } else if (age <= 60) {
                picks.add('46-60');
              } else {
                picks.add('60+');
              }
            }
          }
          if (picks.isNotEmpty) {
            _selectedAgeRanges
              ..clear()
              ..addAll(picks);
            change = 'Age ${picks.join(', ')}';
          }
          break;
        case 'budget':
          final b = _spokenNumber(text);
          if (b != null && b >= 50) {
            // Clamp to the slider's own range (200–5000); a value outside it
            // makes the Slider throw an assertion error.
            _budget = b.toDouble().clamp(_budgetMin, _budgetMax);
            _updateBudgetTier();
            change = '\$${_budget.toInt()}';
          }
          break;
        case 'activities':
          final acts = <String>{};
          if (RegExp(r'adventure|hiking|surf|trek|rafting|climb')
              .hasMatch(text)) {
            acts.add('Adventure');
          }
          if (RegExp(r'religious|heritage|temple|cultural|ancient|history')
              .hasMatch(text)) {
            acts.add('Religious & Heritage');
          }
          if (RegExp(r'chilling|chill|fun|beach|relax|wildlife|food|safari')
              .hasMatch(text)) {
            acts.add('Chilling & Fun');
          }
          if (acts.isNotEmpty) {
            _selectedActivities
              ..clear()
              ..addAll(acts);
            change = acts.join(' + ');
          }
          break;
        case 'days':
          if (RegExp(r'weekend').hasMatch(text)) {
            _tripDays = 2;
            change = '2 days';
          } else if (RegExp(r'fortnight').hasMatch(text)) {
            _tripDays = 14;
            change = '14 days';
          } else if (text.contains('week')) {
            // "a week", "two weeks", "three weeks"
            final w =
                _spokenNumber(text.replaceAll(RegExp(r'weeks?'), '')) ?? 1;
            _tripDays = (w * 7).clamp(1, 30);
            change = '$_tripDays days';
          } else {
            final n = _spokenNumber(text);
            if (n != null && n >= 1) {
              _tripDays = n.clamp(1, 30);
              change = '$_tripDays days';
            }
          }
          break;
        case 'location':
          if (RegExp(r'outside sri lanka|not in sri lanka|abroad|overseas')
              .hasMatch(text)) {
            _currentLocation = AIRecommendationService.outsideSlOption;
            change = 'Outside Sri Lanka';
          } else {
            final d = _matchDistrict(text);
            if (d != null) {
              _currentLocation = d;
              change = d;
            }
          }
          break;
      }
    });

    final msg = change != null
        ? 'Set: $change'
        : 'Didn\'t catch that (“$transcript”). Try again.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(msg, style: GoogleFonts.nunito(color: AppTheme.coconutCream)),
        backgroundColor: change != null ? AppTheme.deepJungle : AppTheme.cardMid,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  static const _groupTypes = ['solo', 'couple', 'family', 'group'];
  static const _genders = ['All Male', 'All Female', 'Mixed'];
  static const _ageRanges = ['Under 18', '18-24', '25-35', '36-45', '46-60', '60+'];

  // Budget slider bounds — shared by the slider and the voice handler so a
  // spoken value can never fall outside the slider's range.
  static const double _budgetMin = 200;
  static const double _budgetMax = 5000;

  // MATCHED EXACTLY TO NOTEBOOK OPTIONS
  static const _activities = [
    'Adventure',
    'Religious & Heritage',
    'Chilling & Fun',
  ];

  static const _activityIcons = {
    'Adventure': Icons.paragliding_rounded,
    'Religious & Heritage': Icons.account_balance_rounded,
    'Chilling & Fun': Icons.beach_access_rounded,
  };

  void _updateBudgetTier() {
    if (_budget < 500) {
      _budgetTier = 'budget';
    } else if (_budget <= 1500) {
      _budgetTier = 'mid-range';
    } else {
      _budgetTier = 'luxury';
    }
  }

  Future<void> _getRecommendations() async {
    if (_selectedActivities.isEmpty) {
      setState(() => _errorMessage = 'Please select at least one activity');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = TravelPreferences(
        groupType: _groupType,
        groupSize: _groupSize,
        gender: _gender,
        ageRange: _selectedAgeRanges.join(', '),
        budgetUsd: _budget,
        budgetTier: _budgetTier,
        activityPreferences: _selectedActivities.toList(),
        travelDate: DateFormat('yyyy-MM-dd').format(_travelDate),
        travelMonth: DateFormat('MMMM').format(_travelDate),
        tripDays: _tripDays,
        currentLocation: _currentLocation,
      );

      final uid = context.read<app_auth.AuthProvider>().firebaseUser?.uid;
      final service = AIRecommendationService();
      final response = await service.getRecommendations(prefs, uid: uid);

      if (mounted) {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) =>
                RecommendationScreen(response: response, preferences: prefs),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    } catch (e) {
      debugPrint('getRecommendations failed: $e');
      setState(
        () => _errorMessage =
            'Unable to get recommendations. Please check your connection and try again.',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _travelDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppTheme.saffron,
            surface: AppTheme.cardDark,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _travelDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final body = Stack(
      children: [
        SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            24,
            widget.embeddedMode ? 0 : 16,
            24,
            120,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProgressBar(),
              const SizedBox(height: 8),
              if (_voiceReady)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12, top: 4),
                  child: Text(
                    'Tip: tap the 🎤 on any field to fill it by voice.',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              const SizedBox(height: 12),

              _buildSection('Group Type', Icons.group_rounded, voiceField: 'group', [
                _buildChoiceChips(
                  _groupTypes,
                  _groupType,
                  (v) => setState(() => _groupType = v),
                ),
              ]),
              const SizedBox(height: 24),

              _buildSection('Group Size', Icons.people_rounded, voiceField: 'size', [
                Row(
                  children: [
                    _buildCountButton(Icons.remove, () {
                      if (_groupSize > 1) setState(() => _groupSize--);
                    }),
                    const SizedBox(width: 20),
                    Text(
                      '$_groupSize',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.coconutCream,
                      ),
                    ),
                    const SizedBox(width: 20),
                    _buildCountButton(Icons.add, () {
                      if (_groupSize < 20) setState(() => _groupSize++);
                    }),
                  ],
                ),
              ]),
              const SizedBox(height: 24),

              _buildSection('Gender', Icons.person_rounded, voiceField: 'gender', [
                _buildChoiceChips(
                  _genders,
                  _gender,
                  (v) => setState(() => _gender = v),
                ),
              ]),
              const SizedBox(height: 24),

              _buildSection('Age Range', Icons.cake_rounded, voiceField: 'age', [
                Text(
                  'Select all that apply',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 10),
                _buildMultiSelectChips(
                  _ageRanges,
                  _selectedAgeRanges,
                  (opt) => setState(() {
                    if (_selectedAgeRanges.contains(opt)) {
                      if (_selectedAgeRanges.length > 1) {
                        _selectedAgeRanges.remove(opt); // keep at least one
                      }
                    } else {
                      _selectedAgeRanges.add(opt);
                    }
                  }),
                ),
              ]),
              const SizedBox(height: 24),

              _buildSection('Budget (USD)', Icons.attach_money_rounded, voiceField: 'budget', [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '\$${_budget.toInt()}',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.saffron,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _budgetTier == 'luxury'
                            ? AppTheme.saffron.withOpacity(0.2)
                            : _budgetTier == 'mid-range'
                            ? AppTheme.cinnamon.withOpacity(0.2)
                            : AppTheme.deepJungle.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _budgetTier.toUpperCase(),
                        style: GoogleFonts.nunito(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _budgetTier == 'luxury'
                              ? AppTheme.saffron
                              : _budgetTier == 'mid-range'
                              ? AppTheme.cinnamon
                              : AppTheme.coconutCream,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _budget.clamp(_budgetMin, _budgetMax),
                  min: _budgetMin,
                  max: _budgetMax,
                  divisions: 48,
                  onChanged: (v) => setState(() {
                    _budget = v;
                    _updateBudgetTier();
                  }),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '\$200',
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    Text(
                      'Mid ≤\$1,500 · Luxury >\$1,500',
                      style: GoogleFonts.nunito(
                        fontSize: 10,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    Text(
                      '\$5,000',
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ]),
              const SizedBox(height: 24),

              _buildSection(
                'Activity Preferences',
                Icons.sports_score_rounded,
                voiceField: 'activities',
                [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _activities.map((act) {
                      final selected = _selectedActivities.contains(act);
                      return GestureDetector(
                        onTap: () => setState(() {
                          if (selected) {
                            _selectedActivities.remove(act);
                          } else {
                            _selectedActivities.add(act);
                          }
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppTheme.saffron.withOpacity(0.15)
                                : AppTheme.cardMid,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: selected
                                  ? AppTheme.saffron
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _activityIcons[act] ?? Icons.star_rounded,
                                size: 16,
                                color: selected
                                    ? AppTheme.saffron
                                    : AppTheme.textMuted,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                act,
                                style: GoogleFonts.nunito(
                                  fontSize: 13,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: selected
                                      ? AppTheme.coconutCream
                                      : AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              _buildSection('Travel Date', Icons.calendar_month_rounded, [
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.cardMid,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.saffron.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.event_rounded,
                          color: AppTheme.saffron,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          DateFormat('EEEE, MMMM d, yyyy').format(_travelDate),
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            color: AppTheme.coconutCream,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppTheme.textMuted,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 24),

              _buildSection('Trip Duration', Icons.schedule_rounded, voiceField: 'days', [
                Row(
                  children: [
                    _buildCountButton(Icons.remove, () {
                      if (_tripDays > 1) setState(() => _tripDays--);
                    }),
                    const SizedBox(width: 20),
                    Column(
                      children: [
                        Text(
                          '$_tripDays',
                          style: GoogleFonts.cormorantGaramond(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.coconutCream,
                          ),
                        ),
                        Text(
                          'days',
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 20),
                    _buildCountButton(Icons.add, () {
                      if (_tripDays < 30) setState(() => _tripDays++);
                    }),
                  ],
                ),
              ]),
              const SizedBox(height: 24),

              // ── Current Location (drives nearby-destination filtering) ──
              _buildSection('Your Current Location', Icons.my_location_rounded, voiceField: 'location', [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.cardMid,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.saffron.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.place_rounded,
                          color: AppTheme.saffron, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _currentLocation,
                            isExpanded: true,
                            dropdownColor: AppTheme.cardDark,
                            borderRadius: BorderRadius.circular(12),
                            icon: const Icon(Icons.arrow_drop_down_rounded,
                                color: AppTheme.saffron),
                            style: GoogleFonts.nunito(
                              fontSize: 14,
                              color: AppTheme.coconutCream,
                              fontWeight: FontWeight.w600,
                            ),
                            items: AIRecommendationService.locationOptions
                                .map((loc) => DropdownMenuItem(
                                      value: loc,
                                      child: Text(loc),
                                    ))
                                .toList(),
                            onChanged: (v) => setState(
                                () => _currentLocation = v ?? _currentLocation),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _currentLocation == AIRecommendationService.outsideSlOption
                      ? 'Showing best matches island-wide across Sri Lanka.'
                      : "We'll prioritise destinations close to $_currentLocation district.",
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                ),
              ]),

              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.errorRed.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: AppTheme.errorRed,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.darkBg.withOpacity(0), AppTheme.darkBg],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: GestureDetector(
              onTap: _isLoading ? null : _getRecommendations,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 58,
                decoration: BoxDecoration(
                  gradient: _isLoading
                      ? LinearGradient(
                          colors: [
                            AppTheme.saffron.withOpacity(0.5),
                            AppTheme.cinnamon.withOpacity(0.5),
                          ],
                        )
                      : AppTheme.spiceGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.saffron.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: _isLoading
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: AppTheme.darkBg,
                                strokeWidth: 2,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Analyzing your preferences...',
                              style: GoogleFonts.nunito(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.darkBg,
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.auto_awesome_rounded,
                              size: 20,
                              color: AppTheme.darkBg,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Get AI Recommendations',
                              style: GoogleFonts.nunito(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.darkBg,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ],
    );

    if (widget.embeddedMode) {
      return SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Plan Your Trip',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.coconutCream,
                    ),
                  ),
                  Text(
                    'Tell us your preferences',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBg,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_rounded,
            color: AppTheme.saffron,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Plan Your Trip',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: AppTheme.coconutCream,
          ),
        ),
      ),
      body: body,
    );
  }

  Widget _buildProgressBar() {
    return Container(
      height: 4,
      decoration: BoxDecoration(
        color: AppTheme.cardMid,
        borderRadius: BorderRadius.circular(2),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: 0.75,
        child: Container(
          decoration: BoxDecoration(
            gradient: AppTheme.spiceGradient,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children,
      {String? voiceField}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.glassCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppTheme.saffron),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.coconutCream,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (voiceField != null && _voiceReady) _fieldMic(voiceField),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    ).animate().fade(duration: const Duration(milliseconds: 400));
  }

  /// Small per-field mic button; shows a listening (stop) state when active.
  Widget _fieldMic(String field) {
    final active = _activeField == field;
    return GestureDetector(
      onTap: () => _toggleFieldVoice(field),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active ? AppTheme.cinnamon : AppTheme.cardMid,
          border: Border.all(
            color: active ? AppTheme.saffron : AppTheme.saffron.withOpacity(0.4),
            width: 1.5,
          ),
        ),
        child: Icon(
          active ? Icons.stop_rounded : Icons.mic_rounded,
          size: 16,
          color: active ? AppTheme.coconutCream : AppTheme.saffron,
        ),
      ),
    );
  }

  Widget _buildChoiceChips(
    List<String> options,
    String selected,
    ValueChanged<String> onSelect,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final isSelected = opt == selected;
        return GestureDetector(
          onTap: () => onSelect(opt),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.saffron.withOpacity(0.15)
                  : AppTheme.cardMid,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isSelected ? AppTheme.saffron : Colors.transparent,
              ),
            ),
            child: Text(
              opt[0].toUpperCase() + opt.substring(1),
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: isSelected ? AppTheme.coconutCream : AppTheme.textMuted,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Multi-select chips with a check mark on selected items.
  Widget _buildMultiSelectChips(
    List<String> options,
    Set<String> selected,
    ValueChanged<String> onToggle,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final isSelected = selected.contains(opt);
        return GestureDetector(
          onTap: () => onToggle(opt),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.saffron.withOpacity(0.15)
                  : AppTheme.cardMid,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isSelected ? AppTheme.saffron : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected) ...[
                  const Icon(Icons.check_rounded,
                      size: 14, color: AppTheme.saffron),
                  const SizedBox(width: 6),
                ],
                Text(
                  opt,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color:
                        isSelected ? AppTheme.coconutCream : AppTheme.textMuted,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCountButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.cardMid,
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.saffron.withOpacity(0.3)),
        ),
        child: Icon(icon, color: AppTheme.saffron, size: 20),
      ),
    );
  }
} 