/// Privacy & Data Screen.
///
/// AI memory management, analytics opt-out, data export/deletion,
/// wellness check-in toggle, legal links.
///
/// ## Fixes applied (settings-mapping remediation)
/// Previously, the three privacy toggles (Wellness Check-in card visibility,
/// Data Maturity Banner visibility, Analytics opt-out) were held in an
/// in-memory [_PrivacyState] that reset on every cold start.
///
/// They now read from and write to [userPreferencesProvider] via the
/// [wellnessCheckinCardVisibleProvider], [dataMaturityBannerDismissedProvider],
/// and [analyticsOptOutProvider] derived providers.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/core/analytics/analytics_events.dart';
import 'package:zuralog/core/analytics/analytics_service.dart';
import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/settings/presentation/widgets/settings_section_label.dart';
import 'package:zuralog/features/settings/providers/settings_providers.dart';

// ── Local providers ────────────────────────────────────────────────────────────

/// Mock AI memory items — persisted locally for the session.
final _memoryItemsProvider = StateProvider<List<String>>(
  (_) => const [
    'User prefers morning workouts',
    'Responds well to streak motivation',
    'Sleep is a priority goal',
    'Often skips breakfast',
    'Dislikes long cardio sessions',
    'Recovers best with 8+ hours of sleep',
  ],
);

// ── PrivacyDataScreen ──────────────────────────────────────────────────────────

/// Privacy & Data screen — AI memory, privacy toggles, data management, legal.
class PrivacyDataScreen extends ConsumerWidget {
  /// Creates the [PrivacyDataScreen].
  const PrivacyDataScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Global persisted privacy preferences.
    final wellnessCheckin = ref.watch(wellnessCheckinCardVisibleProvider);
    final dataMaturityBanner =
        !ref.watch(dataMaturityBannerDismissedProvider);
    final analyticsEnabled = !ref.watch(analyticsOptOutProvider);

