/// Zuralog Edge Agent — Welcome / Auth Home Screen (v5.0 lifestyle carousel redesign).
///
/// The auth gate screen the user lands on after the slideshow (or on every
/// subsequent launch). Top 58% is a photo carousel that crossfades between
/// lifestyle images. Bottom 42% is the auth action section.
///
/// **Backend wiring is unchanged:**
/// - [_handleGoogleSignIn] → [SocialAuthService.signInWithGoogle] → [authStateProvider.socialLogin]
/// - [_handleAppleSignIn] → [ZAlertDialog] (stubbed until Apple Developer enrollment)
/// - [_showError] → [ZToast.error] overlay notification
library;

import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:simple_icons/simple_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:zuralog/core/di/providers.dart';
import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/auth/data/social_auth_service.dart';
import 'package:zuralog/features/auth/domain/auth_providers.dart';
import 'package:zuralog/features/auth/domain/auth_state.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

// ── Slide data model ───────────────────────────────────────────────────────────

/// A single slide in the WelcomeScreen photo carousel.
/// To add a new photo: drop the file in assets/welcome/ and add one entry here.
class WelcomeSlide {
  const WelcomeSlide({required this.imagePath, required this.tagline});

  final String imagePath;
  final String tagline;
}

const List<WelcomeSlide> welcomeSlides = [
  WelcomeSlide(
    imagePath: 'assets/welcome/placeholder_01.jpg',
    tagline: 'Your health,\none clear picture.',
  ),
];

// ── Screen ─────────────────────────────────────────────────────────────────────

/// The auth home screen — entry point for unauthenticated users.
///
/// A [ConsumerStatefulWidget] to hold the [_isLoading] flag for the social-auth
/// loading overlay, without rebuilding the entire widget tree.
class WelcomeScreen extends ConsumerStatefulWidget {
  /// Creates a [WelcomeScreen].
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  bool _isLoading = false;

  // ── Google Sign In ──────────────────────────────────────────────────────────

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

  // ── Apple Sign In ───────────────────────────────────────────────────────────

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

  // ── Helpers ─────────────────────────────────────────────────────────────────

