/// Zuralog Design System — Color Tokens.
///
/// All hex values are sourced from the View Design Document v1.1
/// (docs/design.md v4.0).
///
/// Usage: Never reference raw hex values in widgets.
/// Always use a semantic token from [AppColors].
library;

import 'package:flutter/material.dart';

/// Centralized color palette for the Zuralog "Sophisticated Softness" design system.
///
/// Provides semantic color tokens for both light and dark themes.
/// Organized by role (brand, backgrounds, surfaces, text, borders, UI elements,
/// health categories).
///
/// ## v3.1 additions
/// - Light mode scaffold, surface, card, and input background tokens per MVP spec.
/// - `textTertiary` for de-emphasized labels and placeholders.
/// - Health category color tokens (`category*`).
/// - Health Score ring color stops.
abstract final class AppColors {
  // ── Brand ────────────────────────────────────────────────────────────────

  /// Sage Green — Main actions, active states, brand identity (dark mode).
  static const Color primary = Color(0xFFCFE1B9);

  /// Deep Forest Green — Primary color for light mode only.
  ///
  /// Sage Green (#CFE1B9) has insufficient contrast (~1.4:1) on white
  /// backgrounds. Deep Forest (#354E42) passes WCAG AA on white while
  /// remaining on-brand. Used as [ColorScheme.primary] in light theme.
  static const Color primaryOnLight = Color(0xFF354E42);

  /// Sage Dark — Pressed states on primary elements.
  static const Color primaryDark = Color(0xFFA8C68A);

  /// Sage Light — Subtle badge fills, soft backgrounds.
  static const Color primaryLight = Color(0xFFE8F3D6);

  /// Deep forest green — top-left stop of the Welcome Screen gradient.
  static const Color gradientForestDark = Color(0xFF0D1F0D);

  /// Mid-tone living green — centre stop of the Welcome Screen gradient.
  static const Color gradientForestMid = Color(0xFF1A3A1A);

  /// Pure black — used for Apple Sign In button background.
  static const Color black = Color(0xFF000000);

  /// Google brand blue — placeholder "G" text in Google Sign In button.
  static const Color googleBlue = Color(0xFF4285F4);

  /// Muted Slate — Secondary buttons, info icons, graphs (light mode).
  static const Color secondaryLight = Color(0xFF5B7C99);

  /// Muted Slate — Secondary buttons, info icons, graphs (dark mode).
  static const Color secondaryDark = Color(0xFF7DA4C7);

  /// Soft Coral — Alerts, destructive actions (light mode).
  static const Color accentLight = Color(0xFFE07A5F);

  /// Soft Coral — Alerts, destructive actions (dark mode).
  static const Color accentDark = Color(0xFFFF8E72);

  // ── Backgrounds ──────────────────────────────────────────────────────────

  /// Main scaffold background — light mode (Brand Cream — matches website light palette).
  static const Color backgroundLight = Color(0xFFFAFAF5);

  /// Main scaffold background — dark mode (Brand Dark Charcoal — matches website dark palette).
  static const Color backgroundDark = Color(0xFF141E18);

  // ── Surfaces ─────────────────────────────────────────────────────────────

  /// Elevated surfaces (colorScheme.surface) — light mode (system grey).
  static const Color surfaceLight = Color(0xFFF2F2F7);

  /// Elevated surfaces (colorScheme.surface) — dark mode.
  static const Color surfaceDark = Color(0xFF1E2E24);

  /// Standard card background — light mode (white on white-scaffold).
  static const Color cardBackgroundLight = Color(0xFFFFFFFF);

  /// Standard card background — dark mode.
  static const Color cardBackgroundDark = Color(0xFF1E2E24);

  /// Elevated card / modal surface — light mode.
  static const Color elevatedSurfaceLight = Color(0xFFFFFFFF);

  /// Elevated card / modal surface — dark mode.
  static const Color elevatedSurfaceDark = Color(0xFF253A2C);

  /// Input field background — light mode.
  static const Color inputBackgroundLight = Color(0xFFF2F2F7);

  /// Input field background — dark mode.
  static const Color inputBackgroundDark = Color(0xFF3A3A3C);

  // ── Text ─────────────────────────────────────────────────────────────────

  /// Primary heading / body text — light mode (pure black).
  static const Color textPrimaryLight = Color(0xFF000000);

  /// Primary heading / body text — dark mode.
  static const Color textPrimaryDark = Color(0xFFFAFAF5);

  /// Subtitles, captions, secondary metadata — light mode.
  static const Color textSecondaryLight = Color(0xFF636366);

  /// Subtitles, captions, secondary metadata — dark mode.
  static const Color textSecondaryDark = Color(0xFFA0A0A5);

