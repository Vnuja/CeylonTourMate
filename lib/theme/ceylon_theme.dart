import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CeylonSpiceTheme {
  // ── Ceylon Spice Palette ──────────────────────────────────
  static const Color deepJungle    = Color(0xFF1B5E3B);  // Nav & header
  static const Color cinnamon      = Color(0xFFB5651D);  // CTA buttons
  static const Color saffron       = Color(0xFFE8A020);  // Accent & icons
  static const Color coconutCream  = Color(0xFFF5F0E8);  // Backgrounds
  static const Color darkBg        = Color(0xFF0F1A12);  // Dark background
  static const Color darkSurface   = Color(0xFF1A2E1E);  // Dark surface
  static const Color darkCard      = Color(0xFF243328);  // Dark card
  static const Color saffronLight  = Color(0xFFFFF3CD);  // Light saffron tint
  static const Color cinnamonDark  = Color(0xFF8B4513);  // Darker cinnamon
  static const Color textPrimary   = Color(0xFFF5F0E8);  // Light text
  static const Color textSecondary = Color(0xFFB8C4BB);  // Secondary text
  static const Color userBubble    = Color(0xFF1B5E3B);  // User message bg
  static const Color botBubble     = Color(0xFF243328);  // Bot message bg
  static const Color inputBg       = Color(0xFF1A2E1E);  // Input background
  static const Color divider       = Color(0xFF2D4A32);  // Dividers

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: deepJungle,
        secondary: saffron,
        tertiary: cinnamon,
        background: darkBg,
        surface: darkSurface,
        onPrimary: coconutCream,
        onSecondary: darkBg,
        onBackground: textPrimary,
        onSurface: textPrimary,
      ),
      scaffoldBackgroundColor: darkBg,
      textTheme: GoogleFonts.latoTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.playfairDisplay(
          fontSize: 32, fontWeight: FontWeight.bold, color: textPrimary,
        ),
        displayMedium: GoogleFonts.playfairDisplay(
          fontSize: 24, fontWeight: FontWeight.bold, color: textPrimary,
        ),
        headlineMedium: GoogleFonts.playfairDisplay(
          fontSize: 20, fontWeight: FontWeight.w600, color: textPrimary,
        ),
        bodyLarge: GoogleFonts.lato(
          fontSize: 16, color: textPrimary,
        ),
        bodyMedium: GoogleFonts.lato(
          fontSize: 14, color: textSecondary,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: textPrimary,
        elevation: 0,
        titleTextStyle: GoogleFonts.playfairDisplay(
          fontSize: 20, fontWeight: FontWeight.bold, color: textPrimary,
        ),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: darkSurface,
      ),
      dividerTheme: const DividerThemeData(
        color: divider,
        thickness: 0.5,
      ),
    );
  }
}