  void _showError(String message) {
    if (!mounted) return;
    ZToast.error(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    return ZuralogScaffold(
      useSafeArea: false,
      body: Stack(
        children: [
          // ── Hero carousel (top 58%) ────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: screenHeight * 0.58,
            child: const _HeroCarousel(),
          ),

          // ── Auth section (bottom 42%) ──────────────────────────────────
          Positioned(
            top: screenHeight * 0.58,
            left: 0,
            right: 0,
            bottom: 0,
            child: ColoredBox(
              color: AppColorsOf(context).canvas,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppDimens.spaceLg,
                  AppDimens.spaceLg,
                  AppDimens.spaceLg,
                  AppDimens.spaceLg + safeBottom,
                ),
                child: _AuthActions(
                  isLoading: _isLoading,
                  onApple: _handleAppleSignIn,
                  onGoogle: _handleGoogleSignIn,
                  onEmail: () => context.push(RouteNames.loginPath),
                ),
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
                  color: Colors.black.withValues(alpha: 0.54),
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

/// Full-bleed photo carousel that crossfades between [welcomeSlides].
///
/// Layers (bottom → top):
/// 1. Current photo
/// 2. Next photo fading in (only when >1 slide)
/// 3. Brand topographic pattern overlay
/// 4. Gradient scrim blending the photo into the canvas color below
/// 5. Logo chip + ZuraLog wordmark (top-left)
/// 6. Animated tagline (bottom-left)
class _HeroCarousel extends StatefulWidget {
  const _HeroCarousel();

  @override
  State<_HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<_HeroCarousel>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  int _nextIndex = 1 % welcomeSlides.length;
  int _displayedTaglineIndex = 0;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnim = CurvedAnimation(
      parent: _fadeCtrl,
      curve: Curves.easeInOut,
    );

    _fadeCtrl.addListener(() {
      if (_fadeCtrl.value >= 0.5 &&
          _displayedTaglineIndex != _nextIndex) {
        setState(() => _displayedTaglineIndex = _nextIndex);
      }
    });

    _fadeCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _currentIndex = _nextIndex;
          _nextIndex = (_currentIndex + 1) % welcomeSlides.length;
          _displayedTaglineIndex = _currentIndex;
        });
        _fadeCtrl.reset();
      }
    });

    if (welcomeSlides.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!mounted) return;
        final reduceMotion = MediaQuery.of(context).disableAnimations;
        if (reduceMotion) {
          setState(() {
            _currentIndex = _nextIndex;
            _nextIndex = (_currentIndex + 1) % welcomeSlides.length;
            _displayedTaglineIndex = _currentIndex;
          });
        } else {
          _fadeCtrl.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Layer 1 — current photo
        Positioned.fill(
          child: Image.asset(
            welcomeSlides[_currentIndex].imagePath,
            fit: BoxFit.cover,
          ),
        ),

        // Layer 2 — next photo fading in (only when >1 slide)
        if (welcomeSlides.length > 1)
          Positioned.fill(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Image.asset(
                welcomeSlides[_nextIndex].imagePath,
                fit: BoxFit.cover,
              ),
            ),
          ),

        // Layer 3 — brand topographic pattern overlay
        const Positioned.fill(
          child: ZPatternOverlay(
            variant: ZPatternVariant.original,
            opacity: 0.09,
            blendMode: BlendMode.screen,
          ),
        ),

        // Layer 4 — gradient scrim (photo → canvas)
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.35, 0.65, 1.0],
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    AppColorsOf(context).canvas.withValues(alpha: 0.5),
                    AppColorsOf(context).canvas,
                  ],
                ),
              ),
            ),
          ),
        ),

        // Layer 5 — logo chip + ZuraLog wordmark (top-left, below safe area)
        Positioned(
          top: MediaQuery.paddingOf(context).top + AppDimens.spaceMd,
          left: AppDimens.spaceLg,
          child: Row(
            children: [
              ClipRRect(
                borderRadius:
                    BorderRadius.circular(AppDimens.shapeXs),
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: Stack(
                    children: [
                      Container(color: AppColors.primary),
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: SvgPicture.asset(
                          AppAssets.logoSvg,
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
              ),
              const SizedBox(width: AppDimens.spaceSm),
              Text(
                'ZuraLog',
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColorsOf(context).textPrimary,
                ),
              ),
            ],
          ),
        ),

        // Layer 6 — animated tagline (bottom-left)
        Positioned(
          left: AppDimens.spaceLg,
          right: AppDimens.spaceLg,
          bottom: AppDimens.spaceLg,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 1200),
            child: Text(
              welcomeSlides[_displayedTaglineIndex].tagline,
              key: ValueKey(_displayedTaglineIndex),
              style: AppTextStyles.displaySmall.copyWith(
                color: AppColorsOf(context).textPrimary,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.54),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
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
        // Apple — secondary (outlined) with FontAwesome apple icon
        ZButton(
          label: 'Continue with Apple',
          variant: ZButtonVariant.secondary,
          size: ZButtonSize.large,
          icon: FontAwesomeIcons.apple,
          onPressed: isLoading ? null : onApple,
        ),

        const SizedBox(height: AppDimens.spaceSm),

        // Google — secondary (outlined) with colored SimpleIcons google mark
        ZButton(
          label: 'Continue with Google',
          variant: ZButtonVariant.secondary,
          size: ZButtonSize.large,
          leadingWidget: const Icon(
            SimpleIcons.google,
            size: 18,
            color: Color(0xFFEA4335), // Google brand red — semantic, never changes
          ),
          onPressed: isLoading ? null : onGoogle,
        ),

        const SizedBox(height: AppDimens.spaceMd),

        // "or" divider
        const _OrDivider(),

        const SizedBox(height: AppDimens.spaceMd),

        // Email — text variant
        ZButton(
          label: 'Log in with Email',
          variant: ZButtonVariant.text,
          size: ZButtonSize.medium,
          onPressed: isLoading ? null : onEmail,
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
            Uri.parse('https://www.zuralog.com/terms'),
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
            Uri.parse('https://www.zuralog.com/privacy'),
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
