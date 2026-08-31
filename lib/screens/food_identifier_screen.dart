// lib/screens/food_identifier_screen.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/ceylon_theme.dart';
import '../services/food_identifier_service.dart';
import '../models/food_identification_result.dart';

class FoodIdentifierScreen extends StatefulWidget {
  const FoodIdentifierScreen({super.key});

  @override
  State<FoodIdentifierScreen> createState() => _FoodIdentifierScreenState();
}

class _FoodIdentifierScreenState extends State<FoodIdentifierScreen>
    with SingleTickerProviderStateMixin {
  final _service = FoodIdentifierService();
  final _picker = ImagePicker();

  XFile? _pickedFile;
  String? _base64Image;
  String? _mimeType;

  bool _isAnalyzing = false;
  FoodIdentificationResult? _result;
  String? _error;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Image picking ─────────────────────────────────────────────────────────

  Future<void> _pick(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();
      final mime = file.mimeType ?? _guessMime(file.path);

      setState(() {
        _pickedFile = file;
        _base64Image = base64Encode(bytes);
        _mimeType = mime;
        _result = null;
        _error = null;
      });
    } catch (e) {
      _showError('Could not open image: $e');
    }
  }

  String _guessMime(String path) {
    final ext = path.toLowerCase().split('.').last;
    const map = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'webp': 'image/webp',
    };
    return map[ext] ?? 'image/jpeg';
  }

  // ── Analysis ──────────────────────────────────────────────────────────────

  Future<void> _analyze() async {
    if (_base64Image == null || _mimeType == null) return;
    setState(() {
      _isAnalyzing = true;
      _result = null;
      _error = null;
    });

    try {
      final result = await _service.identify(
        base64Image: _base64Image!,
        mimeType: _mimeType!,
      );
      setState(() => _result = result);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  void _clear() {
    setState(() {
      _pickedFile = null;
      _base64Image = null;
      _mimeType = null;
      _result = null;
      _error = null;
    });
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.lato(color: Colors.white)),
        backgroundColor: Colors.red.shade700,
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      color: CeylonSpiceTheme.darkBg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HeaderBanner(),
            const SizedBox(height: 20),
            _buildImageArea(),
            const SizedBox(height: 16),
            if (_pickedFile != null) ...[
              _buildActionButtons(),
              const SizedBox(height: 20),
            ],
            if (_isAnalyzing) _buildAnalyzingCard(),
            if (_error != null) _buildErrorCard(),
            if (_result != null && !_isAnalyzing) _buildResultSection(),
          ],
        ),
      ),
    );
  }

  // ── Header banner ─────────────────────────────────────────────────────────

  // ── Image area ────────────────────────────────────────────────────────────

  Widget _buildImageArea() {
    if (_pickedFile == null) {
      return _UploadPlaceholder(onCamera: () => _pick(ImageSource.camera),
          onGallery: () => _pick(ImageSource.gallery));
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          // Image preview
          AspectRatio(
            aspectRatio: 4 / 3,
            child: kIsWeb
                ? Image.network(_pickedFile!.path, fit: BoxFit.cover)
                : Image.file(File(_pickedFile!.path), fit: BoxFit.cover),
          ),
          // Gradient overlay at bottom
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              height: 60,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xCC0F1A12), Colors.transparent],
                ),
              ),
            ),
          ),
          // Change-photo chip
          Positioned(
            bottom: 10, right: 10,
            child: GestureDetector(
              onTap: () => _showPickerSheet(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: CeylonSpiceTheme.darkSurface.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: CeylonSpiceTheme.saffron.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.swap_horiz_rounded,
                        size: 14, color: CeylonSpiceTheme.saffron),
                    const SizedBox(width: 4),
                    Text('Change',
                        style: GoogleFonts.lato(
                            color: CeylonSpiceTheme.saffron, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Action buttons ────────────────────────────────────────────────────────

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.search_rounded, size: 20),
            label: const Text('Identify Food'),
            style: ElevatedButton.styleFrom(
              backgroundColor: CeylonSpiceTheme.cinnamon,
              foregroundColor: CeylonSpiceTheme.textPrimary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              textStyle: GoogleFonts.lato(
                  fontSize: 15, fontWeight: FontWeight.w700),
            ),
            onPressed: _isAnalyzing ? null : _analyze,
          ),
        ),
        const SizedBox(width: 10),
        OutlinedButton(
          onPressed: _clear,
          style: OutlinedButton.styleFrom(
            foregroundColor: CeylonSpiceTheme.textSecondary,
            side: BorderSide(
                color: CeylonSpiceTheme.textSecondary.withOpacity(0.4)),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          child: const Icon(Icons.close_rounded, size: 20),
        ),
      ],
    );
  }

  // ── Analyzing card ────────────────────────────────────────────────────────

  Widget _buildAnalyzingCard() {
    return ScaleTransition(
      scale: _pulse,
      child: Container(
        padding: const EdgeInsets.all(24),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: CeylonSpiceTheme.darkCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: CeylonSpiceTheme.saffron.withOpacity(0.25)),
          boxShadow: [
            BoxShadow(
                color: CeylonSpiceTheme.saffron.withOpacity(0.08),
                blurRadius: 20,
                spreadRadius: 2),
          ],
        ),
        child: Column(
          children: [
            SizedBox(
              width: 48, height: 48,
              child: CircularProgressIndicator(
                color: CeylonSpiceTheme.saffron,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Analyzing your food...',
              style: GoogleFonts.playfairDisplay(
                color: CeylonSpiceTheme.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Our AI is identifying the Sri Lankan dish 🍛',
              textAlign: TextAlign.center,
              style: GoogleFonts.lato(
                color: CeylonSpiceTheme.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Error card ────────────────────────────────────────────────────────────

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.red.shade900.withOpacity(0.25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade700),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded,
              color: Colors.red.shade400, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Analysis failed. Please try again.\n$_error',
              style: GoogleFonts.lato(
                  color: Colors.red.shade300, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // ── Result section ────────────────────────────────────────────────────────

  Widget _buildResultSection() {
    final r = _result!;
    final isUnknown = r.foodName == 'Not a food item' || r.foodName == 'Unknown Food';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Food name hero card
        _FoodNameHero(
          foodName: r.foodName,
          confidence: r.confidence,
          inDatabase: r.inDatabase,
          isUnknown: isUnknown,
        ),
        const SizedBox(height: 14),

        if (!isUnknown) ...[
          // Description
          _InfoCard(
            icon: Icons.info_outline_rounded,
            title: 'About this dish',
            content: r.description,
          ),
          const SizedBox(height: 12),

          // Ingredients
          _ChipInfoCard(
            icon: Icons.eco_outlined,
            title: 'Ingredients',
            items: r.ingredients,
            chipColor: CeylonSpiceTheme.deepJungle,
          ),
          const SizedBox(height: 12),

          // How to eat
          _InfoCard(
            icon: Icons.restaurant_outlined,
            title: 'How to eat',
            content: r.howToEat,
            accentColor: CeylonSpiceTheme.saffron,
          ),
          const SizedBox(height: 12),

          // How to make
          _InfoCard(
            icon: Icons.outdoor_grill_outlined,
            title: 'How it\'s made',
            content: r.howToMake,
            accentColor: CeylonSpiceTheme.cinnamon,
          ),
          const SizedBox(height: 12),

          // Dietary & allergens row
          Row(
            children: [
              Expanded(
                child: _MiniCard(
                  icon: Icons.local_dining_outlined,
                  title: 'Dietary',
                  value: r.dietary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _AllergenCard(allergens: r.allergens),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Try another button
          OutlinedButton.icon(
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('Try Another Photo'),
            style: OutlinedButton.styleFrom(
              foregroundColor: CeylonSpiceTheme.saffron,
              side: BorderSide(
                  color: CeylonSpiceTheme.saffron.withOpacity(0.5)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              textStyle: GoogleFonts.lato(fontWeight: FontWeight.w600),
            ),
            onPressed: _clear,
          ),
        ],
      ],
    );
  }

  // ── Bottom sheet picker ───────────────────────────────────────────────────

  void _showPickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: CeylonSpiceTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: CeylonSpiceTheme.textSecondary.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Select Image Source',
                style: GoogleFonts.playfairDisplay(
                  color: CeylonSpiceTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              _PickerOption(
                icon: Icons.camera_alt_outlined,
                label: 'Camera',
                onTap: () {
                  Navigator.pop(context);
                  _pick(ImageSource.camera);
                },
              ),
              const SizedBox(height: 10),
              _PickerOption(
                icon: Icons.photo_library_outlined,
                label: 'Gallery',
                onTap: () {
                  Navigator.pop(context);
                  _pick(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _HeaderBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B4A2A), Color(0xFF0F1A12)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: CeylonSpiceTheme.saffron.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: CeylonSpiceTheme.saffron.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text('🍛',
                style: const TextStyle(fontSize: 28)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Food Identifier',
                  style: GoogleFonts.playfairDisplay(
                    color: CeylonSpiceTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Scan any Sri Lankan dish to learn its name, ingredients & allergens',
                  style: GoogleFonts.lato(
                    color: CeylonSpiceTheme.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UploadPlaceholder extends StatelessWidget {
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  const _UploadPlaceholder(
      {required this.onCamera, required this.onGallery});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: CeylonSpiceTheme.darkCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: CeylonSpiceTheme.saffron.withOpacity(0.25),
          width: 1.5,
          // Dashed border via custom painter below
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: CeylonSpiceTheme.saffron.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.add_photo_alternate_outlined,
              color: CeylonSpiceTheme.saffron,
              size: 36,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Upload a food photo',
            style: GoogleFonts.playfairDisplay(
              color: CeylonSpiceTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Identify any Sri Lankan dish instantly',
            style: GoogleFonts.lato(
              color: CeylonSpiceTheme.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _SourceButton(
                icon: Icons.camera_alt_outlined,
                label: 'Camera',
                onTap: onCamera,
              ),
              const SizedBox(width: 12),
              _SourceButton(
                icon: Icons.photo_library_outlined,
                label: 'Gallery',
                onTap: onGallery,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SourceButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: CeylonSpiceTheme.darkSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: CeylonSpiceTheme.saffron.withOpacity(0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: CeylonSpiceTheme.saffron, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.lato(
                color: CeylonSpiceTheme.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FoodNameHero extends StatelessWidget {
  final String foodName;
  final String confidence;
  final bool inDatabase;
  final bool isUnknown;

  const _FoodNameHero({
    required this.foodName,
    required this.confidence,
    required this.inDatabase,
    required this.isUnknown,
  });

  Color _confidenceColor() {
    switch (confidence.toLowerCase()) {
      case 'high':
        return const Color(0xFF4CAF50);
      case 'medium':
        return const Color(0xFFE8A020);
      default:
        return const Color(0xFFEF5350);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isUnknown
              ? [const Color(0xFF3A1A1A), const Color(0xFF1A0F0F)]
              : [const Color(0xFF1E3A2A), const Color(0xFF0F1A12)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isUnknown
              ? Colors.red.shade800.withOpacity(0.4)
              : CeylonSpiceTheme.saffron.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: (isUnknown
                    ? Colors.red
                    : CeylonSpiceTheme.saffron)
                .withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                isUnknown ? '❓' : '🍽️',
                style: const TextStyle(fontSize: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  foodName,
                  style: GoogleFonts.playfairDisplay(
                    color: CeylonSpiceTheme.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Badge(
                label: 'Confidence: $confidence',
                color: _confidenceColor(),
              ),
              const SizedBox(width: 8),
              if (inDatabase)
                _Badge(
                  label: '✓ In Database',
                  color: const Color(0xFF4CAF50),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: GoogleFonts.lato(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;
  final Color? accentColor;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.content,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? CeylonSpiceTheme.saffron;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CeylonSpiceTheme.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 17),
              const SizedBox(width: 7),
              Text(
                title.toUpperCase(),
                style: GoogleFonts.lato(
                  color: accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: GoogleFonts.lato(
              color: CeylonSpiceTheme.textPrimary,
              fontSize: 14,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> items;
  final Color chipColor;

  const _ChipInfoCard({
    required this.icon,
    required this.title,
    required this.items,
    required this.chipColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CeylonSpiceTheme.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: CeylonSpiceTheme.saffron.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: CeylonSpiceTheme.saffron, size: 17),
              const SizedBox(width: 7),
              Text(
                title.toUpperCase(),
                style: GoogleFonts.lato(
                  color: CeylonSpiceTheme.saffron,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: items
                .map(
                  (item) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: chipColor.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: chipColor.withOpacity(0.35)),
                    ),
                    child: Text(
                      item,
                      style: GoogleFonts.lato(
                        color: CeylonSpiceTheme.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _MiniCard(
      {required this.icon, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CeylonSpiceTheme.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: CeylonSpiceTheme.saffron.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: CeylonSpiceTheme.saffron, size: 15),
              const SizedBox(width: 5),
              Text(
                title.toUpperCase(),
                style: GoogleFonts.lato(
                  color: CeylonSpiceTheme.saffron,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.lato(
              color: CeylonSpiceTheme.textPrimary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _AllergenCard extends StatelessWidget {
  final List<String> allergens;

  const _AllergenCard({required this.allergens});

  @override
  Widget build(BuildContext context) {
    final hasAllergens = allergens.isNotEmpty;
    final color = hasAllergens ? Colors.orange.shade400 : const Color(0xFF4CAF50);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasAllergens
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_outline,
                color: color,
                size: 15,
              ),
              const SizedBox(width: 5),
              Text(
                'ALLERGENS',
                style: GoogleFonts.lato(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hasAllergens ? allergens.join(', ') : 'None detected',
            style: GoogleFonts.lato(
              color: CeylonSpiceTheme.textPrimary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _PickerOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PickerOption(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: CeylonSpiceTheme.darkCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: CeylonSpiceTheme.saffron.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: CeylonSpiceTheme.saffron.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon,
                  color: CeylonSpiceTheme.saffron, size: 22),
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: GoogleFonts.lato(
                color: CeylonSpiceTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Icon(Icons.chevron_right_rounded,
                color: CeylonSpiceTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}
