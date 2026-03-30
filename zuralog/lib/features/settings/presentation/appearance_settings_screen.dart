/// Appearance Settings Screen.
///
/// Theme selector, haptic feedback toggle, and tooltip controls.
///
/// ## Fixes applied (settings-mapping remediation)
/// - Theme selector now reads/writes [themeModeProvider] (AsyncNotifier) —
///   changes persist across cold starts via SharedPreferences + API.
/// - Haptic toggle now reads [hapticEnabledProvider] and writes via
///   [HapticEnabledNotifier.setEnabled] — previously used a disconnected
///   local [StateProvider].
/// - Tooltip toggle now reads [tooltipsEnabledProvider] and writes via
///   [TooltipsEnabledNotifier.setEnabled] — previously the local
///   `_tooltipsDisabledProvider` did nothing.
/// - Dashboard color section removed — it used a disconnected local
///   [StateProvider]. Category color overrides are managed canonically
///   in the Data tab edit mode via [DashboardLayout].
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/analytics/analytics_events.dart';
import 'package:zuralog/core/analytics/analytics_service.dart';
import 'package:zuralog/core/haptics/haptic_providers.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/core/theme/theme_provider.dart';
import 'package:zuralog/features/settings/presentation/widgets/settings_section_label.dart';
import 'package:zuralog/shared/widgets/widgets.dart';
import 'package:zuralog/shared/widgets/onboarding_tooltip_provider.dart';

// ── AppearanceSettingsScreen ───────────────────────────────────────────────────

/// Appearance preferences: theme, haptics, tooltips.
class AppearanceSettingsScreen extends ConsumerWidget {
  /// Creates the [AppearanceSettingsScreen].
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Theme — async provider; fall back to system while loading.
    final themeMode =
        ref.watch(themeModeProvider).valueOrNull ?? ThemeMode.system;

    // Haptic — async provider; fall back to enabled while loading.
    final hapticEnabled =
        ref.watch(hapticEnabledProvider).valueOrNull ?? true;

    // Tooltips — async provider; fall back to enabled while loading.
    final tooltipsEnabled =
        ref.watch(tooltipsEnabledProvider).valueOrNull ?? true;

    return ZuralogScaffold(
      appBar: ZuralogAppBar(title: 'Appearance', showProfileAvatar: false),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppDimens.spaceXxl),
        children: [
          // ── THEME section ─────────────────────────────────────────────
          const SettingsSectionLabel('THEME'),
          _ThemeSelector(
            selected: themeMode,
            onSelected: (v) {
              ref.read(themeModeProvider.notifier).setTheme(v);
              ref.read(analyticsServiceProvider).capture(
                event: AnalyticsEvents.themeChanged,
                properties: {'theme': v.name},
              );
            },
          ),

          // ── EXPERIENCE section ────────────────────────────────────────
          const SettingsSectionLabel('EXPERIENCE'),
          _SettingsCard(
            children: [
              _ToggleRow(
                icon: Icons.vibration_rounded,
                iconColor: AppColors.categoryActivity,
                title: 'Haptic Feedback',
                subtitle: 'Vibration on interactions',
                value: hapticEnabled,
                onChanged: (v) {
                  ref.read(hapticEnabledProvider.notifier).setEnabled(v);
                  ref.read(analyticsServiceProvider).capture(
                    event: AnalyticsEvents.hapticToggled,
                    properties: {'enabled': v},
                  );
                },
              ),
            ],
          ),

          // ── TOOLTIPS section ──────────────────────────────────────────
          const SettingsSectionLabel('TOOLTIPS'),
          _SettingsCard(
            children: [
              _ToggleRow(
                icon: Icons.help_outline_rounded,
                iconColor: AppColors.categoryVitals,
                title: 'Disable Tooltips',
                subtitle: 'Hide contextual help overlays',
                // The toggle shows "Disable Tooltips", so its value is
                // the inverse of tooltipsEnabled.
                value: !tooltipsEnabled,
                onChanged: (v) => ref
                    .read(tooltipsEnabledProvider.notifier)
                    .setEnabled(!v),
              ),
              const ZDivider(indent: 68),
              ZSettingsTile(
                icon: Icons.refresh_rounded,
                iconColor: AppColors.categoryWellness,
                title: 'Reset Onboarding Tooltips',
                subtitle: 'Show all tooltips again from scratch',
                onTap: () {
                  ref.read(tooltipSeenProvider.notifier).reset();
                  _showResetTooltipsSnackBar(context);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── _SettingsCard ──────────────────────────────────────────────────────────────

/// A card container for mixed groups (toggles + tiles) that cannot use
/// [ZSettingsGroup] (which only accepts [ZSettingsTile] instances).
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        ),
        child: Column(children: children),
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
    final colors = AppColorsOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: 12,
      ),
      child: Row(
        children: [
          ZIconBadge(icon: icon, color: iconColor),
          const SizedBox(width: AppDimens.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyLarge.copyWith(color: colors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
          ZToggle(value: value, onChanged: onChanged),
        ],
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

  final ThemeMode selected;
  final ValueChanged<ThemeMode> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      child: Row(
        children: [
          _ThemeOptionCard(
            value: ThemeMode.dark,
            label: 'Dark',
            icon: Icons.dark_mode_rounded,
            selected: selected == ThemeMode.dark,
            onTap: () => onSelected(ThemeMode.dark),
          ),
          const SizedBox(width: AppDimens.spaceSm),
          _ThemeOptionCard(
            value: ThemeMode.light,
            label: 'Light',
            icon: Icons.light_mode_rounded,
            selected: selected == ThemeMode.light,
            onTap: () => onSelected(ThemeMode.light),
          ),
          const SizedBox(width: AppDimens.spaceSm),
          _ThemeOptionCard(
            value: ThemeMode.system,
            label: 'System',
            icon: Icons.contrast_rounded,
            selected: selected == ThemeMode.system,
            onTap: () => onSelected(ThemeMode.system),
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

  final ThemeMode value;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
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
                ? colors.primary.withValues(alpha: 0.12)
                : colors.surface,
            borderRadius: BorderRadius.circular(AppDimens.radiusCard),
            border: Border.all(
              color: selected
                  ? colors.primary.withValues(alpha: 0.55)
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
                  color: selected ? colors.primary : colors.textTertiary,
                ),
              ),
              const SizedBox(height: AppDimens.spaceXs),
              Text(
                label,
                style: AppTextStyles.bodySmall.copyWith(
                  color: selected ? colors.primary : colors.textSecondary,
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

// ── Helpers ────────────────────────────────────────────────────────────────────

void _showResetTooltipsSnackBar(BuildContext context) {
  final colors = AppColorsOf(context);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        'All onboarding tooltips have been reset.',
        style: AppTextStyles.bodyMedium.copyWith(color: colors.textPrimary),
      ),
      backgroundColor: colors.surface,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
      ),
      duration: const Duration(seconds: 3),
    ),
  );
}
