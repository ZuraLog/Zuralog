/// Zuralog Design System — Theme Factory.
///
/// Produces fully-configured [ThemeData] for light and dark modes.
/// Both themes share typography and spacing tokens but differ in
/// color schemes, surface treatment, and system UI overlay styles.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_dimens.dart';
import 'app_text_styles.dart';

/// Factory class that produces [ThemeData] for Zuralog light and dark modes.
///
/// Wired into [MaterialApp] via [ZuralogApp] using [themeModeProvider].
/// Both themes use Material 3 and `useMaterial3: true`.
///
/// Design principles:
/// - Light: Brand Cream (#FAFAF5) surfaces, soft diffusion shadows, dark text.
/// - Dark: Dark Charcoal (#2D2D2D) background, bordered surfaces, no shadows, light text.
abstract final class AppTheme {
  // ── Public API ────────────────────────────────────────────────────────────

  /// Light theme — Brand Cream surfaces, soft shadows, dark text on light backgrounds.
  static ThemeData get light => _build(Brightness.light);

  /// Dark theme — Dark Charcoal (#2D2D2D) background, bordered card surfaces, no shadows, light text.
  static ThemeData get dark => _build(Brightness.dark);

  // ── Private Builder ───────────────────────────────────────────────────────

  /// Builds the complete [ThemeData] for the given [brightness].
  ///
  /// [brightness] determines color scheme, surface styling, and overlay style.
  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;

    final colorScheme = isLight
        ? ColorScheme.light(
            // Forest Green in light mode — passes WCAG AA (4.8:1 on white).
            // Sage Green (#CFE1B9) is too pale to be readable on white surfaces.
            primary: AppColors.primaryOnLight,
            onPrimary: Colors.white,
            secondary: AppColors.secondaryLight,
            onSecondary: Colors.white,
            tertiary: AppColors.accentLight,
            onTertiary: Colors.white,
            surface: AppColors.surfaceLight,
            onSurface: AppColors.textPrimaryLight,
            onSurfaceVariant: AppColors.textSecondaryLight,
            outline: AppColors.borderLight,
            outlineVariant: AppColors.borderLight,
            error: AppColors.accentLight,
            onError: Colors.white,
            surfaceContainerHighest: AppColors.secondaryButtonLight,
          )
        : ColorScheme.dark(
            primary: AppColors.primary,
            onPrimary: AppColors.primaryButtonText,
            secondary: AppColors.secondaryDark,
            onSecondary: Colors.white,
            tertiary: AppColors.accentDark,
            onTertiary: Colors.white,
            surface: AppColors.surfaceDark,
            onSurface: AppColors.textPrimaryDark,
            onSurfaceVariant: AppColors.textSecondaryDark,
            outline: AppColors.borderDark,
            outlineVariant: AppColors.borderDark,
            error: AppColors.accentDark,
            onError: Colors.white,
            surfaceContainerHighest: AppColors.secondaryButtonDark,
          );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor:
          isLight ? AppColors.backgroundLight : AppColors.backgroundDark,

