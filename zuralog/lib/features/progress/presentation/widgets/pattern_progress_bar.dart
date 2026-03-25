library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/features/progress/presentation/widgets/pattern_fill.dart';

class PatternProgressBar extends StatelessWidget {
  const PatternProgressBar({
    super.key,
    required this.fraction,
    this.height = 8.0,
    this.animate = true,
  });

  final double fraction;
  final double height;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    final effectiveFraction = fraction.clamp(0.0, 1.0);

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              // Track
              Container(
                decoration: BoxDecoration(
                  color: AppColors.progressBorderDefault,
                  borderRadius: BorderRadius.circular(height / 2),
                ),
              ),
              // Fill
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: effectiveFraction),
                duration: (animate && !reducedMotion)
                    ? const Duration(milliseconds: 1200)
                    : Duration.zero,
                curve: const Cubic(0.16, 1, 0.3, 1),
                builder: (context, value, _) {
                  return FractionallySizedBox(
                    widthFactor: value,
                    child: PatternFill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(height / 2),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
