/// Zuralog Edge Agent — Welcome / Auth Home Screen (v3.2 redesign).
///
/// The auth gate screen the user lands on after the slideshow (or on every
/// subsequent launch). Full-screen OLED black with a subtle Sage Green radial
/// bloom at top-center, brand logo card, and three spring-animated auth buttons.
///
/// **Backend wiring is unchanged:**
/// - [_handleGoogleSignIn] → [SocialAuthService.signInWithGoogle] → [authStateProvider.socialLogin]
/// - [_handleAppleSignIn] → stubbed dialog (preserved exactly)
/// - [_showError] → SnackBar helper (preserved exactly)
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:zuralog/core/di/providers.dart';
import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/auth/data/social_auth_service.dart';
import 'package:zuralog/features/auth/domain/auth_providers.dart';
import 'package:zuralog/features/auth/domain/auth_state.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

/// The auth home screen — entry point for unauthenticated users.
///
/// A [ConsumerStatefulWidget] to hold the [_isLoading] flag for the social-auth
/// loading overlay, without rebuilding the entire widget tree.
class WelcomeScreen extends ConsumerStatefulWidget {
  /// Creates a [WelcomeScreen].
  const WelcomeScreen({super.key});

  static const String _logoAsset = AppAssets.logoSvg;

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  bool _isLoading = false;

  // ── Google Sign In ─────────────────────────────────────────────────────────

  /// Initiates the Google Sign In native flow.
  ///
  /// Shows a loading overlay, calls [SocialAuthService.signInWithGoogle],
  /// then delegates to [AuthStateNotifier.socialLogin]. Navigates to the
  /// dashboard on success (handled by GoRouter), or shows a SnackBar on failure.
  Future<void> _handleGoogleSignIn() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final socialService = ref.read(socialAuthServiceProvider);
      final credentials = await socialService.signInWithGoogle();
      if (!mounted) return;

      final result = await ref
          .read(authStateProvider.notifier)
          .socialLogin(credentials);

