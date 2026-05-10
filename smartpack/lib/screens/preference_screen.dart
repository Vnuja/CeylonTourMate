import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/travel_models.dart';
import '../services/ai_recommendation_service.dart';
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
  String _ageRange = '25-35';
  double _budget = 1000;
  String _budgetTier = 'mid-range';
  final Set<String> _selectedActivities = {'Chilling & Fun'};
  DateTime _travelDate = DateTime.now().add(const Duration(days: 30));
  int _tripDays = 7;
  bool _isLoading = false;
  String? _errorMessage;

  static const _groupTypes = ['solo', 'couple', 'family', 'group'];
  static const _genders = ['All Male', 'All Female', 'Mixed'];
  static const _ageRanges = ['18-24', '25-35', '36-45', '46-60', '60+'];

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
        ageRange: _ageRange,
        budgetUsd: _budget,
        budgetTier: _budgetTier,
        activityPreferences: _selectedActivities.toList(),
        travelDate: DateFormat('yyyy-MM-dd').format(_travelDate),
        travelMonth: DateFormat('MMMM').format(_travelDate),
        tripDays: _tripDays,
      );

      final service = AIRecommendationService();
      final response = await service.getRecommendations(prefs);

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
              const SizedBox(height: 28),

              _buildSection('Group Type', Icons.group_rounded, [
                _buildChoiceChips(
                  _groupTypes,
                  _groupType,
                  (v) => setState(() => _groupType = v),
                ),
              ]),
              const SizedBox(height: 24),

              _buildSection('Group Size', Icons.people_rounded, [
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

              _buildSection('Gender', Icons.person_rounded, [
                _buildChoiceChips(
                  _genders,
                  _gender,
                  (v) => setState(() => _gender = v),
                ),
              ]),
              const SizedBox(height: 24),

              _buildSection('Age Range', Icons.cake_rounded, [
                _buildChoiceChips(
                  _ageRanges,
                  _ageRange,
                  (v) => setState(() => _ageRange = v),
                ),
              ]),
              const SizedBox(height: 24),

              _buildSection('Budget (USD)', Icons.attach_money_rounded, [
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
                  value: _budget,
                  min: 200,
                  max: 5000,
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

              _buildSection('Trip Duration', Icons.schedule_rounded, [
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

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
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
              Text(
                title,
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.coconutCream,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    ).animate().fade(duration: const Duration(milliseconds: 400));
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
