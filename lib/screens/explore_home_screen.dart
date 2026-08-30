import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/feedback_service.dart';
import 'preference_screen.dart';
import 'saved_screen.dart';
import 'profile_screen.dart';

class ExploreHomeScreen extends StatefulWidget {
  const ExploreHomeScreen({super.key});

  @override
  State<ExploreHomeScreen> createState() => _ExploreHomeScreenState();
}

class _ExploreHomeScreenState extends State<ExploreHomeScreen> {
  int _selectedIndex = 0;

  static const _featuredDestinations = [
    {
      'name': 'Sigiriya',
      'tagline': 'Ancient Rock Fortress',
      'image': 'assets/images/sigiriya.jpg',
      'region': 'Cultural Triangle',
      'rating': '4.9',
      'tags': ['Heritage', 'Adventure', 'UNESCO'],
    },
    {
      'name': 'Ella',
      'tagline': 'Hill Country Paradise',
      'image': 'assets/images/ella.jpg',
      'region': 'Uva Province',
      'rating': '4.8',
      'tags': ['Nature', 'Trekking', 'Tea'],
    },
    {
      'name': 'Galle Fort',
      'tagline': 'Colonial Coastal Gem',
      'image': 'assets/images/gallefort.jpg',
      'region': 'Southern Province',
      'rating': '4.7',
      'tags': ['History', 'Beach', 'Culture'],
    },
    {
      'name': 'Yala National Park',
      'tagline': 'Wild Leopard Territory',
      'image': 'assets/images/yala.jpg',
      'region': 'Southern Province',
      'rating': '4.8',
      'tags': ['Wildlife', 'Safari', 'Nature'],
    },
    {
      'name': 'Mirissa',
      'tagline': 'Whale Watching Capital',
      'image': 'assets/images/mirissa.jpg',
      'region': 'Southern Coast',
      'rating': '4.6',
      'tags': ['Beach', 'Whales', 'Diving'],
    },
  ];

