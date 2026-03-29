/// Zuralog Edge Agent — Forgot Password Screen.
///
/// Collects the user's email and calls the password-reset API endpoint.
/// On success, navigates to [CheckInboxScreen] with context=reset.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/auth/domain/auth_providers.dart';
import 'package:zuralog/features/auth/domain/auth_state.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

/// Forgot password screen.
///
/// Prompts the user for their account email and, on submit, calls the
/// password-reset API. On success, navigates to [CheckInboxScreen] with
/// `context=reset` to indicate a password-reset flow.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  /// Creates a [ForgotPasswordScreen].
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  // ── Form ───────────────────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _emailFocusNode = FocusNode();

  // ── State ──────────────────────────────────────────────────────────────────
  bool _isLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  // ── Send handler ───────────────────────────────────────────────────────────

  Future<void> _handleSend() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final email = _emailCtrl.text.trim();

    setState(() => _isLoading = true);

    try {
      final result = await ref.read(authRepositoryProvider).resetPassword(email);

      if (!mounted) return;

      switch (result) {
        case AuthSuccess():
          context.go(
            '${RouteNames.checkInboxPath}'
            '?email=${Uri.encodeComponent(email)}&context=reset',
          );
        case AuthFailure(:final message):
          ZToast.error(context, message);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    return ZuralogScaffold(
      resizeToAvoidBottomInset: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top bar with back button + centered logo.
          ZAuthTopBar(
            showBack: true,
            onBack: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(RouteNames.loginPath);
              }
            },
          ),

          // Scrollable form content.
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
                      // ── Icon tile ─────────────────────────────────────────
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

                      // ── Headline ──────────────────────────────────────────
                      Text(
                        'Reset your password.',
                        style: AppTextStyles.displayMedium.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppDimens.spaceXs),
                      Text(
                        "Enter the email you used to create your account. "
                        "We'll send you a reset link.",
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppDimens.spaceLg),

                      // ── Email field ───────────────────────────────────────
                      AppTextField(
                        controller: _emailCtrl,
                        focusNode: _emailFocusNode,
                        labelText: 'Email',
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.email],
                        onEditingComplete: _handleSend,
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                                ? 'Please enter your email'
                                : null,
                      ),
                      const SizedBox(height: AppDimens.spaceLg),

                      // ── Primary CTA ───────────────────────────────────────
                      ZButton(
                        label: 'Send Reset Link',
                        isLoading: _isLoading,
                        onPressed: _isLoading ? null : _handleSend,
                      ),
                      const SizedBox(height: AppDimens.spaceLg),

                      // ── Footer: back to log in ─────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Remember your password? ',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () {
                              if (context.canPop()) {
                                context.pop();
                              } else {
                                context.go(RouteNames.loginPath);
                              }
                            },
                            child: Text(
                              'Log in',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
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
