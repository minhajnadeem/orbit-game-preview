import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_config.dart';

class AppTheme {
  AppTheme._(); // prevent instantiation

  // ── Convenience re-exports (so existing code that imports AppTheme
  //    for color constants still compiles without change) ──────────────────
  static Color get background => AppConfig.backgroundColor;
  static Color get surface => AppConfig.surfaceColor;
  static Color get surfaceVariant => AppConfig.surfaceVariantColor;
  static Color get buzzerAccent => AppConfig.accentColor;
  static Color get correctState => AppConfig.correctColor;
  static Color get incorrectState => AppConfig.incorrectColor;
  static Color get glowAmber => AppConfig.glowAccent;
  static Color get subtleBorder => AppConfig.subtleBorder;

  /// Responsive edge padding: 32 on desktop, 20 on tablet, 12 on phone.
  static EdgeInsets responsivePadding(double viewportWidth) {
    if (viewportWidth >= 1200) return const EdgeInsets.all(32);
    if (viewportWidth >= 600) return const EdgeInsets.all(20);
    return const EdgeInsets.all(12);
  }

  static ThemeData get darkTheme {
    final accent = AppConfig.accentColor;
    final surf = AppConfig.surfaceColor;
    final surfVar = AppConfig.surfaceVariantColor;
    final err = AppConfig.incorrectColor;

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppConfig.backgroundColor,
      colorScheme: ColorScheme.dark(
        primary: accent,
        surface: surf,
        error: err,
      ),
      textTheme: GoogleFonts.getTextTheme(
        AppConfig.fontFamily,
        ThemeData.dark().textTheme,
      ),

      // ── Compact AppBar ────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: surfVar.withOpacity(0.85),
        elevation: 0,
        toolbarHeight: 48,
        titleTextStyle: GoogleFonts.getFont(
          AppConfig.fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),

      cardTheme: CardThemeData(
        color: surf.withOpacity(0.8),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surf.withOpacity(0.5),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accent.withOpacity(0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.transparent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accent),
        ),
      ),
    );
  }
}
