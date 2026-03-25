/// Account Settings Screen — manage email, password, emergency health card,
/// units preferences, sign out, and danger zone (delete account).
///
/// Full implementation: Phase 8, Task 8.2.
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/core/haptics/haptic_providers.dart';
import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/shared/widgets/widgets.dart';
import 'package:zuralog/features/auth/domain/auth_providers.dart';
import 'package:zuralog/features/settings/domain/user_preferences_model.dart';
import 'package:zuralog/features/settings/presentation/widgets/settings_section_label.dart';
import 'package:zuralog/features/settings/providers/settings_providers.dart';

// ── AccountSettingsScreen ─────────────────────────────────────────────────────

/// Account settings: profile, email, password, preferences, medical,
/// sign out, and danger zone (delete account).
class AccountSettingsScreen extends ConsumerStatefulWidget {
  /// Creates the [AccountSettingsScreen].
  const AccountSettingsScreen({super.key});

  @override
  ConsumerState<AccountSettingsScreen> createState() =>
      _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends ConsumerState<AccountSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return ZuralogScaffold(
      appBar: ZuralogAppBar(title: 'Account'),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceMd),
        children: [
          // ── Profile summary (tappable → Edit Profile) ──────────────────
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceMd,
              vertical: AppDimens.spaceSm,
            ),
            child: _ProfileSummaryCard(),
          ),

          // ── Security section ────────────────────────────────────────────
          const SettingsSectionLabel('Security'),
          _SettingsGroup(
            tiles: [
              ZSettingsTile(
                icon: Icons.email_rounded,
                iconColor: AppColors.categorySleep,
                title: 'Email',
                subtitle: ref.watch(userEmailProvider),
                onTap: () => _showChangeEmailSheet(context, ref),
              ),
              ZSettingsTile(
                icon: Icons.lock_outline_rounded,
                iconColor: AppColors.categoryVitals,
                title: 'Change Password',
                subtitle: 'Update your account password',
                onTap: () => _showChangePasswordSheet(context, ref),
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

          // ── Sign Out ─────────────────────────────────────────────────────
          _SettingsGroup(
            tiles: [
              ZSettingsTile(
                icon: Icons.logout_rounded,
                iconColor: AppColors.primary,
                title: 'Sign Out',
                subtitle: 'Sign out of your account',
                showChevron: false,
                onTap: () => _showSignOutDialog(context, ref),
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
                  _showDeleteAccountStep1Dialog(context, ref);
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

class _ProfileSummaryCard extends ConsumerWidget {
  const _ProfileSummaryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColorsOf(context);
    final email = ref.watch(userEmailProvider);
    final profile = ref.watch(userProfileProvider);
    final displayName = profile?.aiName ?? profile?.displayName ?? '';
    final avatarInitial = displayName.isNotEmpty
        ? displayName[0].toUpperCase()
        : email.isNotEmpty
            ? email[0].toUpperCase()
            : 'U';

    return GestureDetector(
      onTap: () => context.push(RouteNames.editProfilePath),
      child: Container(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        decoration: BoxDecoration(
          color: colors.cardBackground,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        ),
        child: Row(
          children: [
            ZAvatar(
              imageUrl: profile?.avatarUrl,
              initials: avatarInitial,
              size: 56,
            ),
            const SizedBox(width: AppDimens.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName.isNotEmpty ? displayName : 'Your Profile',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Edit profile',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: colors.textSecondary,
                    ),
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

// ── Change Email Sheet ────────────────────────────────────────────────────────

void _showChangeEmailSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ChangeEmailSheet(),
  );
}

class _ChangeEmailSheet extends ConsumerStatefulWidget {
  const _ChangeEmailSheet();

  @override
  ConsumerState<_ChangeEmailSheet> createState() => _ChangeEmailSheetState();
}

class _ChangeEmailSheetState extends ConsumerState<_ChangeEmailSheet> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _controller.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Please enter your new email address.');
      return;
    }
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(email)) {
      setState(() => _error = 'Please enter a valid email address.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(userProfileProvider.notifier)
          .changeEmail(email);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Check your new email inbox — we sent a confirmation link.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on DioException catch (e) {
      final detail = e.response?.data?['detail'] as String?;
      setState(() => _error = detail ?? 'Something went wrong. Please try again.');
    } catch (_) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        margin: const EdgeInsets.all(AppDimens.spaceMd),
        decoration: BoxDecoration(
          color: colors.cardBackground,
          borderRadius: BorderRadius.circular(AppDimens.shapeLg),
        ),
        padding: const EdgeInsets.all(AppDimens.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Change Email',
              style: AppTextStyles.displaySmall.copyWith(
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            AppTextField(
              hintText: 'New email address',
              controller: _controller,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: _submit,
            ),
            if (_error != null) ...[
              const SizedBox(height: AppDimens.spaceSm),
              Text(
                _error!,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.statusError,
                ),
              ),
            ],
            const SizedBox(height: AppDimens.spaceMd),
            SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                label: 'Update Email',
                isLoading: _loading,
                onPressed: _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Change Password Sheet ─────────────────────────────────────────────────────

void _showChangePasswordSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ChangePasswordSheet(),
  );
}

class _ChangePasswordSheet extends ConsumerStatefulWidget {
  const _ChangePasswordSheet();

  @override
  ConsumerState<_ChangePasswordSheet> createState() =>
      _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends ConsumerState<_ChangePasswordSheet> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final current = _currentController.text;
    final newPw = _newController.text;
    final confirm = _confirmController.text;

    if (current.isEmpty || newPw.isEmpty || confirm.isEmpty) {
      setState(() => _error = 'Please fill in all three fields.');
      return;
    }
    if (_newController.text.length < 8) {
      setState(() => _error = 'New password must be at least 8 characters.');
      return;
    }
    if (newPw != confirm) {
      setState(() => _error = 'The new passwords do not match.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(userProfileProvider.notifier)
          .changePassword(currentPassword: current, newPassword: newPw);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password updated successfully.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on DioException catch (e) {
      final detail = e.response?.data?['detail'] as String?;
      setState(() => _error = detail ?? 'Something went wrong. Please try again.');
    } catch (_) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final canSubmit = _currentController.text.isNotEmpty &&
        _newController.text.isNotEmpty &&
        _confirmController.text.isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        margin: const EdgeInsets.all(AppDimens.spaceMd),
        decoration: BoxDecoration(
          color: colors.cardBackground,
          borderRadius: BorderRadius.circular(AppDimens.shapeLg),
        ),
        padding: const EdgeInsets.all(AppDimens.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Change Password',
              style: AppTextStyles.displaySmall.copyWith(
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            // Current password.
            AppTextField(
              hintText: 'Current password',
              controller: _currentController,
              obscureText: _obscureCurrent,
              autofocus: true,
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {}),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureCurrent
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: AppDimens.iconMd,
                  color: colors.textSecondary,
                ),
                onPressed: () =>
                    setState(() => _obscureCurrent = !_obscureCurrent),
              ),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            // New password + strength bar.
            AppTextField(
              hintText: 'New password',
              controller: _newController,
              obscureText: _obscureNew,
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {}),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureNew
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: AppDimens.iconMd,
                  color: colors.textSecondary,
                ),
                onPressed: () => setState(() => _obscureNew = !_obscureNew),
              ),
            ),
            ZPasswordStrengthBar(password: _newController.text),
            const SizedBox(height: AppDimens.spaceMd),
            // Confirm password.
            AppTextField(
              hintText: 'Confirm new password',
              controller: _confirmController,
              obscureText: _obscureConfirm,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
              onSubmitted: canSubmit ? _submit : null,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirm
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: AppDimens.iconMd,
                  color: colors.textSecondary,
                ),
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppDimens.spaceSm),
              Text(
                _error!,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.statusError,
                ),
              ),
            ],
            const SizedBox(height: AppDimens.spaceMd),
            SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                label: 'Update Password',
                isLoading: _loading,
                onPressed: canSubmit ? _submit : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sign Out Dialog ───────────────────────────────────────────────────────────

void _showSignOutDialog(BuildContext context, WidgetRef ref) {
  showDialog<void>(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      title: const Text('Sign Out?'),
      content: const Text('You can sign back in any time.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogCtx),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(dialogCtx);
            ref.read(hapticServiceProvider).warning();
            ref.read(authStateProvider.notifier).logout();
          },
          child: const Text('Sign Out'),
        ),
      ],
    ),
  );
}

// ── Delete Account Dialogs (2-step) ───────────────────────────────────────────

/// Step 1: intent warning.
void _showDeleteAccountStep1Dialog(BuildContext context, WidgetRef ref) {
  final colors = AppColorsOf(context);
  showDialog<void>(
    context: context,
    builder: (dialogCtx) => AlertDialog(
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
          onPressed: () => Navigator.pop(dialogCtx),
          child: Text(
            'Cancel',
            style: AppTextStyles.bodyLarge.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(dialogCtx);
            _showDeleteAccountStep2Dialog(context, ref);
          },
          child: Text(
            'Continue',
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

/// Step 2: type-to-confirm dialog.
void _showDeleteAccountStep2Dialog(BuildContext context, WidgetRef ref) {
  showDialog<void>(
    context: context,
    builder: (dialogCtx) => _DeleteConfirmDialog(
      outerContext: context,
      ref: ref,
    ),
  );
}

class _DeleteConfirmDialog extends StatefulWidget {
  const _DeleteConfirmDialog({
    required this.outerContext,
    required this.ref,
  });

  final BuildContext outerContext;
  final WidgetRef ref;

  @override
  State<_DeleteConfirmDialog> createState() => _DeleteConfirmDialogState();
}

class _DeleteConfirmDialogState extends State<_DeleteConfirmDialog> {
  final _controller = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    setState(() => _loading = true);
    try {
      await widget.ref
          .read(userProfileProvider.notifier)
          .deleteAccount();
      // Wipe local state and route to welcome screen.
      await widget.ref.read(authStateProvider.notifier).logout();
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(widget.outerContext).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not delete account. Please try again or contact support@zuralog.com.',
            ),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 6),
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final confirmed = _controller.text == 'DELETE';

    return AlertDialog(
      backgroundColor: colors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      ),
      title: Text(
        'Are you sure?',
        style: AppTextStyles.displaySmall.copyWith(color: colors.textPrimary),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Type DELETE to confirm. This cannot be undone.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          AppTextField(
            hintText: 'Type DELETE',
            controller: _controller,
            autofocus: true,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: AppTextStyles.bodyLarge.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ),
        _loading
            ? const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              )
            : TextButton(
                onPressed: confirmed ? _confirm : null,
                child: Text(
                  'Delete Account',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: confirmed
                        ? AppColors.statusError
                        : AppColors.textTertiary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
      ],
    );
  }
}
