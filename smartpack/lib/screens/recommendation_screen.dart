import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../theme/app_theme.dart';
import '../models/travel_models.dart';
import 'destination_detail_screen.dart';

class RecommendationScreen extends StatefulWidget {
  final RecommendationResponse response;
  final TravelPreferences preferences;

  const RecommendationScreen({
    super.key,
    required this.response,
    required this.preferences,
  });

  @override
  State<RecommendationScreen> createState() => _RecommendationScreenState();
}

class _RecommendationScreenState extends State<RecommendationScreen> {
  final PageController _pageController = PageController(viewportFraction: 0.88);
  int _currentPage = 0;

  final Set<String> _savedNames = {};

  static const _rankBadges = {1: '🥇', 2: '🥈', 3: '🥉'};
  static const _rankColors = {
    1: AppTheme.saffron,
    2: Color(0xFFC0C0C0),
    3: Color(0xFFCD7F32),
  };

  @override
  void initState() {
    super.initState();
    _loadSavedNames();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ── SharedPreferences helpers ─────────────────────────────────────────────

  Future<void> _loadSavedNames() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('saved_destinations') ?? [];
    final names = raw.map((s) {
      final d = jsonDecode(s) as Map<String, dynamic>;
      return d['name'] as String;
    }).toSet();
    if (mounted)
      setState(
        () => _savedNames
          ..clear()
          ..addAll(names),
      );
  }

  Map<String, dynamic> _toDestMap(TravelRecommendation rec) => {
    'name': rec.destination,
    'tagline': rec.packageName,
    'image': rec.imageUrl ?? '',
    'region': '',
    'rating': rec.rating?.toString() ?? '',
    'tags': rec.activities.take(2).map((a) => a.name).toList(),
  };

  Future<void> _toggleSave(TravelRecommendation rec) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('saved_destinations') ?? [];
    final alreadySaved = _savedNames.contains(rec.destination);

