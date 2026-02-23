/// Zuralog Edge Agent — Welcome / Auth Home Screen.
///
/// The primary entry point for all users (new and returning). Presents the
/// full account-access menu in a single "Clean Gate" design:
///   - Brand logo in a Sage Green rounded-square card
///   - App name + tagline
///   - Continue with Apple (stubbed — requires Apple Developer Program)
///   - Continue with Google (fully wired)
///   - "or" divider
///   - Log in with Email (navigates to LoginScreen)
///   - Legal footer (Terms of Service / Privacy Policy)
///
/// Social auth buttons are connected to the [SocialAuthService] via
/// [AuthStateNotifier.socialLogin]. A loading overlay is shown during
/// the sign-in flow. Errors are surfaced as [SnackBar]s.
///
/// On first launch the [OnboardingPageView] is shown before this screen,
/// controlled by the [hasSeenOnboardingProvider] flag.
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

/// The auth home screen — entry point for unauthenticated users.
///
/// A [ConsumerStatefulWidget] so it can hold the [_isLoading] flag for
/// the social-auth loading overlay, without rebuilding the entire tree.
class WelcomeScreen extends ConsumerStatefulWidget {
  /// Creates a [WelcomeScreen].
  const WelcomeScreen({super.key});

  // ── Asset Paths ─────────────────────────────────────────────────────────────
  static const String _logoAsset = 'assets/images/zuralog_logo.svg';

  // ── Layout Constants ─────────────────────────────────────────────────────────
  static const double _logoCardSize = 120;
  static const double _logoCardRadius = 28;
  static const double _logoPadding = 22;

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  /// Whether a social sign-in flow is currently in progress.
  bool _isLoading = false;

  // ── Google Sign In ─────────────────────────────────────────────────────────

