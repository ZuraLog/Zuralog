/// Zuralog Design System — Typography Tokens.
///
/// Typography scale from Brand Bible v4.0 (docs/design.md).
/// Font: Plus Jakarta Sans (all platforms via google_fonts).
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Typography tokens for the Zuralog design system.
///
/// Uses Plus Jakarta Sans on all platforms via the google_fonts package.
/// Geometric, modern, and refined — numbers render beautifully at every size,
/// which is critical for a health app full of metrics.
///
/// The 11 semantic style getters (displayLarge … labelSmall) are aligned to
/// Material 3 TextTheme slots.
abstract final class AppTextStyles {
  /// Base text style with Plus Jakarta Sans applied.
  static TextStyle get _base => GoogleFonts.plusJakartaSans();

  // ── Design-System Style Set (v4.0 — Brand Bible) ────────────────────────

  /// Display Large — 34pt Bold 700, height 1.1.
  ///
  /// Hero numbers (step count, calorie total), primary screen titles.
  static TextStyle get displayLarge => _base.copyWith(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        height: 1.1,
      );

  /// Display Medium — 28pt SemiBold 600, height 1.15.
  ///
  /// Section headers, greeting text ("Good morning, Maria").
  static TextStyle get displayMedium => _base.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        height: 1.15,
      );

  /// Display Small — 24pt SemiBold 600, height 1.2.
  ///
  /// Card headlines, modal titles, navigation bar titles.
  static TextStyle get displaySmall => _base.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 1.2,
      );

  /// Title Large — 20pt Medium 500, height 1.25.
  ///
  /// Card titles, dialog headers.
  static TextStyle get titleLarge => _base.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w500,
        height: 1.25,
      );

  /// Title Medium — 17pt Medium 500, height 1.3.
  ///
  /// List item titles, navigation headers.
  static TextStyle get titleMedium => _base.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w500,
        height: 1.3,
      );

  /// Body Large — 16pt Regular 400, height 1.5.
  ///
  /// Primary body text, AI chat messages.
  static TextStyle get bodyLarge => _base.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
      );

  /// Body Medium — 14pt Regular 400, height 1.45.
  ///
  /// Secondary body, descriptions, insight card content.
  static TextStyle get bodyMedium => _base.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.15,
        height: 1.45,
      );

  /// Body Small — 12pt Regular 400, height 1.4.
  ///
  /// Captions, timestamps, metadata, source attribution.
  static TextStyle get bodySmall => _base.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.4,
      );

  /// Label Large — 15pt SemiBold 600, height 1.2.
  ///
  /// Button text, action labels.
  static TextStyle get labelLarge => _base.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.2,
      );

  /// Label Medium — 13pt Medium 500, height 1.2.
  ///
  /// Chip text, tab labels, category tags.
  static TextStyle get labelMedium => _base.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 1.2,
      );

  /// Label Small — 11pt Medium 500, height 1.2.
  ///
  /// Badge text, compact stats, unit labels.
  static TextStyle get labelSmall => _base.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        height: 1.2,
      );

  // ── Deprecated Style Names ───────────────────────────────────────────────

  /// @deprecated Use [displayLarge] instead.
  @Deprecated('Use displayLarge instead.')
  static TextStyle get h1 => displayLarge;

  /// @deprecated Use [displaySmall] instead.
  @Deprecated('Use displaySmall instead.')
  static TextStyle get h2 => _base.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.26,
        height: 1.27,
      );

  /// @deprecated Use [titleMedium] instead.
  @Deprecated('Use titleMedium instead.')
  static TextStyle get h3 => _base.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.41,
        height: 1.29,
      );

  /// @deprecated Use [bodyLarge] instead.
  @Deprecated('Use bodyLarge instead.')
  static TextStyle get body => bodyLarge;

  /// @deprecated Use [bodySmall] instead.
  @Deprecated('Use bodySmall instead.')
  static TextStyle get caption => bodySmall;

  /// @deprecated Use [labelSmall] instead.
  @Deprecated('Use labelSmall instead.')
  static TextStyle get labelXs => _base.copyWith(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        height: 1.3,
      );
}