  static const _categories = [
    {
      'icon': Icons.account_balance_rounded,
      'label': 'Heritage',
      'color': 0xFFB5651D,
      'image': 'assets/images/sigiriya.jpg',
      'description': 'Ancient forts, ruins & UNESCO sites',
      // ── Gallery shown in the "Browse by Category" dialog ──────────────
      'images': [
        'assets/images/sigiriya.jpg',
        'assets/images/sigiriya2.jpg',
        'assets/images/sigiriya3.jpg',
        'assets/images/dambulla.jpg',
        'assets/images/dambulla2.jpg',
        'assets/images/dambulla3.jpg',
        'assets/images/anuradhapura.jpg',
        'assets/images/anuradhapura2.jpg',
        'assets/images/anuradhapura3.jpg',
        'assets/images/polonnaruwa.jpg',
        'assets/images/polonnaruwa2.jpg',
        'assets/images/polonnaruwa3.jpg',
        'assets/images/gallefort.jpg',
        'assets/images/gallefort2.jpg',
        'assets/images/gallefort3.jpg',
      ],
    },
    {
      'icon': Icons.forest_rounded,
      'label': 'Nature',
      'color': 0xFF1B4332,
      'image': 'assets/images/HortonPlains.jpg',
      'description': 'Rainforests, hills & tea country',
      'images': [
        'assets/images/HortonPlains.jpg',
        'assets/images/HortonPlains2.jpg',
        'assets/images/HortonPlains3.jpg',
        'assets/images/Knuckles.jpg',
        'assets/images/Knuckles2.jpg',
        'assets/images/Knuckles3.jpg',
        'assets/images/nuwaraeliya.jpg',
        'assets/images/nuwareliya2.jpg',
        'assets/images/nuwaraeliya3.jpg',
        'assets/images/ella.jpg',
        'assets/images/ella2.jpg',
        'assets/images/ella3.jpg',
      ],
    },
    {
      'icon': Icons.waves_rounded,
      'label': 'Beach',
      'color': 0xFF0B7285,
      'image': 'assets/images/mirissa.jpg',
      'description': 'Golden coastlines & surf towns',
      'images': [
        'assets/images/mirissa.jpg',
        'assets/images/mirissa2.jpg',
        'assets/images/mirissa3.jpg',
        'assets/images/Unawatuna.jpg',
        'assets/images/Unawatuna2.jpg',
        'assets/images/Unawatuna3.jpg',
        'assets/images/benthota.jpg',
        'assets/images/benthota2.jpg',
        'assets/images/benthota3.jpg',
        'assets/images/ArugamBay.jpg',
        'assets/images/ArugamBay2.jpg',
        'assets/images/ArugamBay3.jpg',
        'assets/images/trincomalee.jpg',
        'assets/images/trincomalee2.jpg',
        'assets/images/trincomalee3.jpg',
      ],
    },
    {
      'icon': Icons.pets_rounded,
      'label': 'Wildlife',
      'color': 0xFF5C4033,
      'image': 'assets/images/yala.jpg',
      'description': 'Safaris, leopards & elephants',
      'images': [
        'assets/images/yala.jpg',
        'assets/images/yala2.jpg',
        'assets/images/yala3.jpg',
        'assets/images/Udawalawe.jpg',
        'assets/images/Udawalawe2.jpg',
        'assets/images/Udawalawe3.jpg',
        'assets/images/Wilpattu.jpg',
        'assets/images/Wilpattu2.jpg',
        'assets/images/Wilpattu3.jpg',
      ],
    },
    {
      'icon': Icons.temple_buddhist_rounded,
      'label': 'Culture',
      'color': 0xFF7B1FA2,
      'image': 'assets/images/kandy.jpg',
      'description': 'Temples, festivals & traditions',
      'images': [
        'assets/images/kandy.jpg',
        'assets/images/kandy2.jpg',
        'assets/images/kandy3.jpg',
        'assets/images/Jaffna.jpg',
        'assets/images/Jaffna2.jpg',
        'assets/images/Jaffna3.jpg',
        'assets/images/colombo.jpg',
        'assets/images/colombo2.jpg',
        'assets/images/colombo3.jpg',
      ],
    },
    {
      'icon': Icons.directions_walk_rounded,
      'label': 'Trek',
      'color': 0xFF388E3C,
      'image': 'assets/images/ella.jpg',
      'description': 'Scenic trails & mountain views',
      'images': [
        'assets/images/ella.jpg',
        'assets/images/ella2.jpg',
        'assets/images/ella3.jpg',
        'assets/images/Knuckles.jpg',
        'assets/images/Knuckles2.jpg',
        'assets/images/Knuckles3.jpg',
        'assets/images/HortonPlains.jpg',
        'assets/images/HortonPlains2.jpg',
        'assets/images/HortonPlains3.jpg',
      ],
    },
  ];

  Widget get _currentBody {
    switch (_selectedIndex) {
      case 1:
        return const PreferenceScreen(embeddedMode: true);
      case 2:
        return const SavedScreen();
      default:
        return _ExploreTab(
          featuredDestinations: _featuredDestinations,
          categories: _categories,
          onAIPlanTap: () => setState(() => _selectedIndex = 1),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        child: KeyedSubtree(key: ValueKey(_selectedIndex), child: _currentBody),
      ),
      bottomNavigationBar: _BottomNav(
        selectedIndex: _selectedIndex,
        onChanged: (i) => setState(() => _selectedIndex = i),
      ),
    );
  }
}

// ─── Explore Tab ──────────────────────────────────────────────────────────────
class _ExploreTab extends StatelessWidget {
  final List<Map<String, dynamic>> featuredDestinations;
  final List<Map<String, dynamic>> categories;
  final VoidCallback onAIPlanTap;

