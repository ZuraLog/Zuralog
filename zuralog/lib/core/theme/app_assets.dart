/// Zuralog Design System — Asset Path Registry.
///
/// Centralizes all brand asset paths to eliminate hardcoded strings in widget
/// files and ensure a single place to update when assets are renamed or moved.
///
/// Usage:
/// ```dart
/// import 'package:zuralog/core/theme/theme.dart';
///
/// SvgPicture.asset(AppAssets.logoSvg);
/// Image.asset(AppAssets.logoMainPng);
/// ```
library;

/// Canonical asset path constants for the Zuralog brand.
///
/// **Variant guide:**
/// - [logoSvg] / [logoSagePng] — transparent background, Sage mark only.
///   Use on dark surfaces (OLED black, elevated surfaces) where the
///   surrounding context provides the background. When used with
///   [SvgPicture.asset] + [ColorFilter], [logoSvg] can be recolored freely.
///
/// - [logoWithBgSvg] / [logoMainPng] — dark green (#344E41) background
///   included. Use where the icon must be self-contained: app icons,
///   favicons, mockups, light-colored surfaces.
abstract final class AppAssets {
  // ── SVG Logos ─────────────────────────────────────────────────────────────
  /// Logo mark only, transparent background (Sage variant).
  ///
  /// Use with [SvgPicture.asset]. Accepts [ColorFilter] for recoloring.
  /// Ideal for dark-surface in-app rendering: AppBar, welcome cards, chat.
  static const String logoSvg = 'assets/images/ZuraLog-Sage.svg';

  /// Logo mark with dark green (#344E41) background (Main variant).
  ///
  /// Use when the icon needs its own background context (e.g., standalone
  /// icon in a document, share sheet, or external context).
  static const String logoWithBgSvg = 'assets/images/Zuralog.svg';

  // ── PNG Logos ─────────────────────────────────────────────────────────────
  /// Main logo PNG with dark green (#344E41) background.
  ///
  /// Preferred source for app icons, launcher icons, and any platform-level
  /// icon that must be self-contained (iOS App Store, Android launcher,
  /// iOS splash, share sheet).
  static const String logoMainPng = 'assets/images/ZuraLog-Logo-Main.png';

  /// Sage logo PNG, transparent background.
  ///
  /// Use for inline image rendering on dark surfaces where the
  /// Sage (#CFE1B9) mark should appear on the surface's own background.
  static const String logoSagePng = 'assets/images/ZuraLog-Logo-Sage.png';
}
