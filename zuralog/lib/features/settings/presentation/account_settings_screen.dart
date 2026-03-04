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

// ── AccountSettingsScreen ─────────────────────────────────────────────────────

/// Account settings: email, password, linked social accounts, goals editor,
/// emergency health card, and danger zone (delete account).
class AccountSettingsScreen extends ConsumerWidget {
  /// Creates the [AccountSettingsScreen].
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Account',
          style: AppTextStyles.h3.copyWith(color: AppColors.textPrimaryDark),
        ),
      ),
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
          _SectionLabel(label: 'Credentials'),
          _SettingsGroup(
            tiles: [
              _AccountTile(
                icon: Icons.email_rounded,
                iconColor: AppColors.categorySleep,
                title: 'Email',
                subtitle: 'user@example.com',
                onTap: () => _showChangeEmailSheet(context),
              ),
              _AccountTile(
                icon: Icons.lock_outline_rounded,
                iconColor: AppColors.categoryVitals,
                title: 'Change Password',
                subtitle: 'Update your account password',
                onTap: () => _showChangePasswordSheet(context),
              ),
            ],
          ),

          // ── Linked accounts ─────────────────────────────────────────────
          _SectionLabel(label: 'Linked Accounts'),
          _SettingsGroup(
            tiles: [
              _AccountTile(
                icon: Icons.g_mobiledata_rounded,
                iconColor: const Color(0xFF4285F4),
                title: 'Google',
                subtitle: 'Linked',
                onTap: () {},
                trailingLabel: 'Linked',
                trailingColor: AppColors.statusConnected,
              ),
              _AccountTile(
                icon: Icons.apple_rounded,
                iconColor: AppColors.textPrimaryDark,
                title: 'Apple',
                subtitle: 'Not linked',
                onTap: () => _showLinkAppleSheet(context),
                trailingLabel: 'Link',
                trailingColor: AppColors.primary,
              ),
            ],
          ),

          // ── Goals ───────────────────────────────────────────────────────
          _SectionLabel(label: 'Health Goals'),
          _SettingsGroup(
            tiles: [
              _AccountTile(
                icon: Icons.track_changes_rounded,
                iconColor: AppColors.categoryActivity,
                title: 'My Goals',
                subtitle: 'Edit your health goals',
                onTap: () => _showGoalsEditor(context),
              ),
            ],
          ),

          // ── Emergency Health Card ────────────────────────────────────────
          _SectionLabel(label: 'Medical'),
          _SettingsGroup(
            tiles: [
              _AccountTile(
                icon: Icons.emergency_rounded,
                iconColor: AppColors.categoryHeart,
                title: 'Emergency Health Card',
                subtitle: 'Blood type, allergies, medications',
                onTap: () => context.push(RouteNames.emergencyCardPath),
              ),
            ],
          ),

          // ── Danger Zone ─────────────────────────────────────────────────
          _SectionLabel(label: 'Danger Zone'),
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
              child: _AccountTile(
                icon: Icons.delete_forever_rounded,
                iconColor: AppColors.statusError,
                title: 'Delete Account',
                subtitle: 'Permanently remove all your data',
                onTap: () {
                  ref.read(hapticServiceProvider).warning();
                  _showDeleteAccountDialog(context);
                },
                destructive: true,
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
    return Container(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.cardBackgroundDark,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      ),
      child: Row(
        children: [
          // Avatar circle with initial.
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                'U',
                style: AppTextStyles.h2.copyWith(
                  color: AppColors.primary,
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
                  style: AppTextStyles.h3.copyWith(
                    color: AppColors.textPrimaryDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'user@example.com',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
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

// ── _SectionLabel ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceLg,
        AppDimens.spaceMd,
        AppDimens.spaceXs,
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTextStyles.labelXs.copyWith(
          color: AppColors.textTertiary,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── _SettingsGroup ────────────────────────────────────────────────────────────

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.tiles});

  final List<_AccountTile> tiles;

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
            for (int i = 0; i < tiles.length; i++) ...[
              tiles[i],
              if (i < tiles.length - 1)
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

// ── _AccountTile ──────────────────────────────────────────────────────────────

class _AccountTile extends StatefulWidget {
  const _AccountTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailingLabel,
    this.trailingColor,
    this.destructive = false,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? trailingLabel;
  final Color? trailingColor;
  final bool destructive;

  @override
  State<_AccountTile> createState() => _AccountTileState();
}

class _AccountTileState extends State<_AccountTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final titleColor = widget.destructive
        ? AppColors.statusError
        : AppColors.textPrimaryDark;

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
                    style: AppTextStyles.body.copyWith(color: titleColor),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.subtitle,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (widget.trailingLabel != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.trailingColor!.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppDimens.radiusChip),
                ),
                child: Text(
                  widget.trailingLabel!,
                  style: AppTextStyles.labelXs.copyWith(
                    color: widget.trailingColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else if (!widget.destructive)
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

void _showGoalsEditor(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _GoalsEditorSheet(),
  );
}

class _GoalsEditorSheet extends StatefulWidget {
  const _GoalsEditorSheet();

  @override
  State<_GoalsEditorSheet> createState() => _GoalsEditorSheetState();
}

class _GoalsEditorSheetState extends State<_GoalsEditorSheet> {
  final Set<int> _selected = {0, 2};

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(
        top: MediaQuery.of(context).size.height * 0.3,
      ),
      decoration: const BoxDecoration(
        color: AppColors.cardBackgroundDark,
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
                color: AppColors.borderDark,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
            child: Text(
              'Health Goals',
              style: AppTextStyles.h2.copyWith(
                color: AppColors.textPrimaryDark,
              ),
            ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
            child: Text(
              'Select all that apply',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
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
                  final isSelected = _selected.contains(index);
                  return GestureDetector(
                    onTap: () => setState(() {
                      if (isSelected) {
                        _selected.remove(index);
                      } else {
                        _selected.add(index);
                      }
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.15)
                            : AppColors.surfaceDark,
                        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.6)
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
                                ? AppColors.primary
                                : AppColors.textTertiary,
                          ),
                          const SizedBox(width: AppDimens.spaceXs),
                          Expanded(
                            child: Text(
                              label,
                              style: AppTextStyles.caption.copyWith(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
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
                  style: AppTextStyles.h3.copyWith(
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
    builder: (_) => Container(
      margin: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.cardBackgroundDark,
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.all(AppDimens.spaceLg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.apple_rounded, size: 48, color: AppColors.textPrimaryDark),
          const SizedBox(height: AppDimens.spaceMd),
          Text(
            'Link Apple ID',
            style: AppTextStyles.h2.copyWith(color: AppColors.textPrimaryDark),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Text(
            'Connect your Apple ID for one-tap sign in across devices.',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
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
                style: AppTextStyles.h3.copyWith(color: AppColors.primaryButtonText),
              ),
            ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
        ],
      ),
    ),
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
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        margin: const EdgeInsets.all(AppDimens.spaceMd),
        decoration: BoxDecoration(
          color: AppColors.cardBackgroundDark,
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
                  AppTextStyles.h2.copyWith(color: AppColors.textPrimaryDark),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            TextField(
              autofocus: true,
              keyboardType: keyboardType,
              obscureText: obscureText,
              style: AppTextStyles.body.copyWith(color: AppColors.textPrimaryDark),
              decoration: InputDecoration(
                labelText: fieldLabel,
                labelStyle: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.surfaceDark,
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
                  style: AppTextStyles.h3
                      .copyWith(color: AppColors.primaryButtonText),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ── Delete account dialog ─────────────────────────────────────────────────────

void _showDeleteAccountDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: AppColors.cardBackgroundDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      ),
      title: Text(
        'Delete Account?',
        style: AppTextStyles.h2.copyWith(color: AppColors.textPrimaryDark),
      ),
      content: Text(
        'This will permanently delete all your health data, conversations, '
        'and insights. This action cannot be undone.',
        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            // TODO: trigger delete account API call
          },
          child: Text(
            'Delete',
            style: AppTextStyles.body.copyWith(
              color: AppColors.statusError,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}
