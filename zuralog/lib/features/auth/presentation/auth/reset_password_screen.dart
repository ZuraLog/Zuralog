/// Zuralog Edge Agent — Reset Password Screen.
///
/// Deep link target for password reset. The user arrives here after tapping
/// the reset link in their email. Collects a new password and updates it
/// via the recovery access token stored during deep link handling.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/auth/domain/auth_providers.dart';
import 'package:zuralog/features/auth/domain/auth_state.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _passwordFocusNode = FocusNode();
  final _confirmFocusNode = FocusNode();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _passwordFocusNode.dispose();
    _confirmFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final uri = GoRouterState.of(context).uri;
    final accessToken = uri.queryParameters['access_token'] ?? '';

    if (accessToken.isEmpty) {
      if (mounted) {
        ZToast.error(context, 'Invalid reset link. Please request a new one.');
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await ref.read(authRepositoryProvider).setNewPassword(
            accessToken: accessToken,
            newPassword: _passwordCtrl.text,
          );

      if (!mounted) return;

      switch (result) {
        case AuthSuccess():
          ZToast.success(context, 'Password updated! You can now log in.');
          context.go(RouteNames.loginPath);
        case AuthFailure(:final message):
          ZToast.error(context, message);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    return ZuralogScaffold(
      resizeToAvoidBottomInset: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ZAuthTopBar(showBack: false),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceLg,
                  vertical: AppDimens.spaceLg,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: colors.surfaceRaised,
                            borderRadius:
                                BorderRadius.circular(AppDimens.shapeMd),
                          ),
                          child: Icon(
                            Icons.lock_reset_rounded,
                            size: 28,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppDimens.spaceLg),
                      Text(
                        'Set your new password.',
                        style: AppTextStyles.displayMedium.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppDimens.spaceXs),
                      Text(
                        'Choose a strong password for your account.',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppDimens.spaceLg),
                      AppTextField(
                        controller: _passwordCtrl,
                        focusNode: _passwordFocusNode,
                        labelText: 'New password',
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.newPassword],
                        onEditingComplete: () =>
                            _confirmFocusNode.requestFocus(),
                        onChanged: (_) => setState(() {}),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: colors.textSecondary,
                            size: 20,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a password';
                          }
                          if (value.length < 8) {
                            return 'Password must be at least 8 characters';
                          }
                          return null;
                        },
                      ),
                      ZPasswordRequirements(password: _passwordCtrl.text),
                      const SizedBox(height: AppDimens.spaceMd),
                      AppTextField(
                        controller: _confirmCtrl,
                        focusNode: _confirmFocusNode,
                        labelText: 'Confirm password',
                        obscureText: _obscureConfirm,
                        textInputAction: TextInputAction.done,
                        onEditingComplete: _handleSubmit,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirm
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: colors.textSecondary,
                            size: 20,
                          ),
                          onPressed: () => setState(
                            () => _obscureConfirm = !_obscureConfirm,
                          ),
                        ),
                        validator: (value) {
                          if (value != _passwordCtrl.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppDimens.spaceLg),
                      ZButton(
                        label: 'Update Password',
                        isLoading: _isLoading,
                        onPressed: _isLoading ? null : _handleSubmit,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