      if (!mounted) return;
      switch (result) {
        case AuthSuccess():
          // Navigation handled by GoRouter's auth guard — no push needed.
          break;
        case AuthFailure(:final message):
          _showError(message);
      }
    } on SocialAuthCancelledException {
      // User cancelled the Google account picker — no error shown.
    } on SocialAuthException catch (e) {
      if (mounted) _showError(e.message);
    } catch (e) {
      if (mounted) _showError('Google Sign In failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Apple Sign In ──────────────────────────────────────────────────────────

  /// Initiates the Apple Sign In native flow.
  ///
  /// Currently shows a "coming soon" dialog because Apple Sign In
  /// requires an Apple Developer Program membership. Preserved exactly.
  Future<void> _handleAppleSignIn() async {
    if (_isLoading) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Apple Sign In'),
        content: const Text(
          'Apple Sign In requires an Apple Developer Program membership '
          '(\$99/year). Configuration is in progress — use Google or Email '
          'sign-in in the meantime.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    return ZuralogScaffold(
      useSafeArea: false,
      body: Stack(
        children: [
          // ── Radial bloom background — Sage Green at top-center ────────
          const Positioned.fill(child: _RadialBloom()),

          // ── Main content ──────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceLg),
              child: Column(
                children: [
                  // ── Brand area ─────────────────────────────────────────
                  const Expanded(child: _BrandArea()),

                  // ── Auth action buttons ────────────────────────────────
                  _AuthActions(
                    isLoading: _isLoading,
                    onApple: _handleAppleSignIn,
                    onGoogle: _handleGoogleSignIn,
                    onEmail: () => context.push(RouteNames.loginPath),
                    colorScheme: colorScheme,
                  ),

                  SizedBox(height: AppDimens.spaceLg + safeBottom),
                ],
              ),
            ),
          ),

          // ── Loading overlay ────────────────────────────────────────────
          if (_isLoading)
            const ColoredBox(
              color: Colors.black54,
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

// ── Private Widgets ────────────────────────────────────────────────────────────

/// Full-screen subtle sage green radial gradient bloom at top-center.
/// Creates depth and anchors the content to the dark background.
class _RadialBloom extends StatelessWidget {
  const _RadialBloom();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -1.2),
          radius: 0.8,
          colors: [
            Color(0x12CFE1B9), // AppColors.primary at ~7% opacity
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

/// Brand area: logo card + app name + tagline.
class _BrandArea extends StatelessWidget {
  const _BrandArea();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Logo card — 96×96px, shapeLg, primary fill with glow shadow
        const _LogoCard(),

        const SizedBox(height: AppDimens.spaceLg),

        // App name
        Text(
          'Zuralog',
          style: AppTextStyles.displayLarge.copyWith(color: Colors.white),
        ),

        const SizedBox(height: AppDimens.spaceSm),

        // Tagline — two short editorial lines
        Text(
          'Better health,\ntogether.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// 96×96px logo card with Sage Green fill and brand glow shadow.
class _LogoCard extends StatelessWidget {
  const _LogoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppDimens.shapeLg),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.40),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: SvgPicture.asset(
        WelcomeScreen._logoAsset,
        fit: BoxFit.contain,
        colorFilter: const ColorFilter.mode(
          AppColors.primaryButtonText,
          BlendMode.srcIn,
        ),
      ),
    );
  }
}

/// Auth action buttons: Apple, Google, "or" divider, Email, legal footer.
class _AuthActions extends StatelessWidget {
  const _AuthActions({
    required this.isLoading,
    required this.onApple,
    required this.onGoogle,
    required this.onEmail,
    required this.colorScheme,
  });

  final bool isLoading;
  final VoidCallback onApple;
  final VoidCallback onGoogle;
  final VoidCallback onEmail;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Apple button
        ZuralogSpringButton(
          onTap: isLoading ? null : onApple,
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: isLoading ? null : onApple,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.black,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimens.shapePill),
                ),
                textStyle: AppTextStyles.titleMedium,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.apple, size: 20, color: Colors.white),
                  SizedBox(width: AppDimens.spaceSm),
                  Text('Continue with Apple'),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: AppDimens.spaceSm),

        // Google button
        ZuralogSpringButton(
          onTap: isLoading ? null : onGoogle,
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton(
              onPressed: isLoading ? null : onGoogle,
              style: OutlinedButton.styleFrom(
                foregroundColor: colorScheme.onSurface,
                side: BorderSide(
                  color: colors.border,
                  width: 1.5,
                ),
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimens.shapePill),
                ),
                textStyle: AppTextStyles.titleMedium,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'G',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.googleBlue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: AppDimens.spaceSm),
                  Text(
                    'Continue with Google',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: AppDimens.spaceMd),

        // "or" divider
        const _OrDivider(),

        const SizedBox(height: AppDimens.spaceMd),

        // Email button
        ZuralogSpringButton(
          onTap: isLoading ? null : onEmail,
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: TextButton(
              onPressed: isLoading ? null : onEmail,
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.onSurfaceVariant,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimens.shapePill),
                ),
                textStyle: AppTextStyles.titleMedium,
              ),
              child: const Text('Log in with Email'),
            ),
          ),
        ),

        const SizedBox(height: AppDimens.spaceMd),

        // Legal footer
        const _LegalFooter(),
      ],
    );
  }
}

/// Horizontal "─── or ───" divider row.
class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
          child: Text(
            'or',
            style: AppTextStyles.bodySmall.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

/// Legal footer with tappable Terms of Service and Privacy Policy links.
class _LegalFooter extends StatefulWidget {
  const _LegalFooter();

  @override
  State<_LegalFooter> createState() => _LegalFooterState();
}

class _LegalFooterState extends State<_LegalFooter> {
  late final TapGestureRecognizer _tosRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;

  @override
  void initState() {
    super.initState();
    _tosRecognizer = TapGestureRecognizer()
      ..onTap = () {
        // TODO(dev): Open Terms of Service URL via url_launcher.
      };
    _privacyRecognizer = TapGestureRecognizer()
      ..onTap = () {
        // TODO(dev): Open Privacy Policy URL via url_launcher.
      };
  }

  @override
  void dispose() {
    _tosRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: AppTextStyles.bodySmall.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        children: [
          const TextSpan(text: 'By continuing, you agree to our '),
          TextSpan(
            text: 'Terms of Service',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.primary,
              decoration: TextDecoration.underline,
              decorationColor: AppColors.primary,
            ),
            recognizer: _tosRecognizer,
          ),
          const TextSpan(text: '\nand '),
          TextSpan(
            text: 'Privacy Policy',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.primary,
              decoration: TextDecoration.underline,
              decorationColor: AppColors.primary,
            ),
            recognizer: _privacyRecognizer,
          ),
          const TextSpan(text: '.'),
        ],
      ),
    );
  }
}
