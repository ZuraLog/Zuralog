/// Unit tests for [AppTheme] — the central theme factory.
///
/// Verifies that light and dark themes are produced with the correct
/// brightness, scaffold background, primary color, and font family.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_theme.dart';

void main() {
  group('AppTheme.light', () {
    late ThemeData light;

    setUpAll(() {
      light = AppTheme.light;
    });

    test('has Brightness.light', () {
      expect(light.brightness, Brightness.light);
    });

    test('scaffold background is backgroundLight (#FAFAF5)', () {
      expect(light.scaffoldBackgroundColor, AppColors.backgroundLight);
    });

    test('primary color is primaryOnLight (Deep Forest #354E42)', () {
      // Light mode uses primaryOnLight for WCAG AA contrast on light surfaces.
      // Sage Green (#CFE1B9) is too pale on white backgrounds.
      expect(light.colorScheme.primary, AppColors.primaryOnLight);
    });

    test('onPrimary is white (on primaryOnLight in light mode)', () {
      expect(light.colorScheme.onPrimary, Colors.white);
    });

    test('secondary color is secondaryLight (Muted Slate)', () {
      expect(light.colorScheme.secondary, AppColors.secondaryLight);
    });

    test('tertiary color is accentLight (Soft Coral)', () {
      expect(light.colorScheme.tertiary, AppColors.accentLight);
    });

    test('surface is surfaceLight (white)', () {
      expect(light.colorScheme.surface, AppColors.surfaceLight);
    });

    test('onSurface is textPrimaryLight (near-black)', () {
      expect(light.colorScheme.onSurface, AppColors.textPrimaryLight);
    });

    test('outline is borderLight', () {
      expect(light.colorScheme.outline, AppColors.borderLight);
    });

    test('uses Material 3', () {
      expect(light.useMaterial3, isTrue);
    });

    test('bodyLarge fontFamily matches Inter (or null on iOS / SF Pro)', () {
      // Inter is expected on non-iOS. On iOS, fontFamily is null (SF Pro).
      // In the test environment Platform.isIOS is false → expect 'Inter'.
      final family = light.textTheme.bodyLarge?.fontFamily;
      expect(family, anyOf(equals('Inter'), isNull));
    });

    test('card shape has 20px corner radius', () {
      final shape = light.cardTheme.shape as RoundedRectangleBorder?;
      expect(shape, isNotNull);
      final radius = (shape!.borderRadius as BorderRadius).topLeft.x;
      expect(radius, 20.0); // AppDimens.radiusCard = 20
    });

    test('ElevatedButton background is primaryOnLight in light mode', () {
      final bg = light.elevatedButtonTheme.style
          ?.backgroundColor
          ?.resolve({});
      expect(bg, AppColors.primaryOnLight);
    });

    test('divider color is borderLight', () {
      expect(light.dividerTheme.color, AppColors.borderLight);
    });
  });

  group('AppTheme.dark', () {
    late ThemeData dark;

    setUpAll(() {
      dark = AppTheme.dark;
    });

    test('has Brightness.dark', () {
      expect(dark.brightness, Brightness.dark);
    });

    test('scaffold background is backgroundDark (Dark Charcoal #2D2D2D)', () {
      expect(dark.scaffoldBackgroundColor, AppColors.backgroundDark);
      // Confirm it matches the brand Dark Charcoal palette.
      expect(dark.scaffoldBackgroundColor, const Color(0xFF2D2D2D));
    });

    test('primary color is still Sage Green (#CFE1B9)', () {
      expect(dark.colorScheme.primary, AppColors.primary);
    });

    test('secondary color is secondaryDark (lighter Muted Slate)', () {
      expect(dark.colorScheme.secondary, AppColors.secondaryDark);
    });

    test('tertiary color is accentDark (lighter Soft Coral)', () {
      expect(dark.colorScheme.tertiary, AppColors.accentDark);
    });

    test('surface is surfaceDark (#1C1C1E)', () {
      expect(dark.colorScheme.surface, AppColors.surfaceDark);
    });

    test('onSurface is textPrimaryDark (near-white)', () {
      expect(dark.colorScheme.onSurface, AppColors.textPrimaryDark);
    });

    test('outline is borderDark', () {
      expect(dark.colorScheme.outline, AppColors.borderDark);
    });

    test('uses Material 3', () {
      expect(dark.useMaterial3, isTrue);
    });

    test('ElevatedButton background is still Sage Green in dark mode', () {
      final bg = dark.elevatedButtonTheme.style
          ?.backgroundColor
          ?.resolve({});
      expect(bg, AppColors.primary);
    });

    test('divider color is borderDark', () {
      expect(dark.dividerTheme.color, AppColors.borderDark);
    });
  });

  group('AppTheme light vs dark', () {
    test('light and dark themes differ in brightness', () {
      expect(AppTheme.light.brightness, isNot(AppTheme.dark.brightness));
    });

    test('primary colors differ between modes (light uses primaryOnLight for contrast)', () {
      // Light mode uses primaryOnLight (Deep Forest #344E41) for WCAG AA contrast.
      // Dark mode uses primary (Sage Green #CFE1B9) for brand identity on dark bg.
      expect(
        AppTheme.light.colorScheme.primary,
        isNot(AppTheme.dark.colorScheme.primary),
      );
      expect(AppTheme.light.colorScheme.primary, AppColors.primaryOnLight);
      expect(AppTheme.dark.colorScheme.primary, AppColors.primary);
    });

    test('scaffold backgrounds differ', () {
      expect(
        AppTheme.light.scaffoldBackgroundColor,
        isNot(AppTheme.dark.scaffoldBackgroundColor),
      );
    });

    test('secondary colors differ between modes', () {
      expect(
        AppTheme.light.colorScheme.secondary,
        isNot(AppTheme.dark.colorScheme.secondary),
      );
    });
  });
}
