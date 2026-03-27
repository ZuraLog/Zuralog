/// Zuralog Edge Agent — Welcome / Auth Home Screen (v4.0 brand bible redesign).
///
/// The auth gate screen the user lands on after the slideshow (or on every
/// subsequent launch). Full-screen canvas with a subtle Sage Green radial
/// bloom at top-center, brand logo card with topographic pattern, and three
/// auth buttons using the design system [ZButton] component.
///
/// **Backend wiring is unchanged:**
/// - [_handleGoogleSignIn] → [SocialAuthService.signInWithGoogle] → [authStateProvider.socialLogin]
/// - [_handleAppleSignIn] → [ZAlertDialog] (stubbed until Apple Developer enrollment)
/// - [_showError] → [ZToast.error] overlay notification
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

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
  /// dashboard on success (handled by GoRouter), or shows a ZToast on failure.
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
    await ZAlertDialog.show(
      context,
      title: 'Apple Sign In',
      body: 'Apple Sign In requires an Apple Developer Program membership '
          '(\$99/year). Configuration is in progress — use Google or Email '
          'sign-in in the meantime.',
      confirmLabel: 'OK',
      cancelLabel: 'Close',
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _showError(String message) {
    if (!mounted) return;
    ZToast.error(context, message);
  }

  @override
  Widget build(BuildContext context) {
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
                  ),

                  SizedBox(height: AppDimens.spaceLg + safeBottom),
                ],
              ),
            ),
          ),

          // ── Loading overlay ────────────────────────────────────────────
          if (_isLoading)
            Positioned.fill(
              child: Semantics(
                liveRegion: true,
                label: 'Signing in',
                child: ColoredBox(
                  color: Colors.black54,
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
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

// ── Private Widgets ────────────────────────────────────────────────────────────

/// Full-screen subtle sage green radial gradient bloom at top-center.
/// Creates depth and anchors the content to the dark background.
class _RadialBloom extends StatelessWidget {
  const _RadialBloom();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -1.2),
          radius: 0.8,
          colors: [
            AppColors.primary.withValues(alpha: 0.07),
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
    final colors = AppColorsOf(context);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Logo card — 96×96px, shapeLg, primary fill with pattern
        const _LogoCard(),

        const SizedBox(height: AppDimens.spaceLg),

        // App name
        Text(
          'Zuralog',
          style: AppTextStyles.displayLarge.copyWith(
            color: colors.textPrimary,
          ),
        ),

        const SizedBox(height: AppDimens.spaceSm),

        // Tagline — two short editorial lines
        Text(
          'Better health,\ntogether.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: colors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// 96×96px logo card with Sage Green fill and brand topographic pattern.
class _LogoCard extends StatelessWidget {
  const _LogoCard();

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(AppDimens.shapeLg);

    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        width: 96,
        height: 96,
        child: Stack(
          children: [
            // Sage fill background
            Container(
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: borderRadius,
              ),
            ),
            // Brand pattern — Sage surface gets colorBurn at 15%
            const Positioned.fill(
              child: ZPatternOverlay(
                variant: ZPatternVariant.sage,
                opacity: 0.15,
                blendMode: BlendMode.colorBurn,
              ),
            ),
            // Logo icon
            Padding(
              padding: const EdgeInsets.all(20),
              child: SvgPicture.asset(
                WelcomeScreen._logoAsset,
                fit: BoxFit.contain,
                colorFilter: const ColorFilter.mode(
                  AppColors.primaryButtonText,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ],
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
  });

  final bool isLoading;
  final VoidCallback onApple;
  final VoidCallback onGoogle;
  final VoidCallback onEmail;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Apple button — secondary (outlined) with Apple icon
        ZButton(
          label: 'Continue with Apple',
          variant: ZButtonVariant.secondary,
          icon: Icons.apple,
          onPressed: isLoading ? null : onApple,
          size: ZButtonSize.large,
        ),

        const SizedBox(height: AppDimens.spaceSm),

        // Google button — secondary (outlined) with colored "G"
        ZButton(
          label: 'Continue with Google',
          variant: ZButtonVariant.secondary,
          leadingWidget: Text(
            'G',
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.googleBlue,
              fontWeight: FontWeight.w700,
            ),
          ),
          onPressed: isLoading ? null : onGoogle,
          size: ZButtonSize.large,
        ),

        const SizedBox(height: AppDimens.spaceMd),

        // "or" divider
        const _OrDivider(),

        const SizedBox(height: AppDimens.spaceMd),

        // Email button — text variant (Sage text, no background)
        ZButton(
          label: 'Log in with Email',
          variant: ZButtonVariant.text,
          onPressed: isLoading ? null : onEmail,
          size: ZButtonSize.medium,
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
    final colors = AppColorsOf(context);

    return Row(
      children: [
        const Expanded(child: ZDivider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
          child: Text(
            'or',
            style: AppTextStyles.bodySmall.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ),
        const Expanded(child: ZDivider()),
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
      ..onTap = () async {
        try {
          await launchUrl(
            Uri.parse('https://zuralog.com/terms'),
            mode: LaunchMode.externalApplication,
          );
        } catch (_) {
          // Silently ignore — do not crash if the URL cannot be opened.
        }
      };
    _privacyRecognizer = TapGestureRecognizer()
      ..onTap = () async {
        try {
          await launchUrl(
            Uri.parse('https://zuralog.com/privacy'),
            mode: LaunchMode.externalApplication,
          );
        } catch (_) {
          // Silently ignore — do not crash if the URL cannot be opened.
        }
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
    final colors = AppColorsOf(context);

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: AppTextStyles.bodySmall.copyWith(
          color: colors.textSecondary,
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
