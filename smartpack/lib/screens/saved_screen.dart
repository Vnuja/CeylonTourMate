import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../theme/app_theme.dart';

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  List<Map<String, dynamic>> _savedItems = [];
  bool _isLoading = true;

  static const _allDestinations = [
    {
      'name': 'Sigiriya',
      'tagline': 'Ancient Rock Fortress',
      'image': 'assets/images/sigiriya.jpg',
      'region': 'Cultural Triangle',
      'rating': '4.9',
      'tags': ['Heritage', 'Adventure'],
    },
    {
      'name': 'Ella',
      'tagline': 'Hill Country Paradise',
      'image': 'assets/images/ella2.jpg',
      'region': 'Uva Province',
      'rating': '4.8',
      'tags': ['Nature', 'Tea'],
    },
    {
      'name': 'Galle Fort',
      'tagline': 'Colonial Coastal Gem',
      'image': 'assets/images/gallefort.jpg',
      'region': 'Southern Province',
      'rating': '4.7',
      'tags': ['History', 'Beach'],
    },
    {
      'name': 'Yala National Park',
      'tagline': 'Wild Leopard Territory',
      'image': 'assets/images/yala.jpg',
      'region': 'Southern Province',
      'rating': '4.8',
      'tags': ['Wildlife', 'Safari'],
    },
    {
      'name': 'Mirissa',
      'tagline': 'Whale Watching Capital',
      'image': 'assets/images/mirissa.jpg',
      'region': 'Southern Coast',
      'rating': '4.6',
      'tags': ['Beach', 'Whales'],
    },
    {
      'name': 'Nuwara Eliya',
      'tagline': 'Little England of Sri Lanka',
      'image': 'assets/images/nuwaraeliya.jpg',
      'region': 'Central Province',
      'rating': '4.6',
      'tags': ['Nature', 'Cool Climate'],
    },
    {
      'name': 'Kandy',
      'tagline': 'Sacred City of the Tooth',
      'image': 'assets/images/kandy.jpg',
      'region': 'Central Province',
      'rating': '4.8',
      'tags': ['Culture', 'Heritage'],
    },
    {
      'name': 'Trincomalee',
      'tagline': 'Natural Harbour & Beaches',
      'image': 'assets/images/trincomalee.jpg',
      'region': 'Eastern Province',
      'rating': '4.6',
      'tags': ['Beach', 'Diving'],
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList('saved_destinations') ?? [];
      setState(() {
        _savedItems = raw
            .map((s) => jsonDecode(s) as Map<String, dynamic>)
            .toList();
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveDestination(Map<String, dynamic> dest) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList('saved_destinations') ?? [];
    final alreadySaved = existing.any((s) {
      final d = jsonDecode(s) as Map<String, dynamic>;
      return d['name'] == dest['name'];
    });
    if (alreadySaved) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${dest['name']} already saved!',
            style: GoogleFonts.nunito(color: AppTheme.coconutCream),
          ),
          backgroundColor: AppTheme.cardMid,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    existing.add(jsonEncode(dest));
    await prefs.setStringList('saved_destinations', existing);
    _loadSaved();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${dest['name']} saved! ✓',
            style: GoogleFonts.nunito(color: AppTheme.coconutCream),
          ),
          backgroundColor: AppTheme.deepJungle,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _removeDestination(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList('saved_destinations') ?? [];
    existing.removeWhere((s) {
      final d = jsonDecode(s) as Map<String, dynamic>;
      return d['name'] == name;
    });
    await prefs.setStringList('saved_destinations', existing);
    _loadSaved();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Saved',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.coconutCream,
                      ),
                    ),
                    Text(
                      'Your wishlist destinations',
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            if (_isLoading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: AppTheme.saffron),
                ),
              )
            else if (_savedItems.isEmpty) ...[
              // Empty state
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                  child: Column(
                    children: [
                      Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: AppTheme.cardDark,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppTheme.saffron.withOpacity(0.15),
                              ),
                            ),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.favorite_border_rounded,
                                  color: AppTheme.saffron,
                                  size: 48,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No saved destinations yet',
                                  style: GoogleFonts.cormorantGaramond(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.coconutCream,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Tap ♥ on any destination below to save it',
                                  style: GoogleFonts.nunito(
                                    fontSize: 13,
                                    color: AppTheme.textMuted,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                          .animate()
                          .fade(duration: const Duration(milliseconds: 400))
                          .scale(begin: const Offset(0.9, 0.9)),
                      const SizedBox(height: 28),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Popular Destinations',
                          style: GoogleFonts.cormorantGaramond(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.coconutCream,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Tap ♥ to add to your wishlist',
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                  ),
                ),
              ),
              // Suggestion cards
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                    child: _DestinationTile(
                      data: _allDestinations[i],
                      isSaved: false,
                      onSave: () => _saveDestination(_allDestinations[i]),
                      onRemove: null,
                      index: i,
                    ),
                  ),
                  childCount: _allDestinations.length,
                ),
              ),
            ] else ...[
              // Saved count
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.saffron.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppTheme.saffron.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          '${_savedItems.length} saved',
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.saffron,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Saved list
              SliverList(
                delegate: SliverChildBuilderDelegate((context, i) {
                  final item = _savedItems[i];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                    child: _DestinationTile(
                      data: item,
                      isSaved: true,
                      onSave: null,
                      onRemove: () =>
                          _removeDestination(item['name'] as String),
                      index: i,
                    ),
                  );
                }, childCount: _savedItems.length),
              ),
              // Suggest more
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(color: AppTheme.cardMid),
                      const SizedBox(height: 12),
                      Text(
                        'Discover More',
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.coconutCream,
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate((context, i) {
                  final dest = _allDestinations[i];
                  final alreadySaved = _savedItems.any(
                    (s) => s['name'] == dest['name'],
                  );
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                    child: _DestinationTile(
                      data: dest,
                      isSaved: alreadySaved,
                      onSave: alreadySaved
                          ? null
                          : () => _saveDestination(dest),
                      onRemove: alreadySaved
                          ? () => _removeDestination(dest['name'] as String)
                          : null,
                      index: i,
                    ),
                  );
                }, childCount: _allDestinations.length),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }
}

