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
/// Organized by role (brand, backgrounds, surfaces, text, borders, UI elements).
abstract final class AppColors {
  // ── Brand ────────────────────────────────────────────────────────────────

  /// Sage Green — Main actions, active states, brand identity.
  /// Same value in both light and dark modes.
  static const Color primary = Color(0xFFCFE1B9);

  /// Muted Slate — Secondary buttons, info icons, graphs (light mode).
  static const Color secondaryLight = Color(0xFF5B7C99);

  /// Muted Slate — Secondary buttons, info icons, graphs (dark mode).
  static const Color secondaryDark = Color(0xFF7DA4C7);

  /// Soft Coral — Alerts, destructive actions (light mode).
  static const Color accentLight = Color(0xFFE07A5F);

  /// Soft Coral — Alerts, destructive actions (dark mode).
  static const Color accentDark = Color(0xFFFF8E72);

  // ── Backgrounds ──────────────────────────────────────────────────────────

  /// Main app background — light mode.
  static const Color backgroundLight = Color(0xFFFAFAFA);

  /// Main app background — dark mode (OLED Black for battery savings).
  static const Color backgroundDark = Color(0xFF000000);

  // ── Surfaces ─────────────────────────────────────────────────────────────

  /// Cards, modals, bottom sheets — light mode.
  static const Color surfaceLight = Color(0xFFFFFFFF);

  /// Cards, modals, bottom sheets — dark mode.
  static const Color surfaceDark = Color(0xFF1C1C1E);

  // ── Text ─────────────────────────────────────────────────────────────────

  /// Headings, body text — light mode.
  static const Color textPrimaryLight = Color(0xFF1C1C1E);

  /// Headings, body text — dark mode.
  static const Color textPrimaryDark = Color(0xFFF2F2F7);

  /// Subtitles, captions, disabled states — same in both modes.
  static const Color textSecondary = Color(0xFF8E8E93);

  // ── Borders ──────────────────────────────────────────────────────────────

  /// Dividers, card borders — light mode.
  static const Color borderLight = Color(0xFFE5E5EA);

  /// Dividers, card borders — dark mode.
  static const Color borderDark = Color(0xFF38383A);

  // ── Chat Bubbles ─────────────────────────────────────────────────────────

  /// User message bubble background (Sage Green, consistent across modes).
  static const Color userBubble = primary;

  /// User message bubble text color (always dark for contrast on Sage Green).
  static const Color userBubbleText = Color(0xFF1C1C1E);

  /// AI message bubble — light mode.
  static const Color aiBubbleLight = Color(0xFFF2F2F7);

  /// AI message bubble — dark mode.
  static const Color aiBubbleDark = Color(0xFF2C2C2E);

  // ── Buttons ──────────────────────────────────────────────────────────────

  /// Primary button foreground text (always dark grey on Sage Green).
  static const Color primaryButtonText = Color(0xFF1C1C1E);

  /// Secondary button background — light mode (translucent grey).
  static const Color secondaryButtonLight = Color(0xFFF2F2F7);

  /// Secondary button background — dark mode (dark translucent grey).
  static const Color secondaryButtonDark = Color(0xFF2C2C2E);
}
