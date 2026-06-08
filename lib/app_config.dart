import 'package:flutter/material.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// APP CONFIGURATION — Single source of truth for all branding.
///
/// To rebrand this app, edit ONLY this file.
///
/// ──────────────────────────────────────────────────────────────────────────
/// PLATFORM FILES that must also be updated manually (cannot be driven from
/// Dart at runtime):
///
///   • android/app/src/main/AndroidManifest.xml  → android:label
///   • ios/Runner/Info.plist                      → CFBundleDisplayName,
///                                                   CFBundleName
///   • web/index.html                             → <title>,
///                                                   apple-mobile-web-app-title
///   • web/manifest.json                          → "name", "short_name"
///
/// ═══════════════════════════════════════════════════════════════════════════
class AppConfig {
  AppConfig._(); // prevent instantiation

  // ── Identity ──────────────────────────────────────────────────────────────
  /// The app name shown in AppBars, the landing page, and the OS task switcher.
  static const String appName = 'ENDO BUZZ';

  /// Short tagline shown below the app name on the landing screen.
  static const String appTagline = 'REAL-TIME BUZZER GAME';

  // ── Color Palette ─────────────────────────────────────────────────────────
  /// Scaffold / page background.
  static const Color backgroundColor = Color(0xFF0A0E17);

  /// Default card and container surface color.
  static const Color surfaceColor = Color(0xFF1E2530);

  /// Darker surface variant used for the AppBar and subtle backgrounds.
  static const Color surfaceVariantColor = Color(0xFF161B22);

  /// Primary brand / accent color. Used for the buzzer button, AppBar logo
  /// text, highlighted borders, and primary action buttons.
  static const Color accentColor = Color(0xFFFF9F0A);

  /// Color shown when a player answers correctly.
  static const Color correctColor = Color(0xFF30D158);

  /// Color shown when a player answers incorrectly or is locked out.
  static const Color incorrectColor = Color(0xFFFF453A);

  // ── Derived helpers (computed from the above — no need to edit) ───────────
  /// Semi-transparent glow variant of [accentColor] used for borders & glows.
  static Color get glowAccent => accentColor.withOpacity(0.25);

  /// Subtle white border used on cards and containers.
  static const Color subtleBorder = Color(0x1AFFFFFF);

  // ── Typography ────────────────────────────────────────────────────────────
  /// Google Font family name used throughout the app.
  /// Must be a valid font available in the google_fonts package.
  /// See: https://fonts.google.com
  static const String fontFamily = 'Inter';
}