    final prefsNotifier = ref.read(userPreferencesProvider.notifier);
    final memoryItems = ref.watch(_memoryItemsProvider);
    final memoryNotifier = ref.read(_memoryItemsProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: CustomScrollView(
        slivers: [
          // ── Large-title header ───────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 100,
            pinned: true,
            backgroundColor: AppColors.backgroundDark,
            scrolledUnderElevation: 0,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              titlePadding: const EdgeInsets.only(
                left: AppDimens.spaceMd,
                bottom: AppDimens.spaceMd,
              ),
              title: Text(
                'Privacy & Data',
                style: AppTextStyles.h2.copyWith(
                  color: AppColors.textPrimaryDark,
                ),
              ),
            ),
          ),

          SliverList(
            delegate: SliverChildListDelegate([
              // ── AI MEMORY section ──────────────────────────────────────
              const SettingsSectionLabel('AI Memory'),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceMd,
                ),
                child: Text(
                  'Stored context your AI coach uses to personalize insights',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: AppDimens.spaceSm),

              // Memory items list
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceMd,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.cardBackgroundDark,
                    borderRadius: BorderRadius.circular(AppDimens.radiusCard),
                  ),
                  child: Column(
                    children: [
                      if (memoryItems.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDimens.spaceMd,
                            vertical: AppDimens.spaceLg,
                          ),
                          child: Text(
                            'No memory stored',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                        )
                      else
                        ...List.generate(memoryItems.length, (index) {
                          final item = memoryItems[index];
                          final isLast = index == memoryItems.length - 1;
                          return Column(
                            children: [
                               _MemoryItemRow(
                                text: item,
                                onDelete: () {
                                  final updated = List<String>.from(
                                    memoryItems,
                                  )..removeAt(index);
                                  memoryNotifier.state = updated;
                                  ref.read(analyticsServiceProvider).capture(
                                    event: AnalyticsEvents.memoryDeleted,
                                  );
                                },
                              ),
                              if (!isLast) const _Divider(),
                            ],
                          );
                        }),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppDimens.spaceSm),

              // Clear All Memory row
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceMd,
                ),
                child: _ClearMemoryRow(
                  enabled: memoryItems.isNotEmpty,
                  onConfirmed: () {
                    memoryNotifier.state = [];
                    ref.read(analyticsServiceProvider).capture(
                      event: AnalyticsEvents.allMemoriesCleared,
                    );
                  },
                ),
              ),

              // ── PRIVACY section ────────────────────────────────────────
              const SettingsSectionLabel('Privacy'),
              _SettingsCard(
                children: [
                  _ToggleRow(
                    icon: Icons.self_improvement_rounded,
                    iconColor: AppColors.categoryWellness,
                    title: 'Wellness Check-in',
                    subtitle: 'Show check-in card on Today tab',
                    value: wellnessCheckin,
                    onChanged: (v) => prefsNotifier.mutate(
                      (p) => p.copyWith(wellnessCheckinCardVisible: v),
                    ),
                  ),
                  const _Divider(),
                  _ToggleRow(
                    icon: Icons.info_outline_rounded,
                    iconColor: AppColors.categoryBody,
                    title: 'Data Maturity Banner',
                    subtitle: 'Show data quality guidance banners',
                    value: dataMaturityBanner,
                    onChanged: (v) => prefsNotifier.mutate(
                      // Banner toggle: "show" = not dismissed.
                      (p) => p.copyWith(dataMaturityBannerDismissed: !v),
                    ),
                  ),
                  const _Divider(),
                  _ToggleRow(
                    icon: Icons.bar_chart_rounded,
                    iconColor: AppColors.secondaryDark,
                    title: 'Analytics',
                    subtitle: 'Helps us improve Zuralog',
                    subtitleExtra: 'Share anonymous usage data',
                    value: analyticsEnabled,
                    onChanged: (v) => prefsNotifier.mutate(
                      // Analytics toggle: "enabled" = not opted out.
                      (p) => p.copyWith(analyticsOptOut: !v),
                    ),
                  ),
                ],
              ),

              // ── DATA section ───────────────────────────────────────────
              const SettingsSectionLabel('Data'),
              _SettingsCard(
                children: [
                  _ExportDataRow(
                    onTap: () {
                      ref.read(analyticsServiceProvider).capture(
                        event: AnalyticsEvents.dataExportRequested,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Data export coming soon'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                  const _Divider(),
                  _DeleteDataRow(
                    onConfirmed: () {
                      ref.read(analyticsServiceProvider).capture(
                        event: AnalyticsEvents.accountDeleteRequested,
                      );
                      // TODO(phase9): Wire to Supabase delete-all-data API endpoint.
                      // Do not show a success message until the API call succeeds.
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Data deletion is not yet available. '
                            'Contact support@zuralog.com to request erasure.',
                          ),
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 6),
                        ),
                      );
                    },
                  ),
                ],
              ),

              // ── LEGAL section ──────────────────────────────────────────
              const SettingsSectionLabel('Legal'),
              _SettingsCard(
                children: [
                  _TapRow(
                    icon: Icons.shield_outlined,
                    iconColor: AppColors.primary,
                    title: 'Privacy Policy',
                    onTap: () => context.pushNamed(RouteNames.settingsPrivacyPolicy),
                  ),
                  const _Divider(),
                  _TapRow(
                    icon: Icons.description_outlined,
                    iconColor: AppColors.primary,
                    title: 'Terms of Service',
                    onTap: () => context.pushNamed(RouteNames.settingsTerms),
                  ),
                ],
              ),

              const SizedBox(height: AppDimens.spaceXxl),
            ]),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

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

class _MemoryItemRow extends StatelessWidget {
  const _MemoryItemRow({required this.text, required this.onDelete});

  final String text;
  final VoidCallback onDelete;

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
              color: AppColors.categorySleep.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppDimens.radiusSm),
            ),
            child: const Icon(
              Icons.memory_rounded,
              size: 20,
              color: AppColors.categorySleep,
            ),
          ),
          const SizedBox(width: AppDimens.spaceMd),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimaryDark,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.close_rounded,
              size: 18,
              color: AppColors.textTertiary,
            ),
            onPressed: onDelete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            splashRadius: 16,
          ),
        ],
      ),
    );
  }
}

