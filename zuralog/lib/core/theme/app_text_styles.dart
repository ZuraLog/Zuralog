/// Zuralog Design System — Typography Tokens.
///
/// Typography scale from Design System v3.2 (docs/design.md).
/// Font: Inter (Android/Web) / SF Pro Display (iOS, system font).
library;

import 'dart:io' show Platform;

import 'package:flutter/material.dart';

/// Typography tokens for the Zuralog design system.
///
/// Uses the Inter font family on Android (bundled in assets/fonts/).
/// On iOS, passes `null` as the font family to fall back to SF Pro Display,
/// which is Apple's system font and requires no bundling.
///
/// ## v3.2 additions
/// Added 11 new semantic style getters (displayLarge … labelSmall) aligned to
/// Material 3 TextTheme slots. Seven old names are deprecated but kept functional
/// to avoid breaking existing callsites during the transition period.
abstract final class AppTextStyles {
  /// Resolves the correct font family for the current platform.
  ///
  /// Returns `null` on iOS so Flutter inherits SF Pro Display automatically.
  /// Returns `'Inter'` on all other platforms.
  static String? get _fontFamily {
    try {
      return Platform.isIOS ? null : 'Inter';
    } catch (_) {
      // Platform check unavailable (e.g., web or test environment).
      // Default to Inter, which is always bundled.
      return 'Inter';
    }
  }

  // ── New Design-System Style Set (v3.2) ────────────────────────────────────

  /// Display Large — 34pt Bold 700, height 1.1.
  ///
  /// Hero numbers (step count, calorie total), primary screen titles.
  static TextStyle get displayLarge => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 34,
        fontWeight: FontWeight.w700,
        height: 1.1,
      );

  /// Display Medium — 28pt SemiBold 600, height 1.15.
  ///
  /// Section headers, greeting text ("Good morning, Maria").
  static TextStyle get displayMedium => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 28,
        fontWeight: FontWeight.w600,
        height: 1.15,
      );

  /// Display Small — 24pt SemiBold 600, height 1.2.
  ///
  /// Card headlines, modal titles, navigation bar titles.
  static TextStyle get displaySmall => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 1.2,
      );

  /// Title Large — 20pt Medium 500, height 1.25.
  ///
  /// Card titles, dialog headers.
  static TextStyle get titleLarge => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 20,
        fontWeight: FontWeight.w500,
        height: 1.25,
      );

  /// Title Medium — 17pt Medium 500, height 1.3.
  ///
  /// List item titles, navigation headers.
  static TextStyle get titleMedium => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 17,
        fontWeight: FontWeight.w500,
        height: 1.3,
      );

  /// Body Large — 16pt Regular 400, height 1.5.
  ///
  /// Primary body text, AI chat messages.
  static TextStyle get bodyLarge => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
      );

  /// Body Medium — 14pt Regular 400, height 1.45.
  ///
  /// Secondary body, descriptions, insight card content.
  /// Updated from v3.1 (height was 1.43 → now 1.45 per v3.2 spec).
  static TextStyle get bodyMedium => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.15,
        height: 1.45,
      );

  /// Body Small — 12pt Regular 400, height 1.4.
  ///
  /// Captions, timestamps, metadata, source attribution.
  static TextStyle get bodySmall => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.4,
      );

  /// Label Large — 15pt SemiBold 600, height 1.2.
  ///
  /// Button text, action labels.
  static TextStyle get labelLarge => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.2,
      );

  /// Label Medium — 13pt Medium 500, height 1.2.
  ///
  /// Chip text, tab labels, category tags.
  static TextStyle get labelMedium => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 1.2,
      );

  /// Label Small — 11pt Medium 500, height 1.2.
  ///
  /// Badge text, compact stats, unit labels.
  static TextStyle get labelSmall => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        height: 1.2,
      );

  // ── Deprecated Style Names (v3.1 → v3.2 migration) ───────────────────────
  // These names are kept functional so existing callsites continue to compile.
  // Migrate to the new names at your next opportunity.

  /// H1 — Large Title: 34pt Bold.
  ///
  /// @deprecated Use [displayLarge] instead.
  @Deprecated('Use displayLarge instead.')
  static TextStyle get h1 => displayLarge;

  /// H2 — Title 2: 22pt SemiBold.
  ///
  /// @deprecated Use [displaySmall] instead (24pt is the closest replacement).
  @Deprecated('Use displaySmall instead.')
  static TextStyle get h2 => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.26,
        height: 1.27,
      );

  /// H3 — Headline: 17pt SemiBold.
  ///
  /// @deprecated Use [titleMedium] instead.
  @Deprecated('Use titleMedium instead.')
  static TextStyle get h3 => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.41,
        height: 1.29,
      );

  /// Body — 17pt Regular.
  ///
  /// @deprecated Use [bodyLarge] instead.
  @Deprecated('Use bodyLarge instead.')
  static TextStyle get body => bodyLarge;

  /// Caption — 12pt Medium.
  ///
  /// @deprecated Use [bodySmall] instead (note: new bodySmall is 12pt Regular 400,
  /// whereas the old caption was 12pt Medium 500 — the v3.2 spec takes precedence).
  @Deprecated('Use bodySmall instead.')
  static TextStyle get caption => bodySmall;

  /// Label XS — 10pt Medium.
  ///
  /// @deprecated Use [labelSmall] instead (11pt Medium 500).
  @Deprecated('Use labelSmall instead.')
  static TextStyle get labelXs => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 10,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        height: 1.3,
      );
}
