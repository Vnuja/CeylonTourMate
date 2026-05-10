import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'preference_screen.dart';
import 'saved_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
      'name': 'Yala Safari',
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
    },
    {'icon': Icons.forest_rounded, 'label': 'Nature', 'color': 0xFF1B4332},
    {'icon': Icons.waves_rounded, 'label': 'Beach', 'color': 0xFF0B7285},
    {'icon': Icons.pets_rounded, 'label': 'Wildlife', 'color': 0xFF5C4033},
    {
      'icon': Icons.temple_buddhist_rounded,
      'label': 'Culture',
      'color': 0xFF7B1FA2,
    },
    {
      'icon': Icons.directions_walk_rounded,
      'label': 'Trek',
      'color': 0xFF388E3C,
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
                            'TRAVEL PLANNER',
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
                          crossAxisCount: 3,
                          childAspectRatio: 1.1,
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
                child:
                    Container(
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

  const _FeaturedCard({required this.data, required this.index});

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
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: AppTheme.saffron,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            data['rating'] as String,
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

  @override
  Widget build(BuildContext context) {
    final color = Color(data['color'] as int);
    return Container(
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(data['icon'] as IconData, color: color, size: 28),
              const SizedBox(height: 6),
              Text(
                data['label'] as String,
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.coconutCream,
                ),
              ),
            ],
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
