import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/ceylon_theme.dart';
import '../services/location_identifier_service.dart';

class LocationResultScreen extends StatelessWidget {
  final PlaceResult result;
  final File imageFile;

  const LocationResultScreen({
    super.key,
    required this.result,
    required this.imageFile,
  });

  Color get _confidenceColor {
    switch (result.confidence.toLowerCase()) {
      case 'high':
        return const Color(0xFF2E7D32);
      case 'medium':
        return const Color(0xFFF57C00);
      default:
        return const Color(0xFFC62828);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CeylonSpiceTheme.darkBg,
      body: CustomScrollView(
        slivers: [
          // ── Collapsible image header ──────────────────────
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: CeylonSpiceTheme.darkSurface,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(imageFile, fit: BoxFit.cover),
                  // Gradient overlay
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.75),
                        ],
                        stops: const [0.5, 1.0],
                      ),
                    ),
                  ),
                  // Title overlaid on image
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result.name,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              color: CeylonSpiceTheme.saffron,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                result.location,
                                style: GoogleFonts.lato(
                                  fontSize: 13,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _confidenceColor.withOpacity(0.85),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '● ${result.confidence.toUpperCase()}',
                                style: GoogleFonts.lato(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
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

          // ── Content ────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: CeylonSpiceTheme.deepJungle.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: CeylonSpiceTheme.deepJungle,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      '🏛  ${result.type}',
                      style: GoogleFonts.lato(
                        fontSize: 13,
                        color: CeylonSpiceTheme.saffron,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Why it matters ──────────────────────────
                  _SectionTitle(icon: '🌟', title: 'Why It Matters'),
                  const SizedBox(height: 8),
                  Text(
                    result.importance,
                    style: GoogleFonts.lato(
                      fontSize: 14,
                      color: CeylonSpiceTheme.textSecondary,
                      height: 1.6,
                    ),
                  ),

                  const SizedBox(height: 22),

                  // ── Quick info cards ────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: _InfoCard(
                          icon: '🗓',
                          label: 'Best Time to Visit',
                          value: result.bestTimeToVisit,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _InfoCard(
                          icon: '🎟',
                          label: 'Entry Fee',
                          value: result.entryFee,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  // ── Highlights ──────────────────────────────
                  _SectionTitle(icon: '✨', title: 'Highlights'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: result.highlights
                        .map((h) => _HighlightChip(label: h))
                        .toList(),
                  ),

                  const SizedBox(height: 22),

                  // ── Similar places ──────────────────────────
                  _SectionTitle(icon: '🗺', title: 'Similar Places to Explore'),
                  const SizedBox(height: 10),
                  ...result.similarPlaces
                      .map((sp) => _SimilarPlaceCard(place: sp))
                      .toList(),

                  const SizedBox(height: 30),

                  // ── Try another button ──────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: CeylonSpiceTheme.saffron,
                      ),
                      label: Text(
                        'Identify Another Place',
                        style: GoogleFonts.lato(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: CeylonSpiceTheme.saffron,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: CeylonSpiceTheme.saffron,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section title widget ──────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String icon;
  final String title;

  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.playfairDisplay(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: CeylonSpiceTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}

// ── Info card ─────────────────────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  final String icon;
  final String label;
  final String value;

  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CeylonSpiceTheme.darkCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CeylonSpiceTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.lato(
              fontSize: 11,
              color: CeylonSpiceTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$icon  $value',
            style: GoogleFonts.lato(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: CeylonSpiceTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Highlight chip ────────────────────────────────────────────────────────────
class _HighlightChip extends StatelessWidget {
  final String label;

  const _HighlightChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: CeylonSpiceTheme.darkCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: CeylonSpiceTheme.saffron.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: GoogleFonts.lato(fontSize: 13, color: CeylonSpiceTheme.saffron),
      ),
    );
  }
}

// ── Similar place card ────────────────────────────────────────────────────────
class _SimilarPlaceCard extends StatelessWidget {
  final SimilarPlace place;

  const _SimilarPlaceCard({required this.place});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CeylonSpiceTheme.darkCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CeylonSpiceTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.place_rounded,
                color: CeylonSpiceTheme.saffron,
                size: 16,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  place.name,
                  style: GoogleFonts.lato(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: CeylonSpiceTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Padding(
            padding: const EdgeInsets.only(left: 22),
            child: Text(
              place.location,
              style: GoogleFonts.lato(
                fontSize: 12,
                color: CeylonSpiceTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 22),
            child: Text(
              place.reason,
              style: GoogleFonts.lato(
                fontSize: 13,
                color: CeylonSpiceTheme.textSecondary.withOpacity(0.8),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
