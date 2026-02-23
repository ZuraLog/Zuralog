/// Zuralog Design System — Typography Tokens.
///
/// Typography scale from View Design Document v1.1, Section 1.2.
/// Font: Inter (Android) / SF Pro Display (iOS, system font).
library;

import 'dart:io' show Platform;

import 'package:flutter/material.dart';

/// Typography tokens for the Zuralog design system.
///
/// Uses the Inter font family on Android (bundled in assets/fonts/).
/// On iOS, passes `null` as the font family to fall back to SF Pro Display,
/// which is Apple's system font and requires no bundling.
///
/// All sizes and weights match the view-design.md specification exactly.
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

  /// H1 — Large Title: 34pt Bold.
  ///
  /// Used for primary screen headings (e.g., "Good Morning, [Name]").
  static TextStyle get h1 => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 34,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        height: 1.2,
      );

  /// H2 — Title 2: 22pt SemiBold.
  ///
  /// Used for section titles and navigation bar titles (e.g., "Coach").
  static TextStyle get h2 => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.26,
        height: 1.27,
      );

  /// H3 — Headline: 17pt SemiBold.
  ///
  /// Used for card titles, list headers, and button labels.
  static TextStyle get h3 => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.41,
        height: 1.29,
      );

  /// Body — 17pt Regular.
  ///
  /// Standard body text for content paragraphs and chat messages.
  static TextStyle get body => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 17,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.41,
        height: 1.41,
      );

  /// Caption — 12pt Medium.
  ///
  /// Used for subtitles, timestamps, status labels, and metadata.
  static TextStyle get caption => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        height: 1.33,
      );
}
