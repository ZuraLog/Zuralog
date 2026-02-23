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
/// - Light: white surfaces, soft diffusion shadows, dark text.
/// - Dark: OLED black background, bordered surfaces, no shadows, light text.
abstract final class AppTheme {
  // ── Public API ────────────────────────────────────────────────────────────

  /// Light theme — white surfaces, soft shadows, dark text on light backgrounds.
  static ThemeData get light => _build(Brightness.light);

  /// Dark theme — OLED black, bordered card surfaces, no shadows, light text.
  static ThemeData get dark => _build(Brightness.dark);

  // ── Private Builder ───────────────────────────────────────────────────────

  /// Builds the complete [ThemeData] for the given [brightness].
  ///
  /// [brightness] determines color scheme, surface styling, and overlay style.
  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;

    final colorScheme = isLight
        ? ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: AppColors.primaryButtonText,
            secondary: AppColors.secondaryLight,
            onSecondary: Colors.white,
            tertiary: AppColors.accentLight,
            onTertiary: Colors.white,
            surface: AppColors.surfaceLight,
            onSurface: AppColors.textPrimaryLight,
            onSurfaceVariant: AppColors.textSecondary,
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
            onSurfaceVariant: AppColors.textSecondary,
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
      fontFamily: AppTextStyles.body.fontFamily,
      textTheme: _buildTextTheme(
        isLight ? AppColors.textPrimaryLight : AppColors.textPrimaryDark,
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
        titleTextStyle: AppTextStyles.h2.copyWith(
          color: isLight ? AppColors.textPrimaryLight : AppColors.textPrimaryDark,
        ),
      ),
      cardTheme: CardThemeData(
        color: isLight ? AppColors.surfaceLight : AppColors.surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          side: isLight
              ? BorderSide.none
              : BorderSide(color: AppColors.borderDark),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.primaryButtonText,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
          disabledForegroundColor:
              AppColors.primaryButtonText.withValues(alpha: 0.5),
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize:
              const Size(double.infinity, AppDimens.touchTargetMin),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusButton),
          ),
          textStyle: AppTextStyles.h3,
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
          foregroundColor: AppColors.primary,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spaceSm,
            vertical: AppDimens.spaceXs,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusButton),
          ),
          textStyle: AppTextStyles.body.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor:
              isLight ? AppColors.textPrimaryLight : AppColors.textPrimaryDark,
          side: BorderSide(
            color: isLight ? AppColors.borderLight : AppColors.borderDark,
          ),
          minimumSize:
              const Size(double.infinity, AppDimens.touchTargetMin),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusButton),
          ),
          textStyle: AppTextStyles.h3,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor:
            isLight ? AppColors.surfaceLight : AppColors.surfaceDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusInput),
          borderSide: BorderSide(
            color: isLight ? AppColors.borderLight : AppColors.borderDark,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusInput),
          borderSide: BorderSide(
            color: isLight ? AppColors.borderLight : AppColors.borderDark,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusInput),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusInput),
          borderSide: BorderSide(
            color: isLight ? AppColors.accentLight : AppColors.accentDark,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusInput),
          borderSide: BorderSide(
            color: isLight ? AppColors.accentLight : AppColors.accentDark,
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: AppDimens.spaceMd,
        ),
        hintStyle: AppTextStyles.body
            .copyWith(color: AppColors.textSecondary),
        labelStyle: AppTextStyles.body.copyWith(
          color: isLight ? AppColors.textPrimaryLight : AppColors.textPrimaryDark,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: isLight ? AppColors.borderLight : AppColors.borderDark,
        thickness: 0.5,
        space: 0,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor:
            isLight ? AppColors.surfaceLight : AppColors.surfaceDark,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: AppTextStyles.caption,
        unselectedLabelStyle: AppTextStyles.caption,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor:
            isLight ? AppColors.surfaceLight : AppColors.surfaceDark,
        indicatorColor: AppColors.primary.withValues(alpha: 0.2),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primary);
          }
          return const IconThemeData(color: AppColors.textSecondary);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppTextStyles.caption
                .copyWith(color: AppColors.primary);
          }
          return AppTextStyles.caption
              .copyWith(color: AppColors.textSecondary);
        }),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return isLight ? AppColors.surfaceLight : AppColors.surfaceDark;
          }
          return AppColors.textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return isLight ? AppColors.borderLight : AppColors.borderDark;
        }),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: AppDimens.spaceXs,
        ),
        iconColor: AppColors.textSecondary,
        titleTextStyle: AppTextStyles.body.copyWith(
          color: isLight ? AppColors.textPrimaryLight : AppColors.textPrimaryDark,
        ),
        subtitleTextStyle:
            AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
      ),
      iconTheme: IconThemeData(
        color: isLight ? AppColors.textPrimaryLight : AppColors.textPrimaryDark,
        size: AppDimens.iconMd,
      ),
    );
  }

  // ── Text Theme ────────────────────────────────────────────────────────────

  /// Maps [AppTextStyles] to Material [TextTheme] slots.
  ///
  /// [defaultColor] is the primary text color for the current brightness.
  static TextTheme _buildTextTheme(Color defaultColor) {
    return TextTheme(
      // Largest display text — not used in Zuralog but required for completeness.
      displayLarge: AppTextStyles.h1.copyWith(color: defaultColor),
      displayMedium: AppTextStyles.h1.copyWith(color: defaultColor),
      displaySmall: AppTextStyles.h1.copyWith(color: defaultColor),
      // Headings
      headlineLarge: AppTextStyles.h1.copyWith(color: defaultColor),
      headlineMedium: AppTextStyles.h2.copyWith(color: defaultColor),
      headlineSmall: AppTextStyles.h3.copyWith(color: defaultColor),
      // Titles (used by AppBar, ListTile, etc.)
      titleLarge: AppTextStyles.h2.copyWith(color: defaultColor),
      titleMedium: AppTextStyles.h3.copyWith(color: defaultColor),
      titleSmall: AppTextStyles.h3.copyWith(color: defaultColor),
      // Body text
      bodyLarge: AppTextStyles.body.copyWith(color: defaultColor),
      bodyMedium: AppTextStyles.body.copyWith(color: defaultColor),
      bodySmall: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
      // Labels (used by buttons, chips, badges)
      labelLarge: AppTextStyles.h3.copyWith(color: defaultColor),
      labelMedium: AppTextStyles.caption.copyWith(color: defaultColor),
      labelSmall: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
    );
  }
}