  /// Initiates the Google Sign In native flow.
  ///
  /// Shows a loading overlay, calls [SocialAuthService.signInWithGoogle],
  /// then delegates to [AuthStateNotifier.socialLogin]. Navigates to the
  /// dashboard on success, or shows an error [SnackBar] on failure.
  ///
  /// Silently swallows [SocialAuthCancelledException] — the user changed
  /// their mind and we should not show an error.
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
          // Navigation is handled by GoRouter's auth guard — no push needed.
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
  /// requires an Apple Developer Program membership. Once configured,
  /// this method uses the same pattern as [_handleGoogleSignIn].
  Future<void> _handleAppleSignIn() async {
    if (_isLoading) return;
    // Apple Sign In is stubbed until Apple Developer credentials are
    // configured. Show an informative dialog instead of an error.
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

  /// Shows a floating error [SnackBar] with the given [message].
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
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      // No AppBar — full-screen immersive auth experience.
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceLg),
              child: Column(
                children: [
                  // ── Brand area — centred in the upper portion ──────────────
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo card — sage green rounded square.
                        _LogoCard(
                          size: WelcomeScreen._logoCardSize,
                          radius: WelcomeScreen._logoCardRadius,
                          padding: WelcomeScreen._logoPadding,
                          logoAsset: WelcomeScreen._logoAsset,
                        ),

                        const SizedBox(height: AppDimens.spaceLg),

                        // App name
                        Text(
                          'Zuralog',
                          style: AppTextStyles.h1.copyWith(
                            color: colorScheme.onSurface,
                            letterSpacing: -0.5,
                          ),
                        ),

                        const SizedBox(height: AppDimens.spaceSm),

                        // Tagline
                        Text(
                          'Your journey to better health starts here.',
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  // ── Auth actions — pinned to the bottom ──────────────────
                  Column(
                    children: [
                      // Continue with Apple
                      _AppleButton(
                        onPressed: _isLoading ? null : _handleAppleSignIn,
                      ),

                      const SizedBox(height: AppDimens.spaceSm),

                      // Continue with Google
                      _GoogleButton(
                        onPressed: _isLoading ? null : _handleGoogleSignIn,
                      ),

                      const SizedBox(height: AppDimens.spaceMd),

                      // ── "or" divider ───────────────────────────────────
                      const _OrDivider(),

                      const SizedBox(height: AppDimens.spaceMd),

                      // Log in with Email
                      SizedBox(
                        width: double.infinity,
                        height: AppDimens.touchTargetMin,
                        child: TextButton(
                          onPressed: _isLoading
                              ? null
                              : () => context.push(RouteNames.loginPath),
                          style: TextButton.styleFrom(
                            foregroundColor: colorScheme.onSurface,
                            textStyle: AppTextStyles.h3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppDimens.radiusButton,
                              ),
                            ),
                          ),
                          child: const Text('Log in with Email'),
                        ),
                      ),

                      const SizedBox(height: AppDimens.spaceMd),

                      // Legal footer
                      _LegalFooter(textTheme: textTheme),

                      const SizedBox(height: AppDimens.spaceLg),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Loading overlay — blocks input during social auth ──────────
          if (_isLoading)
            const ColoredBox(
              color: Colors.black38,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Private Widgets ────────────────────────────────────────────────────────────

/// The brand logo rendered inside a Sage Green rounded-square card.
///
/// Displays the SVG logo asset centered inside a pill-rounded container
/// with the brand's primary sage green background — matching the reference design.
class _LogoCard extends StatelessWidget {
  /// Creates a [_LogoCard].
  const _LogoCard({
    required this.size,
    required this.radius,
    required this.padding,
    required this.logoAsset,
  });

  /// The width and height of the square card.
  final double size;

  /// The corner radius of the card.
  final double radius;

  /// Internal padding between card edge and the logo.
  final double padding;

  /// Asset path for the SVG logo.
  final String logoAsset;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.45),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: EdgeInsets.all(padding),
      child: SvgPicture.asset(
        logoAsset,
        fit: BoxFit.contain,
        // Render the logo in dark grey for contrast on the sage green background.
        colorFilter: const ColorFilter.mode(
          AppColors.primaryButtonText,
          BlendMode.srcIn,
        ),
      ),
    );
  }
}

/// Full-width black pill button styled for Apple Sign In.
///
/// Uses a forced black background and white foreground per Apple's
/// Human Interface Guidelines for Sign in with Apple.
class _AppleButton extends StatelessWidget {
  /// Creates an [_AppleButton].
  const _AppleButton({required this.onPressed});

  /// Callback invoked when the button is tapped.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: AppDimens.touchTargetMin + 8,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.black,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusButton),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.apple, size: AppDimens.iconMd),
            const SizedBox(width: AppDimens.spaceSm),
            Text(
              'Continue with Apple',
              style: AppTextStyles.h3.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-width outlined pill button styled for Google Sign In.
///
/// Uses a light border with a stylized "G" text placeholder until
/// a proper Google SVG icon is available.
class _GoogleButton extends StatelessWidget {
  /// Creates a [_GoogleButton].
  const _GoogleButton({required this.onPressed});

  /// Callback invoked when the button is tapped.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: double.infinity,
      height: AppDimens.touchTargetMin + 8,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          side: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusButton),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Google "G" placeholder — replace with SVG in future phase.
            Text(
              'G',
              style: AppTextStyles.h3.copyWith(
                color: AppColors.googleBlue,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: AppDimens.spaceSm),
            Text(
              'Continue with Google',
              style: AppTextStyles.h3.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Horizontal "─── or ───" divider row.
class _OrDivider extends StatelessWidget {
  /// Creates an [_OrDivider].
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
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

/// Legal footer with tappable Terms of Service and Privacy Policy links.
class _LegalFooter extends StatelessWidget {
  /// Creates a [_LegalFooter].
  const _LegalFooter({required this.textTheme});

  /// The current [TextTheme] for style inheritance.
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
        children: [
          const TextSpan(text: 'By continuing, you agree to our '),
          TextSpan(
            text: 'Terms of Service',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.primary,
              decoration: TextDecoration.underline,
              decorationColor: AppColors.primary,
            ),
            recognizer: TapGestureRecognizer()..onTap = () {
              // TODO(dev): Open Terms of Service URL via url_launcher.
            },
          ),
          const TextSpan(text: '\nand '),
          TextSpan(
            text: 'Privacy Policy',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.primary,
              decoration: TextDecoration.underline,
              decorationColor: AppColors.primary,
            ),
            recognizer: TapGestureRecognizer()..onTap = () {
              // TODO(dev): Open Privacy Policy URL via url_launcher.
            },
          ),
          const TextSpan(text: '.'),
        ],
      ),
    );
  }
}
