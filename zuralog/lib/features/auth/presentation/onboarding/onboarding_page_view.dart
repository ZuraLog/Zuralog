/// Zuralog Edge Agent — Onboarding Page View.
///
/// A 2-page horizontal page view that tells the product story using editorial
/// illustration cards and value-prop copy. Users can swipe or tap the Next /
/// Get Started button to advance. The "Skip" link bypasses to the auth home.
///
/// Shown only on the **first launch** of the app. After the user completes or
/// skips onboarding, [markOnboardingComplete] is called to persist the flag so
/// subsequent launches go directly to [WelcomeScreen] (the auth home).
///
/// **Design direction:** "Editorial Storytelling" — full-screen scaffold,
/// large illustration containers, clean page-dot indicator row.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/auth/domain/auth_providers.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

// ── Data ──────────────────────────────────────────────────────────────────────

/// Immutable data descriptor for a single onboarding value-prop page.
class _PageData {
  /// Creates a [_PageData].
  const _PageData({
    required this.icon,
    required this.headline,
    required this.description,
    required this.accentColor,
  });

  /// Material icon representing this value proposition.
  final IconData icon;

  /// Short, punchy headline (max ~4 words).
  final String headline;

  /// Explanatory body copy (1–2 sentences).
  final String description;

  /// Tint color used for the illustration container and icon.
  final Color accentColor;
}

/// The ordered list of onboarding pages shown in [OnboardingPageView].
const List<_PageData> _pages = [
  _PageData(
    icon: Icons.hub_rounded,
    headline: 'Connect Everything',
    description:
        'Sync Strava, Apple Health, and more. Zuralog pulls all your health data into one intelligent place.',
    accentColor: AppColors.primary,
  ),
  _PageData(
    icon: Icons.psychology_rounded,
    headline: 'Intelligence, Not Data',
    description:
        'Your AI coach analyzes everything and gives you personalized guidance — no spreadsheets required.',
    accentColor: AppColors.secondaryLight,
  ),
];

// ── Screen ────────────────────────────────────────────────────────────────────

/// Multi-page onboarding flow that presents Zuralog's core value propositions.
///
/// Manages a [PageController] to drive a horizontal [PageView].
/// Provides page-dot indicators and an adaptive Next / Create Account button.
/// A "Skip" link is available in the top-right corner throughout.
class OnboardingPageView extends StatefulWidget {
  /// Creates an [OnboardingPageView].
  const OnboardingPageView({super.key});

  @override
  State<OnboardingPageView> createState() => _OnboardingPageViewState();
}

/// State for [OnboardingPageView].
///
/// Tracks [_currentPage] and drives the [PageController].
class _OnboardingPageViewState extends State<OnboardingPageView> {
  /// Controls animated page transitions.
  final PageController _pageController = PageController();

  /// Zero-based index of the currently visible page.
  int _currentPage = 0;

  /// Duration for animated page transitions.
  static const Duration _animationDuration = Duration(milliseconds: 350);

  /// Curve for animated page transitions.
  static const Curve _animationCurve = Curves.easeInOut;

  /// Width of the CTA button in the bottom row.
  static const double _buttonWidth = 140;

  /// Diameter of an active page-dot indicator.
  static const double _activeDotSize = 10;

  /// Diameter of an inactive page-dot indicator.
  static const double _inactiveDotSize = 8;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Returns `true` when the user is on the final page.
  bool get _isLastPage => _currentPage == _pages.length - 1;

  /// Advances to the next page, or completes onboarding and navigates to the
  /// auth home ([WelcomeScreen]) when on the last page.
  Future<void> _handleNextOrFinish() async {
    if (_isLastPage) {
      await markOnboardingComplete();
      if (!mounted) return;
      // go() replaces the onboarding stack — the user cannot go "back" to
      // onboarding after completing it.
      context.go(RouteNames.welcomePath);
    } else {
      _pageController.nextPage(
        duration: _animationDuration,
        curve: _animationCurve,
      );
    }
  }

  /// Skips onboarding and navigates immediately to the auth home.
  Future<void> _handleSkip() async {
    await markOnboardingComplete();
    if (!mounted) return;
    context.go(RouteNames.welcomePath);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // ── Skip link (top-right) ────────────────────────────────────
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(
                  top: AppDimens.spaceSm,
                  right: AppDimens.spaceMd,
                ),
                child: TextButton(
                  onPressed: _handleSkip,
                  child: Text(
                    'Skip',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),

            // ── Page content ─────────────────────────────────────────────
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return _ValuePropPage(
                    icon: page.icon,
                    headline: page.headline,
                    description: page.description,
                    accentColor: page.accentColor,
                  );
                },
              ),
            ),

            // ── Bottom row: dots + CTA button ─────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceLg,
                vertical: AppDimens.spaceLg,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Page-dot indicators.
                  Row(
                    children: List.generate(_pages.length, (i) {
                      final isActive = i == _currentPage;
                      return AnimatedContainer(
                        duration: _animationDuration,
                        curve: _animationCurve,
                        margin: const EdgeInsets.only(right: AppDimens.spaceSm),
                        width: isActive ? _activeDotSize : _inactiveDotSize,
                        height: isActive ? _activeDotSize : _inactiveDotSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isActive
                              ? AppColors.primary
                              : AppColors.borderLight,
                        ),
                      );
                    }),
                  ),

                  // Next / Create Account CTA.
                  SizedBox(
                    width: _buttonWidth,
                    child: PrimaryButton(
                      label: _isLastPage ? 'Get Started' : 'Next',
                      onPressed: _handleNextOrFinish,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Private Widgets ────────────────────────────────────────────────────────────

/// A single value-proposition page rendered inside [OnboardingPageView].
///
/// Displays a large illustration container with a tinted background, an icon,
/// a bold headline, and descriptive body copy.
class _ValuePropPage extends StatelessWidget {
  /// Creates a [_ValuePropPage].
  const _ValuePropPage({
    required this.icon,
    required this.headline,
    required this.description,
    required this.accentColor,
  });

  /// Material icon displayed at full size inside the illustration area.
  final IconData icon;

  /// Short headline for this value proposition.
  final String headline;

  /// 1-2 sentence description explaining the value proposition.
  final String description;

  /// Tint color used for the illustration background and icon.
  final Color accentColor;

  /// Dimension of the square illustration container.
  static const double _illustrationSize = 200;

  /// Size of the icon rendered inside the illustration container.
  static const double _iconSize = 80;

  /// Maximum number of lines for the description text.
  static const int _descriptionMaxLines = 4;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceXl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ── Illustration container ───────────────────────────────────
          Container(
            width: _illustrationSize,
            height: _illustrationSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDimens.radiusCard),
              color: accentColor.withValues(alpha: 0.1),
            ),
            child: Icon(
              icon,
              size: _iconSize,
              color: accentColor,
            ),
          ),

          const SizedBox(height: AppDimens.spaceLg),

          // ── Headline ────────────────────────────────────────────────
          Text(
            headline,
            style: AppTextStyles.h2,
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppDimens.spaceMd),

          // ── Description ─────────────────────────────────────────────
          Text(
            description,
            style: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
            maxLines: _descriptionMaxLines,
          ),
        ],
      ),
    );
  }
}
