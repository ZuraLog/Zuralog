/// Zuralog — Onboarding Step 1: Welcome.
///
/// Animated welcome screen with app logo, headline, sub-headline, and a
/// "Get Started" CTA button. This step manages its own CTA button (no shared
/// bottom nav). The animation fades in and slides content upward on mount.
library;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

// ── Step Widget ────────────────────────────────────────────────────────────────

/// Step 1 of the onboarding flow — animated welcome screen.
///
/// Fades in and slides content up on mount. Calls [onNext] when the user
/// taps "Get Started", advancing to Step 2 (Goals).
class WelcomeStep extends StatefulWidget {
  /// Creates a [WelcomeStep].
  const WelcomeStep({super.key, required this.onNext});

  /// Callback invoked when the user taps "Get Started".
  final VoidCallback onNext;

  @override
  State<WelcomeStep> createState() => _WelcomeStepState();
}

class _WelcomeStepState extends State<WelcomeStep>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    // Start animation after first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceLg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Logo ─────────────────────────────────────────────────────
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppDimens.radiusCard),
                  ),
                  padding: const EdgeInsets.all(AppDimens.spaceMd),
                  child: SvgPicture.asset(
                    'assets/images/zuralog_logo.svg',
                    colorFilter: const ColorFilter.mode(
                      AppColors.primary,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppDimens.spaceXl),

              // ── Welcome label ─────────────────────────────────────────────
              Center(
                child: Text(
                  'Welcome to Zuralog',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              ),

              const SizedBox(height: AppDimens.spaceSm),

              // ── Headline ──────────────────────────────────────────────────
              Text(
                'Your health,\nunderstood.',
                style: AppTextStyles.h1.copyWith(
                  color: colorScheme.onSurface,
                  height: 1.1,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppDimens.spaceMd),

              // ── Sub-headline ──────────────────────────────────────────────
              Text(
                'Zuralog brings all your health data together and turns it into '
                'actionable insights — powered by your personal AI coach.',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppDimens.spaceXxl),

              // ── CTA button ────────────────────────────────────────────────
              PrimaryButton(
                label: 'Get Started',
                onPressed: widget.onNext,
              ),

              const SizedBox(height: AppDimens.spaceMd),

              Center(
                child: Text(
                  'Takes about 2 minutes',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
