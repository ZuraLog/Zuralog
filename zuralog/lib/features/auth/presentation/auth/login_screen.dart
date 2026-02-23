/// Zuralog Edge Agent — Login Screen.
///
/// A clean, focused email/password login form. Validates inputs before
/// submission, shows inline validation errors, and displays a SnackBar on
/// [AuthFailure]. On [AuthSuccess] the GoRouter auth guard automatically
/// redirects to [dashboardPath].
///
/// **Widget type:** [ConsumerStatefulWidget] — needs Riverpod [ref] and
/// local [TextEditingController] + form-state management.
///
/// **Navigation:**
/// - Back button: [context.pop] returns to [WelcomeScreen] (auth home).
/// - "Sign up" link: [context.pushReplacement] to [RegisterScreen] — replaces
///   this route on the stack to prevent unbounded Login ↔ Register accumulation.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/auth/domain/auth_providers.dart';
import 'package:zuralog/features/auth/domain/auth_state.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

/// Screen that allows an existing user to sign in with email and password.
///
/// Integrates with [authStateProvider] via Riverpod. Transitions to
/// [AuthState.authenticated] on success, which triggers the GoRouter guard
/// to navigate the user to the dashboard automatically.
class LoginScreen extends ConsumerStatefulWidget {
  /// Creates a [LoginScreen].
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

/// State for [LoginScreen].
///
/// Owns the [GlobalKey<FormState>], [TextEditingController]s, password
/// visibility toggle, and loading flag.
class _LoginScreenState extends ConsumerState<LoginScreen> {
  /// Key used to validate and submit the form.
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  /// Controller for the email text field.
  final TextEditingController _emailController = TextEditingController();

  /// Controller for the password text field.
  final TextEditingController _passwordController = TextEditingController();

  /// Whether the password characters are masked.
  ///
  /// Toggled by the suffix icon inside the password field.
  bool _obscurePassword = true;

  /// Whether an authentication request is in flight.
  ///
  /// Set `true` before the API call and `false` in the completion callback
  /// to drive the loading state of [PrimaryButton].
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── Form Validation ──────────────────────────────────────────────────────

  /// Validates the email field.
  ///
  /// Returns an error message if [value] is blank or missing '@' and '.'.
  /// Returns `null` when valid.
  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    if (!value.contains('@') || !value.contains('.')) {
      return 'Enter a valid email address';
    }
    return null;
  }

  /// Validates the password field.
  ///
  /// Returns an error message if [value] is shorter than 6 characters.
  /// Returns `null` when valid.
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  // ── Submission ───────────────────────────────────────────────────────────

  /// Validates the form, calls the login action, and handles the result.
  ///
  /// Shows a SnackBar on [AuthFailure]. On [AuthSuccess] the GoRouter
  /// redirect takes over — no explicit navigation call is required here.
  Future<void> _handleLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    final result = await ref.read(authStateProvider.notifier).login(
          _emailController.text.trim(),
          _passwordController.text,
        );

    if (!mounted) return;
    setState(() => _isLoading = false);

    switch (result) {
      case AuthSuccess():
        // GoRouter auth guard navigates to dashboard automatically.
        break;
      case AuthFailure(:final message):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        // Explicit back button — returns to the WelcomeScreen (auth home).
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          tooltip: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(RouteNames.welcomePath);
            }
          },
        ),
        // Zuralog SVG logo centered in the AppBar for brand continuity.
        title: SvgPicture.asset(
          'assets/images/zuralog_logo.svg',
          height: 28,
          colorFilter: ColorFilter.mode(
            colorScheme.onSurface,
            BlendMode.srcIn,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.spaceLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Heading ──────────────────────────────────────────────
                Text(
                  'Welcome back',
                  style: AppTextStyles.h2.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: AppDimens.spaceSm),
                Text(
                  'Sign in to your Zuralog account.',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),

                const SizedBox(height: AppDimens.spaceXl),

                // ── Email field ──────────────────────────────────────────
                AppTextField(
                  hintText: 'Email address',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  prefixIcon: const Icon(Icons.email_outlined),
                  controller: _emailController,
                  validator: _validateEmail,
                ),

                const SizedBox(height: AppDimens.spaceMd),

                // ── Password field ───────────────────────────────────────
                AppTextField(
                  hintText: 'Password',
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  prefixIcon: const Icon(Icons.lock_outlined),
                  controller: _passwordController,
                  validator: _validatePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                  onSubmitted: _handleLogin,
                ),

                const SizedBox(height: AppDimens.spaceXl),

                // ── Submit button ────────────────────────────────────────
                PrimaryButton(
                  label: 'Log In',
                  isLoading: _isLoading,
                  onPressed: _handleLogin,
                ),

                const SizedBox(height: AppDimens.spaceMd),

                // ── Registration link ────────────────────────────────────
                // Centered inline text + link row.
                // pushReplacement prevents Login↔Register stack accumulation.
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.pushReplacement(
                          RouteNames.registerPath,
                        ),
                        child: const Text('Sign up'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
