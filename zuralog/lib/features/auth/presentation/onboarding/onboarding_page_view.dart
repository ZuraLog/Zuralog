/// Zuralog Edge Agent — Onboarding Page View (v3.2 redesign).
///
/// 3-slide full-bleed layout with hero image, parallax scroll, editorial
/// typography, morphing dot indicators, and spring CTA button.
///
/// Shown only on first launch. After completion or skip, marks onboarding done
/// and navigates to [WelcomeScreen].
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/auth/domain/auth_providers.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

// ── Slide Data ────────────────────────────────────────────────────────────────

/// Immutable descriptor for a single onboarding slide.
class _SlideData {
  const _SlideData({
    required this.imagePath,
    required this.imagePlaceholderColor,
    required this.headline,
    required this.body,
    required this.accentColor,
    required this.placeholderIcon,
  });

  final String imagePath;
  final Color imagePlaceholderColor;
  final String headline;
  final String body;
  final Color accentColor;
  final IconData placeholderIcon;
}

const List<_SlideData> _slides = [
  _SlideData(
    imagePath: 'assets/images/onboarding/slide_1_health_constellation.png',
    imagePlaceholderColor: AppColors.primary,
    headline: 'Your health,\ncomplete.',
    body: 'Connect every app.\nSee the full picture.',
    accentColor: AppColors.primary,
    placeholderIcon: Icons.hub_rounded,
  ),
  _SlideData(
    imagePath: 'assets/images/onboarding/slide_2_ai_understanding.png',
    imagePlaceholderColor: AppColors.categoryWellness,
    headline: 'AI that\ngets you.',
    body: 'Personalized insights from\neverything you track.',
    accentColor: AppColors.categoryWellness,
    placeholderIcon: Icons.psychology_rounded,
  ),
  _SlideData(
    imagePath: 'assets/images/onboarding/slide_3_built_to_last.png',
    imagePlaceholderColor: AppColors.categoryActivity,
    headline: 'Built\nto last.',
    body: 'Privacy-first.\nYour data, always yours.',
    accentColor: AppColors.categoryActivity,
    placeholderIcon: Icons.shield_rounded,
  ),
];

// ── Screen ────────────────────────────────────────────────────────────────────

/// Full-bleed 3-slide onboarding slideshow shown on first app launch.
///
/// Manages a [PageController] for hero parallax, animated dot indicators,
/// and skip/next navigation. Marks onboarding complete on finish.
class OnboardingPageView extends ConsumerStatefulWidget {
  /// Creates an [OnboardingPageView].
  const OnboardingPageView({super.key});

  @override
  ConsumerState<OnboardingPageView> createState() => _OnboardingPageViewState();
}

class _OnboardingPageViewState extends ConsumerState<OnboardingPageView> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  double _pageOffset = 0;

  static const Duration _transitionDuration = Duration(milliseconds: 380);
  static const Curve _transitionCurve = Curves.easeOutCubic;

  @override
  void initState() {
    super.initState();
    _pageController.addListener(_onPageScroll);
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageScroll);
    _pageController.dispose();
    super.dispose();
  }

  void _onPageScroll() {
    if (_pageController.hasClients && mounted) {
      setState(() {
        _pageOffset = _pageController.page ?? 0;
      });
    }
  }

  bool get _isLastPage => _currentPage == _slides.length - 1;

  Future<void> _handleNextOrFinish() async {
    if (_isLastPage) {
      await markOnboardingComplete();
      if (!mounted) return;
      ref.invalidate(hasSeenOnboardingProvider);
      context.go(RouteNames.welcomePath);
    } else {
      _pageController.nextPage(
        duration: _transitionDuration,
        curve: _transitionCurve,
      );
    }
  }

  Future<void> _handleSkip() async {
    await markOnboardingComplete();
    if (!mounted) return;
    ref.invalidate(hasSeenOnboardingProvider);
    context.go(RouteNames.welcomePath);
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final imageHeight = screenHeight * 0.58;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Column(
        children: [
          // ── Hero image area — top 58% ──────────────────────────────────
          SizedBox(
            height: imageHeight,
            child: PageView.builder(
              controller: _pageController,
              itemCount: _slides.length,
              onPageChanged: (index) => setState(() => _currentPage = index),
              itemBuilder: (context, index) {
                final slide = _slides[index];
                // Parallax offset: translate image at 30% of page scroll delta.
                final offset = (index - _pageOffset) * MediaQuery.sizeOf(context).width * 0.3;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.spaceLg,
                    AppDimens.spaceXxl,
                    AppDimens.spaceLg,
                    0,
                  ),
                  child: _HeroImageCard(
                    slide: slide,
                    parallaxOffset: offset,
                  ),
                );
              },
            ),
          ),

          // ── Bottom content panel ────────────────────────────────────────
          Expanded(
            child: _BottomPanel(
              slides: _slides,
              currentPage: _currentPage,
              pageOffset: _pageOffset,
              isLastPage: _isLastPage,
              onNext: _handleNextOrFinish,
              onSkip: _handleSkip,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hero Image Card ───────────────────────────────────────────────────────────

/// Full-bleed hero image with shapeLg rounded corners and parallax transform.
class _HeroImageCard extends StatelessWidget {
  const _HeroImageCard({
    required this.slide,
    required this.parallaxOffset,
  });

  final _SlideData slide;
  final double parallaxOffset;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(parallaxOffset, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimens.shapeLg),
          boxShadow: [
            BoxShadow(
              color: slide.accentColor.withValues(alpha: 0.30),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppDimens.shapeLg),
          child: Image.asset(
            slide.imagePath,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, e, st) => _ImagePlaceholder(slide: slide),
          ),
        ),
      ),
    );
  }
}

