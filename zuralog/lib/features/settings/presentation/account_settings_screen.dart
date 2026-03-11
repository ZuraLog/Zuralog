/// Account Settings Screen — manage email, password, linked accounts, goals,
/// and emergency health card link.
///
/// Full implementation: Phase 8, Task 8.2.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/core/haptics/haptic_providers.dart';
import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/shared/widgets/widgets.dart';
import 'package:zuralog/features/settings/domain/user_preferences_model.dart';
import 'package:zuralog/features/settings/presentation/widgets/settings_section_label.dart';
import 'package:zuralog/features/settings/providers/settings_providers.dart';

// ── AccountSettingsScreen ─────────────────────────────────────────────────────

/// Account settings: email, password, linked social accounts, goals editor,
/// emergency health card, and danger zone (delete account).
class AccountSettingsScreen extends ConsumerWidget {
  /// Creates the [AccountSettingsScreen].
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColorsOf(context);
    return ZuralogScaffold(
      appBar: ZuralogAppBar(title: 'Account'),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceMd),
        children: [
          // ── Profile summary ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceMd,
              vertical: AppDimens.spaceSm,
            ),
            child: _ProfileSummaryCard(),
          ),

          // ── Credentials section ─────────────────────────────────────────
          const SettingsSectionLabel('Credentials'),
          _SettingsGroup(
            tiles: [
              ZSettingsTile(
                icon: Icons.email_rounded,
                iconColor: AppColors.categorySleep,
                title: 'Email',
                subtitle: 'user@example.com',
                onTap: () => _showChangeEmailSheet(context),
              ),
              ZSettingsTile(
                icon: Icons.lock_outline_rounded,
                iconColor: AppColors.categoryVitals,
                title: 'Change Password',
                subtitle: 'Update your account password',
                onTap: () => _showChangePasswordSheet(context),
              ),
            ],
          ),

          // ── Linked accounts ─────────────────────────────────────────────
          const SettingsSectionLabel('Linked Accounts'),
          _SettingsGroup(
            tiles: [
              ZSettingsTile(
                icon: Icons.g_mobiledata_rounded,
                iconColor: AppColors.googleBlue,
                title: 'Google',
                subtitle: 'Linked',
                onTap: () {},
                showChevron: false,
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.statusConnected.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppDimens.radiusChip),
                  ),
                  child: Text(
                    'Linked',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.statusConnected,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              ZSettingsTile(
                icon: Icons.apple_rounded,
                iconColor: colors.textPrimary,
                title: 'Apple',
                subtitle: 'Not linked',
                onTap: () => _showLinkAppleSheet(context),
                showChevron: false,
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppDimens.radiusChip),
                  ),
                  child: Text(
                    'Link',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // ── Goals ───────────────────────────────────────────────────────
          const SettingsSectionLabel('Health Goals'),
          _SettingsGroup(
            tiles: [
              ZSettingsTile(
                icon: Icons.track_changes_rounded,
                iconColor: AppColors.categoryActivity,
                title: 'My Goals',
                subtitle: 'Edit your health goals',
                onTap: () => _showGoalsEditor(context),
              ),
            ],
          ),

          // ── Preferences ─────────────────────────────────────────────────
          const SettingsSectionLabel('Preferences'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
            child: Container(
              decoration: BoxDecoration(
                color: colors.cardBackground,
                borderRadius: BorderRadius.circular(AppDimens.radiusCard),
              ),
              child: const _UnitsTile(),
            ),
          ),

          // ── Emergency Health Card ────────────────────────────────────────
          const SettingsSectionLabel('Medical'),
          _SettingsGroup(
            tiles: [
              ZSettingsTile(
                icon: Icons.emergency_rounded,
                iconColor: AppColors.categoryHeart,
                title: 'Emergency Health Card',
                subtitle: 'Blood type, allergies, medications',
                onTap: () => context.push(RouteNames.emergencyCardPath),
              ),
            ],
          ),

          // ── Danger Zone ─────────────────────────────────────────────────
          const SettingsSectionLabel('Danger Zone'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.statusError.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppDimens.radiusCard),
                border: Border.all(
                  color: AppColors.statusError.withValues(alpha: 0.25),
                ),
              ),
              child: ZSettingsTile(
                icon: Icons.delete_forever_rounded,
                iconColor: AppColors.statusError,
                title: 'Delete Account',
                subtitle: 'Permanently remove all your data',
                titleColor: AppColors.statusError,
                showChevron: false,
                onTap: () {
                  ref.read(hapticServiceProvider).warning();
                  _showDeleteAccountDialog(context);
                },
              ),
            ),
          ),

          const SizedBox(height: AppDimens.spaceXxl),
        ],
      ),
    );
  }
}

// ── _ProfileSummaryCard ───────────────────────────────────────────────────────

