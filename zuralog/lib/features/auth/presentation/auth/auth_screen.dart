/// Zuralog Edge Agent — Combined Auth Screen (v4.0 brand bible redesign).
///
/// Uses [ZSegmentedControl] to switch between Login and Create Account.
/// All UI elements use the shared design system components (ZButton,
/// ZIconButton, AppTextField, ZSegmentedControl).
///
/// **Backend wiring is 100% unchanged:**
/// - Login: [authStateProvider.notifier.login(email, password)]
/// - Register: [authStateProvider.notifier.register(email, password)]
/// - Analytics: [loginFailed] / [signUpFailed] events preserved exactly
/// - Sentry breadcrumbs: included in [AuthStateNotifier] (unchanged)
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/core/analytics/analytics_events.dart';
import 'package:zuralog/core/analytics/analytics_service.dart';
import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/auth/domain/auth_providers.dart';
import 'package:zuralog/features/auth/domain/auth_state.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

/// Combined login + register screen with a [ZSegmentedControl] toggle.
///
/// [initialTab]: 0 = Log in, 1 = Create account.
/// The router sends both `/auth/login` and `/auth/register` here.
class AuthScreen extends ConsumerStatefulWidget {
  /// Creates an [AuthScreen].
  const AuthScreen({super.key, this.initialTab = 0});

  /// Initial tab index: 0 = Log in, 1 = Create account.
  final int initialTab;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  // ── Segment selection ───────────────────────────────────────────────────────
  late int _selectedIndex = widget.initialTab;

  // ── Shared form state ──────────────────────────────────────────────────────
  final GlobalKey<FormState> _loginFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _registerFormKey = GlobalKey<FormState>();

  final TextEditingController _loginEmailCtrl = TextEditingController();
  final TextEditingController _loginPasswordCtrl = TextEditingController();
  final TextEditingController _registerEmailCtrl = TextEditingController();
  final TextEditingController _registerPasswordCtrl = TextEditingController();

  bool _loginObscure = true;
  bool _registerObscure = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _loginEmailCtrl.dispose();
    _loginPasswordCtrl.dispose();
    _registerEmailCtrl.dispose();
    _registerPasswordCtrl.dispose();
    super.dispose();
  }

  // ── Validation ─────────────────────────────────────────────────────────────

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    if (!value.contains('@') || !value.contains('.')) {
      return 'Enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  // ── Forgot Password ────────────────────────────────────────────────────────

  Future<void> _handleForgotPassword() async {
    final email = _loginEmailCtrl.text.trim();
    if (email.isEmpty) {
      _showError('Enter your email address first');
      return;
    }

    setState(() => _isLoading = true);

    final result = await ref
        .read(authRepositoryProvider)
        .resetPassword(email);

    if (!mounted) return;
    setState(() => _isLoading = false);

    switch (result) {
      case AuthSuccess():
        if (mounted) {
          ZToast.success(context, 'Password reset email sent — check your inbox');
        }
      case AuthFailure(:final message):
        _showError(message);
    }
  }

  // ── Login ──────────────────────────────────────────────────────────────────

  Future<void> _handleLogin() async {
    if (!(_loginFormKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);

    final result = await ref.read(authStateProvider.notifier).login(
          _loginEmailCtrl.text.trim(),
          _loginPasswordCtrl.text,
        );

    if (!mounted) return;
    setState(() => _isLoading = false);

    switch (result) {
      case AuthSuccess():
        // GoRouter auth guard navigates to dashboard automatically.
        break;
      case AuthFailure(:final message):
        ref.read(analyticsServiceProvider).capture(
          event: AnalyticsEvents.loginFailed,
          properties: {'method': 'email', 'error_type': message},
        );
        _showError(message);
    }
  }

  // ── Register ───────────────────────────────────────────────────────────────

  Future<void> _handleRegister() async {
    if (!(_registerFormKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);

    final result = await ref.read(authStateProvider.notifier).register(
          _registerEmailCtrl.text.trim(),
          _registerPasswordCtrl.text,
        );

    if (!mounted) return;
    setState(() => _isLoading = false);

    switch (result) {
      case AuthSuccess():
        // Router guard redirects to profile questionnaire automatically.
        break;
      case AuthFailure(:final message):
        ref.read(analyticsServiceProvider).capture(
          event: AnalyticsEvents.signUpFailed,
          properties: {'method': 'email', 'error_type': message},
        );
        _showError(message);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ZToast.error(context, message);
  }

  @override
  Widget build(BuildContext context) {
    return ZuralogScaffold(
      body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Custom top bar ────────────────────────────────────────
            _TopBar(onBack: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(RouteNames.welcomePath);
              }
            }),

            // ── Segmented control ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceLg,
              ),
              child: ZSegmentedControl(
                selectedIndex: _selectedIndex,
                onChanged: (i) => setState(() => _selectedIndex = i),
                segments: const ['Log in', 'Create account'],
              ),
            ),

            const SizedBox(height: AppDimens.spaceSm),

            // ── Form content (IndexedStack preserves form state) ─────
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: [
                  // Login tab
                  _LoginForm(
                    formKey: _loginFormKey,
                    emailCtrl: _loginEmailCtrl,
                    passwordCtrl: _loginPasswordCtrl,
                    obscurePassword: _loginObscure,
                    isLoading: _isLoading,
                    onToggleObscure: () =>
                        setState(() => _loginObscure = !_loginObscure),
                    onSubmit: _handleLogin,
                    onForgotPassword: _handleForgotPassword,
                    onSwitchToRegister: () =>
                        setState(() => _selectedIndex = 1),
                    validateEmail: _validateEmail,
                    validatePassword: _validatePassword,
                  ),

                  // Register tab
                  _RegisterForm(
                    formKey: _registerFormKey,
                    emailCtrl: _registerEmailCtrl,
                    passwordCtrl: _registerPasswordCtrl,
                    obscurePassword: _registerObscure,
                    isLoading: _isLoading,
                    onToggleObscure: () =>
                        setState(() => _registerObscure = !_registerObscure),
                    onSubmit: _handleRegister,
                    onSwitchToLogin: () =>
                        setState(() => _selectedIndex = 0),
                    validateEmail: _validateEmail,
                    validatePassword: _validatePassword,
                  ),
                ],
              ),
            ),
          ],
        ),
    );
  }
}

