import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../theme/app_theme.dart';
import '../models/travel_models.dart';

class DestinationDetailScreen extends StatefulWidget {
  final TravelRecommendation recommendation;
  final TravelPreferences preferences;

  const DestinationDetailScreen({
    super.key,
    required this.recommendation,
    required this.preferences,
  });

  @override
  State<DestinationDetailScreen> createState() =>
      _DestinationDetailScreenState();
}

class _DestinationDetailScreenState extends State<DestinationDetailScreen> {
  bool _isSaved = false;

  // ── 3 unique images per location (all 20 SL destinations) ────────────────
  static const Map<String, List<String>> _galleryImages = {
    'Sigiriya': [
      'assets/images/sigiriya.jpg',
      'assets/images/sigiriya2.jpg',
      'assets/images/sigiriya3.jpg',
    ],
    'Ella': [
      'assets/images/ella.jpg',
      'assets/images/ella2.jpg',
      'assets/images/ella3.jpg',
    ],
    'Galle': [
      'assets/images/gallefort.jpg',
      'assets/images/gallefort2.jpg',
      'assets/images/gallefort3.jpg',
    ],
    'Kandy': [
      'assets/images/kandy.jpg',
      'assets/images/kandy2.jpg',
      'assets/images/kandy3.jpg',
    ],
    'Nuwara Eliya': [
      'assets/images/nuwaraeliya.jpg',
      'assets/images/nuwaraeliya2.jpg',
      'assets/images/nuwaraeliya3.jpg',
    ],
    'Yala': [
      'assets/images/yala.jpg',
      'assets/images/yala2.jpg',
      'assets/images/yala3.jpg',
    ],
    'Mirissa': [
      'assets/images/mirissa.jpg',
      'assets/images/mirissa2.jpg',
      'assets/images/mirissa3.jpg',
    ],
    'Bentota': [
      'assets/images/benthota.jpg',
      'assets/images/benthota2.jpg',
      'assets/images/benthota3.jpg',
    ],
    'Colombo': [
      'assets/images/colombo.jpg',
      'assets/images/colombo2.jpg',
      'assets/images/colombo3.jpg',
    ],
    'Dambulla': [
      'assets/images/dambulla.jpg',
      'assets/images/dambulla2.jpg',
      'assets/images/dambulla3.jpg',
    ],
    'Anuradhapura': [
      'assets/images/anuradhapura.jpg',
      'assets/images/anuradhapura2.jpg',
      'assets/images/anuradhapura3.jpg',
    ],
    'Polonnaruwa': [
      'assets/images/polonnaruwa.jpg',
      'assets/images/polonnaruwa2.jpg',
      'assets/images/polonnaruwa3.jpg',
    ],
    'Trincomalee': [
      'assets/images/trincomalee.jpg',
      'assets/images/trincomalee2.jpg',
      'assets/images/trincomalee3.jpg',
    ],
    'Arugam Bay': [
      'assets/images/ArugamBay.jpg',
      'assets/images/ArugamBay2.jpg',
      'assets/images/ArugamBay3.jpg',
    ],
    'Udawalawe': [
      'assets/images/Udawalawe.jpg',
      'assets/images/Udawalawe2.jpg',
      'assets/images/Udawalawe3.jpg',
    ],
    'Wilpattu': [
      'assets/images/Wilpattu.jpg',
      'assets/images/Wilpattu2.jpg',
      'assets/images/Wilpattu3.jpg',
    ],
    'Horton Plains': [
      'assets/images/HortonPlains.jpg',
      'assets/images/HortonPlains2.jpg',
      'assets/images/HortonPlains3.jpg',
    ],
    'Knuckles': [
      'assets/images/Knuckles.jpg',
      'assets/images/Knuckles2.jpg',
      'assets/images/Knuckles3.jpg',
    ],
    'Jaffna': [
      'assets/images/Jaffna.jpg',
      'assets/images/Jaffna2.jpg',
      'assets/images/Jaffna3.jpg',
    ],
    'Unawatuna': [
      'assets/images/Unawatuna.jpg',
      'assets/images/Unawatuna2.jpg',
      'assets/images/Unawatuna3.jpg',
    ],
  };

