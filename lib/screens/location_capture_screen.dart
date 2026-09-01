import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/ceylon_theme.dart';
import '../services/location_identifier_service.dart';
import 'location_result_screen.dart';

class LocationCaptureScreen extends StatefulWidget {
  const LocationCaptureScreen({super.key});

  @override
  State<LocationCaptureScreen> createState() => _LocationCaptureScreenState();
}

class _LocationCaptureScreenState extends State<LocationCaptureScreen> {
  XFile? _selectedImage;
  Uint8List? _imageBytes;
  bool _isAnalyzing = false;
  final ImagePicker _picker = ImagePicker();
  final LocationIdentifierService _service = LocationIdentifierService();

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _selectedImage = picked;
          _imageBytes = bytes;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not access ${source == ImageSource.camera ? 'camera' : 'gallery'}. '
              'Please grant permission in settings.',
            ),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _analyzeImage() async {
    if (_imageBytes == null) return;

    setState(() => _isAnalyzing = true);

    try {
      final result = await _service.analyzeImageBytes(_imageBytes!);
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LocationResultScreen(
              result: result,
              imageBytes: _imageBytes!,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Analysis failed: ${e.toString()}'),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CeylonSpiceTheme.darkBg,
      appBar: AppBar(
        backgroundColor: CeylonSpiceTheme.darkSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: CeylonSpiceTheme.textSecondary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Location Identifier',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: CeylonSpiceTheme.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Header ──────────────────────────────────────
              Text(
                '🌍 Identify Any Tourist Place',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: CeylonSpiceTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Take a photo or choose from gallery,\nthen let AI identify the location for you.',
                style: GoogleFonts.lato(
                  fontSize: 13,
                  color: CeylonSpiceTheme.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),

              // ── Image Preview Area ───────────────────────────
              Expanded(
                child: GestureDetector(
                  onTap: () => _pickImage(ImageSource.gallery),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: CeylonSpiceTheme.darkCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _imageBytes != null
                            ? CeylonSpiceTheme.saffron.withOpacity(0.6)
                            : CeylonSpiceTheme.divider,
                        width: _imageBytes != null ? 2 : 1,
                      ),
                      boxShadow: _imageBytes != null
                          ? [
                              BoxShadow(
                                color: CeylonSpiceTheme.saffron.withOpacity(
                                  0.15,
                                ),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ]
                          : [],
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: _imageBytes != null
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.memory(_imageBytes!, fit: BoxFit.cover),
                              // Overlay hint
                              Positioned(
                                bottom: 12,
                                right: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'Tap to change',
                                    style: GoogleFonts.lato(
                                      fontSize: 12,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: CeylonSpiceTheme.darkSurface,
                                  border: Border.all(
                                    color: CeylonSpiceTheme.divider,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.image_outlined,
                                  size: 40,
                                  color: CeylonSpiceTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No image selected',
                                style: GoogleFonts.lato(
                                  fontSize: 15,
                                  color: CeylonSpiceTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Use the buttons below to get started',
                                style: GoogleFonts.lato(
                                  fontSize: 12,
                                  color: CeylonSpiceTheme.textSecondary
                                      .withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Camera & Gallery Buttons ─────────────────────
              Row(
                children: [
                  // Camera
                  Expanded(
                    child: _SourceButton(
                      icon: Icons.camera_alt_rounded,
                      label: 'Camera',
                      onTap: () => _pickImage(ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Gallery
                  Expanded(
                    child: _SourceButton(
                      icon: Icons.photo_library_rounded,
                      label: 'Gallery',
                      onTap: () => _pickImage(ImageSource.gallery),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── Find Location Button ─────────────────────────
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: (_imageBytes != null && !_isAnalyzing)
                      ? _analyzeImage
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CeylonSpiceTheme.cinnamon,
                    disabledBackgroundColor: CeylonSpiceTheme.darkCard,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isAnalyzing
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Analyzing...',
                              style: GoogleFonts.lato(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.location_searching_rounded,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Find the Location',
                              style: GoogleFonts.lato(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Reusable source button ────────────────────────────────────────────────────
class _SourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SourceButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: CeylonSpiceTheme.darkCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: CeylonSpiceTheme.divider),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: CeylonSpiceTheme.saffron, size: 22),
            const SizedBox(width: 10),
            Text(
              label,
              style: GoogleFonts.lato(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: CeylonSpiceTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