class _ClearMemoryRow extends StatelessWidget {
  const _ClearMemoryRow({required this.enabled, required this.onConfirmed});

  final bool enabled;
  final VoidCallback onConfirmed;

  Future<void> _showConfirmDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        ),
        title: Text(
          'Clear All Memory?',
          style: AppTextStyles.h3.copyWith(color: AppColors.textPrimaryDark),
        ),
        content: Text(
          'Your AI coach will lose all personalization context. '
          'It will start fresh with generic recommendations.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Clear All',
              style: AppTextStyles.body.copyWith(
                color: AppColors.accentDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      onConfirmed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _PressableRow(
      onTap: enabled ? () => _showConfirmDialog(context) : null,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackgroundDark,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        ),
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
                color: AppColors.accentDark.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
              ),
              child: Icon(
                Icons.delete_sweep_rounded,
                size: 20,
                color: enabled ? AppColors.accentDark : AppColors.textTertiary,
              ),
            ),
            const SizedBox(width: AppDimens.spaceMd),
            Text(
              'Clear All Memory',
              style: AppTextStyles.body.copyWith(
                color: enabled ? AppColors.accentDark : AppColors.textTertiary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.subtitleExtra,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? subtitleExtra;
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
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textPrimaryDark,
                  ),
                ),
                const SizedBox(height: 2),
                if (subtitleExtra != null) ...[
                  Text(
                    subtitleExtra!,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 1),
                ],
                Text(
                  subtitle,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textTertiary,
                  ),
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

class _ExportDataRow extends StatelessWidget {
  const _ExportDataRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _PressableRow(
      onTap: onTap,
      child: Padding(
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
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
              ),
              child: const Icon(
                Icons.download_rounded,
                size: 20,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: AppDimens.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Export Data',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textPrimaryDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Coming soon',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.secondaryDark.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppDimens.radiusChip),
              ),
              child: Text(
                'Soon',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.secondaryDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeleteDataRow extends StatelessWidget {
  const _DeleteDataRow({required this.onConfirmed});

  final VoidCallback onConfirmed;

  Future<void> _showConfirmDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        ),
        title: Text(
          'Delete All My Data?',
          style: AppTextStyles.h3.copyWith(color: AppColors.textPrimaryDark),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This action is permanent and cannot be undone.',
              style: AppTextStyles.body.copyWith(
                color: AppColors.accentDark,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppDimens.spaceSm),
            Text(
              'All health records, AI memory, preferences, and account data '
              'will be permanently erased. You will be signed out immediately.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Delete',
              style: AppTextStyles.body.copyWith(
                color: AppColors.accentDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      onConfirmed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _PressableRow(
      onTap: () => _showConfirmDialog(context),
      child: Padding(
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
                color: AppColors.accentDark.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
              ),
              child: const Icon(
                Icons.delete_forever_rounded,
                size: 20,
                color: AppColors.accentDark,
              ),
            ),
            const SizedBox(width: AppDimens.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Delete All My Data',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.accentDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Permanently removes all health data',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

class _TapRow extends StatelessWidget {
  const _TapRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _PressableRow(
      onTap: onTap,
      child: Padding(
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
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: AppDimens.spaceMd),
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textPrimaryDark,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Generic pressable wrapper — AnimatedContainer with 100ms press feedback.
class _PressableRow extends StatefulWidget {
  const _PressableRow({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_PressableRow> createState() => _PressableRowState();
}

class _PressableRowState extends State<_PressableRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap != null
          ? (_) => setState(() => _pressed = true)
          : null,
      onTapUp: widget.onTap != null
          ? (_) {
              setState(() => _pressed = false);
              widget.onTap!();
            }
          : null,
      onTapCancel: widget.onTap != null
          ? () => setState(() => _pressed = false)
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        color: _pressed
            ? AppColors.borderDark.withValues(alpha: 0.3)
            : Colors.transparent,
        child: widget.child,
      ),
    );
  }
}
