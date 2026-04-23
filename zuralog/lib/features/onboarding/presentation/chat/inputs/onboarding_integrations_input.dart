/// Zuralog — Onboarding Integrations Picker.
///
/// A 2×2 grid of tappable integration tiles — Apple Health, Oura,
/// Strava, Fitbit. Multi-select: every tap toggles. A sage Continue
/// button sits beneath the grid and submits the picked set; a quiet
/// "Skip for now" text link lets the user move on without connecting
/// anything.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/shared/widgets/pattern/z_pattern_overlay.dart';

class OnboardingIntegrationOption {
  const OnboardingIntegrationOption({
    required this.id,
    required this.icon,
    required this.accent,
    required this.name,
    required this.tagline,
  });

  final String id;
  final IconData icon;
  final Color accent;
  final String name;
  final String tagline;
}

/// Default integration options. Kept top-level so the conversation
/// controller can label them without duplicating metadata.
const List<OnboardingIntegrationOption> kOnboardingIntegrations = [
  OnboardingIntegrationOption(
    id: 'apple_health',
    icon: FontAwesomeIcons.apple,
    accent: AppColors.categoryHeart,
    name: 'Apple Health',
    tagline: 'iPhone & Watch data',
  ),
  OnboardingIntegrationOption(
    id: 'oura',
    icon: FontAwesomeIcons.circleNotch,
    accent: AppColors.categoryWellness,
    name: 'Oura',
    tagline: 'Sleep & recovery ring',
  ),
  OnboardingIntegrationOption(
    id: 'strava',
    icon: FontAwesomeIcons.strava,
    accent: AppColors.categoryNutrition,
    name: 'Strava',
    tagline: 'Runs & rides',
  ),
  OnboardingIntegrationOption(
    id: 'fitbit',
    icon: FontAwesomeIcons.heartPulse,
    accent: AppColors.categoryBody,
    name: 'Fitbit',
    tagline: 'Steps & heart',
  ),
];

class OnboardingIntegrationsInput extends StatefulWidget {
  const OnboardingIntegrationsInput({
    super.key,
    required this.onSubmit,
  });

  /// Called with the selected integration IDs (or empty list when the
  /// user taps "Skip for now").
  final ValueChanged<List<String>> onSubmit;

  @override
  State<OnboardingIntegrationsInput> createState() =>
      _OnboardingIntegrationsInputState();
}

class _OnboardingIntegrationsInputState
    extends State<OnboardingIntegrationsInput> {
  final Set<String> _picked = {};

  // Tile sizing.
  static const double _tileRadius = 16;
  static const double _iconSize = 22;
  static const double _iconContainerSize = 40;
  static const double _gridSpacing = AppDimens.spaceSm;
  static const double _gridChildAspectRatio = 2.3;

  void _toggle(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_picked.contains(id)) {
        _picked.remove(id);
      } else {
        _picked.add(id);
      }
    });
  }

  void _submit() {
    HapticFeedback.mediumImpact();
    widget.onSubmit(_picked.toList());
  }

  void _skip() {
    HapticFeedback.lightImpact();
    widget.onSubmit(const <String>[]);
  }

  @override
  Widget build(BuildContext context) {
    final canContinue = _picked.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: kOnboardingIntegrations.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: _gridSpacing,
            crossAxisSpacing: _gridSpacing,
            childAspectRatio: _gridChildAspectRatio,
          ),
          itemBuilder: (context, i) {
            final opt = kOnboardingIntegrations[i];
            final on = _picked.contains(opt.id);
            return GestureDetector(
              onTap: () => _toggle(opt.id),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceMd,
                  vertical: AppDimens.spaceSm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(_tileRadius),
                  border: Border.all(
                    color: on ? AppColors.primary : Colors.transparent,
                    width: 1.5,
                  ),
                  boxShadow: on
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.18),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    Container(
                      width: _iconContainerSize,
                      height: _iconContainerSize,
                      decoration: BoxDecoration(
                        color: opt.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        opt.icon,
                        size: _iconSize,
                        color: opt.accent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            opt.name,
                            style: AppTextStyles.labelLarge.copyWith(
                              color: AppColors.warmWhite,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            opt.tagline,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondaryDark,
                              letterSpacing: -0.05,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // Trailing selection indicator.
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: on
                            ? AppColors.primary
                            : AppColors.surfaceRaised,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: on
                          ? const Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: Color(0xFF1A2E22),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: AppDimens.spaceMd),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: canContinue ? 1 : 0.45,
          child: GestureDetector(
            onTap: canContinue ? _submit : null,
            behavior: HitTestBehavior.opaque,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: canContinue
                    ? AppColors.primary
                    : AppColors.surfaceRaised,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Stack(
                children: [
                  if (canContinue)
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: const IgnorePointer(
                          child: ZPatternOverlay(
                            variant: ZPatternVariant.sage,
                            opacity: 0.55,
                            animate: true,
                          ),
                        ),
                      ),
                    ),
                  Center(
                    child: Text(
                      canContinue
                          ? _picked.length == 1
                              ? 'Connect 1 app'
                              : 'Connect ${_picked.length} apps'
                          : 'Tap to connect',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: canContinue
                            ? const Color(0xFF1A2E22)
                            : AppColors.textSecondaryDark,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppDimens.spaceXs),
        Center(
          child: GestureDetector(
            onTap: _skip,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppDimens.spaceSm,
                horizontal: AppDimens.spaceMd,
              ),
              child: Text(
                'Skip for now',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.primary.withValues(alpha: 0.65),
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.1,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
