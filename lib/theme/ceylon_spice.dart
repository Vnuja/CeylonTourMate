// lib/theme/ceylon_spice.dart
import 'package:flutter/material.dart';

class CeylonSpice {
  // Core palette
  static const Color deepJungle   = Color(0xFF1B5E3B);
  static const Color cinnamon     = Color(0xFFC8782A);
  static const Color saffron      = Color(0xFFE5A020);
  static const Color coconutCream = Color(0xFFF5F0E8);

  // Derived
  static const Color jungleDark    = Color(0xFF143F28);
  static const Color jungleLight   = Color(0xFF236B45);
  static const Color cinnamonDark  = Color(0xFFA5611F);
  static const Color cinnamonLight = Color(0xFFD9924A);
  static const Color saffronLight  = Color(0xFFF0B840);
  static const Color saffronDark   = Color(0xFFC48A14);
  static const Color creamDark     = Color(0xFFEAE3D5);
  static const Color creamDarker   = Color(0xFFD8CEBC);

  // Text
  static const Color text      = Color(0xFF2A1F0E);
  static const Color textMid   = Color(0xFF6B5A3E);
  static const Color textLight = Color(0xFF9C8B72);
  static const Color surface   = Color(0xFFFDFAF5);

  // Status
  static const Color danger      = Color(0xFFA63022);
  static const Color dangerLight = Color(0xFFFBF0EE);
  static const Color warnLight   = Color(0xFFFBF4EA);
  static const Color cleanBg     = Color(0xFFEEF7F1);

  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.light(
      primary:    deepJungle,
      secondary:  cinnamon,
      tertiary:   saffron,
      surface:    coconutCream,
      onPrimary:  coconutCream,
      onSecondary: coconutCream,
      onSurface:  text,
    ),
    scaffoldBackgroundColor: coconutCream,
    appBarTheme: const AppBarTheme(
      backgroundColor: deepJungle,
      foregroundColor: coconutCream,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'Georgia',
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: coconutCream,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: cinnamon,
        foregroundColor: coconutCream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 15),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: creamDarker),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: creamDarker, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: cinnamon, width: 2),
      ),
      hintStyle: const TextStyle(color: textLight),
    ),
  );
}
