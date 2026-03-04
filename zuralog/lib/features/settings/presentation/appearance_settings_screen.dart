/// Appearance Settings Screen.
///
/// Theme selector, haptic feedback toggle, tooltip controls, and
/// per-category dashboard color customization.
/// Full implementation: Phase 8, Task 8.4.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/settings/presentation/widgets/settings_section_label.dart';

// ── Local providers ────────────────────────────────────────────────────────────

/// Selected theme mode. Values: `'dark'`, `'light'`, `'system'`.
final _themeModeProvider = StateProvider<String>((_) => 'dark');

/// Haptic feedback enabled flag.
final _hapticFeedbackProvider = StateProvider<bool>((_) => true);

/// Tooltips disabled flag.
final _tooltipsDisabledProvider = StateProvider<bool>((_) => false);

/// Per-category selected accent colors.
final _categoryColorsProvider = StateProvider<Map<String, Color>>((_) => {
      'Activity': AppColors.categoryActivity,
      'Sleep': AppColors.categorySleep,
      'Heart': AppColors.categoryHeart,
      'Nutrition': AppColors.categoryNutrition,
      'Wellness': AppColors.categoryWellness,
    });

// ── Constants ──────────────────────────────────────────────────────────────────

/// Available color palette for dashboard category accent customization.
const _kColorPalette = <Color>[
  AppColors.categoryActivity,
  AppColors.categorySleep,
  AppColors.categoryHeart,
  AppColors.categoryNutrition,
  AppColors.categoryWellness,
  AppColors.categoryBody,
  AppColors.categoryVitals,
  AppColors.categoryMobility,
  AppColors.primary,
];

/// The 5 health categories shown in the Dashboard Colors section.
const _kCategories = <(String, IconData)>[
  ('Activity', Icons.directions_run_rounded),
  ('Sleep', Icons.bedtime_rounded),
  ('Heart', Icons.favorite_rounded),
  ('Nutrition', Icons.restaurant_rounded),
  ('Wellness', Icons.self_improvement_rounded),
];

// ── AppearanceSettingsScreen ───────────────────────────────────────────────────

/// Appearance preferences: theme, haptics, tooltips, dashboard colors.
class AppearanceSettingsScreen extends ConsumerWidget {
  /// Creates the [AppearanceSettingsScreen].
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(_themeModeProvider);
    final haptic = ref.watch(_hapticFeedbackProvider);
    final tooltipsDisabled = ref.watch(_tooltipsDisabledProvider);
    final categoryColors = ref.watch(_categoryColorsProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: CustomScrollView(
        slivers: [
          // ── Large-title app bar ───────────────────────────────────────────
          SliverAppBar(
            backgroundColor: AppColors.backgroundDark,
            expandedHeight: 100,
            pinned: true,
            elevation: 0,
            scrolledUnderElevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(
                left: AppDimens.spaceMd,
                bottom: 14,
              ),
              collapseMode: CollapseMode.parallax,
              title: Text(
                'Appearance',
                style:
                    AppTextStyles.h2.copyWith(color: AppColors.textPrimaryDark),
              ),
            ),
          ),

          SliverList(
            delegate: SliverChildListDelegate([
              // ── THEME section ─────────────────────────────────────────────
              const SettingsSectionLabel('THEME'),
              _ThemeSelector(
                selected: theme,
                onSelected: (v) =>
                    ref.read(_themeModeProvider.notifier).state = v,
              ),

              // ── EXPERIENCE section ────────────────────────────────────────
              const SettingsSectionLabel('EXPERIENCE'),
              _SettingsGroup(
                children: [
                  _ToggleRow(
                    icon: Icons.vibration_rounded,
                    iconColor: AppColors.categoryActivity,
                    title: 'Haptic Feedback',
                    subtitle: 'Vibration on interactions',
                    value: haptic,
                    onChanged: (v) =>
                        ref.read(_hapticFeedbackProvider.notifier).state = v,
                  ),
                ],
              ),

              // ── TOOLTIPS section ──────────────────────────────────────────
              const SettingsSectionLabel('TOOLTIPS'),
              _SettingsGroup(
                children: [
                  _ToggleRow(
                    icon: Icons.help_outline_rounded,
                    iconColor: AppColors.categoryVitals,
                    title: 'Disable Tooltips',
                    subtitle: 'Hide contextual help overlays',
                    value: tooltipsDisabled,
                    onChanged: (v) =>
                        ref.read(_tooltipsDisabledProvider.notifier).state = v,
                  ),
                  _Divider(),
                  _TapRow(
                    icon: Icons.refresh_rounded,
                    iconColor: AppColors.categoryWellness,
                    title: 'Reset Onboarding Tooltips',
                    subtitle: 'Show all tooltips again from scratch',
                    onTap: () => _showResetTooltipsSnackBar(context),
                  ),
                ],
              ),

              // ── DASHBOARD COLORS section ──────────────────────────────────
              const SettingsSectionLabel('DASHBOARD COLORS'),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceMd,
                ),
                child: Text(
                  'Customize accent colors for each health category',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: AppDimens.spaceMd),
              _CategoryColorGrid(
                categoryColors: categoryColors,
                onColorSelected: (category, color) {
                  ref.read(_categoryColorsProvider.notifier).state = {
                    ...categoryColors,
                    category: color,
                  };
                },
              ),

              const SizedBox(height: AppDimens.spaceXxl),
            ]),
          ),
        ],
      ),
    );
  }
}

// ── _SettingsGroup ─────────────────────────────────────────────────────────────

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackgroundDark,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        ),
        child: Column(children: children),
      ),
    );
  }
}

