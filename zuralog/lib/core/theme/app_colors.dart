/// Zuralog Design System — Color Tokens.
///
/// All hex values are sourced from the View Design Document v1.1
/// (docs/design.md v4.0).
///
/// Usage: Never reference raw hex values in widgets.
/// Always use a semantic token from [AppColors].
library;

import 'package:flutter/material.dart';

/// Centralized color palette for the Zuralog design system.
///
/// Provides semantic color tokens for both light and dark themes.
/// Organized by role (brand, canvas/elevation, text, borders, UI elements,
/// health categories).
///
/// ## v4.0 — Brand Bible alignment
/// - Unified Canvas → Surface → Surface Raised → Surface Overlay elevation system.
/// - Plus Jakarta Sans font (see AppTextStyles).
/// - Warm White and Text On Sage/Warm White tokens.
/// - Semantic status colors (success, warning, error, syncing).
abstract final class AppColors {
  // ── Brand ────────────────────────────────────────────────────────────────

  /// Sage Green — Main actions, active states, brand identity (dark mode).
  static const Color primary = Color(0xFFCFE1B9);

  /// Warm White — Navigation, secondary controls, selected tab indicators.
  static const Color warmWhite = Color(0xFFF0EEE9);

  /// Deep Forest Green — Primary color for light mode only.
  ///
  /// Sage Green (#CFE1B9) has insufficient contrast (~1.4:1) on white
  /// backgrounds. Deep Forest (#344E41) passes WCAG AA on white while
  /// remaining on-brand. Used as [ColorScheme.primary] in light theme.
  static const Color primaryOnLight = Color(0xFF344E41);

  /// Deep Forest — the dark brand token used as foreground on Sage surfaces
  /// (bottom-nav log pill, `ZPatternPillButton`, active-tab pill in light mode).
  static const Color deepForest = Color(0xFF344E41);

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
  /// Kept for backwards compatibility. New code should use [canvasLight].
  static const Color backgroundLight = Color(0xFFFAFAF5);

  /// Main scaffold background — dark mode (Canvas per brand bible).
  static const Color backgroundDark = canvas;

  // ── Canvas & Elevation (Brand Bible v4.0) ────────────────────────────────
  // Dark mode uses a four-level brightness hierarchy — no borders, no shadows.
  // Each step is ~8 brighter per channel with a subtle warm tint.

  /// Canvas — screen/page background. Darkest level.
  /// Subtle warm tint (+2 blue channel) per brand bible.
  static const Color canvas = Color(0xFF161618);

  // ── Light-mode Brand Bible surface tokens ────────────────────────────────

  /// Canvas — light mode screen/page background (Brand Bible Warm White tint).
  static const Color canvasLight = Color(0xFFF0EEE9);

  /// Surface — light mode cards and content containers.
  static const Color surfaceLightNew = Color(0xFFE8E6E1);

  /// Surface Raised — light mode popovers, dropdowns, hover states.
  static const Color surfaceRaisedLight = Color(0xFFDEDAD4);

  /// Surface Overlay — light mode modals, bottom sheets, dialogs.
  static const Color surfaceOverlayLight = Color(0xFFD4D0CA);

  /// Surface — cards, content containers. One step above canvas.
  static const Color surface = Color(0xFF1E1E20);

  /// Surface Raised — popovers, dropdowns, tooltips, hover states.
  static const Color surfaceRaised = Color(0xFF272729);

  /// Surface Overlay — modals, bottom sheets, dialogs. Highest level.
  static const Color surfaceOverlay = Color(0xFF313133);

  // ── Legacy surface aliases (light/dark) ─────────────────────────────────

  /// Elevated surfaces (colorScheme.surface) — light mode (system grey).
  static const Color surfaceLight = Color(0xFFF2F2F7);

  /// Elevated surfaces (colorScheme.surface) — dark mode.
  static const Color surfaceDark = surface;

  /// Standard card background — light mode (white on white-scaffold).
  static const Color cardBackgroundLight = Color(0xFFFFFFFF);

  /// Standard card background — dark mode.
  static const Color cardBackgroundDark = surface;

  /// Elevated card / modal surface — light mode.
  static const Color elevatedSurfaceLight = Color(0xFFFFFFFF);

  /// Elevated card / modal surface — dark mode.
  static const Color elevatedSurfaceDark = surfaceRaised;

  /// Input field background — light mode.
  static const Color inputBackgroundLight = Color(0xFFF2F2F7);

  /// Input field background — dark mode (same as Surface per brand bible).
  static const Color inputBackgroundDark = surface;

