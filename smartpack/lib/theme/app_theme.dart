import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Ceylon Spice Palette ──────────────────────────────────────────
  static const Color deepJungle    = Color(0xFF1B4332);
  static const Color cinnamon      = Color(0xFFB5651D);
  static const Color saffron       = Color(0xFFE9A825);
  static const Color coconutCream  = Color(0xFFF5F0E8);
  static const Color darkBg        = Color(0xFF0F1C14);
  static const Color cardDark      = Color(0xFF1A2E20);
  static const Color cardMid       = Color(0xFF243B2A);
  static const Color textLight     = Color(0xFFF5F0E8);
  static const Color textMuted     = Color(0xFFB8C4BC);
  static const Color gold          = Color(0xFFD4A017);
  static const Color errorRed      = Color(0xFFE53935);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: darkBg,
      colorScheme: const ColorScheme.dark(
        primary: saffron,
        secondary: cinnamon,
        surface: cardDark,
        error: errorRed,
      ),
      textTheme: GoogleFonts.cormorantGaramondTextTheme().copyWith(
        displayLarge: GoogleFonts.cormorantGaramond(
          color: coconutCream, fontSize: 48, fontWeight: FontWeight.w700,
          letterSpacing: -1.0,
        ),
        displayMedium: GoogleFonts.cormorantGaramond(
          color: coconutCream, fontSize: 36, fontWeight: FontWeight.w600,
        ),
        headlineLarge: GoogleFonts.cormorantGaramond(
          color: coconutCream, fontSize: 28, fontWeight: FontWeight.w600,
        ),
        headlineMedium: GoogleFonts.cormorantGaramond(
          color: coconutCream, fontSize: 22, fontWeight: FontWeight.w500,
        ),
        titleLarge: GoogleFonts.nunito(
          color: coconutCream, fontSize: 18, fontWeight: FontWeight.w600,
        ),
        titleMedium: GoogleFonts.nunito(
          color: coconutCream, fontSize: 16, fontWeight: FontWeight.w500,
        ),
        bodyLarge: GoogleFonts.nunito(
          color: textLight, fontSize: 15,
        ),
        bodyMedium: GoogleFonts.nunito(
          color: textMuted, fontSize: 13,
        ),
        labelLarge: GoogleFonts.nunito(
          color: saffron, fontSize: 13, fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: darkBg,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.cormorantGaramond(
          color: coconutCream, fontSize: 22, fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: saffron),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: saffron,
          foregroundColor: darkBg,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          textStyle: GoogleFonts.nunito(
            fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.5,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardMid,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: saffron, width: 1.5),
        ),
        labelStyle: GoogleFonts.nunito(color: textMuted, fontSize: 14),
        hintStyle: GoogleFonts.nunito(color: textMuted, fontSize: 14),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: cardMid,
        selectedColor: saffron.withOpacity(0.2),
        labelStyle: GoogleFonts.nunito(color: textLight, fontSize: 13),
        side: const BorderSide(color: Colors.transparent),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: saffron,
        inactiveTrackColor: cardMid,
        thumbColor: saffron,
        overlayColor: Color(0x29E9A825),
      ),
    );
  }

  // Gradient helpers
  static LinearGradient get jungleGradient => const LinearGradient(
    colors: [deepJungle, darkBg],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get spiceGradient => const LinearGradient(
    colors: [cinnamon, saffron],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get cardOverlay => const LinearGradient(
    colors: [Colors.transparent, Color(0xCC0F1C14)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static BoxDecoration get glassCard => BoxDecoration(
    color: cardDark.withOpacity(0.85),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: saffron.withOpacity(0.15), width: 1),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.3),
        blurRadius: 20,
        offset: const Offset(0, 8),
      ),
    ],
  );
}
