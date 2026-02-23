/// Zuralog Design System — Visual Component Catalog.
///
/// A "Storybook-lite" developer screen that displays all design system
/// tokens (colors, typography, spacing) and reusable components side-by-side.
///
/// This is a developer tool — NOT a production screen.
/// It is accessed from [HarnessScreen] for QA verification.
/// Required by Phase 2.1 exit criteria.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/core/theme/theme_provider.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

/// Visual catalog for all design system tokens and reusable components.
///
/// Allows QA to toggle between System, Light, and Dark modes to verify
/// that all tokens and components correctly adapt to each theme.
class CatalogScreen extends ConsumerWidget {
  /// Creates the [CatalogScreen].
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Design Catalog'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.spaceMd,
              0,
              AppDimens.spaceMd,
              AppDimens.spaceSm,
            ),
            child: _ThemeToggle(themeMode: themeMode),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        children: const [
          _ColorPaletteSection(),
          SizedBox(height: AppDimens.spaceLg),
          _TypographySection(),
          SizedBox(height: AppDimens.spaceLg),
          _ButtonSection(),
          SizedBox(height: AppDimens.spaceLg),
          _CardSection(),
          SizedBox(height: AppDimens.spaceLg),
          _InputSection(),
          SizedBox(height: AppDimens.spaceLg),
          _LayoutSection(),
          SizedBox(height: AppDimens.spaceLg),
          _IndicatorSection(),
          SizedBox(height: AppDimens.spaceXxl),
        ],
      ),
    );
  }
}

// ── Theme Toggle ─────────────────────────────────────────────────────────────

/// Segmented button for switching theme mode from within the catalog.
class _ThemeToggle extends ConsumerWidget {
  final ThemeMode themeMode;

  const _ThemeToggle({required this.themeMode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SegmentedButton<ThemeMode>(
      segments: const [
        ButtonSegment(
          value: ThemeMode.system,
          label: Text('System'),
          icon: Icon(Icons.brightness_auto),
        ),
        ButtonSegment(
          value: ThemeMode.light,
          label: Text('Light'),
          icon: Icon(Icons.light_mode),
        ),
        ButtonSegment(
          value: ThemeMode.dark,
          label: Text('Dark'),
          icon: Icon(Icons.dark_mode),
        ),
      ],
      selected: {themeMode},
      onSelectionChanged: (Set<ThemeMode> selected) {
        ref.read(themeModeProvider.notifier).state = selected.first;
      },
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: AppColors.primary,
        selectedForegroundColor: AppColors.primaryButtonText,
      ),
    );
  }
}

// ── Section Shell ─────────────────────────────────────────────────────────────

/// Wrapper card for each catalog section with a consistent title.
class _CatalogSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _CatalogSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title),
        const SizedBox(height: AppDimens.spaceSm),
        child,
      ],
    );
  }
}

// ── Color Palette ─────────────────────────────────────────────────────────────

class _ColorPaletteSection extends StatelessWidget {
  const _ColorPaletteSection();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final swatches = [
      _Swatch('Primary\n#CFE1B9', AppColors.primary, Colors.black),
      _Swatch(
        'Secondary\n${isDark ? "#7DA4C7" : "#5B7C99"}',
        isDark ? AppColors.secondaryDark : AppColors.secondaryLight,
        Colors.white,
      ),
      _Swatch(
        'Accent\n${isDark ? "#FF8E72" : "#E07A5F"}',
        isDark ? AppColors.accentDark : AppColors.accentLight,
        Colors.white,
      ),
      _Swatch(
        'Background\n${isDark ? "#000000" : "#FAFAFA"}',
        isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
        isDark ? Colors.white : Colors.black,
      ),
      _Swatch(
        'Surface\n${isDark ? "#1C1C1E" : "#FFFFFF"}',
        isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        isDark ? Colors.white : Colors.black,
      ),
      _Swatch(
        'Text Primary\n${isDark ? "#F2F2F7" : "#1C1C1E"}',
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
        isDark ? Colors.black : Colors.white,
      ),
      _Swatch('Text Secondary\n#8E8E93', AppColors.textSecondary, Colors.white),
      _Swatch(
        'Border\n${isDark ? "#38383A" : "#E5E5EA"}',
        isDark ? AppColors.borderDark : AppColors.borderLight,
        isDark ? Colors.white : Colors.black,
      ),
    ];

    return _CatalogSection(
      title: 'Color Palette',
      child: Wrap(
        spacing: AppDimens.spaceSm,
        runSpacing: AppDimens.spaceSm,
        children: swatches,
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;

  const _Swatch(this.label, this.color, this.textColor);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 80,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        border: Border.all(color: AppColors.borderLight.withValues(alpha: 0.3)),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(AppDimens.spaceXs),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: textColor,
          height: 1.4,
        ),
      ),
    );
  }
}

// ── Typography ────────────────────────────────────────────────────────────────