  // ── Text ─────────────────────────────────────────────────────────────────

  /// Primary heading / body text — light mode (near-black per brand bible).
  static const Color textPrimaryLight = Color(0xFF161618);

  /// Primary heading / body text — dark mode (Warm White per brand bible).
  static const Color textPrimaryDark = Color(0xFFF0EEE9);

  /// Subtitles, captions, secondary metadata — light mode (warm grey per brand bible).
  static const Color textSecondaryLight = Color(0xFF6B6864);

  /// Subtitles, captions, secondary metadata — dark mode.
  static const Color textSecondaryDark = Color(0xFF9B9894);

  /// Text on Sage-filled surfaces — dark mode (deep forest for contrast on sage).
  /// For backwards compatibility; prefer [textOnSageDark] in new code.
  static const Color textOnSage = Color(0xFF1A2E22);

  /// Text on Sage-filled surfaces — dark mode (same as [textOnSage]).
  static const Color textOnSageDark = Color(0xFF1A2E22);

  /// Text on Sage-filled surfaces — light mode (light cream for contrast on sage).
  static const Color textOnSageLight = Color(0xFFE8EDE0);

  /// Text on Warm White surfaces (active segmented control).
  static const Color textOnWarmWhite = Color(0xFF161618);

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

  /// Brand bible divider: warm-tinted 6% transparency.
  static const Color dividerDefault = Color(0x0FF0EEE9); // rgba(240,238,233,0.06)

  // ── Semantic Status ─────────────────────────────────────────────────────

  /// Connected, positive deltas, goal complete.
  static const Color success = Color(0xFF34C759);

  /// Caution, approaching limits.
  static const Color warning = Color(0xFFFF9500);

  /// Errors, destructive actions, delete buttons.
  static const Color error = Color(0xFFFF3B30);

  /// Loading/sync indicators.
  static const Color syncing = Color(0xFF007AFF);

  /// Streak flame accent.
  static const Color streakWarm = Color(0xFFFF9500);

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

  /// Primary button foreground text (dark forest on Sage Green).
  static const Color primaryButtonText = textOnSage;

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

  // ── Progress Tab tokens — dark mode ──────────────────────────────────────
  // Redirected to unified brand bible tokens (v4.0).
  static const Color progressCanvas = canvas;
  static const Color progressSurface = surface;
  static const Color progressSurfaceRaised = surfaceRaised;
  static const Color progressTextPrimary = textPrimaryDark;
  static const Color progressTextSecondary = primary;
  static const Color progressTextMuted = Color(0x66CFE1B9);
  static const Color progressBorderDefault = dividerDefault;
  static const Color progressBorderStrong = Color(0x1FCFE1B9);
  static const Color progressSage = primary;
  static const Color progressStreakWarm = streakWarm;

  // ── Progress Tab tokens — light mode ─────────────────────────────────────
  static const Color progressCanvasLight = Color(0xFFF4F7F0);
  static const Color progressSurfaceLight = Color(0xFFEBF1E5);
  static const Color progressSurfaceRaisedLight = Color(0xFFDFEBD6);
  static const Color progressTextPrimaryLight = Color(0xFF1A2E1E);
  static const Color progressTextSecondaryLight = Color(0xFF3D5E2E);
  static const Color progressTextMutedLight = Color(0xFF5C7A4D);
  static const Color progressBorderDefaultLight = Color(0x1F3D5E2E);
  static const Color progressBorderStrongLight = Color(0x333D5E2E);
  static const Color progressSageLight = Color(0xFF4A7C3F);
  static const Color progressStreakWarmLight = Color(0xFFFF9500);

  // -- Trends Tab tokens ---------------------------------------------------
  // Redirected to unified brand bible tokens (v4.0).
  static const Color trendsCanvas = canvas;
  static const Color trendsSurface = surface;
  static const Color trendsSurfaceRaised = surfaceRaised;
  static const Color trendsTextPrimary = textPrimaryDark;
  static const Color trendsTextSecondary = primary;
  static const Color trendsTextMuted = Color(0x66CFE1B9);
  static const Color trendsBorderDefault = dividerDefault;
  static const Color trendsBorderStrong = Color(0x1FCFE1B9);
  static const Color trendsSage = primary;
  static const Color trendsDeepForest = Color(0xFF344E41);

  /// Muted trends text — light mode static constant (Deep Forest at 40% opacity).
  ///
  /// Pre-computed to avoid calling [Color.withValues] at runtime.
  static const Color trendsTextMutedLight = Color(0x66344E41);

