/// Zuralog — Onboarding Step 1: Welcome (v3.2 redesign).
///
/// Animated brand moment with logo card spring entrance, staggered text
/// fade-in, and a full-width "Let's go" CTA. No top bar — full-screen feel.
///
/// Uses elasticOut curve for logo scale-in (0.6 → 1.0 with natural overshoot).
/// Text elements stagger 80ms per element.
library;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:zuralog/core/theme/app_assets.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

// ── Step Widget ────────────────────────────────────────────────────────────────

/// Step 1 of the onboarding flow — animated welcome brand moment.
///
/// Logo card scales in from 0.6 → 1.0 with elastic overshoot.
/// Headline and subtitle stagger in with fade + translate-up.
class WelcomeStep extends StatefulWidget {
  /// Creates a [WelcomeStep].
  const WelcomeStep({super.key, required this.onNext});

  /// Callback invoked when the user taps "Let's go".
  final VoidCallback onNext;

  @override
  State<WelcomeStep> createState() => _WelcomeStepState();
}

class _WelcomeStepState extends State<WelcomeStep>
    with TickerProviderStateMixin {
  late final AnimationController _logoController;
  late final AnimationController _text1Controller;
  late final AnimationController _text2Controller;
  late final AnimationController _ctaController;

  late final Animation<double> _logoScale;
  late final Animation<double> _text1Opacity;
  late final Animation<Offset> _text1Slide;
  late final Animation<double> _text2Opacity;
  late final Animation<Offset> _text2Slide;
  late final Animation<double> _ctaOpacity;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    _text1Controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _text1Opacity = CurvedAnimation(
      parent: _text1Controller,
      curve: Curves.easeOut,
    );
    _text1Slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _text1Controller, curve: Curves.easeOut),
    );

    _text2Controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _text2Opacity = CurvedAnimation(
      parent: _text2Controller,
      curve: Curves.easeOut,
    );
    _text2Slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _text2Controller, curve: Curves.easeOut),
    );

    _ctaController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _ctaOpacity = CurvedAnimation(
      parent: _ctaController,
      curve: Curves.easeOut,
    );

    // Staggered entrance
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _logoController.forward();
      Future<void>.delayed(const Duration(milliseconds: 80), () {
        if (mounted) _text1Controller.forward();
      });
      Future<void>.delayed(const Duration(milliseconds: 160), () {
        if (mounted) _text2Controller.forward();
      });
      Future<void>.delayed(const Duration(milliseconds: 240), () {
        if (mounted) _ctaController.forward();
      });
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _text1Controller.dispose();
    _text2Controller.dispose();
    _ctaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceLg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Logo card — spring scale entrance, pattern overlay ────
          Center(
            child: ScaleTransition(
              scale: _logoScale,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppDimens.shapeLg),
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius:
                              BorderRadius.circular(AppDimens.shapeLg),
                        ),
                      ),
                      const Positioned.fill(
                        child: ZPatternOverlay(
                          variant: ZPatternVariant.sage,
                          opacity: 0.15,
                          blendMode: BlendMode.colorBurn,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(18),
                        child: SvgPicture.asset(
                          AppAssets.logoSvg,
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
            ),
          ),

          const SizedBox(height: AppDimens.spaceXl),

          // ── Headline — Sage color, displayLarge ──────────────────
          FadeTransition(
            opacity: _text1Opacity,
            child: SlideTransition(
              position: _text1Slide,
              child: Text(
                'Hi, welcome\nto Zuralog.',
                style: AppTextStyles.displayLarge.copyWith(
                  color: AppColors.primary,
                  height: 1.1,
                ),
              ),
            ),
          ),

          const SizedBox(height: AppDimens.spaceMd),

          // ── Sub-headline — textSecondary, bodyLarge ──────────────
          FadeTransition(
            opacity: _text2Opacity,
            child: SlideTransition(
              position: _text2Slide,
              child: Text(
                "Let's set up your AI health coach.",
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.textSecondaryDark,
                ),
              ),
            ),
          ),

          const SizedBox(height: AppDimens.spaceXxl),

          // ── CTA button — ZButton with pattern ────────────────────
          FadeTransition(
            opacity: _ctaOpacity,
            child: ZButton(
              label: "Let's go →",
              onPressed: widget.onNext,
            ),
          ),
        ],
      ),
    );
  }
}