class _TypographySection extends StatelessWidget {
  const _TypographySection();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;

    return _CatalogSection(
      title: 'Typography',
      child: ZuralogCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('H1 — Large Title 34pt Bold',
                style: AppTextStyles.h1.copyWith(color: color)),
            const SizedBox(height: AppDimens.spaceSm),
            Text('H2 — Title 2 22pt SemiBold',
                style: AppTextStyles.h2.copyWith(color: color)),
            const SizedBox(height: AppDimens.spaceSm),
            Text('H3 — Headline 17pt SemiBold',
                style: AppTextStyles.h3.copyWith(color: color)),
            const SizedBox(height: AppDimens.spaceSm),
            Text('Body — 17pt Regular body text',
                style: AppTextStyles.body.copyWith(color: color)),
            const SizedBox(height: AppDimens.spaceSm),
            Text('Caption — 12pt Medium label text',
                style: AppTextStyles.caption.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}

// ── Buttons ───────────────────────────────────────────────────────────────────

class _ButtonSection extends StatelessWidget {
  const _ButtonSection();

  @override
  Widget build(BuildContext context) {
    return _CatalogSection(
      title: 'Buttons',
      child: ZuralogCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PrimaryButton(
              label: 'Primary Button',
              onPressed: null,
            ),
            const SizedBox(height: AppDimens.spaceSm),
            const PrimaryButton(
              label: 'Loading State',
              isLoading: true,
              onPressed: null,
            ),
            const SizedBox(height: AppDimens.spaceSm),
            const SecondaryButton(
              label: 'Secondary Button',
              onPressed: null,
            ),
            const SizedBox(height: AppDimens.spaceSm),
            const SecondaryButton(
              label: 'Continue with Apple',
              icon: Icons.apple,
              onPressed: null,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Cards ─────────────────────────────────────────────────────────────────────

class _CardSection extends StatelessWidget {
  const _CardSection();

  @override
  Widget build(BuildContext context) {
    return _CatalogSection(
      title: 'Cards',
      child: Column(
        children: [
          ZuralogCard(
            child: Row(
              children: [
                const Icon(Icons.bedtime_rounded, size: 32),
                const SizedBox(width: AppDimens.spaceMd),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('7h 42m',
                        style: AppTextStyles.h2.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        )),
                    Text(
                      'Sleep Score: 85',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          ZuralogCard(
            onTap: () {},
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tappable Card (with ripple)',
                  style: AppTextStyles.body.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Inputs ────────────────────────────────────────────────────────────────────

class _InputSection extends StatelessWidget {
  const _InputSection();

  @override
  Widget build(BuildContext context) {
    return _CatalogSection(
      title: 'Inputs',
      child: ZuralogCard(
        child: Column(
          children: [
            const AppTextField(
              hintText: 'Email address',
              prefixIcon: Icon(Icons.mail_outline),
            ),
            const SizedBox(height: AppDimens.spaceSm),
            const AppTextField(
              hintText: 'Password',
              obscureText: true,
              prefixIcon: Icon(Icons.lock_outline),
            ),
            const SizedBox(height: AppDimens.spaceSm),
            AppTextField(
              hintText: 'With validation',
              validator: (v) =>
                  (v?.isEmpty ?? true) ? 'This field is required' : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Layout ────────────────────────────────────────────────────────────────────

class _LayoutSection extends StatelessWidget {
  const _LayoutSection();

  @override
  Widget build(BuildContext context) {
    return _CatalogSection(
      title: 'Layout',
      child: ZuralogCard(
        child: Column(
          children: [
            const SectionHeader(title: 'Section Header Only'),
            const SizedBox(height: AppDimens.spaceSm),
            const Divider(),
            const SizedBox(height: AppDimens.spaceSm),
            SectionHeader(
              title: 'With Action',
              actionLabel: 'See All',
              onAction: () {},
            ),
          ],
        ),
      ),
    );
  }
}

// ── Indicators ────────────────────────────────────────────────────────────────

class _IndicatorSection extends StatelessWidget {
  const _IndicatorSection();

  @override
  Widget build(BuildContext context) {
    return _CatalogSection(
      title: 'Indicators',
      child: ZuralogCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const StatusIndicator(
              color: AppColors.primary,
              label: 'Online (Sage Green)',
              pulsing: true,
            ),
            const SizedBox(height: AppDimens.spaceSm),
            StatusIndicator(
              color: Theme.of(context).colorScheme.tertiary,
              label: 'Warning (Soft Coral)',
            ),
            const SizedBox(height: AppDimens.spaceSm),
            const StatusIndicator(
              color: AppColors.textSecondary,
              label: 'Not connected',
            ),
            const SizedBox(height: AppDimens.spaceSm),
            StatusIndicator(
              color: Theme.of(context).colorScheme.secondary,
              label: 'Synced 2m ago (Muted Slate)',
            ),
          ],
        ),
      ),
    );
  }
}