class _ProfileSummaryCard extends StatelessWidget {
  const _ProfileSummaryCard();

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Container(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      ),
      child: Row(
        children: [
          // Avatar circle with initial.
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                'U',
                style: AppTextStyles.displaySmall.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppDimens.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'User',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'user@example.com',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── _SettingsGroup ────────────────────────────────────────────────────────────

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.tiles});

  final List<ZSettingsTile> tiles;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      child: Container(
        decoration: BoxDecoration(
          color: colors.cardBackground,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        ),
        child: Column(
          children: [
            for (int i = 0; i < tiles.length; i++) ...[
              tiles[i],
              if (i < tiles.length - 1)
                Padding(
                  padding: const EdgeInsets.only(left: 68),
                  child: Container(
                    height: 1,
                    color: colors.border.withValues(alpha: 0.5),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── _UnitsTile ────────────────────────────────────────────────────────────────

/// Segmented toggle for metric / imperial — reads and writes [unitsSystemProvider].
class _UnitsTile extends ConsumerWidget {
  const _UnitsTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColorsOf(context);
    final current = ref.watch(unitsSystemProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: 14,
      ),
      child: Row(
        children: [
          // Icon badge.
          const ZIconBadge(
            icon: Icons.straighten_rounded,
            color: AppColors.categoryActivity,
          ),
          const SizedBox(width: AppDimens.spaceMd),
          // Label.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Units',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  current == UnitsSystem.metric
                      ? 'Metric (km, kg, °C)'
                      : 'Imperial (mi, lb, °F)',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppDimens.spaceSm),
          // Segmented control.
          _UnitsSegmentedButton(current: current),
        ],
      ),
    );
  }
}

/// Compact two-option segmented button for metric / imperial.
class _UnitsSegmentedButton extends ConsumerWidget {
  const _UnitsSegmentedButton({required this.current});

  final UnitsSystem current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColorsOf(context);
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Segment(
            label: 'Metric',
            selected: current == UnitsSystem.metric,
            isLeft: true,
            onTap: () {
              if (current != UnitsSystem.metric) {
                ref.read(hapticServiceProvider).selectionTick();
                ref
                    .read(userPreferencesProvider.notifier)
                    .mutate((p) => p.copyWith(unitsSystem: UnitsSystem.metric));
              }
            },
          ),
          _Segment(
            label: 'Imperial',
            selected: current == UnitsSystem.imperial,
            isLeft: false,
            onTap: () {
              if (current != UnitsSystem.imperial) {
                ref.read(hapticServiceProvider).selectionTick();
                ref
                    .read(userPreferencesProvider.notifier)
                    .mutate(
                      (p) => p.copyWith(unitsSystem: UnitsSystem.imperial),
                    );
              }
            },
          ),
        ],
      ),
    );
  }
}

/// A single tab within [_UnitsSegmentedButton].
class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.isLeft,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool isLeft;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final radius = BorderRadius.horizontal(
      left: isLeft ? const Radius.circular(AppDimens.radiusSm) : Radius.zero,
      right: isLeft ? Radius.zero : const Radius.circular(AppDimens.radiusSm),
    );
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected
              ? colors.primary.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: radius,
          border: selected
              ? Border.all(
                  color: colors.primary.withValues(alpha: 0.55),
                )
              : null,
        ),
        child: Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: selected ? colors.primary : colors.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

// ── Goals editor bottom sheet ─────────────────────────────────────────────────

/// 8 predefined health goals for multi-select.
const _kGoals = [
  ('Lose Weight', Icons.monitor_weight_outlined),
  ('Build Muscle', Icons.fitness_center_rounded),
  ('Sleep Better', Icons.bedtime_rounded),
  ('Reduce Stress', Icons.self_improvement_rounded),
  ('Improve Endurance', Icons.directions_run_rounded),
  ('Eat Healthier', Icons.restaurant_rounded),
  ('Track Vitals', Icons.favorite_rounded),
  ('Stay Consistent', Icons.emoji_events_rounded),
];

/// File-scoped provider — persists goal selections across sheet dismissals.
/// TODO(phase9): Replace with a proper goals repository backed by Supabase.
final _selectedGoalsProvider =
    StateProvider<Set<int>>((_) => const {0, 2});

void _showGoalsEditor(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _GoalsEditorSheet(),
  );
}

class _GoalsEditorSheet extends ConsumerWidget {
  const _GoalsEditorSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(_selectedGoalsProvider);

