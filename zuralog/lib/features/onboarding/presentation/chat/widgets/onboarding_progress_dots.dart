/// Zuralog — Onboarding Chat Progress Dots.
///
/// Tiny pill-dots at the top of the chat. Advance as the user completes
/// each [ChatStep]. Separate from [ZProgressPill] because the chat
/// context wants smaller, quieter dots — not a full-width bar.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/features/onboarding/presentation/chat/domain/chat_types.dart';

class OnboardingProgressDots extends StatelessWidget {
  const OnboardingProgressDots({
    super.key,
    required this.currentStep,
  });

  final ChatStep currentStep;

  // Only the first 9 steps (name through connect) are user-input steps.
  // The finale is a reveal, not a progress slot.
  static const int _progressSlotCount = 9;

  // Dot sizing.
  static const double _dotWidth = 10;
  static const double _dotHeight = 2.5;
  static const double _dotGap = 3;

  // Inactive opacity relative to warm-white.
  static const double _inactiveAlpha = 0.18;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final currentIndex = currentStep.index.clamp(0, _progressSlotCount - 1);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(_progressSlotCount, (i) {
        final isActive = i <= currentIndex;
        return Padding(
          padding: EdgeInsets.only(left: i == 0 ? 0 : _dotGap),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOut,
            width: _dotWidth,
            height: _dotHeight,
            decoration: BoxDecoration(
              color: isActive
                  ? colors.primary
                  : colors.textPrimary.withValues(alpha: _inactiveAlpha),
              borderRadius: BorderRadius.circular(_dotHeight),
            ),
          ),
        );
      }),
    );
  }
}
