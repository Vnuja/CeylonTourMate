import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../theme/app_theme.dart';
import '../models/travel_models.dart';
import '../providers/auth_provider.dart' as app_auth;
import '../services/feedback_service.dart';

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
  final FeedbackService _feedbackService = FeedbackService();
  int _userRating = 0;
  bool _submittingRating = false;
  final TextEditingController _commentController = TextEditingController();

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

  // ── Full-screen gallery viewer (pinch-zoom + swipe) ───────────────────────
  void _openGallery(int initialIndex) {
    final images = _images;
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (context, animation, __) {
          return FadeTransition(
            opacity: animation,
            child: _GalleryViewer(
              images: images,
              initialIndex: initialIndex,
              buildImage: _buildImage,
            ),
          );
        },
      ),
    );
  }

  Widget _buildImage({
    required String imagePath,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    final defaultPlaceholder =
        placeholder ?? Container(color: AppTheme.cardDark);
    final defaultError = errorWidget ??
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
    _loadUserRating();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadUserRating() async {
    final uid = context.read<app_auth.AuthProvider>().firebaseUser?.uid;
    if (uid == null) return;
    final existing = await _feedbackService.getUserFeedback(
      uid: uid,
      destination: widget.recommendation.destination,
    );
    if (mounted && existing != null) {
      setState(() {
        _userRating = existing.rating;
        _commentController.text = existing.comment;
      });
    }
  }

  // ── Map link (opens Google Maps externally — no in-app map view) ─────────
  Future<void> _openInMaps() async {
    final query = Uri.encodeComponent(
      '${widget.recommendation.destination}, Sri Lanka',
    );
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$query',
    );
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not open Maps',
            style: GoogleFonts.nunito(color: AppTheme.coconutCream),
          ),
          backgroundColor: AppTheme.cardMid,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── Feedback / rating + comment (used to personalise future AI recs and
  // shown publicly in the Reviews list) ─────────────────────────────────────

  /// Tapping a star only selects it locally — the actual submission (with
  /// whatever comment has been typed) happens when "Submit Review" is tapped,
  /// so the comment isn't lost/skipped by an eager auto-submit on tap.
  void _selectStar(int stars) {
    final uid = context.read<app_auth.AuthProvider>().firebaseUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sign in to rate this destination',
            style: GoogleFonts.nunito(color: AppTheme.coconutCream),
          ),
          backgroundColor: AppTheme.cardMid,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _userRating = stars);
  }

  Future<void> _submitReview() async {
    final uid = context.read<app_auth.AuthProvider>().firebaseUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sign in to rate this destination',
            style: GoogleFonts.nunito(color: AppTheme.coconutCream),
          ),
          backgroundColor: AppTheme.cardMid,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_userRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Tap a star to choose a rating first',
            style: GoogleFonts.nunito(color: AppTheme.coconutCream),
          ),
          backgroundColor: AppTheme.cardMid,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _submittingRating = true);
    try {
      final displayName =
          context.read<app_auth.AuthProvider>().firebaseUser?.displayName;
      await _feedbackService.submitRating(
        uid: uid,
        destination: widget.recommendation.destination,
        rating: _userRating,
        comment: _commentController.text,
        displayName: (displayName != null && displayName.isNotEmpty)
            ? displayName
            : null,
      );
      if (mounted) {
        FocusScope.of(context).unfocus();
        setState(() {
          _userRating = 0;
          _commentController.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Thanks! Your review helps us recommend better trips for you.',
              style: GoogleFonts.nunito(color: AppTheme.coconutCream),
            ),
            backgroundColor: AppTheme.deepJungle,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('submitReview failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not submit your review. Please try again.',
              style: GoogleFonts.nunito(color: AppTheme.coconutCream),
            ),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submittingRating = false);
    }
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
                  color: AppTheme.darkBg.withValues(alpha: 0.7),
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
                    color: AppTheme.darkBg.withValues(alpha: 0.7),
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
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, AppTheme.darkBg],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.5, 1.0],
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
                        StreamBuilder<RatingSummary>(
                          stream: _feedbackService.watchAverageRating(
                            rec.destination,
                          ),
                          builder: (context, ratingSnap) {
                            final live = ratingSnap.data;
                            final hasLive = live != null && live.count > 0;
                            return Row(
                              children: [
                                if (hasLive) ...[
                                  ...List.generate(
                                    5,
                                    (i) => Icon(
                                      i < live.average.round()
                                          ? Icons.star_rounded
                                          : Icons.star_border_rounded,
                                      color: AppTheme.saffron,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
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
                                    '(${live.count} rating${live.count == 1 ? '' : 's'})',
                                    style: GoogleFonts.nunito(
                                      fontSize: 12,
                                      color: AppTheme.textMuted,
                                    ),
                                  ),
                                ] else
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.star_border_rounded,
                                        color: AppTheme.textMuted,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'New — be the first to rate',
                                        style: GoogleFonts.nunito(
                                          fontSize: 12,
                                          color: AppTheme.textMuted,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ),
                                const SizedBox(width: 14),
                                StreamBuilder<List<ReviewEntry>>(
                                  stream: _feedbackService.watchReviews(
                                    rec.destination,
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
                                          size: 13,
                                          color: AppTheme.textMuted,
                                        ),
                                        const SizedBox(width: 4),
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
                      color: AppTheme.deepJungle.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.deepJungle.withValues(alpha: 0.4),
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
                      itemBuilder: (_, i) => GestureDetector(
                        onTap: () => _openGallery(i),
                        child: Container(
                          width: 175,
                          height: 130, // fixed size, same for every thumbnail
                          margin: const EdgeInsets.only(right: 12),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: SizedBox(
                                  width: 175,
                                  height: 130,
                                  child: _buildImage(
                                    imagePath: _images[i],
                                    fit: BoxFit
                                        .cover, // fills the box completely, crops if needed
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
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(
                                      alpha: 0.45,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.zoom_in_rounded,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                              ),
                            ],
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

          // ── Location (external Google Maps link) ────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle('Location', Icons.map_rounded),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _openInMaps,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.cardDark,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.saffron.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.saffron.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.location_on_rounded,
                              color: AppTheme.saffron,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Open in Google Maps',
                                  style: GoogleFonts.nunito(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.coconutCream,
                                  ),
                                ),
                                Text(
                                  'Get directions to ${rec.destination}',
                                  style: GoogleFonts.nunito(
                                    fontSize: 12,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.open_in_new_rounded,
                            color: AppTheme.textMuted,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ).animate().fade(duration: 400.ms),
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
                          const Color(0xFF0B7285).withValues(alpha: 0.15),
                          AppTheme.cardDark,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF0B7285).withValues(alpha: 0.3),
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
                          AppTheme.cinnamon.withValues(alpha: 0.15),
                          AppTheme.cardDark,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.cinnamon.withValues(alpha: 0.3),
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
                        if (rec.transportInfo.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _packageStat(
                            'Transport',
                            rec.transportInfo,
                            Icons.directions_car_filled_rounded,
                            const Color(0xFF0B7285),
                          ),
                        ],
                        if (rec.entryFees.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _packageStat(
                            'Entry Fees',
                            rec.entryFees,
                            Icons.confirmation_number_rounded,
                            const Color(0xFF7B1FA2),
                          ),
                        ],
                        if (rec.hotelOptions.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            'HOTEL OPTIONS',
                            style: GoogleFonts.nunito(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                              color: AppTheme.textMuted,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...rec.hotelOptions.map(
                            (tierOption) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        _hotelTierIcon(tierOption.tier),
                                        size: 13,
                                        color: AppTheme.saffron,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        tierOption.tier,
                                        style: GoogleFonts.nunito(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.saffron,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  ...tierOption.hotels.map(
                                    (h) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 6,
                                        left: 4,
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Icon(
                                            Icons.hotel_rounded,
                                            size: 14,
                                            color: AppTheme.cinnamon,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              h,
                                              style: GoogleFonts.nunito(
                                                fontSize: 12.5,
                                                color: AppTheme.textLight,
                                                height: 1.4,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
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
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
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

          // ── Rate this destination (feeds future AI recommendations) ──────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle('Rate This Destination', Icons.star_rounded),
                  const SizedBox(height: 6),
                  Text(
                    'Your rating and review help us recommend better trips for you next time.',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.cardDark,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.saffron.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (i) {
                            final starIndex = i + 1;
                            final filled = starIndex <= _userRating;
                            return GestureDetector(
                              onTap: _submittingRating
                                  ? null
                                  : () => _selectStar(starIndex),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: Icon(
                                  filled
                                      ? Icons.star_rounded
                                      : Icons.star_border_rounded,
                                  color: AppTheme.saffron,
                                  size: 32,
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _commentController,
                          enabled: !_submittingRating,
                          maxLines: 3,
                          maxLength: 500,
                          style: GoogleFonts.nunito(
                            fontSize: 13,
                            color: AppTheme.coconutCream,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Share your experience (optional)...',
                            hintStyle: GoogleFonts.nunito(
                              fontSize: 13,
                              color: AppTheme.textMuted,
                            ),
                            filled: true,
                            fillColor: AppTheme.cardMid,
                            counterStyle: GoogleFonts.nunito(
                              fontSize: 10,
                              color: AppTheme.textMuted,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.all(12),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _submittingRating ? null : _submitReview,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.saffron,
                              foregroundColor: AppTheme.darkBg,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _submittingRating
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppTheme.darkBg,
                                    ),
                                  )
                                : Text(
                                    'Submit Review',
                                    style: GoogleFonts.nunito(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
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

          // ── Reviews list (live, from all users) ───────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
              child: StreamBuilder<List<ReviewEntry>>(
                stream: _feedbackService.watchReviews(rec.destination),
                builder: (context, snapshot) {
                  final reviews = (snapshot.data ?? [])
                      .where((r) => r.comment.trim().isNotEmpty)
                      .toList();
                  if (reviews.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle(
                        'Reviews (${reviews.length})',
                        Icons.rate_review_rounded,
                      ),
                      const SizedBox(height: 12),
                      ...reviews.map(
                        (r) => Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.cardMid,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  ...List.generate(
                                    5,
                                    (i) => Icon(
                                      i < r.rating
                                          ? Icons.star_rounded
                                          : Icons.star_border_rounded,
                                      color: AppTheme.saffron,
                                      size: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    (r.displayName != null &&
                                            r.displayName!.isNotEmpty)
                                        ? r.displayName!
                                        : 'Traveller',
                                    style: GoogleFonts.nunito(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.coconutCream,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                r.comment,
                                style: GoogleFonts.nunito(
                                  fontSize: 13,
                                  color: AppTheme.textLight,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
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
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
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

  // Small icon per hotel comfort tier, used above each 3-hotel group.
  IconData _hotelTierIcon(String tier) {
    final t = tier.toLowerCase();
    if (t.contains('budget')) return Icons.cottage_rounded;
    if (t.contains('luxury')) return Icons.diamond_rounded;
    return Icons.hotel_class_rounded; // mid-range / default
  }

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
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
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
              color: color.withValues(alpha: 0.1),
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
                  ? AppTheme.errorRed.withValues(alpha: 0.1)
                  : AppTheme.deepJungle.withValues(alpha: 0.2),
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
                      color:
                          isOver ? AppTheme.errorRed : const Color(0xFF51CF66),
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

// ── Full-screen gallery viewer ─────────────────────────────────────────────
/// Swipeable, pinch-to-zoom full-screen image viewer opened when a gallery
/// thumbnail is tapped. [buildImage] is passed in from the parent screen so
/// it reuses the exact same network/asset loading + placeholder/error logic.
class _GalleryViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  final Widget Function({
    required String imagePath,
    BoxFit fit,
    Widget? placeholder,
    Widget? errorWidget,
  }) buildImage;

  const _GalleryViewer({
    required this.images,
    required this.initialIndex,
    required this.buildImage,
  });

  @override
  State<_GalleryViewer> createState() => _GalleryViewerState();
}

class _GalleryViewerState extends State<_GalleryViewer> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (context, i) {
              return InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Center(
                  child: widget.buildImage(
                    imagePath: widget.images[i],
                    fit: BoxFit.contain,
                    placeholder: const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.saffron,
                        strokeWidth: 2,
                      ),
                    ),
                    errorWidget: const Icon(
                      Icons.image_not_supported_rounded,
                      color: AppTheme.textMuted,
                      size: 48,
                    ),
                  ),
                ),
              );
            },
          ),
          // Close button
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                    if (widget.images.length > 1)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_currentIndex + 1} / ${widget.images.length}',
                          style: GoogleFonts.nunito(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          // Dot indicators
          if (widget.images.length > 1)
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.images.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _currentIndex ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _currentIndex
                          ? AppTheme.saffron
                          : Colors.white.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