    final colors = AppColorsOf(context);
    return Container(
      margin: EdgeInsets.only(
        top: MediaQuery.of(context).size.height * 0.3,
      ),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle.
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: AppDimens.spaceLg),
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
            child: Text(
              'Health Goals',
              style: AppTextStyles.displaySmall.copyWith(
                color: colors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
            child: Text(
              'Select all that apply',
              style: AppTextStyles.bodyMedium.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: AppDimens.spaceSm,
                  crossAxisSpacing: AppDimens.spaceSm,
                  childAspectRatio: 2.8,
                ),
                itemCount: _kGoals.length,
                itemBuilder: (context, index) {
                  final (label, icon) = _kGoals[index];
                  final isSelected = selected.contains(index);
                  return GestureDetector(
                    onTap: () {
                      final next = Set<int>.from(selected);
                      if (isSelected) {
                        next.remove(index);
                      } else {
                        next.add(index);
                      }
                      ref.read(_selectedGoalsProvider.notifier).state = next;
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colors.primary.withValues(alpha: 0.15)
                            : colors.surface,
                        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                        border: Border.all(
                          color: isSelected
                              ? colors.primary.withValues(alpha: 0.6)
                              : Colors.transparent,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.spaceSm,
                        vertical: AppDimens.spaceXs,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            icon,
                            size: 18,
                            color: isSelected
                                ? colors.primary
                                : AppColors.textTertiary,
                          ),
                          const SizedBox(width: AppDimens.spaceXs),
                          Expanded(
                            child: Text(
                              label,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: isSelected
                                    ? colors.primary
                                    : colors.textSecondary,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppDimens.spaceMd),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.primaryButtonText,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimens.radiusButtonMd),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Save Goals',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.primaryButtonText,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
        ],
      ),
    );
  }
}

// ── Change email / password sheet stubs ──────────────────────────────────────

void _showChangeEmailSheet(BuildContext context) {
  _showSimpleFormSheet(
    context,
    title: 'Change Email',
    fieldLabel: 'New email address',
    keyboardType: TextInputType.emailAddress,
    actionLabel: 'Update Email',
  );
}

void _showChangePasswordSheet(BuildContext context) {
  _showSimpleFormSheet(
    context,
    title: 'Change Password',
    fieldLabel: 'New password',
    obscureText: true,
    actionLabel: 'Update Password',
  );
}

void _showLinkAppleSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) {
      final colors = AppColorsOf(sheetCtx);
      return Container(
      margin: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.all(AppDimens.spaceLg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.apple_rounded, size: 48, color: colors.textPrimary),
          const SizedBox(height: AppDimens.spaceMd),
          Text(
            'Link Apple ID',
            style: AppTextStyles.displaySmall.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Text(
            'Connect your Apple ID for one-tap sign in across devices.',
            style: AppTextStyles.bodyMedium.copyWith(color: colors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimens.spaceLg),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.primaryButtonText,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusButtonMd),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Continue with Apple',
                style: AppTextStyles.titleMedium.copyWith(color: AppColors.primaryButtonText),
              ),
            ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
        ],
      ),
    );
    },
  );
}

void _showSimpleFormSheet(
  BuildContext context, {
  required String title,
  required String fieldLabel,
  required String actionLabel,
  TextInputType keyboardType = TextInputType.text,
  bool obscureText = false,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) {
      final colors = AppColorsOf(sheetCtx);
      return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        margin: const EdgeInsets.all(AppDimens.spaceMd),
        decoration: BoxDecoration(
          color: colors.cardBackground,
          borderRadius: BorderRadius.circular(28),
        ),
        padding: const EdgeInsets.all(AppDimens.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style:
                  AppTextStyles.displaySmall.copyWith(color: colors.textPrimary),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            TextField(
              autofocus: true,
              keyboardType: keyboardType,
              obscureText: obscureText,
              style: AppTextStyles.bodyLarge.copyWith(color: colors.textPrimary),
              decoration: InputDecoration(
                labelText: fieldLabel,
                labelStyle: AppTextStyles.bodySmall
                    .copyWith(color: colors.textSecondary),
                filled: true,
                fillColor: colors.surface,
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimens.radiusInput),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.primaryButtonText,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimens.radiusButtonMd),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text(
                  actionLabel,
                  style: AppTextStyles.titleMedium
                      .copyWith(color: AppColors.primaryButtonText),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    },
  );
}

// ── Delete account dialog ─────────────────────────────────────────────────────

void _showDeleteAccountDialog(BuildContext context) {
  final colors = AppColorsOf(context);
  showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: colors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      ),
      title: Text(
        'Delete Account?',
        style: AppTextStyles.displaySmall.copyWith(color: colors.textPrimary),
      ),
      content: Text(
        'This will permanently delete all your health data, conversations, '
        'and insights. This action cannot be undone.',
        style: AppTextStyles.bodyMedium.copyWith(color: colors.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: AppTextStyles.bodyLarge.copyWith(color: colors.textSecondary),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            // TODO(phase9): Call Supabase delete-account API endpoint here.
            // For now, show an honest message — do not silently no-op.
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Account deletion is not yet available. '
                  'Please contact support@zuralog.com to request deletion.',
                ),
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 6),
              ),
            );
          },
          child: Text(
            'Delete',
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.statusError,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}