    if (alreadySaved) {
      raw.removeWhere((s) {
        final d = jsonDecode(s) as Map<String, dynamic>;
        return d['name'] == rec.destination;
      });
      await prefs.setStringList('saved_destinations', raw);
      if (mounted) {
        setState(() => _savedNames.remove(rec.destination));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${rec.destination} removed from saved',
              style: GoogleFonts.nunito(color: AppTheme.coconutCream),
            ),
            backgroundColor: AppTheme.cardMid,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      raw.add(jsonEncode(_toDestMap(rec)));
      await prefs.setStringList('saved_destinations', raw);
      if (mounted) {
        setState(() => _savedNames.add(rec.destination));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${rec.destination} saved! ✓',
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
    final recs = widget.response.recommendations;
    final tips = widget.response.travelTips;

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: CustomScrollView(
        slivers: [
          // ── Hero Header ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.deepJungle, AppTheme.darkBg],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_rounded,
                          color: AppTheme.saffron,
                        ),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.saffron.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppTheme.saffron.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.auto_awesome_rounded,
                              color: AppTheme.saffron,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'AI Curated',
                              style: GoogleFonts.nunito(
                                fontSize: 11,
                                color: AppTheme.saffron,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Your Perfect',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.coconutCream,
                    ),
                  ).animate().fade(duration: 500.ms).slideY(begin: 0.2),
                  Text(
                        'Destinations',
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.saffron,
                        ),
                      )
                      .animate(delay: 100.ms)
                      .fade(duration: 500.ms)
                      .slideY(begin: 0.2),
                  const SizedBox(height: 12),
                  _buildTripSummary(),
                ],
              ),
            ),
          ),

          // ── Page Indicator ───────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  Text(
                    'Showing ${recs.length} recommendations',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: List.generate(
                      recs.length,
                      (i) => AnimatedContainer(
                        duration: 300.ms,
                        width: i == _currentPage ? 20 : 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: i == _currentPage
                              ? AppTheme.saffron
                              : AppTheme.cardMid,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Destination Cards ────────────────────────────────────────────
          SliverToBoxAdapter(
            child: SizedBox(
              height: 520,
              child: PageView.builder(
                controller: _pageController,
                itemCount: recs.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, index) {
                  final rec = recs[index];
                  return _DestinationCard(
                    rec: rec,
                    rankColor: _rankColors[rec.rank] ?? AppTheme.saffron,
                    rankBadge: _rankBadges[rec.rank] ?? '⭐',
                    isSaved: _savedNames.contains(rec.destination),
                    onToggleSave: () => _toggleSave(rec),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DestinationDetailScreen(
                          recommendation: rec,
                          preferences: widget.preferences,
                        ),
                      ),
                    ).then((_) => _loadSavedNames()),
                  );
                },
              ),
            ),
          ),

          // ── Quick Comparison ─────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Compare',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.coconutCream,
                    ),
                  ).animate(delay: 300.ms).fade(duration: 400.ms),
                  const SizedBox(height: 12),
                  ...recs.map(
                    (rec) => _ComparisonRow(rec: rec, isTop: rec.rank == 1),
                  ),
                ],
              ),
            ),
          ),

          // ── Travel Tips ──────────────────────────────────────────────────
          if (tips.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.tips_and_updates_rounded,
                          color: AppTheme.saffron,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Travel Tips',
                          style: GoogleFonts.cormorantGaramond(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.coconutCream,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...tips.asMap().entries.map(
                      (e) => _TipCard(tip: e.value, index: e.key),
                    ),
                  ],
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildTripSummary() {
    final p = widget.preferences;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardDark.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.saffron.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _summaryChip(Icons.group_rounded, '${p.groupSize} ${p.groupType}'),
          _divider(),
          _summaryChip(Icons.attach_money_rounded, '\$${p.budgetUsd.toInt()}'),
          _divider(),
          _summaryChip(Icons.schedule_rounded, '${p.tripDays} days'),
          _divider(),
          _summaryChip(Icons.calendar_today_rounded, p.travelMonth),
        ],
      ),
    ).animate(delay: 200.ms).fade(duration: 400.ms);
  }

  Widget _summaryChip(IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: AppTheme.saffron),
      const SizedBox(width: 4),
      Text(
        text,
        style: GoogleFonts.nunito(
          fontSize: 11,
          color: AppTheme.textLight,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );

  Widget _divider() =>
      Container(width: 1, height: 16, color: AppTheme.saffron.withOpacity(0.2));
}

// ─── Destination Card ─────────────────────────────────────────────────────────
class _DestinationCard extends StatelessWidget {
  final TravelRecommendation rec;
  final Color rankColor;
  final String rankBadge;
  final VoidCallback onTap;
  final bool isSaved;
  final VoidCallback onToggleSave;

  const _DestinationCard({
    required this.rec,
    required this.rankColor,
    required this.rankBadge,
    required this.onTap,
    required this.isSaved,
    required this.onToggleSave,
  });

