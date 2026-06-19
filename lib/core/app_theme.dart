// lib/core/app_theme.dart
import 'package:flutter/material.dart';

class MostromoTheme {
  // --- ANA RENK PALETİ ---
  // İleride Cyan yerine başka bir renk istersen, sadece bu satırı değiştirmen yeterli olacak.
  static const Color accentColor = Color(0xFF00E5FF);
  static const Color accentHover = Color(0xFF00B8D4);

  static const Color backgroundColor = Color(0xFF121212);
  static const Color surfaceColor = Color(0xFF1E1E1E);
  static const Color sidebarColor = Color(0xFF0A0A0A);

  // --- METİN VE YARDIMCI RENKLER ---
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Colors.white54;
  static const Color textMuted = Colors.white38;
  static const Color dividerColor = Colors.white10;

  // --- MERKEZİ TEMA YAPILANDIRMASI ---
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: backgroundColor,
      colorScheme: const ColorScheme.dark(
        primary: accentColor,
        secondary: accentHover,
        surface: surfaceColor,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: accentColor),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: accentColor,
        selectionColor: accentColor.withValues(alpha: 0.3),
        selectionHandleColor: accentColor,
      ),
    );
  }
}
