/// Zuralog Edge Agent — Register Screen.
///
/// Standalone email/password registration form with:
/// - Autofill group (iOS Keychain / Android autofill)
/// - Blur-only email validation + ZEmailTypoSuggestion
/// - Live ZPasswordStrengthBar and collapsing ZPasswordRequirements
/// - Inline "email already exists" error shown below the email field
/// - ToS / Privacy Policy links via TapGestureRecognizer + url_launcher
/// - Analytics on register failure
/// - HapticFeedback on success and failure
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:zuralog/core/analytics/analytics_events.dart';
import 'package:zuralog/core/analytics/analytics_service.dart';
import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/auth/domain/auth_providers.dart';
import 'package:zuralog/features/auth/domain/auth_state.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

/// Standalone registration screen.
///
/// Wires directly to [authStateProvider.notifier.register]. On success,
/// navigates to [RouteNames.checkInboxPath] with the email address and a
/// `context=verification` query parameter so the inbox screen knows what
/// message to show.
class RegisterScreen extends ConsumerStatefulWidget {
  /// Creates a [RegisterScreen].
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
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
  bool _passwordFocused = false;
  String? _inlineEmailError;

  // ── Gesture recognizers ───────────────────────────────────────────────────
  late final TapGestureRecognizer _tosRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;

  @override
  void initState() {
    super.initState();

    // Blur listener: validate email format when user leaves the email field.
    _emailFocusNode.addListener(_onEmailFocusChange);

    // Password focus listener: show/hide strength bar + requirements.
    _passwordFocusNode.addListener(_onPasswordFocusChange);

    // Password text listener: rebuild so strength bar + requirements update live.
    _passwordCtrl.addListener(_onPasswordTextChange);

    // ToS / Privacy links.
    _tosRecognizer = TapGestureRecognizer()
      ..onTap = () => launchUrl(
            Uri.parse('https://www.zuralog.com/terms-of-service'),
            mode: LaunchMode.externalApplication,
          );
    _privacyRecognizer = TapGestureRecognizer()
      ..onTap = () => launchUrl(
            Uri.parse('https://www.zuralog.com/privacy-policy'),
            mode: LaunchMode.externalApplication,
          );
  }

  @override
  void dispose() {
    _emailFocusNode.removeListener(_onEmailFocusChange);
    _passwordFocusNode.removeListener(_onPasswordFocusChange);
    _passwordCtrl.removeListener(_onPasswordTextChange);
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _tosRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  // ── Listeners ──────────────────────────────────────────────────────────────

  void _onEmailFocusChange() {
    // Validate inline only on blur, and only if the user has already typed.
    if (!_emailFocusNode.hasFocus && _emailTouched) {
      _validateEmailInline(_emailCtrl.text);
    }
  }

  void _onPasswordFocusChange() {
    setState(() => _passwordFocused = _passwordFocusNode.hasFocus);
  }

  void _onPasswordTextChange() {
    // Trigger rebuild so strength bar + requirements update as the user types.
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
    setState(() => _inlineEmailError = error);
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Must be at least 8 characters';
    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Must contain at least one number';
    }
    return null;
  }

  // ── Error translation ──────────────────────────────────────────────────────

  /// Returns `null` for duplicate-email errors (handled inline instead) or a
  /// human-readable message for everything else.
  String? _translateError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('user_already_exists') ||
        lower.contains('user already registered')) {
      return null; // handled inline below the email field
    }
    if (lower.contains('rate') || lower.contains('too many')) {
      return 'Please wait a moment before trying again.';
    }
    return 'Something went wrong. Please try again.';
  }

  // ── Register handler ───────────────────────────────────────────────────────

  Future<void> _handleRegister() async {
    // Mark email as touched so blur validation fires from now on.
    setState(() => _emailTouched = true);
    _validateEmailInline(_emailCtrl.text);

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    try {
      final email = _emailCtrl.text.trim();
      final result = await ref.read(authStateProvider.notifier).register(
            email,
            _passwordCtrl.text,
          );

      if (!mounted) return;

      switch (result) {
        case AuthSuccess():
          TextInput.finishAutofillContext();
          HapticFeedback.lightImpact();
          context.go(
            '${RouteNames.checkInboxPath}?email=${Uri.encodeComponent(email)}&context=verification',
          );

        case AuthFailure(:final message):
          HapticFeedback.heavyImpact();
          final translated = _translateError(message);
          ref.read(analyticsServiceProvider).capture(
            event: AnalyticsEvents.signUpFailed,
            properties: {'method': 'email', 'error_type': message},
          );
          if (translated == null) {
            // Duplicate email — show inline error below email field.
            setState(() => _inlineEmailError =
                'An account with this email already exists');
            // Re-validate the form so the email field shows the error.
            _formKey.currentState?.validate();
          } else {
            if (mounted) ZToast.error(context, translated);
          }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final showStrengthWidgets =
        _passwordFocused || _passwordCtrl.text.isNotEmpty;

    return ZuralogScaffold(
      resizeToAvoidBottomInset: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top bar with back button + centered logo.
          ZAuthTopBar(
            showBack: true,
            onBack: () => context.go(RouteNames.loginPath),
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
                          'Create account.',
                          style: AppTextStyles.displayMedium.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppDimens.spaceXs),
                        Text(
                          'Join ZuraLog and start tracking.',
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
                          validator: (_) => _inlineEmailError,
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
                          labelText: 'Create password',
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.newPassword],
                          onEditingComplete: _handleRegister,
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
                          validator: _validatePassword,
                        ),

                        // ── Password strength bar (always if non-empty) ────
                        if (showStrengthWidgets) ...[
                          ZPasswordStrengthBar(
                            password: _passwordCtrl.text,
                          ),
                          ZPasswordRequirements(
                            password: _passwordCtrl.text,
                          ),
                        ],

                        const SizedBox(height: AppDimens.spaceLg),

                        // ── Primary CTA ───────────────────────────────────
                        ZButton(
                          label: 'Create Account',
                          isLoading: _isLoading,
                          onPressed: _isLoading ? null : _handleRegister,
                        ),
                        const SizedBox(height: AppDimens.spaceMd),

                        // ── ToS / Privacy notice ──────────────────────────
                        Center(
                          child: RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: AppTextStyles.bodySmall.copyWith(
                                color: colors.textSecondary,
                              ),
                              children: [
                                const TextSpan(
                                    text:
                                        'By creating an account, you agree to our '),
                                TextSpan(
                                  text: 'Terms of Service',
                                  recognizer: _tosRecognizer,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: colors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const TextSpan(text: ' and '),
                                TextSpan(
                                  text: 'Privacy Policy',
                                  recognizer: _privacyRecognizer,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: colors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const TextSpan(text: '.'),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppDimens.spaceLg),

                        // ── Footer: log in link ───────────────────────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Already have an account? ',
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
                                  context.go(RouteNames.loginPath),
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
          ),
        ],
      ),
    );
  }
}