// ── Top Bar ────────────────────────────────────────────────────────────────────

/// Custom top bar: back chevron + "Zuralog" wordmark + balancing spacer.
///
/// In debug builds, triple-tapping the wordmark opens the component showcase.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceSm,
        vertical: AppDimens.spaceSm,
      ),
      child: Row(
        children: [
          ZIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onPressed: onBack,
            filled: false,
            semanticLabel: 'Back',
          ),
          Expanded(
            child: Center(
              child: GestureDetector(
                onDoubleTap: kDebugMode
                    ? () => context.push(RouteNames.componentShowcasePath)
                    : null,
                child: Text(
                  'Zuralog',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ),
          // Mirror of icon button width (44px) to keep wordmark centered.
          const SizedBox(width: 44),
        ],
      ),
    );
  }
}

// ── Login Form ─────────────────────────────────────────────────────────────────

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.formKey,
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.obscurePassword,
    required this.isLoading,
    required this.onToggleObscure,
    required this.onSubmit,
    required this.onForgotPassword,
    required this.onSwitchToRegister,
    required this.validateEmail,
    required this.validatePassword,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final bool obscurePassword;
  final bool isLoading;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;
  final VoidCallback onForgotPassword;
  final VoidCallback onSwitchToRegister;
  final FormFieldValidator<String> validateEmail;
  final FormFieldValidator<String> validatePassword;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimens.spaceLg),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: AppDimens.spaceLg),

                  Text(
                    'Welcome back.',
                    style: AppTextStyles.displayLarge.copyWith(
                      color: AppColorsOf(context).textPrimary,
                    ),
                  ),

                  const SizedBox(height: AppDimens.spaceSm),

                  Text(
                    'Sign in to continue.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColorsOf(context).textSecondary,
                    ),
                  ),

                  const SizedBox(height: AppDimens.spaceXl),

                  AppTextField(
                    hintText: 'Email address',
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    controller: emailCtrl,
                    validator: validateEmail,
                  ),

                  const SizedBox(height: AppDimens.spaceMd),

                  AppTextField(
                    hintText: 'Password',
                    obscureText: obscurePassword,
                    textInputAction: TextInputAction.done,
                    controller: passwordCtrl,
                    validator: validatePassword,
                    onSubmitted: onSubmit,
                    suffixIcon: ZIconButton(
                      icon: obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      onPressed: onToggleObscure,
                      filled: false,
                      iconSize: 20,
                      semanticLabel: 'Toggle password visibility',
                    ),
                  ),

                  const SizedBox(height: AppDimens.spaceSm),

                  // "Forgot password?" — right-aligned Sage text link
                  Align(
                    alignment: Alignment.centerRight,
                    child: Semantics(
                      button: true,
                      label: 'Forgot password',
                      child: GestureDetector(
                        onTap: isLoading ? null : onForgotPassword,
                        behavior: HitTestBehavior.opaque,
                        child: SizedBox(
                          height: AppDimens.touchTargetMin,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppDimens.spaceSm,
                            ),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                'Forgot password?',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppDimens.spaceXl),

                  // Primary CTA — Sage fill + pattern
                  ZButton(
                    label: 'Log In',
                    onPressed: isLoading ? null : onSubmit,
                    isLoading: isLoading,
                  ),

                  const SizedBox(height: AppDimens.spaceMd),

                  // Footer — switch to register
                  Center(
                    child: SizedBox(
                      height: AppDimens.touchTargetMin,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Don't have an account? ",
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColorsOf(context).textSecondary,
                            ),
                          ),
                          Semantics(
                            button: true,
                            label: 'Sign up for a new account',
                            child: GestureDetector(
                              onTap: onSwitchToRegister,
                              behavior: HitTestBehavior.opaque,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppDimens.spaceSm,
                                ),
                                child: Text(
                                  'Sign up',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Register Form ─────────────────────────────────────────────────────────────

class _RegisterForm extends StatelessWidget {
  const _RegisterForm({
    required this.formKey,
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.obscurePassword,
    required this.isLoading,
    required this.onToggleObscure,
    required this.onSubmit,
    required this.onSwitchToLogin,
    required this.validateEmail,
    required this.validatePassword,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final bool obscurePassword;
  final bool isLoading;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;
  final VoidCallback onSwitchToLogin;
  final FormFieldValidator<String> validateEmail;
  final FormFieldValidator<String> validatePassword;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimens.spaceLg),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: AppDimens.spaceLg),

                  Text(
                    'Create account.',
                    style: AppTextStyles.displayLarge.copyWith(
                      color: AppColorsOf(context).textPrimary,
                    ),
                  ),

                  const SizedBox(height: AppDimens.spaceSm),

                  Text(
                    'Start your health journey.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColorsOf(context).textSecondary,
                    ),
                  ),

                  const SizedBox(height: AppDimens.spaceXl),

                  AppTextField(
                    hintText: 'Email address',
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    controller: emailCtrl,
                    validator: validateEmail,
                  ),

                  const SizedBox(height: AppDimens.spaceMd),

                  AppTextField(
                    hintText: 'Password',
                    obscureText: obscurePassword,
                    textInputAction: TextInputAction.done,
                    controller: passwordCtrl,
                    validator: validatePassword,
                    onSubmitted: onSubmit,
                    suffixIcon: ZIconButton(
                      icon: obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      onPressed: onToggleObscure,
                      filled: false,
                      iconSize: 20,
                      semanticLabel: 'Toggle password visibility',
                    ),
                  ),

                  const SizedBox(height: AppDimens.spaceXl),

                  // Primary CTA — Sage fill + pattern
                  ZButton(
                    label: 'Create Account',
                    onPressed: isLoading ? null : onSubmit,
                    isLoading: isLoading,
                  ),

                  const SizedBox(height: AppDimens.spaceMd),

                  // Footer — switch to login
                  Center(
                    child: SizedBox(
                      height: AppDimens.touchTargetMin,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Already have an account? ',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColorsOf(context).textSecondary,
                            ),
                          ),
                          Semantics(
                            button: true,
                            label: 'Log in to existing account',
                            child: GestureDetector(
                              onTap: onSwitchToLogin,
                              behavior: HitTestBehavior.opaque,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppDimens.spaceSm,
                                ),
                                child: Text(
                                  'Log in',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
