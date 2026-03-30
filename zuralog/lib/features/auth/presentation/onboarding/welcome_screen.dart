/// Zuralog Edge Agent — Welcome / Auth Home Screen (v5.0 lifestyle carousel redesign).
///
/// The auth gate screen the user lands on after the slideshow (or on every
/// subsequent launch). A photo carousel fills the top portion of the screen
/// with a theme-aware gradient fade; the auth action section sits below it.
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
    imagePath: 'assets/welcome/welcome_01.jpg',
    tagline: 'Your health,\none clear picture.',
  ),
  WelcomeSlide(
    imagePath: 'assets/welcome/welcome_02.jpg',
    tagline: 'Rest, finally\nunderstood.',
  ),
  WelcomeSlide(
    imagePath: 'assets/welcome/welcome_03.jpg',
    tagline: 'Peace of mind,\nmeasured.',
  ),
  WelcomeSlide(
    imagePath: 'assets/welcome/welcome_04.jpg',
    tagline: 'Every rep,\nrecorded.',
  ),
  WelcomeSlide(
    imagePath: 'assets/welcome/welcome_05.jpg',
    tagline: 'What you eat,\ndecoded.',
  ),
  WelcomeSlide(
    imagePath: 'assets/welcome/welcome_06.jpg',
    tagline: 'Your day,\nyour way.',
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
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final canvas = AppColorsOf(context).canvas;

    return ZuralogScaffold(
      useSafeArea: false,
      body: Stack(
        children: [
          // Two-layer layout: photo fills the top, auth buttons sit below.
          Column(
            children: [
              // Layer 1 — photo carousel with bottom gradient fade.
              //    Takes all space above the auth section.
              const Expanded(child: _HeroCarousel()),

              // Layer 2 — auth buttons on solid canvas background.
              ColoredBox(
                color: canvas,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppDimens.spaceLg,
                    AppDimens.spaceMd,
                    AppDimens.spaceLg,
                    AppDimens.spaceMd + safeBottom,
                  ),
                  child: _AuthActions(
                    isLoading: _isLoading,
                    onApple: _handleAppleSignIn,
                    onGoogle: _handleGoogleSignIn,
                    onEmail: () => context.push(RouteNames.loginPath),
                  ),
                ),
              ),
            ],
          ),

          // Loading overlay
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
                        AppColorsOf(context).primary,
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
/// 3. Brand topographic pattern overlay (very subtle)
/// 4. Top dark scrim (logo/wordmark legibility on any photo)
/// 5. Bottom gradient scrim (photo → canvas)
/// 6. ZuraLog mark + wordmark (top-left)
/// 7. Animated tagline (centered)
class _HeroCarousel extends StatefulWidget {
  const _HeroCarousel();

  @override
  State<_HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<_HeroCarousel>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  int _nextIndex = welcomeSlides.length > 1 ? 1 : 0;
  int _displayedTaglineIndex = 0;
  bool _reduceMotion = false;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.of(context).disableAnimations;
  }

  @override
  void initState() {
    super.initState();
    assert(welcomeSlides.isNotEmpty, 'welcomeSlides must contain at least one slide');

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnim = CurvedAnimation(
      parent: _fadeCtrl,
      curve: Curves.easeInOut,
    );

    _fadeCtrl.addListener(() {
      if (!mounted) return;
      if (_fadeCtrl.value >= 0.5 &&
          _displayedTaglineIndex != _nextIndex) {
        setState(() => _displayedTaglineIndex = _nextIndex);
      }
    });

    _fadeCtrl.addStatusListener((status) {
      if (!mounted) return;
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
        if (_reduceMotion) {
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

        // Layer 3 — brand topographic pattern overlay (very subtle on photos)
        const Positioned.fill(
          child: ZPatternOverlay(
            variant: ZPatternVariant.original,
            opacity: 0.04,
          ),
        ),

        // Layer 4 — top scrim: darkens the photo behind the logo/wordmark.
        //    This is the standard industry pattern for text-on-photo legibility.
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.center,
                  colors: [
                    Colors.black.withValues(alpha: 0.55),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),

        // Layer 5 — bottom gradient: fades photo into canvas (theme-aware).
        //    Transparent at mid-hero, fully canvas at the bottom edge —
        //    light mode fades to warm cream, dark mode fades to near-black.
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.45, 1.0],
                  colors: [
                    Colors.transparent,
                    AppColorsOf(context).canvas,
                  ],
                ),
              ),
            ),
          ),
        ),

        // Layer 6 — logo chip + ZuraLog wordmark (top-left, below safe area).
        //    Frosted glass chip (semi-transparent white) with the Sage PNG mark
        //    inside. Reads clearly on any photo in any mode — no theme dependency.
        Positioned(
          top: MediaQuery.paddingOf(context).top + AppDimens.spaceMd,
          left: AppDimens.spaceLg,
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppDimens.shapeXs),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.all(6),
                child: Image.asset(AppAssets.logoSagePng),
              ),
              const SizedBox(width: AppDimens.spaceSm),
              Text(
                'ZuraLog',
                style: AppTextStyles.labelLarge.copyWith(
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),

        // Layer 7 — animated tagline, centered in the photo zone.
        Positioned(
          left: AppDimens.spaceLg,
          right: AppDimens.spaceLg,
          bottom: 120,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 1200),
            child: Text(
              welcomeSlides[_displayedTaglineIndex].tagline,
              key: ValueKey(_displayedTaglineIndex),
              textAlign: TextAlign.center,
              style: AppTextStyles.displaySmall.copyWith(
                color: Colors.white,
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

        const SizedBox(height: AppDimens.spaceSm),

        // "or" divider
        const _OrDivider(),

        const SizedBox(height: AppDimens.spaceSm),

        // Email — text variant
        ZButton(
          label: 'Continue with Email',
          variant: ZButtonVariant.text,
          size: ZButtonSize.medium,
          onPressed: isLoading ? null : onEmail,
        ),

        const SizedBox(height: AppDimens.spaceSm),

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
      ..onTap = () => context.push(RouteNames.settingsTermsPath);
    _privacyRecognizer = TapGestureRecognizer()
      ..onTap = () => context.push(RouteNames.settingsPrivacyPolicyPath);
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
              color: AppColorsOf(context).primary,
              decoration: TextDecoration.underline,
              decorationColor: AppColorsOf(context).primary,
            ),
            recognizer: _tosRecognizer,
          ),
          const TextSpan(text: '\nand '),
          TextSpan(
            text: 'Privacy Policy',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColorsOf(context).primary,
              decoration: TextDecoration.underline,
              decorationColor: AppColorsOf(context).primary,
            ),
            recognizer: _privacyRecognizer,
          ),
          const TextSpan(text: '.'),
        ],
      ),
    );
  }
}