  const _ExploreTab({
    required this.featuredDestinations,
    required this.categories,
    required this.onAIPlanTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ceylon',
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.coconutCream,
                        ),
                      ),
                      Text(
                        'Tour Mate',
                        style: GoogleFonts.nunito(
                          fontSize: 10,
                          color: AppTheme.saffron,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 3,
                        ),
                      ),
                    ],
                  )
                      .animate()
                      .fade(duration: const Duration(milliseconds: 500))
                      .slideX(begin: -0.1),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: onAIPlanTap,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            gradient: AppTheme.spiceGradient,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.saffron.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.auto_awesome_rounded,
                                size: 16,
                                color: AppTheme.darkBg,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'AI Plan',
                                style: GoogleFonts.nunito(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.darkBg,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                          .animate(delay: const Duration(milliseconds: 200))
                          .fade(duration: const Duration(milliseconds: 400))
                          .scale(),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ProfileScreen(),
                          ),
                        ),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.cardMid,
                            border: Border.all(
                              color: AppTheme.saffron.withOpacity(0.3),
                            ),
                          ),
                          child: const Icon(
                            Icons.person_rounded,
                            color: AppTheme.saffron,
                            size: 20,
                          ),
                        ),
                      )
                          .animate(delay: const Duration(milliseconds: 250))
                          .fade(duration: const Duration(milliseconds: 400))
                          .scale(),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Discover\nSri Lanka',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 42,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.coconutCream,
                      height: 1.1,
                    ),
                  )
                      .animate(delay: const Duration(milliseconds: 100))
                      .fade(duration: const Duration(milliseconds: 600))
                      .slideY(begin: 0.2),
                  const SizedBox(height: 8),
                  Text(
                    'AI-powered recommendations tailored to you',
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      color: AppTheme.textMuted,
                    ),
                  )
                      .animate(delay: const Duration(milliseconds: 200))
                      .fade(duration: const Duration(milliseconds: 500)),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 24),
              child: SizedBox(
                height: 340,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: featuredDestinations.length,
                  itemBuilder: (context, index) => _FeaturedCard(
                    data: featuredDestinations[index],
                    index: index,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Browse by',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.coconutCream,
                    ),
                  ),
                  Text(
                    'Category',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.saffron,
                    ),
                  ),
                  const SizedBox(height: 16),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.35,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                    ),
                    itemCount: categories.length,
                    itemBuilder: (_, i) =>
                        _CategoryCard(data: categories[i], index: i),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
              child: GestureDetector(
                onTap: onAIPlanTap,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: AppTheme.jungleGradient,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppTheme.saffron.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Plan Your Perfect',
                              style: GoogleFonts.cormorantGaramond(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.coconutCream,
                              ),
                            ),
                            Text(
                              'Sri Lanka Journey',
                              style: GoogleFonts.cormorantGaramond(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.saffron,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Get AI-curated top 3 destinations with packages, activities & pricing',
                              style: GoogleFonts.nunito(
                                fontSize: 12,
                                color: AppTheme.textMuted,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                gradient: AppTheme.spiceGradient,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Get Recommendations →',
                                style: GoogleFonts.nunito(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.darkBg,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.saffron.withOpacity(0.15),
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: AppTheme.saffron,
                          size: 30,
                        ),
                      ),
                    ],
                  ),
                )
                    .animate(delay: const Duration(milliseconds: 400))
                    .fade(duration: const Duration(milliseconds: 600))
                    .slideY(begin: 0.2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Featured Destination Card ────────────────────────────────────────────────
class _FeaturedCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final int index;
  final FeedbackService _feedbackService = FeedbackService();

  _FeaturedCard({required this.data, required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      margin: const EdgeInsets.only(right: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ✅ Image.asset replaces CachedNetworkImage for local assets
            Image.asset(
              data['image'] as String,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: AppTheme.cardDark,
                child: const Center(
                  child: Icon(
                    Icons.image_not_supported_rounded,
                    color: AppTheme.textMuted,
                    size: 32,
                  ),
                ),
              ),
            ),
            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    AppTheme.darkBg.withOpacity(0.95),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.3, 1.0],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.deepJungle.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      data['region'] as String,
                      style: GoogleFonts.nunito(
                        fontSize: 10,
                        color: AppTheme.coconutCream,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    data['name'] as String,
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.coconutCream,
                    ),
                  ),
                  Text(
                    data['tagline'] as String,
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: (data['tags'] as List<String>)
                        .map(
                          (t) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.saffron.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppTheme.saffron.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              t,
                              style: GoogleFonts.nunito(
                                fontSize: 10,
                                color: AppTheme.saffron,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 10),
                  StreamBuilder<RatingSummary>(
                    stream: _feedbackService.watchAverageRating(
                      data['name'] as String,
                    ),
                    builder: (context, snapshot) {
                      final live = snapshot.data;
                      final hasLive = live != null && live.count > 0;
                      return Row(
                        children: [
                          if (hasLive) ...[
                            const Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: AppTheme.saffron,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              live.average.toStringAsFixed(1),
                              style: GoogleFonts.nunito(
                                fontSize: 13,
                                color: AppTheme.coconutCream,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '(${live.count})',
                              style: GoogleFonts.nunito(
                                fontSize: 11,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ] else ...[
                            const Icon(
                              Icons.star_border_rounded,
                              size: 14,
                              color: AppTheme.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'New',
                              style: GoogleFonts.nunito(
                                fontSize: 12,
                                color: AppTheme.textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(width: 10),
                          StreamBuilder<List<ReviewEntry>>(
                            stream: _feedbackService.watchReviews(
                              data['name'] as String,
                            ),
                            builder: (context, reviewSnap) {
                              final commentCount = (reviewSnap.data ?? [])
                                  .where(
                                    (r) => r.comment.trim().isNotEmpty,
                                  )
                                  .length;
                              if (commentCount == 0) {
                                return const SizedBox.shrink();
                              }
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.chat_bubble_rounded,
                                    size: 12,
                                    color: AppTheme.textMuted,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    '$commentCount',
                                    style: GoogleFonts.nunito(
                                      fontSize: 12,
                                      color: AppTheme.textMuted,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: 100 * index))
        .fade(duration: const Duration(milliseconds: 500))
        .slideX(begin: 0.2);
  }
}

// ─── Category Card ─────────────────────────────────────────────────────────────
class _CategoryCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final int index;

  const _CategoryCard({required this.data, required this.index});

  void _openGallery(BuildContext context) {
    final color = Color(data['color'] as int);
    final images = (data['images'] as List?)?.cast<String>() ??
        [if (data['image'] != null) data['image'] as String];

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.75),
      builder: (dialogContext) => Dialog(
        backgroundColor: AppTheme.cardDark,
        insetPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 40,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: color.withOpacity(0.35)),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 620),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.85),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        data['icon'] as IconData,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['label'] as String,
                            style: GoogleFonts.cormorantGaramond(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.coconutCream,
                            ),
                          ),
                          Text(
                            data['description'] as String? ?? '',
                            style: GoogleFonts.nunito(
                              fontSize: 11,
                              color: AppTheme.textMuted,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: color.withOpacity(0.2)),
              Flexible(
                child: images.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          'No images available yet.',
                          style: GoogleFonts.nunito(
                            color: AppTheme.textMuted,
                          ),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        shrinkWrap: true,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 1.1,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                        ),
                        itemCount: images.length,
                        itemBuilder: (_, i) => ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.asset(
                            images[i],
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: color.withOpacity(0.15),
                              child: const Center(
                                child: Icon(
                                  Icons.image_not_supported_rounded,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(data['color'] as int);
    final image = data['image'] as String?;
    return GestureDetector(
      onTap: () => _openGallery(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (image != null)
                Image.asset(
                  image,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Container(color: color.withOpacity(0.2)),
                ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.15),
                      AppTheme.darkBg.withOpacity(0.88),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.2, 1.0],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.85),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        data['icon'] as IconData,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      data['label'] as String,
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.coconutCream,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      data['description'] as String? ?? '',
                      style: GoogleFonts.nunito(
                        fontSize: 10,
                        color: AppTheme.textMuted,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: 50 * index))
        .fade(duration: const Duration(milliseconds: 400))
        .scale(begin: const Offset(0.85, 0.85));
  }
}

// ─── Bottom Navigation ─────────────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _BottomNav({required this.selectedIndex, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        border: Border(
          top: BorderSide(color: AppTheme.saffron.withOpacity(0.1)),
        ),
      ),
      child: BottomNavigationBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        currentIndex: selectedIndex,
        onTap: onChanged,
        selectedItemColor: AppTheme.saffron,
        unselectedItemColor: AppTheme.textMuted,
        selectedLabelStyle: GoogleFonts.nunito(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.nunito(fontSize: 11),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.explore_rounded),
            label: 'Explore',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.auto_awesome_rounded),
            label: 'AI Plan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_rounded),
            label: 'Saved',
          ),
        ],
      ),
    );
  }
}