  /// ── FIX: Smart image loader ───────────────────────────────────────────────
  /// Handles local asset paths, network URLs, and null/empty gracefully.
  Widget _buildImage(String? imageUrl) {
    // Placeholder widget reused for null/empty and errors
    Widget placeholder = Container(
      color: AppTheme.cardDark,
      child: const Center(
        child: Icon(
          Icons.image_not_supported_rounded,
          color: AppTheme.textMuted,
          size: 48,
        ),
      ),
    );

    if (imageUrl == null || imageUrl.trim().isEmpty) {
      return placeholder;
    }

    final isNetwork =
        imageUrl.startsWith('http://') || imageUrl.startsWith('https://');

    if (isNetwork) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(color: AppTheme.cardDark),
        errorWidget: (_, __, ___) => placeholder,
      );
    }

    // Local asset path (e.g. "assets/images/bali.jpg")
    return Image.asset(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => placeholder,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: rankColor.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── FIX: use smart image loader ──────────────────────────────
              _buildImage(rec.imageUrl),

              // Gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      AppTheme.darkBg.withOpacity(0.98),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.25, 1.0],
                  ),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Rank badge + save button row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: rankColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: rankColor.withOpacity(0.5),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                rankBadge,
                                style: const TextStyle(fontSize: 14),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Rank #${rec.rank}',
                                style: GoogleFonts.nunito(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: rankColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        // Save button with animated icon
                        GestureDetector(
                          onTap: onToggleSave,
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: AppTheme.darkBg.withOpacity(0.6),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSaved
                                    ? AppTheme.saffron.withOpacity(0.5)
                                    : AppTheme.textMuted.withOpacity(0.3),
                              ),
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              transitionBuilder: (child, anim) =>
                                  ScaleTransition(scale: anim, child: child),
                              child: Icon(
                                isSaved
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                key: ValueKey(isSaved),
                                size: 16,
                                color: isSaved
                                    ? AppTheme.saffron
                                    : AppTheme.textMuted,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (rec.rating != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.darkBg.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  size: 13,
                                  color: AppTheme.saffron,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '${rec.rating}',
                                  style: GoogleFonts.nunito(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.coconutCream,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const Spacer(),
                    // Destination name
                    Text(
                      rec.destination,
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.coconutCream,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.wb_sunny_rounded,
                          size: 14,
                          color: AppTheme.saffron,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            rec.weatherSuitability,
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Package info
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.cardDark.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: rankColor.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.luggage_rounded,
                                size: 14,
                                color: AppTheme.saffron,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  rec.packageName,
                                  style: GoogleFonts.nunito(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.coconutCream,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _infoChip(
                                Icons.attach_money_rounded,
                                'USD ${rec.packageCostPerPerson}/pp',
                                AppTheme.saffron,
                              ),
                              _infoChip(
                                Icons.hotel_rounded,
                                rec.accommodation.split(',').first,
                                AppTheme.cinnamon,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: AppTheme.spiceGradient,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'View Details →',
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.darkBg,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fade(duration: 500.ms).scale(begin: const Offset(0.95, 0.95));
  }

  Widget _infoChip(IconData icon, String text, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 12, color: color),
      const SizedBox(width: 4),
      Text(
        text,
        style: GoogleFonts.nunito(fontSize: 11, color: AppTheme.textMuted),
      ),
    ],
  );
}

// ─── Comparison Row ───────────────────────────────────────────────────────────
class _ComparisonRow extends StatelessWidget {
  final TravelRecommendation rec;
  final bool isTop;

  const _ComparisonRow({required this.rec, required this.isTop});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isTop ? AppTheme.saffron.withOpacity(0.08) : AppTheme.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isTop ? AppTheme.saffron.withOpacity(0.3) : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isTop
                  ? AppTheme.saffron.withOpacity(0.2)
                  : AppTheme.cardMid,
            ),
            child: Center(
              child: Text(
                '${rec.rank}',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isTop ? AppTheme.saffron : AppTheme.textMuted,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rec.destination,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.coconutCream,
                  ),
                ),
                Text(
                  'USD ${rec.totalCostPerPerson}/person',
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (isTop)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.saffron.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Best Match',
                style: GoogleFonts.nunito(
                  fontSize: 10,
                  color: AppTheme.saffron,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    ).animate(delay: 400.ms).fade(duration: 400.ms).slideX(begin: 0.1);
  }
}

// ─── Tip Card ─────────────────────────────────────────────────────────────────
class _TipCard extends StatelessWidget {
  final String tip;
  final int index;

  const _TipCard({required this.tip, required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.cardDark,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.deepJungle.withOpacity(0.5)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.deepJungle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.coconutCream,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  tip,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: AppTheme.textLight,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        )
        .animate(delay: Duration(milliseconds: 100 * index))
        .fade(duration: 400.ms);
  }
}