  // ── Legacy compatibility alias ────────────────────────────────────────────
  // Kept to avoid breaking existing widgets that reference the old `nutrition`
  // constant. New code should use [categoryNutrition] for consistency.

  @Deprecated('Use categoryNutrition instead')
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

  // ── Canvas & Elevation (Brand Bible) ───────────────────────────────────
  Color get canvas => _isDark ? AppColors.canvas : AppColors.canvasLight;
  Color get surfaceRaised => _isDark ? AppColors.surfaceRaised : AppColors.surfaceRaisedLight;
  Color get surfaceOverlay => _isDark ? AppColors.surfaceOverlay : AppColors.surfaceOverlayLight;

  // ── Backgrounds ────────────────────────────────────────────────────────
  Color get background => _isDark ? AppColors.backgroundDark : AppColors.canvasLight;

  // ── Surfaces ───────────────────────────────────────────────────────────
  Color get surface => _isDark ? AppColors.surfaceDark : AppColors.surfaceLightNew;
  Color get cardBackground => _isDark ? AppColors.cardBackgroundDark : AppColors.surfaceLightNew;
  Color get elevatedSurface => _isDark ? AppColors.elevatedSurfaceDark : AppColors.elevatedSurfaceLight;
  Color get inputBackground => _isDark ? AppColors.inputBackgroundDark : AppColors.surfaceRaisedLight;

  // ── Text ───────────────────────────────────────────────────────────────
  Color get textPrimary => _isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
  Color get textSecondary => _isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
  Color get textTertiary => AppColors.textTertiary;
  Color get textOnSage => _isDark ? AppColors.textOnSageDark : AppColors.textOnSageLight;
  Color get textOnWarmWhite => AppColors.textOnWarmWhite;
  Color get warmWhite => AppColors.warmWhite;

  // ── Borders ────────────────────────────────────────────────────────────
  Color get border => _isDark ? AppColors.dividerDefault : const Color(0x14161618);
  Color get divider => _isDark ? AppColors.dividerDefault : const Color(0x14161618);

  // ── Semantic Status ────────────────────────────────────────────────────
  Color get success => AppColors.success;
  Color get warning => AppColors.warning;
  Color get error => AppColors.error;
  Color get syncing => AppColors.syncing;

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
  Color get progressCanvas => _isDark ? AppColors.progressCanvas : AppColors.progressCanvasLight;
  Color get progressSurface => _isDark ? AppColors.progressSurface : AppColors.progressSurfaceLight;
  Color get progressSurfaceRaised => _isDark ? AppColors.progressSurfaceRaised : AppColors.progressSurfaceRaisedLight;
  Color get progressTextPrimary => _isDark ? AppColors.progressTextPrimary : AppColors.progressTextPrimaryLight;
  Color get progressTextSecondary => _isDark ? AppColors.progressTextSecondary : AppColors.progressTextSecondaryLight;
  Color get progressTextMuted => _isDark ? AppColors.progressTextMuted : AppColors.progressTextMutedLight;
  Color get progressBorderDefault => _isDark ? AppColors.progressBorderDefault : AppColors.progressBorderDefaultLight;
  Color get progressBorderStrong => _isDark ? AppColors.progressBorderStrong : AppColors.progressBorderStrongLight;
  Color get progressSage => _isDark ? AppColors.progressSage : AppColors.progressSageLight;
  Color get progressStreakWarm => _isDark ? AppColors.progressStreakWarm : AppColors.progressStreakWarmLight;

  // ── Trends ────────────────────────────────────────────────────────────────
  Color get trendsCanvas => _isDark ? AppColors.canvas : AppColors.canvasLight;
  Color get trendsSurface => _isDark ? AppColors.surface : AppColors.surfaceLightNew;
  Color get trendsSurfaceRaised => _isDark ? AppColors.surfaceRaised : AppColors.surfaceRaisedLight;
  Color get trendsTextPrimary => _isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
  Color get trendsTextSecondary => _isDark ? AppColors.primary : AppColors.primaryOnLight;
  Color get trendsTextMuted => _isDark ? AppColors.trendsTextMuted : AppColors.trendsTextMutedLight;
  Color get trendsBorderDefault => _isDark ? AppColors.dividerDefault : AppColors.borderLight;
  Color get trendsBorderStrong => _isDark ? const Color(0x1FCFE1B9) : AppColors.borderLight;
  Color get trendsSage => _isDark ? AppColors.primary : AppColors.primaryOnLight;
  Color get trendsDeepForest => AppColors.trendsDeepForest;
}