// ─── Destination Tile ─────────────────────────────────────────────────────────
class _DestinationTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isSaved;
  final VoidCallback? onSave;
  final VoidCallback? onRemove;
  final int index;

  const _DestinationTile({
    required this.data,
    required this.isSaved,
    required this.onSave,
    required this.onRemove,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
          height: 110,
          decoration: BoxDecoration(
            color: AppTheme.cardDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSaved
                  ? AppTheme.saffron.withOpacity(0.3)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              // Image — ✅ Image.asset replaces CachedNetworkImage
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
                child: SizedBox(
                  width: 110,
                  height: 110,
                  child: Image.asset(
                    data['image'] as String? ?? '',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppTheme.cardMid,
                      child: const Icon(
                        Icons.image_not_supported_rounded,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
              // Info
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        data['name'] as String? ?? '',
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.coconutCream,
                        ),
                      ),
                      Text(
                        data['tagline'] as String? ?? '',
                        style: GoogleFonts.nunito(
                          fontSize: 11,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            size: 11,
                            color: AppTheme.saffron,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              data['region'] as String? ?? '',
                              style: GoogleFonts.nunito(
                                fontSize: 11,
                                color: AppTheme.saffron,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (data['rating'] != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 11,
                              color: AppTheme.saffron,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              data['rating'] as String,
                              style: GoogleFonts.nunito(
                                fontSize: 11,
                                color: AppTheme.coconutCream,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Save / Remove button
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: GestureDetector(
                  onTap: isSaved ? onRemove : onSave,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSaved
                          ? AppTheme.saffron.withOpacity(0.15)
                          : AppTheme.cardMid,
                      border: Border.all(
                        color: isSaved
                            ? AppTheme.saffron.withOpacity(0.5)
                            : AppTheme.textMuted.withOpacity(0.2),
                      ),
                    ),
                    child: Icon(
                      isSaved
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: isSaved ? AppTheme.saffron : AppTheme.textMuted,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
        )
        .animate(delay: Duration(milliseconds: 60 * index))
        .fade(duration: const Duration(milliseconds: 350))
        .slideX(begin: 0.1);
  }
}