  /// De-emphasised labels, placeholders, disabled text — both modes.
  static const Color textTertiary = Color(0xFFABABAB);

  /// Convenience alias for widgets that don't need theme awareness.
  /// Resolves to [textSecondaryDark] — used in dark-first contexts.
  static const Color textSecondary = textSecondaryDark;

  // ── Borders / Dividers ────────────────────────────────────────────────────

  /// Dividers, card borders — light mode.
  static const Color borderLight = Color(0xFFE5E5EA);

  /// Dividers, card borders — dark mode.
  static const Color borderDark = Color(0xFF4A4A4C);

  // ── Health Category Colors ────────────────────────────────────────────────
  // Vivid, saturated colors designed to pop on OLED black backgrounds.
  // Used on cards, charts, progress rings, and category headers.

  /// Activity — Movement, energy. Apple Move-ring convention.
  static const Color categoryActivity = Color(0xFF30D158);

  /// Sleep — Night sky, calm. Apple sleep convention.
  static const Color categorySleep = Color(0xFF5E5CE6);

  /// Body — Mass, weight, composition. Neutral/clinical blue.
  static const Color categoryBody = Color(0xFF64D2FF);

  /// Heart — Cardio health, heart rate.
  static const Color categoryHeart = Color(0xFFFF375F);

  /// Vitals — Blood pressure, oxygen, temperature. Medical blue.
  static const Color categoryVitals = Color(0xFF6AC4DC);

  /// Nutrition — Food, calories, macros. Warm orange.
  static const Color categoryNutrition = Color(0xFFFF9F0A);

  /// Cycle — Menstrual / reproductive health.
  static const Color categoryCycle = Color(0xFFFF6482);

  /// Wellness — Mood, stress, energy subjective check-in. Purple/mindfulness.
  static const Color categoryWellness = Color(0xFFBF5AF2);

  /// Mobility — Flexibility, range of motion, recovery. Bright yellow/active.
  static const Color categoryMobility = Color(0xFFFFD60A);

  /// Environment — Air quality, UV index, weather exposure. Teal/nature.
  static const Color categoryEnvironment = Color(0xFF63E6BE);

  // ── Health Score Ring Color Stops ─────────────────────────────────────────

  /// Score 0-39 — critical / red.
  static const Color healthScoreRed = Color(0xFFFF3B30);

  /// Score 40-69 — fair / amber.
  static const Color healthScoreAmber = Color(0xFFFF9F0A);

  /// Score 70-100 — good / green (brand primary).
  static const Color healthScoreGreen = Color(0xFF30D158);

  // ── Chat Bubbles ─────────────────────────────────────────────────────────

  /// User message bubble background (Sage Green, consistent across modes).
  static const Color userBubble = primary;

  /// User message bubble text color (always dark for contrast on Sage Green).
  static const Color userBubbleText = Color(0xFF1C1C1E);

  /// AI message bubble — light mode.
  static const Color aiBubbleLight = Color(0xFFF2F2F7);

  /// AI message bubble — dark mode.
  static const Color aiBubbleDark = Color(0xFF3A3A3C);

  // ── Status Indicators ────────────────────────────────────────────────────

  /// iOS System Green — connection status "connected" dot.
  static const Color statusConnected = Color(0xFF30D158);

  /// iOS System Amber — connection status "connecting" or "stale" dot.
  static const Color statusConnecting = Color(0xFFFF9F0A);

  /// iOS System Red — connection status "error" dot.
  static const Color statusError = Color(0xFFFF3B30);

  // ── Buttons ──────────────────────────────────────────────────────────────

  /// Primary button foreground text (always dark grey on Sage Green).
  static const Color primaryButtonText = Color(0xFF1C1C1E);

  /// Secondary button background — light mode (translucent grey).
  static const Color secondaryButtonLight = Color(0xFFF2F2F7);

  /// Secondary button background — dark mode.
  static const Color secondaryButtonDark = Color(0xFF444444);

  // ── Brand / Integration Colors ────────────────────────────────────────────
  // Official brand palette for third-party app integration tiles.
  // Used only in integration UI (connect_apps_step, integrations hub).

  /// Strava brand orange.
  static const Color brandStrava = Color(0xFFFC4C02);

  /// Fitbit brand teal.
  static const Color brandFitbit = Color(0xFF00B0B9);

  /// Oura Ring brand indigo.
  static const Color brandOura = Color(0xFF514689);

  /// MyFitnessPal brand blue.
  static const Color brandMfp = Color(0xFF0070D1);