  static const List<String> _fallbackImages = [
    'https://images.unsplash.com/photo-1568454537842-d933259bb258?w=700',
    'https://images.unsplash.com/photo-1596627116790-af6f46dddfce?w=700',
    'https://images.unsplash.com/photo-1588598198321-9735fd6a1d0a?w=700',
  ];

  List<String> get _images {
    final dest = widget.recommendation.destination.toLowerCase();
    for (final entry in _galleryImages.entries) {
      if (dest.contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    return _fallbackImages;
  }

  bool _isNetworkImage(String path) =>
      path.startsWith('http://') || path.startsWith('https://');

  Widget _buildImage({
    required String imagePath,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    final defaultPlaceholder =
        placeholder ?? Container(color: AppTheme.cardDark);
    final defaultError =
        errorWidget ??
        Container(
          color: AppTheme.cardMid,
          child: const Icon(Icons.image_rounded, color: AppTheme.textMuted),
        );

    if (_isNetworkImage(imagePath)) {
      return CachedNetworkImage(
        imageUrl: imagePath,
        fit: fit,
        placeholder: (_, __) => defaultPlaceholder,
        errorWidget: (_, __, ___) => defaultError,
      );
    } else {
      return Image.asset(
        imagePath,
        fit: fit,
        errorBuilder: (_, __, ___) => defaultError,
      );
    }
  }

  // ── SharedPreferences helpers ─────────────────────────────────────────────

  /// Builds a save-compatible map from the current recommendation,
  /// matching the format used by SavedScreen._allDestinations.
  Map<String, dynamic> get _destMap => {
    'name': widget.recommendation.destination,
    'tagline': widget.recommendation.packageName,
    'image': _images.first,
    'region': '', // not available in TravelRecommendation
    'rating': widget.recommendation.rating?.toString() ?? '',
    'tags': widget.recommendation.activities
        .take(2)
        .map((a) => a.name)
        .toList(),
  };

  @override
  void initState() {
    super.initState();
    _loadSavedState();
  }

  Future<void> _loadSavedState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('saved_destinations') ?? [];
    final saved = raw.any((s) {
      final d = jsonDecode(s) as Map<String, dynamic>;
      return d['name'] == widget.recommendation.destination;
    });
    if (mounted) setState(() => _isSaved = saved);
  }

  Future<void> _toggleSave() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('saved_destinations') ?? [];

    if (_isSaved) {
      // Remove
      raw.removeWhere((s) {
        final d = jsonDecode(s) as Map<String, dynamic>;
        return d['name'] == widget.recommendation.destination;
      });
      await prefs.setStringList('saved_destinations', raw);
      if (mounted) {
        setState(() => _isSaved = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${widget.recommendation.destination} removed from saved',
              style: GoogleFonts.nunito(color: AppTheme.coconutCream),
            ),
            backgroundColor: AppTheme.cardMid,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      // Save
      raw.add(jsonEncode(_destMap));
      await prefs.setStringList('saved_destinations', raw);
      if (mounted) {
        setState(() => _isSaved = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${widget.recommendation.destination} saved! ✓',
              style: GoogleFonts.nunito(color: AppTheme.coconutCream),
            ),
            backgroundColor: AppTheme.deepJungle,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rec = widget.recommendation;

    final heroImagePath = (rec.imageUrl != null && rec.imageUrl!.isNotEmpty)
        ? rec.imageUrl!
        : _images.first;

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: CustomScrollView(
        slivers: [
          // ── Hero Image ───────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: AppTheme.darkBg,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.darkBg.withOpacity(0.7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back_ios_rounded,
                  color: AppTheme.saffron,
                  size: 18,
                ),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.darkBg.withOpacity(0.7),
                    shape: BoxShape.circle,
                  ),
                  // FIX: icon and color now reflect real saved state
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, anim) =>
                        ScaleTransition(scale: anim, child: child),
                    child: Icon(
                      _isSaved
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      key: ValueKey(_isSaved),
                      color: AppTheme.saffron,
                      size: 18,
                    ),
                  ),
                ),
                // FIX: was () {} — now calls _toggleSave
                onPressed: _toggleSave,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  _buildImage(
                    imagePath: heroImagePath,
                    fit: BoxFit.cover,
                    placeholder: Container(color: AppTheme.cardDark),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, AppTheme.darkBg],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.5, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 24,
                    right: 24,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rec.destination,
                          style: GoogleFonts.cormorantGaramond(
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.coconutCream,
                          ),
                        ),
                        if (rec.rating != null)
                          Row(
                            children: [
                              ...List.generate(
                                5,
                                (i) => Icon(
                                  i < rec.rating!.floor()
                                      ? Icons.star_rounded
                                      : Icons.star_border_rounded,
                                  color: AppTheme.saffron,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${rec.rating}',
                                style: GoogleFonts.nunito(
                                  fontSize: 13,
                                  color: AppTheme.coconutCream,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Why Suitable ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle('Why It Suits You', Icons.auto_awesome_rounded),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.deepJungle.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.deepJungle.withOpacity(0.4),
                      ),
                    ),
                    child: Text(
                      rec.whySuitable,
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        color: AppTheme.textLight,
                        height: 1.6,
                      ),
                    ),
                  ).animate().fade(duration: 400.ms),
                ],
              ),
            ),
          ),

          // ── Gallery ───────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 0, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _sectionTitle('Gallery', Icons.photo_library_rounded),
                        Text(
                          '${_images.length} photos',
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 130,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _images.length,
                      padding: const EdgeInsets.only(right: 24),
                      itemBuilder: (_, i) =>
                          Container(
                                width: 175,
                                margin: const EdgeInsets.only(right: 12),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: _buildImage(
                                    imagePath: _images[i],
                                    fit: BoxFit.cover,
                                    placeholder: Container(
                                      color: AppTheme.cardMid,
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                          color: AppTheme.saffron,
                                          strokeWidth: 1.5,
                                        ),
                                      ),
                                    ),
                                    errorWidget: Container(
                                      color: AppTheme.cardMid,
                                      child: const Icon(
                                        Icons.image_rounded,
                                        color: AppTheme.textMuted,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                              .animate(delay: Duration(milliseconds: 100 * i))
                              .fade(duration: 400.ms)
                              .slideX(begin: 0.15),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Weather ───────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle('Weather Suitability', Icons.wb_sunny_rounded),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF0B7285).withOpacity(0.15),
                          AppTheme.cardDark,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF0B7285).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.cloud_done_rounded,
                          color: Color(0xFF74C0FC),
                          size: 32,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            rec.weatherSuitability,
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              color: AppTheme.textLight,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fade(duration: 400.ms),
                ],
              ),
            ),
          ),

          // ── Tour Package ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle('Recommended Package', Icons.luggage_rounded),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.cinnamon.withOpacity(0.15),
                          AppTheme.cardDark,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.cinnamon.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rec.packageName,
                          style: GoogleFonts.cormorantGaramond(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.coconutCream,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _packageStat(
                                'Cost/Person',
                                'USD ${rec.packageCostPerPerson}',
                                Icons.attach_money_rounded,
                                AppTheme.saffron,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _packageStat(
                                'Total/Person',
                                'USD ${rec.totalCostPerPerson}',
                                Icons.calculate_rounded,
                                AppTheme.cinnamon,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _packageStat(
                          'Accommodation',
                          rec.accommodation,
                          Icons.hotel_rounded,
                          AppTheme.deepJungle,
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.cardMid,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.people_rounded,
                                color: AppTheme.saffron,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Full group (${widget.preferences.groupSize}): '
                                  'USD ~${_estimateGroupCost(rec.totalCostPerPerson, widget.preferences.groupSize)}',
                                  style: GoogleFonts.nunito(
                                    fontSize: 13,
                                    color: AppTheme.coconutCream,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ).animate().fade(duration: 500.ms),
                ],
              ),
            ),
          ),

          // ── Activities ───────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle('Top Activities', Icons.sports_score_rounded),
                  const SizedBox(height: 12),
                  ...rec.activities.asMap().entries.map(
                    (e) => _ActivityCard(activity: e.value, index: e.key),
                  ),
                ],
              ),
            ),
          ),

          // ── Budget Assessment ─────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle(
                    'Budget Assessment',
                    Icons.account_balance_wallet_rounded,
                  ),
                  const SizedBox(height: 12),
                  _BudgetMeter(
                    budget: widget.preferences.budgetUsd,
                    estimated: _parseMinCost(rec.totalCostPerPerson),
                    groupSize: widget.preferences.groupSize,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) => Row(
    children: [
      Icon(icon, color: AppTheme.saffron, size: 18),
      const SizedBox(width: 8),
      Text(
        title,
        style: GoogleFonts.cormorantGaramond(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppTheme.coconutCream,
        ),
      ),
    ],
  );

  Widget _packageStat(String label, String value, IconData icon, Color color) =>
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.nunito(
                      fontSize: 10,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  Text(
                    value,
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.coconutCream,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  String _estimateGroupCost(String perPerson, int groupSize) {
    final min = _parseMinCost(perPerson);
    if (min <= 0) return 'N/A';
    return '${(min * groupSize).toInt()}–${((min * 1.3) * groupSize).toInt()}';
  }

  double _parseMinCost(String costStr) {
    final matches = RegExp(r'\d+').allMatches(costStr.replaceAll(',', ''));
    if (matches.isEmpty) return 0;
    return double.tryParse(matches.first.group(0) ?? '0') ?? 0;
  }
}

// ─── Activity Card ────────────────────────────────────────────────────────────
class _ActivityCard extends StatelessWidget {
  final Activity activity;
  final int index;

  const _ActivityCard({required this.activity, required this.index});

  static const _activityColors = [
    AppTheme.saffron,
    AppTheme.cinnamon,
    AppTheme.deepJungle,
    Color(0xFF0B7285),
    Color(0xFF7B1FA2),
  ];

  @override
  Widget build(BuildContext context) {
    final color = _activityColors[index % _activityColors.length];
    return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardDark,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  activity.name,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.coconutCream,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'USD ${activity.priceUsd}',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        )
        .animate(delay: Duration(milliseconds: 100 * index))
        .fade(duration: 400.ms)
        .slideX(begin: 0.1);
  }
}

