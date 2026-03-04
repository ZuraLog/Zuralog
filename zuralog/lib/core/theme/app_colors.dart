/// Zuralog Design System — Color Tokens.
///
/// All hex values are sourced from the View Design Document v1.1
/// (docs/plans/frontend/view-design.md, Feb 18, 2026).
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

  /// Sage Green — Main actions, active states, brand identity.
  /// Same value in both light and dark modes.
  static const Color primary = Color(0xFFCFE1B9);

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

  /// Main scaffold background — light mode (pure white).
  static const Color backgroundLight = Color(0xFFFFFFFF);

  /// Main scaffold background — dark mode (OLED true black for battery savings).
  static const Color backgroundDark = Color(0xFF000000);

  // ── Surfaces ─────────────────────────────────────────────────────────────

  /// Elevated surfaces (colorScheme.surface) — light mode (system grey).
  static const Color surfaceLight = Color(0xFFF2F2F7);

  /// Elevated surfaces (colorScheme.surface) — dark mode (dark island).
  static const Color surfaceDark = Color(0xFF1C1C1E);

  /// Standard card background — light mode (white on white-scaffold).
  static const Color cardBackgroundLight = Color(0xFFFFFFFF);

  /// Standard card background — dark mode (near-black for contrast on true black).
  static const Color cardBackgroundDark = Color(0xFF121212);

  /// Elevated card / modal surface — light mode.
  static const Color elevatedSurfaceLight = Color(0xFFFFFFFF);

  /// Elevated card / modal surface — dark mode.
  static const Color elevatedSurfaceDark = Color(0xFF1C1C1E);

  /// Input field background — light mode.
  static const Color inputBackgroundLight = Color(0xFFF2F2F7);

  /// Input field background — dark mode.
  static const Color inputBackgroundDark = Color(0xFF1C1C1E);

  // ── Text ─────────────────────────────────────────────────────────────────

  /// Primary heading / body text — light mode (pure black).
  static const Color textPrimaryLight = Color(0xFF000000);

  /// Primary heading / body text — dark mode.
  static const Color textPrimaryDark = Color(0xFFF2F2F7);

  /// Subtitles, captions, secondary metadata — light mode.
  static const Color textSecondaryLight = Color(0xFF636366);

  /// Subtitles, captions, secondary metadata — dark mode.
  static const Color textSecondaryDark = Color(0xFF8E8E93);

  /// De-emphasised labels, placeholders, disabled text — both modes.
  static const Color textTertiary = Color(0xFFABABAB);

  /// Convenience alias for widgets that don't need theme awareness.
  /// Resolves to [textSecondaryDark] — used in dark-first contexts.
  static const Color textSecondary = textSecondaryDark;

  // ── Borders / Dividers ────────────────────────────────────────────────────

  /// Dividers, card borders — light mode.
  static const Color borderLight = Color(0xFFE5E5EA);

  /// Dividers, card borders — dark mode.
  static const Color borderDark = Color(0xFF38383A);

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
  static const Color aiBubbleDark = Color(0xFF2C2C2E);

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

  /// Secondary button background — dark mode (dark translucent grey).
  static const Color secondaryButtonDark = Color(0xFF2C2C2E);

  // ── Legacy compatibility alias ────────────────────────────────────────────
  // Kept to avoid breaking existing widgets that reference the old `nutrition`
  // constant. New code should use [categoryNutrition] for consistency.

  /// @deprecated Use [categoryNutrition] instead.
  static const Color nutrition = categoryNutrition;
}