      fontFamily: AppTextStyles.bodyLarge.fontFamily,
      textTheme: _buildTextTheme(
        isLight ? AppColors.textPrimaryLight : AppColors.textPrimaryDark,
        isLight,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor:
            isLight ? AppColors.backgroundLight : AppColors.backgroundDark,
        foregroundColor:
            isLight ? AppColors.textPrimaryLight : AppColors.textPrimaryDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: isLight
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
        titleTextStyle: AppTextStyles.displayMedium.copyWith(
          color: isLight ? AppColors.textPrimaryLight : AppColors.textPrimaryDark,
        ),
      ),
      cardTheme: CardThemeData(
        color: isLight
            ? AppColors.cardBackgroundLight
            : AppColors.cardBackgroundDark,
        elevation: 0,
        // No border, no shadow — cards defined by background contrast only.
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isLight ? AppColors.primaryOnLight : AppColors.primary,
          foregroundColor: isLight ? Colors.white : AppColors.primaryButtonText,
          disabledBackgroundColor: isLight
              ? AppColors.primaryOnLight.withValues(alpha: 0.5)
              : AppColors.primary.withValues(alpha: 0.5),
          disabledForegroundColor: isLight
              ? Colors.white.withValues(alpha: 0.5)
              : AppColors.primaryButtonText.withValues(alpha: 0.5),
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize:
              const Size(double.infinity, AppDimens.touchTargetMin),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusButton),
          ),
          textStyle: AppTextStyles.labelLarge,
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spaceLg,
            vertical: AppDimens.spaceMd,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        // Inline text links (e.g. "Log in", "Sign up") must remain shrink-wrapped.
        // Full-width filled "secondary button" style is applied explicitly by
        // the SecondaryButton widget — NOT here — to avoid collapsing Rows.
        style: TextButton.styleFrom(
          foregroundColor:
              isLight ? AppColors.primaryOnLight : AppColors.primary,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spaceSm,
            vertical: AppDimens.spaceXs,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusButton),
          ),
          textStyle: AppTextStyles.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor:
              isLight ? AppColors.primaryOnLight : AppColors.primary,
          foregroundColor: isLight ? Colors.white : AppColors.primaryButtonText,
          disabledBackgroundColor: isLight
              ? AppColors.primaryOnLight.withValues(alpha: 0.5)
              : AppColors.primary.withValues(alpha: 0.5),
          disabledForegroundColor: isLight
              ? Colors.white.withValues(alpha: 0.5)
              : AppColors.primaryButtonText.withValues(alpha: 0.5),
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.shapePill),
          ),
          textStyle: AppTextStyles.labelLarge,
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        // minimumSize is intentionally NOT set to double.infinity here.
        // Full-width outlined buttons (e.g. login form) should set their own
        // width explicitly. Setting infinity globally causes a layout crash
        // when an OutlinedButton is placed inside a Row with an Expanded child
        // (e.g. IntegrationTile "Connect" button) — identical to the
        // TextButton issue fixed in the auth sprint.
        style: OutlinedButton.styleFrom(
          foregroundColor:
              isLight ? AppColors.textPrimaryLight : AppColors.textPrimaryDark,
          side: BorderSide(
            color: isLight ? AppColors.borderLight : AppColors.borderDark,
          ),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusButton),
          ),
          textStyle: AppTextStyles.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight
            ? AppColors.inputBackgroundLight
            : AppColors.inputBackgroundDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusInput),
          borderSide: BorderSide(
            color: isLight ? AppColors.borderLight : AppColors.borderDark,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusInput),
          borderSide: isLight
              ? BorderSide(color: AppColors.borderLight)
              : BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusInput),
          borderSide: BorderSide(
            color: isLight
                ? AppColors.primaryOnLight
                : AppColors.primary.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusInput),
          borderSide: BorderSide(
            color: AppColors.error.withValues(alpha: 0.5),
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusInput),
          borderSide: BorderSide(
            color: AppColors.error,
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: AppDimens.spaceMd,
        ),
        hintStyle: AppTextStyles.bodyLarge.copyWith(
          color: isLight ? AppColors.textSecondaryLight : AppColors.textSecondaryDark,
        ),
        labelStyle: AppTextStyles.bodyLarge.copyWith(
          color: isLight ? AppColors.textPrimaryLight : AppColors.textPrimaryDark,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: isLight ? AppColors.borderLight : AppColors.dividerDefault,
        thickness: 1,
        space: 0,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor:
            isLight ? AppColors.surfaceLight : AppColors.surfaceDark,
        selectedItemColor:
            isLight ? AppColors.primaryOnLight : AppColors.primary,
        unselectedItemColor:
            isLight ? AppColors.textSecondaryLight : AppColors.textSecondaryDark,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: AppTextStyles.labelSmall,
        unselectedLabelStyle: AppTextStyles.labelSmall,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor:
            isLight ? AppColors.surfaceLight : AppColors.surfaceDark,
        indicatorColor: (isLight ? AppColors.primaryOnLight : AppColors.primary)
            .withValues(alpha: 0.2),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final activeColor =
              isLight ? AppColors.primaryOnLight : AppColors.primary;
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: activeColor);
          }
          return IconThemeData(
            color: isLight ? AppColors.textSecondaryLight : AppColors.textSecondaryDark,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final activeColor =
              isLight ? AppColors.primaryOnLight : AppColors.primary;
          if (states.contains(WidgetState.selected)) {
            return AppTextStyles.labelSmall.copyWith(color: activeColor);
          }
          return AppTextStyles.labelSmall.copyWith(
            color: isLight ? AppColors.textSecondaryLight : AppColors.textSecondaryDark,
          );
        }),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return isLight ? AppColors.textSecondaryLight : AppColors.textSecondaryDark;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return isLight ? AppColors.primaryOnLight : AppColors.primary;
          }
          return isLight ? AppColors.borderLight : AppColors.surfaceRaised;
        }),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: AppDimens.spaceXs,
        ),
        iconColor: isLight
            ? AppColors.textSecondaryLight
            : AppColors.textSecondaryDark,
        titleTextStyle: AppTextStyles.bodyLarge.copyWith(
          color:
              isLight ? AppColors.textPrimaryLight : AppColors.textPrimaryDark,
        ),
        subtitleTextStyle: AppTextStyles.bodySmall.copyWith(
          color: isLight
              ? AppColors.textSecondaryLight
              : AppColors.textSecondaryDark,
        ),
      ),
      iconTheme: IconThemeData(
        color:
            isLight ? AppColors.textPrimaryLight : AppColors.textPrimaryDark,
        size: AppDimens.iconMd,
      ),
      // Tooltip styling — used by OnboardingTooltip and system tooltips.
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isLight ? AppColors.surfaceLight : AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(AppDimens.shapeXs),
        ),
        textStyle: AppTextStyles.bodySmall.copyWith(
          color: isLight ? AppColors.textPrimaryLight : AppColors.textPrimaryDark,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  // ── Text Theme ────────────────────────────────────────────────────────────

  /// Maps [AppTextStyles] to Material [TextTheme] slots.
  ///
  /// [defaultColor] is the primary text color for the current brightness.
  /// [isLight] selects the correct secondary color token for WCAG AA contrast.
  static TextTheme _buildTextTheme(Color defaultColor, bool isLight) {
    final secondaryColor =
        isLight ? AppColors.textSecondaryLight : AppColors.textSecondaryDark;
    return TextTheme(
      displayLarge: AppTextStyles.displayLarge.copyWith(color: defaultColor),
      displayMedium: AppTextStyles.displayMedium.copyWith(color: defaultColor),
      displaySmall: AppTextStyles.displaySmall.copyWith(color: defaultColor),
      headlineLarge: AppTextStyles.displayLarge.copyWith(color: defaultColor),
      headlineMedium: AppTextStyles.displayMedium.copyWith(color: defaultColor),
      headlineSmall: AppTextStyles.displaySmall.copyWith(color: defaultColor),
      titleLarge: AppTextStyles.titleLarge.copyWith(color: defaultColor),
      titleMedium: AppTextStyles.titleMedium.copyWith(color: defaultColor),
      titleSmall: AppTextStyles.labelLarge.copyWith(color: defaultColor),
      bodyLarge: AppTextStyles.bodyLarge.copyWith(color: defaultColor),
      bodyMedium: AppTextStyles.bodyMedium.copyWith(color: defaultColor),
      bodySmall: AppTextStyles.bodySmall.copyWith(color: secondaryColor),
      labelLarge: AppTextStyles.labelLarge.copyWith(color: defaultColor),
      labelMedium: AppTextStyles.labelMedium.copyWith(color: defaultColor),
      labelSmall: AppTextStyles.labelSmall.copyWith(color: secondaryColor),
    );
  }
}