// ── _Divider ───────────────────────────────────────────────────────────────────

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 68),
      child: Container(
        height: 1,
        color: AppColors.borderDark.withValues(alpha: 0.5),
      ),
    );
  }
}

// ── _ToggleRow ─────────────────────────────────────────────────────────────────

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: 12,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppDimens.radiusSm),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: AppDimens.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                      AppTextStyles.body.copyWith(color: AppColors.textPrimaryDark),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
            inactiveThumbColor: AppColors.textTertiary,
            inactiveTrackColor: AppColors.borderDark,
          ),
        ],
      ),
    );
  }
}

// ── _TapRow ────────────────────────────────────────────────────────────────────

class _TapRow extends StatefulWidget {
  const _TapRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  State<_TapRow> createState() => _TapRowState();
}

class _TapRowState extends State<_TapRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        color: _pressed
            ? AppColors.borderDark.withValues(alpha: 0.3)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: 14,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: widget.iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
              ),
              child: Icon(widget.icon, size: 20, color: widget.iconColor),
            ),
            const SizedBox(width: AppDimens.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: AppTextStyles.body
                        .copyWith(color: AppColors.textPrimaryDark),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.subtitle,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: AppDimens.iconMd,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

// ── _ThemeSelector ─────────────────────────────────────────────────────────────

class _ThemeSelector extends StatelessWidget {
  const _ThemeSelector({
    required this.selected,
    required this.onSelected,
  });

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      child: Row(
        children: [
          _ThemeOptionCard(
            value: 'dark',
            label: 'Dark',
            icon: Icons.dark_mode_rounded,
            selected: selected == 'dark',
            onTap: () => onSelected('dark'),
          ),
          const SizedBox(width: AppDimens.spaceSm),
          _ThemeOptionCard(
            value: 'light',
            label: 'Light',
            icon: Icons.light_mode_rounded,
            selected: selected == 'light',
            onTap: () => onSelected('light'),
          ),
          const SizedBox(width: AppDimens.spaceSm),
          _ThemeOptionCard(
            value: 'system',
            label: 'System',
            icon: Icons.contrast_rounded,
            selected: selected == 'system',
            onTap: () => onSelected('system'),
          ),
        ],
      ),
    );
  }
}

class _ThemeOptionCard extends StatelessWidget {
  const _ThemeOptionCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String value;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(
            vertical: AppDimens.spaceMd,
            horizontal: AppDimens.spaceSm,
          ),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.12)
                : AppColors.cardBackgroundDark,
            borderRadius: BorderRadius.circular(AppDimens.radiusCard),
            border: Border.all(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.55)
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  icon,
                  key: ValueKey<bool>(selected),
                  size: 26,
                  color: selected ? AppColors.primary : AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: AppDimens.spaceXs),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color:
                      selected ? AppColors.primary : AppColors.textSecondary,
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── _CategoryColorGrid ─────────────────────────────────────────────────────────

class _CategoryColorGrid extends StatelessWidget {
  const _CategoryColorGrid({
    required this.categoryColors,
    required this.onColorSelected,
  });

  final Map<String, Color> categoryColors;
  final void Function(String category, Color color) onColorSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackgroundDark,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        ),
        child: Column(
          children: [
            for (int i = 0; i < _kCategories.length; i++) ...[
              _CategoryColorRow(
                category: _kCategories[i].$1,
                icon: _kCategories[i].$2,
                selectedColor: categoryColors[_kCategories[i].$1] ??
                    AppColors.primary,
                onColorSelected: (color) =>
                    onColorSelected(_kCategories[i].$1, color),
              ),
              if (i < _kCategories.length - 1)
                Padding(
                  padding: const EdgeInsets.only(left: 68),
                  child: Container(
                    height: 1,
                    color: AppColors.borderDark.withValues(alpha: 0.5),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CategoryColorRow extends StatelessWidget {
  const _CategoryColorRow({
    required this.category,
    required this.icon,
    required this.selectedColor,
    required this.onColorSelected,
  });

  final String category;
  final IconData icon;
  final Color selectedColor;
  final ValueChanged<Color> onColorSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceMd,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: selectedColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppDimens.radiusSm),
            ),
            child: Icon(icon, size: 20, color: selectedColor),
          ),
          const SizedBox(width: AppDimens.spaceSm),
          SizedBox(
            width: 72,
            child: Text(
              category,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textPrimaryDark),
            ),
          ),
          const SizedBox(width: AppDimens.spaceXs),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final color in _kColorPalette) ...[
                    _ColorSwatch(
                      color: color,
                      isSelected: selectedColor == color,
                      onTap: () => onColorSelected(color),
                    ),
                    const SizedBox(width: AppDimens.spaceXs),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected
                ? AppColors.textPrimaryDark
                : Colors.transparent,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.45),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: isSelected
            ? Icon(
                Icons.check_rounded,
                size: 14,
                color: _contrastColor(color),
              )
            : null,
      ),
    );
  }

  /// Returns black or white for the checkmark, depending on swatch luminance.
  Color _contrastColor(Color c) {
    final luminance = c.computeLuminance();
    return luminance > 0.35 ? AppColors.backgroundDark : AppColors.textPrimaryDark;
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────────

void _showResetTooltipsSnackBar(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        'All onboarding tooltips have been reset.',
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textPrimaryDark,
        ),
      ),
      backgroundColor: AppColors.surfaceDark,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
      ),
      duration: const Duration(seconds: 3),
    ),
  );
}
