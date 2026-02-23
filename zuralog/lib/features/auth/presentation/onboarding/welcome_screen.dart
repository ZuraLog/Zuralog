/// Zuralog Edge Agent — Welcome Screen.
///
/// The full-screen entry point for new users. Creates a bold first impression
/// with a dramatic dark-green gradient background, a glowing brand logo,
/// and two CTAs: "Get Started" (to onboarding) and "I already have an account"
/// (to login).
///
/// **Design direction:** "Living Brand Moment" — organic diagonal gradient,
/// semi-transparent glass logo container, radial glow accent.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

/// Full-screen welcome screen shown to new, unauthenticated users.
///
/// Renders a living brand gradient and two navigation actions:
/// - "Get Started" leads to the onboarding value-prop slideshow.
/// - "I already have an account" leads directly to the login screen.
class WelcomeScreen extends StatelessWidget {
  /// Creates a [WelcomeScreen].
  const WelcomeScreen({super.key});

  /// App name font size override for the hero title.
  static const double _appNameFontSize = 40;

  /// Letter-spacing for the hero app name title.
  static const double _appNameLetterSpacing = 2.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // No AppBar — full-screen immersive experience.
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            // Diagonal top-left → bottom-right for an organic, living feel.
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.gradientForestDark, // Deep forest green at the top-left.
              AppColors.gradientForestMid,  // Mid-tone living green at the centre.
              AppColors.primary,            // Sage green at the bottom-right.
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceLg),
            child: Column(
              children: [
                // ── Main brand content — vertically centred ──────────────
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _LogoArea(),
                      const SizedBox(height: AppDimens.spaceLg),
                      Text(
                        'Zuralog',
                        style: AppTextStyles.h1.copyWith(
                          color: Colors.white,
                          fontSize: _appNameFontSize,
                          letterSpacing: _appNameLetterSpacing,
                        ),
                      ),
                      const SizedBox(height: AppDimens.spaceSm),
                      Text(
                        'Your AI Health Coach',
                        style: AppTextStyles.body.copyWith(
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Bottom CTAs pinned to the safe-area bottom ────────────
                Column(
                  children: [
                    PrimaryButton(
                      label: 'Get Started',
                      onPressed: () => context.go(RouteNames.onboardingPath),
                    ),
                    const SizedBox(height: AppDimens.spaceSm),
                    TextButton(
                      onPressed: () => context.push(RouteNames.loginPath),
                      child: Text(
                        'I already have an account',
                        style: AppTextStyles.body.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppDimens.spaceMd),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Private Widgets ────────────────────────────────────────────────────────────

/// Renders the Zuralog logo with a radial glow effect behind it.
///
/// Displays the [assets/images/zuralog_logo.png] brand asset inside a
/// frosted glass circle container. A [Stack] positions a blurred radial
/// glow decoration behind the main container for depth.
class _LogoArea extends StatelessWidget {
  /// Creates a [_LogoArea].
  const _LogoArea();

  /// Diameter of the circular logo container.
  static const double _logoDiameter = 120;

  /// Diameter of the radial glow halo behind the logo.
  static const double _glowDiameter = 180;

  /// Asset path for the Zuralog brand logo.
  static const String _logoAsset = 'assets/images/zuralog_logo.png';

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _glowDiameter,
      height: _glowDiameter,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ── Radial glow halo (sits behind logo container) ────────────
          Container(
            width: _glowDiameter,
            height: _glowDiameter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.35),
                  AppColors.primary.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),

          // ── Glass logo container ──────────────────────────────────────
          Container(
            width: _logoDiameter,
            height: _logoDiameter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.15),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1.5,
              ),
            ),
            padding: const EdgeInsets.all(AppDimens.spaceMd),
            child: Image.asset(
              _logoAsset,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}