// ─── Budget Meter ─────────────────────────────────────────────────────────────
class _BudgetMeter extends StatelessWidget {
  final double budget;
  final double estimated;
  final int groupSize;

  const _BudgetMeter({
    required this.budget,
    required this.estimated,
    required this.groupSize,
  });

  @override
  Widget build(BuildContext context) {
    final totalEstimated = estimated * groupSize;
    final ratio = budget > 0 ? (totalEstimated / budget).clamp(0.0, 1.5) : 0.0;
    final isOver = totalEstimated > budget;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.glassCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your Budget',
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  color: AppTheme.textMuted,
                ),
              ),
              Text(
                'USD ${budget.toInt()}',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.coconutCream,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Estimated (group)',
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  color: AppTheme.textMuted,
                ),
              ),
              Text(
                '~USD ${totalEstimated.toInt()}',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isOver ? AppTheme.errorRed : AppTheme.saffron,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: AppTheme.cardMid,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              FractionallySizedBox(
                widthFactor: ratio.clamp(0.0, 1.0),
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isOver
                          ? [AppTheme.errorRed, AppTheme.errorRed]
                          : [AppTheme.deepJungle, AppTheme.saffron],
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isOver
                  ? AppTheme.errorRed.withOpacity(0.1)
                  : AppTheme.deepJungle.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  isOver ? Icons.warning_rounded : Icons.check_circle_rounded,
                  color: isOver ? AppTheme.errorRed : const Color(0xFF51CF66),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isOver
                        ? 'Slightly over budget. Consider reducing trip days or group size.'
                        : 'Within your budget! Great choice for your group.',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: isOver
                          ? AppTheme.errorRed
                          : const Color(0xFF51CF66),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate(delay: 200.ms).fade(duration: 500.ms);
  }
}
