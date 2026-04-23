/// Zuralog — Onboarding Typing Indicator.
///
/// Three animated dots in a small pill, paired with the coach blob in
/// thinking-state. Drops into the chat transcript as a placeholder
/// while the coach's real message is "composing."
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/features/coach/presentation/widgets/coach_blob.dart';

class OnboardingTypingIndicator extends StatefulWidget {
  const OnboardingTypingIndicator({super.key});

  @override
  State<OnboardingTypingIndicator> createState() =>
      _OnboardingTypingIndicatorState();
}

class _OnboardingTypingIndicatorState extends State<OnboardingTypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // Dot animation: staggered fade-in across three dots.
  static const Duration _loopDuration = Duration(milliseconds: 1400);
  static const double _dotSize = 6;
  static const double _dotSpacing = 4;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _loopDuration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Returns the animated alpha for a given dot index (0, 1, 2).
  /// Phase-shifted so the dots pulse in sequence.
  double _dotAlpha(int index) {
    final phase = (_controller.value + index / 3) % 1.0;
    // Triangle wave: 0 → 1 → 0 across the loop.
    final tri = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
    // Keep dots always partially visible so they don't "disappear" feels dead.
    return 0.25 + tri * 0.75;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const CoachBlob(state: BlobState.thinking, size: 22),
          const SizedBox(width: AppDimens.spaceSm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    return Padding(
                      padding: EdgeInsets.only(
                        left: i == 0 ? 0 : _dotSpacing,
                      ),
                      child: Container(
                        width: _dotSize,
                        height: _dotSize,
                        decoration: BoxDecoration(
                          color: colors.textSecondary.withValues(
                            alpha: _dotAlpha(i),
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
