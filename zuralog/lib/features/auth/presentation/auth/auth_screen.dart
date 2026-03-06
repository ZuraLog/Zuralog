/// Zuralog Edge Agent — Combined Auth Screen (v3.2).
///
/// Replaces the separate [LoginScreen] and [RegisterScreen] with a single
/// screen that uses a [TabBar] toggle to switch between Login and Create Account.
/// Spring-animated tab content, AppTextField inputs, and ZuralogSpringButton CTAs.
///
/// **Backend wiring is 100% unchanged:**
/// - Login: [authStateProvider.notifier.login(email, password)]
/// - Register: [authStateProvider.notifier.register(email, password)]
/// - Analytics: [loginFailed] / [signUpFailed] events preserved exactly
/// - Sentry breadcrumbs: included in [AuthStateNotifier] (unchanged)
library;

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

/// Combined login + register screen with a [TabBar] to switch between modes.
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

class _AuthScreenState extends ConsumerState<AuthScreen>
    with SingleTickerProviderStateMixin {
  // ── Tab controller ─────────────────────────────────────────────────────────
  late final TabController _tabController;

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
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Custom top bar (not AppBar) ────────────────────────────
            _TopBar(onBack: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(RouteNames.welcomePath);
              }
            }),

            // ── TabBar ─────────────────────────────────────────────────
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Log in'),
                Tab(text: 'Create account'),
              ],
              indicatorColor: AppColors.primary,
              indicatorWeight: 2,
              labelStyle: AppTextStyles.h3,
              unselectedLabelStyle: AppTextStyles.bodyMedium,
              labelColor: colorScheme.onSurface,
              unselectedLabelColor: AppColors.textSecondary,
              dividerColor: Colors.transparent,
            ),

            // ── TabBarView ─────────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
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
                    onSwitchToRegister: () => _tabController.animateTo(1),
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
                    onSwitchToLogin: () => _tabController.animateTo(0),
                    validateEmail: _validateEmail,
                    validatePassword: _validatePassword,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Top Bar ────────────────────────────────────────────────────────────────────

/// Custom top bar: back chevron + "Zuralog" wordmark + balancing spacer.
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
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            iconSize: 20,
            onPressed: onBack,
            tooltip: 'Back',
          ),
          Expanded(
            child: Center(
              child: Text(
                'Zuralog',
                style: AppTextStyles.h3.copyWith(color: AppColors.primary),
              ),
            ),
          ),
          // Mirror of icon button width to keep wordmark centered.
          const SizedBox(width: 48),
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
  final VoidCallback onSwitchToRegister;
  final FormFieldValidator<String> validateEmail;
  final FormFieldValidator<String> validatePassword;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimens.spaceLg),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppDimens.spaceLg),

            Text('Welcome back.', style: AppTextStyles.h1),

            const SizedBox(height: AppDimens.spaceSm),

            Text(
              'Sign in to continue.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
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
              suffixIcon: IconButton(
                icon: Icon(
                  obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: onToggleObscure,
              ),
            ),

            const SizedBox(height: AppDimens.spaceSm),

            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  // TODO(dev): Implement forgot password flow.
                },
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.spaceSm,
                    vertical: AppDimens.spaceXs,
                  ),
                  foregroundColor: AppColors.textSecondary,
                ),
                child: Text(
                  'Forgot password?',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),

            const SizedBox(height: AppDimens.spaceXl),

            ZuralogSpringButton(
              onTap: isLoading ? null : onSubmit,
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: isLoading ? null : onSubmit,
                  child: isLoading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.primaryButtonText,
                          ),
                        )
                      : const Text('Log In'),
                ),
              ),
            ),

            const SizedBox(height: AppDimens.spaceMd),

            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Don't have an account? ",
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  TextButton(
                    onPressed: onSwitchToRegister,
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.spaceSm,
                        vertical: AppDimens.spaceXs,
                      ),
                    ),
                    child: Text(
                      'Sign up',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimens.spaceLg),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppDimens.spaceLg),

            Text('Create account.', style: AppTextStyles.h1),

            const SizedBox(height: AppDimens.spaceSm),

            Text(
              'Start your health journey.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
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
              suffixIcon: IconButton(
                icon: Icon(
                  obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: onToggleObscure,
              ),
            ),

            const SizedBox(height: AppDimens.spaceXl),

            ZuralogSpringButton(
              onTap: isLoading ? null : onSubmit,
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: isLoading ? null : onSubmit,
                  child: isLoading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.primaryButtonText,
                          ),
                        )
                      : const Text('Create Account'),
                ),
              ),
            ),

            const SizedBox(height: AppDimens.spaceMd),

            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Already have an account? ',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  TextButton(
                    onPressed: onSwitchToLogin,
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.spaceSm,
                        vertical: AppDimens.spaceXs,
                      ),
                    ),
                    child: Text(
                      'Log in',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
