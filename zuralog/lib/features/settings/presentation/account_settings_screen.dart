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
      appBar: const ZuralogAppBar(title: 'Account', showProfileAvatar: false),
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
          ZSettingsGroup(
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
                color: colors.surface,
                borderRadius: BorderRadius.circular(AppDimens.radiusCard),
              ),
              child: const _UnitsTile(),
            ),
          ),

          // ── Emergency Health Card ────────────────────────────────────────
          const SettingsSectionLabel('Medical'),
          ZSettingsGroup(
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
          ZSettingsGroup(
            tiles: [
              ZSettingsTile(
                icon: Icons.logout_rounded,
                iconColor: colors.primary,
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
          color: colors.surface,
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
              color: colors.textTertiary,
            ),
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
          SizedBox(
            width: 160,
            child: ZSegmentedControl(
              selectedIndex: current == UnitsSystem.metric ? 0 : 1,
              segments: const ['Metric', 'Imperial'],
              onChanged: (i) {
                final unit =
                    i == 0 ? UnitsSystem.metric : UnitsSystem.imperial;
                if (unit != current) {
                  ref.read(hapticServiceProvider).selectionTick();
                  ref.read(userPreferencesProvider.notifier).mutate(
                    (p) => p.copyWith(unitsSystem: unit),
                  );
                }
              },
            ),
          ),
        ],
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
    final currentEmail = ref.read(userEmailProvider);
    if (email == currentEmail) {
      setState(() => _error = 'This is already your current email address.');
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
          color: colors.surface,
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
      String message;
      if (e.response?.statusCode == 401) {
        message = 'Password change is not available for accounts signed in with Google or Apple.';
      } else {
        message = e.response?.data?['detail'] as String? ?? 'Something went wrong. Try again.';
      }
      setState(() => _error = message);
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
          color: colors.surface,
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
        ZButton(
          label: 'Cancel',
          onPressed: () => Navigator.pop(dialogCtx),
          variant: ZButtonVariant.text,
          isFullWidth: false,
        ),
        ZButton(
          label: 'Sign Out',
          onPressed: () {
            Navigator.pop(dialogCtx);
            ref.read(hapticServiceProvider).warning();
            ref.read(authStateProvider.notifier).logout();
          },
          variant: ZButtonVariant.text,
          isFullWidth: false,
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
      backgroundColor: colors.surface,
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
        ZButton(
          label: 'Cancel',
          onPressed: () => Navigator.pop(dialogCtx),
          variant: ZButtonVariant.text,
          isFullWidth: false,
        ),
        ZButton(
          label: 'Continue',
          onPressed: () {
            Navigator.pop(dialogCtx);
            _showDeleteAccountStep2Dialog(context, ref);
          },
          variant: ZButtonVariant.destructive,
          isFullWidth: false,
        ),
      ],
    ),
  );
}

/// Step 2: type-to-confirm dialog.
void _showDeleteAccountStep2Dialog(BuildContext context, WidgetRef ref) {
  showDialog<void>(
    context: context,
    builder: (dialogCtx) => const _DeleteConfirmDialog(),
  );
}

class _DeleteConfirmDialog extends ConsumerStatefulWidget {
  const _DeleteConfirmDialog();

  @override
  ConsumerState<_DeleteConfirmDialog> createState() =>
      _DeleteConfirmDialogState();
}

class _DeleteConfirmDialogState extends ConsumerState<_DeleteConfirmDialog> {
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
      await ref
          .read(userProfileProvider.notifier)
          .deleteAccount();
      // Wipe local state and route to welcome screen.
      await ref.read(authStateProvider.notifier).logout();
    } catch (e) {
      // If the server confirms the account is already gone (404/410), clear
      // local session so the user isn't stuck on a screen for a deleted account.
      if (e is DioException &&
          (e.response?.statusCode == 404 ||
              e.response?.statusCode == 410)) {
        await ref.read(authStateProvider.notifier).logout();
        return;
      }
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
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
      backgroundColor: colors.surface,
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
        ZButton(
          label: 'Cancel',
          onPressed: _loading ? null : () => Navigator.pop(context),
          variant: ZButtonVariant.text,
          isFullWidth: false,
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
            : ZButton(
                label: 'Delete Account',
                onPressed: confirmed ? _confirm : null,
                variant: ZButtonVariant.destructive,
                isFullWidth: false,
              ),
      ],
    );
  }
}
