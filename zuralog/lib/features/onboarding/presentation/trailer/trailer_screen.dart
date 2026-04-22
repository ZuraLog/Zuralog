/// Zuralog Onboarding — Act 1 Trailer Screen.
///
/// Three cinematic slides that play as a trailer before the welcome
/// screen. Auto-advances every 5 seconds; pauses for 8 seconds after
/// any manual swipe. Tapping "Get started" on any slide persists the
/// has-seen flag and navigates to /welcome.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/auth/domain/auth_providers.dart';
import 'package:zuralog/features/onboarding/presentation/trailer/trailer_data.dart';
import 'package:zuralog/features/onboarding/presentation/trailer/trailer_slide.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

class TrailerScreen extends ConsumerStatefulWidget {
  const TrailerScreen({super.key});

  @override
  ConsumerState<TrailerScreen> createState() => _TrailerScreenState();
}

class _TrailerScreenState extends ConsumerState<TrailerScreen> {
  // Auto-advance cadence — slow enough to breathe, fast enough to keep
  // the trailer moving if the user just watches.
  static const Duration _autoAdvanceInterval = Duration(seconds: 5);

  // After any manual swipe, pause auto-advance for this long before
  // resuming. Matches the rhythm the user set.
  static const Duration _pauseAfterInteraction = Duration(seconds: 8);

  // Page-to-page crossfade duration when auto-advancing.
  static const Duration _advanceTransitionDuration = Duration(milliseconds: 1200);

  // Logo chip top-left sizing.
  static const double _logoChipSize = 36.0;
  static const double _logoChipPadding = 6.0;
  static const double _logoChipBackgroundAlpha = 0.18;
  static const double _logoChipBorderAlpha = 0.35;

  final PageController _pageCtrl = PageController();
  int _index = 0;
  Timer? _autoAdvance;
  Timer? _resumeAfterInteraction;
  bool _programmaticAdvanceInFlight = false;

  @override
  void initState() {
    super.initState();
    _startAutoAdvance();
  }

  void _startAutoAdvance() {
    _autoAdvance?.cancel();
    _autoAdvance = Timer.periodic(_autoAdvanceInterval, (_) async {
      if (!mounted) return;
      final next = (_index + 1) % trailerSlides.length;
      _programmaticAdvanceInFlight = true;
      try {
        await _pageCtrl.animateToPage(
          next,
          duration: _advanceTransitionDuration,
          curve: Curves.easeInOut,
        );
      } finally {
        if (mounted) _programmaticAdvanceInFlight = false;
      }
    });
  }

  void _pauseAutoAdvanceForInteraction() {
    _autoAdvance?.cancel();
    _resumeAfterInteraction?.cancel();
    _resumeAfterInteraction = Timer(_pauseAfterInteraction, () {
      if (!mounted) return;
      _startAutoAdvance();
    });
  }

  Future<void> _onGetStarted() async {
    HapticFeedback.mediumImpact();
    await markOnboardingComplete();
    if (!mounted) return;
    ref.invalidate(hasSeenOnboardingProvider);
    if (!mounted) return;
    context.go(RouteNames.welcomePath);
  }

  @override
  void dispose() {
    _autoAdvance?.cancel();
    _resumeAfterInteraction?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.paddingOf(context).top;
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColorsOf(context).canvas,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageCtrl,
            itemCount: trailerSlides.length,
            onPageChanged: (i) {
              setState(() => _index = i);
              if (_programmaticAdvanceInFlight) return;
              HapticFeedback.lightImpact();
              _pauseAutoAdvanceForInteraction();
            },
            itemBuilder: (_, i) => TrailerSlideView(slide: trailerSlides[i]),
          ),

          // Logo chip — top-left over the photo's top scrim.
          Positioned(
            top: safeTop + AppDimens.spaceMd,
            left: AppDimens.spaceLg,
            child: Row(
              children: [
                Container(
                  width: _logoChipSize,
                  height: _logoChipSize,
                  padding: const EdgeInsets.all(_logoChipPadding),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: _logoChipBackgroundAlpha),
                    borderRadius: BorderRadius.circular(AppDimens.shapeXs),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: _logoChipBorderAlpha),
                    ),
                  ),
                  child: Image.asset(AppAssets.logoSagePng),
                ),
                const SizedBox(width: AppDimens.spaceSm),
                Text(
                  'ZuraLog',
                  style: AppTextStyles.labelLarge.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),

          // Bottom stack: page dots + Get started button.
          Positioned(
            left: 0,
            right: 0,
            bottom: safeBottom + AppDimens.spaceMd,
            child: Column(
              children: [
                _PageDots(count: trailerSlides.length, activeIndex: _index),
                const SizedBox(height: AppDimens.spaceMd),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.spaceLg),
                  child: ZButton(
                    label: 'Get started',
                    size: ZButtonSize.large,
                    onPressed: _onGetStarted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.activeIndex});
  final int count;
  final int activeIndex;

  static const Duration _transitionDuration = Duration(milliseconds: 300);
  static const double _dotHorizontalPadding = 3.0;

  // Active / inactive page-dot sizing.
  static const double _activeDotWidth = 18.0;
  static const double _activeDotHeight = 3.0;
  static const double _inactiveDotSize = 5.0;
  static const double _inactiveDotAlpha = 0.30;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isActive = i == activeIndex;
        return AnimatedContainer(
          duration: _transitionDuration,
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: _dotHorizontalPadding),
          width: isActive ? _activeDotWidth : _inactiveDotSize,
          height: isActive ? _activeDotHeight : _inactiveDotSize,
          decoration: BoxDecoration(
            color: isActive
                ? AppColorsOf(context).primary
                : Colors.white.withValues(alpha: _inactiveDotAlpha),
            borderRadius: BorderRadius.circular(_activeDotHeight),
          ),
        );
      }),
    );
  }
}