/// Fallback shown when the slide image asset doesn't exist yet.
class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({required this.slide});

  final _SlideData slide;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: slide.accentColor.withValues(alpha: 0.15),
      child: Center(
        child: Icon(
          slide.placeholderIcon,
          size: 80,
          color: slide.accentColor,
        ),
      ),
    );
  }
}

// ── Bottom Panel ──────────────────────────────────────────────────────────────

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.slides,
    required this.currentPage,
    required this.pageOffset,
    required this.isLastPage,
    required this.onNext,
    required this.onSkip,
  });

  final List<_SlideData> slides;
  final int currentPage;
  final double pageOffset;
  final bool isLastPage;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final currentSlide = slides[currentPage];
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppDimens.spaceLg,
        AppDimens.spaceLg,
        AppDimens.spaceLg,
        AppDimens.spaceLg + safeBottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Skip link — hidden on last slide
          if (!isLastPage)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onSkip,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.spaceSm,
                    vertical: AppDimens.spaceXs,
                  ),
                ),
                child: Text(
                  'Skip',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            )
          else
            const SizedBox(height: 32), // Mirror skip button height

          const Spacer(),

          // Headline
          Text(
            currentSlide.headline,
            style: AppTextStyles.h1.copyWith(color: Colors.white),
          ),

          const SizedBox(height: AppDimens.spaceSm),

          // Body
          Text(
            currentSlide.body,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),

          const SizedBox(height: AppDimens.spaceLg),

          // Bottom row: dots (left) + CTA button (right)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Morphing dots
              _SlideDots(
                slides: slides,
                currentPage: currentPage,
                pageOffset: pageOffset,
              ),

              const Spacer(),

              // CTA Button — 140px fixed width
              SizedBox(
                width: 140,
                child: ZuralogSpringButton(
                  onTap: onNext,
                  child: FilledButton(
                    onPressed: onNext,
                    style: FilledButton.styleFrom(
                      backgroundColor: currentSlide.accentColor,
                      foregroundColor: AppColors.primaryButtonText,
                      minimumSize: const Size(140, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimens.shapePill),
                      ),
                      textStyle: AppTextStyles.h3,
                    ),
                    child: Text(isLastPage ? 'Get Started' : 'Next'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Slide Dots ────────────────────────────────────────────────────────────────

/// Animated pill dot indicators for the onboarding slideshow.
///
/// Active dot: 20×6px pill in slide accent color.
/// Inactive dot: 6×6px circle in [AppColors.borderDark].
/// Width morphs using [AnimatedContainer] with [Curves.easeOutCubic].
class _SlideDots extends StatelessWidget {
  const _SlideDots({
    required this.slides,
    required this.currentPage,
    required this.pageOffset,
  });

  final List<_SlideData> slides;
  final int currentPage;
  final double pageOffset;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(slides.length, (index) {
        final isActive = index == currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.only(right: AppDimens.spaceSm),
          width: isActive ? 20 : 6,
          height: 6,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimens.shapePill),
            color: isActive
                ? slides[currentPage].accentColor
                : AppColors.borderDark,
          ),
        );
      }),
    );
  }
}
