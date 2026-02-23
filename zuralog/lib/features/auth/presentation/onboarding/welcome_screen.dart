/// Zuralog Edge Agent — Welcome / Auth Home Screen.
///
/// The primary entry point for all users (new and returning). Presents the
/// full account-access menu in a single "Clean Gate" design:
///   - Brand logo in a Sage Green rounded-square card
///   - App name + tagline
///   - Continue with Apple (stub)
///   - Continue with Google (stub)
///   - "or" divider
///   - Log in with Email (navigates to LoginScreen)
///   - Legal footer (Terms of Service / Privacy Policy)
///
/// This screen replaces the previous gradient "Living Brand Moment" welcome
/// and the previously-orphaned [AuthSelectionScreen], merging them into one
/// cohesive entry point that matches the reference design.
///
/// On first launch the [OnboardingPageView] is shown before this screen,
/// controlled by the [hasSeenOnboardingProvider] flag.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/theme.dart';

/// The auth home screen — entry point for unauthenticated users.
///
/// Presents all account-access options (Apple, Google, email) in a minimal,
/// light-themed layout. Social auth buttons trigger a "coming soon" snackbar
/// until OAuth integration is implemented in a future phase.
class WelcomeScreen extends StatelessWidget {
  /// Creates a [WelcomeScreen].
  const WelcomeScreen({super.key});

  // ── Asset Paths ─────────────────────────────────────────────────────────────
  static const String _logoAsset = 'assets/images/zuralog_logo.svg';

  // ── Layout Constants ─────────────────────────────────────────────────────────
  static const double _logoCardSize = 120;
  static const double _logoCardRadius = 28;
  static const double _logoPadding = 22;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      // No AppBar — full-screen immersive auth experience.
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceLg),
          child: Column(
            children: [
              // ── Brand area — centred in the upper portion ──────────────────
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo card — sage green rounded square, matching reference.
                    _LogoCard(
                      size: _logoCardSize,
                      radius: _logoCardRadius,
                      padding: _logoPadding,
                      logoAsset: _logoAsset,
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

              // ── Auth actions — pinned to the bottom ────────────────────────
              Column(
                children: [
                  // Continue with Apple
                  _AppleButton(
                    onPressed: () => _showComingSoon(context, 'Apple Sign In'),
                  ),

                  const SizedBox(height: AppDimens.spaceSm),

                  // Continue with Google
                  _GoogleButton(
                    onPressed: () => _showComingSoon(context, 'Google Sign In'),
                  ),

                  const SizedBox(height: AppDimens.spaceMd),

                  // ── "or" divider ─────────────────────────────────────────
                  const _OrDivider(),

                  const SizedBox(height: AppDimens.spaceMd),

                  // Log in with Email — navigates to the unified login screen.
                  // Email-only users can switch to registration from LoginScreen.
                  SizedBox(
                    width: double.infinity,
                    height: AppDimens.touchTargetMin,
                    child: TextButton(
                      onPressed: () => context.push(RouteNames.loginPath),
                      style: TextButton.styleFrom(
                        foregroundColor: colorScheme.onSurface,
                        textStyle: AppTextStyles.h3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDimens.radiusButton),
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
    );
  }

  /// Shows a "coming soon" [SnackBar] for a given [featureName].
  void _showComingSoon(BuildContext context, String featureName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$featureName coming soon'),
        behavior: SnackBarBehavior.floating,
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