  // ── Progress Tab tokens ──────────────────────────────────────────────────
  static const Color progressCanvas = Color(0xFF141E18);
  static const Color progressSurface = Color(0xFF1E2E24);
  static const Color progressSurfaceRaised = Color(0xFF253A2C);
  static const Color progressTextPrimary = Color(0xFFE8EDE0);
  static const Color progressTextSecondary = Color(0xFFCFE1B9);
  static const Color progressTextMuted = Color(0x66CFE1B9);
  static const Color progressBorderDefault = Color(0x0FCFE1B9);
  static const Color progressBorderStrong = Color(0x1FCFE1B9);
  static const Color progressSage = Color(0xFFCFE1B9);
  static const Color progressStreakWarm = Color(0xFFFF9500);

  // ── Legacy compatibility alias ────────────────────────────────────────────
  // Kept to avoid breaking existing widgets that reference the old `nutrition`
  // constant. New code should use [categoryNutrition] for consistency.

  /// @deprecated Use [categoryNutrition] instead.
  static const Color nutrition = categoryNutrition;

  // ── Shimmer / skeleton loading ────────────────────────────────────────────

  /// Shimmer base color — surface-relative overlay on dark background (#2D2D2D).
  static const Color shimmerBase = Color(0x26FFFFFF);

  /// Shimmer highlight color — surface-relative sweep highlight on dark background.
  static const Color shimmerHighlight = Color(0x66FFFFFF);

  /// Shimmer base color — light mode (10% black overlay on light surface).
  static const Color shimmerBaseLight = Color(0x1A000000);

  /// Shimmer highlight color — light mode (20% black overlay on light surface).
  static const Color shimmerHighlightLight = Color(0x33000000);
}

/// Brightness-aware color resolver.
///
/// Usage:
/// ```dart
/// final colors = AppColorsOf(context);
/// Container(color: colors.cardBackground);
/// ```
///
/// Prefer this over manual `isDark ? dark : light` branching.
class AppColorsOf {
  AppColorsOf(BuildContext context)
      : _isDark = Theme.of(context).brightness == Brightness.dark;

  final bool _isDark;

  // ── Brand ──────────────────────────────────────────────────────────────
  Color get primary => _isDark ? AppColors.primary : AppColors.primaryOnLight;
  Color get secondary => _isDark ? AppColors.secondaryDark : AppColors.secondaryLight;
  Color get accent => _isDark ? AppColors.accentDark : AppColors.accentLight;

  // ── Backgrounds ────────────────────────────────────────────────────────
  Color get background => _isDark ? AppColors.backgroundDark : AppColors.backgroundLight;

  // ── Surfaces ───────────────────────────────────────────────────────────
  Color get surface => _isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
  Color get cardBackground => _isDark ? AppColors.cardBackgroundDark : AppColors.cardBackgroundLight;
  Color get elevatedSurface => _isDark ? AppColors.elevatedSurfaceDark : AppColors.elevatedSurfaceLight;
  Color get inputBackground => _isDark ? AppColors.inputBackgroundDark : AppColors.inputBackgroundLight;

  // ── Text ───────────────────────────────────────────────────────────────
  Color get textPrimary => _isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
  Color get textSecondary => _isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
  Color get textTertiary => AppColors.textTertiary;

  // ── Borders ────────────────────────────────────────────────────────────
  Color get border => _isDark ? AppColors.borderDark : AppColors.borderLight;

  // ── Chat ───────────────────────────────────────────────────────────────
  Color get aiBubble => _isDark ? AppColors.aiBubbleDark : AppColors.aiBubbleLight;

  // ── Buttons ────────────────────────────────────────────────────────────
  Color get secondaryButton => _isDark ? AppColors.secondaryButtonDark : AppColors.secondaryButtonLight;

  // ── Shimmer ────────────────────────────────────────────────────────────
  Color get shimmerBase => _isDark ? AppColors.shimmerBase : AppColors.shimmerBaseLight;
  Color get shimmerHighlight => _isDark ? AppColors.shimmerHighlight : AppColors.shimmerHighlightLight;

  // ── Convenience ────────────────────────────────────────────────────────
  bool get isDark => _isDark;

  // ── Progress ──────────────────────────────────────────────────────────
  // TODO(light-mode): add light variant values for progress tokens.
  Color get progressCanvas => AppColors.progressCanvas;
  Color get progressSurface => AppColors.progressSurface;
  Color get progressSurfaceRaised => AppColors.progressSurfaceRaised;
  Color get progressTextPrimary => AppColors.progressTextPrimary;
  Color get progressTextSecondary => AppColors.progressTextSecondary;
  Color get progressTextMuted => AppColors.progressTextMuted;
  Color get progressBorderDefault => AppColors.progressBorderDefault;
  Color get progressBorderStrong => AppColors.progressBorderStrong;
  Color get progressSage => AppColors.progressSage;
  Color get progressStreakWarm => AppColors.progressStreakWarm;
}
