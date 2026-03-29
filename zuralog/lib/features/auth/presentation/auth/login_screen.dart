/// Zuralog Edge Agent — Login Screen.
///
/// Standalone email/password login form with:
/// - Autofill group (iOS Keychain / Android autofill)
/// - Blur-only email validation + ZEmailTypoSuggestion
/// - Escalating hint after 2 failures
/// - Analytics on login failure
/// - HapticFeedback on success and failure
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/core/analytics/analytics_events.dart';
import 'package:zuralog/core/analytics/analytics_service.dart';
import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/auth/domain/auth_providers.dart';
import 'package:zuralog/features/auth/domain/auth_state.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

/// Standalone login screen.
///
/// Wires directly to [authStateProvider.notifier.login]. On success, the
/// GoRouter auth guard automatically navigates the user to the dashboard.
class LoginScreen extends ConsumerStatefulWidget {
  /// Creates a [LoginScreen].
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  // ── Form ───────────────────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  // ── State ──────────────────────────────────────────────────────────────────
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _emailTouched = false;
  int _loginFailureCount = 0;
  String? _emailError;

  @override
  void initState() {
    super.initState();

    // Blur listener: validate email format when user leaves the email field.
    _emailFocusNode.addListener(_onEmailFocusChange);

    // Text listener: rebuilds to show/hide ZEmailTypoSuggestion.
    _emailCtrl.addListener(_onEmailTextChange);

    // Auto-focus the email field after the first frame is drawn.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) _emailFocusNode.requestFocus();
      });
    });
  }

  @override
  void dispose() {
    _emailFocusNode.removeListener(_onEmailFocusChange);
    _emailCtrl.removeListener(_onEmailTextChange);
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ── Listeners ──────────────────────────────────────────────────────────────

  void _onEmailFocusChange() {
    // Validate inline only on blur, and only if the user has already typed.
    if (!_emailFocusNode.hasFocus && _emailTouched) {
      _validateEmailInline(_emailCtrl.text);
    }
  }

  void _onEmailTextChange() {
    // Trigger rebuild so ZEmailTypoSuggestion updates as the user types.
    setState(() {});
  }

  // ── Validation ─────────────────────────────────────────────────────────────

  void _validateEmailInline(String value) {
    String? error;
    if (value.trim().isEmpty) {
      error = 'Please enter your email';
    } else if (!value.contains('@') || !value.contains('.')) {
      error = 'Please enter a valid email';
    }
    setState(() => _emailError = error);
  }

  // ── Error translation ──────────────────────────────────────────────────────

  String _translateError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('invalid_credentials') ||
        lower.contains('invalid login credentials')) {
      return 'Wrong email or password. Try again.';
    }
    if (lower.contains('email_not_confirmed')) {
      return 'Please verify your email. Check your inbox for a verification link.';
    }
    return 'Something went wrong. Please try again.';
  }

  // ── Login handler ──────────────────────────────────────────────────────────

  Future<void> _handleLogin() async {
    // Mark email as touched so blur validation fires from now on.
    setState(() => _emailTouched = true);

    // Run inline email validation before the full form validate.
    _validateEmailInline(_emailCtrl.text);

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    try {
      final result = await ref.read(authStateProvider.notifier).login(
            _emailCtrl.text.trim(),
            _passwordCtrl.text,
          );

      if (!mounted) return;

      switch (result) {
        case AuthSuccess():
          // Tell the platform autofill service that we're done — persists
          // the credentials to Keychain / Android credential store.
          TextInput.finishAutofillContext();
          HapticFeedback.lightImpact();
          // GoRouter auth guard navigates to dashboard automatically.

        case AuthFailure(:final message):
          HapticFeedback.heavyImpact();
          final translated = _translateError(message);
          setState(() => _loginFailureCount++);
          ref.read(analyticsServiceProvider).capture(
            event: AnalyticsEvents.loginFailed,
            properties: {'method': 'email', 'error_type': message},
          );
          if (mounted) ZToast.error(context, translated);
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
                context.go(RouteNames.welcomePath);
              }
            },
          ),

          // Scrollable form content.
          Expanded(
            child: SingleChildScrollView(
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.spaceLg,
                      vertical: AppDimens.spaceLg,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Headline ──────────────────────────────────────
                        Text(
                          'Welcome back.',
                          style: AppTextStyles.displayMedium.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppDimens.spaceXs),
                        Text(
                          'Log in to your account.',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppDimens.spaceLg),

                        // ── Email field ───────────────────────────────────
                        AppTextField(
                          controller: _emailCtrl,
                          focusNode: _emailFocusNode,
                          labelText: 'Email',
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          onEditingComplete: () {
                            setState(() => _emailTouched = true);
                            _validateEmailInline(_emailCtrl.text);
                            _passwordFocusNode.requestFocus();
                          },
                          validator: (_) => _emailError,
                        ),

                        // ── Email typo suggestion ─────────────────────────
                        ZEmailTypoSuggestion(
                          email: _emailCtrl.text,
                          onAccept: () {
                            final suggestion =
                                detectEmailTypo(_emailCtrl.text);
                            if (suggestion != null) {
                              _emailCtrl.text = suggestion;
                              _emailCtrl.selection =
                                  TextSelection.collapsed(
                                offset: suggestion.length,
                              );
                            }
                            _validateEmailInline(_emailCtrl.text);
                          },
                        ),
                        const SizedBox(height: AppDimens.spaceMd),

                        // ── Password field ────────────────────────────────
                        AppTextField(
                          controller: _passwordCtrl,
                          focusNode: _passwordFocusNode,
                          labelText: 'Password',
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          onEditingComplete: _handleLogin,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            color: colors.textSecondary,
                          ),
                          validator: (value) =>
                              (value == null || value.isEmpty)
                                  ? 'Please enter your password'
                                  : null,
                        ),
                        const SizedBox(height: AppDimens.spaceSm),

                        // ── Forgot password link ──────────────────────────
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () =>
                                context.push(RouteNames.forgotPasswordPath),
                            child: Text(
                              'Forgot password?',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          ),
                        ),

                        // ── Escalating hint after 2 failures ─────────────
                        if (_loginFailureCount >= 2) ...[
                          Container(
                            padding: const EdgeInsets.all(AppDimens.spaceMd),
                            decoration: BoxDecoration(
                              color: colors.surfaceRaised,
                              borderRadius: BorderRadius.circular(
                                AppDimens.shapeSm,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  size: 16,
                                  color: colors.textSecondary,
                                ),
                                const SizedBox(width: AppDimens.spaceSm),
                                Expanded(
                                  child: Text(
                                    'Having trouble? Try resetting your password.',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: AppDimens.spaceLg),

                        // ── Primary CTA ───────────────────────────────────
                        ZButton(
                          label: 'Log In',
                          isLoading: _isLoading,
                          onPressed: _isLoading ? null : _handleLogin,
                        ),
                        const SizedBox(height: AppDimens.spaceLg),

                        // ── Footer: sign up link ──────────────────────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Don't have an account? ",
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
                              onPressed: () =>
                                  context.go(RouteNames.registerPath),
                              child: Text(
                                'Sign up',
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
          ),
        ],
      ),
    );
  }
}
