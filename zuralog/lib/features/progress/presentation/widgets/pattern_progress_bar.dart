library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/features/progress/presentation/widgets/pattern_fill.dart';

class PatternProgressBar extends StatefulWidget {
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
  State<PatternProgressBar> createState() => _PatternProgressBarState();
}

class _PatternProgressBarState extends State<PatternProgressBar> {
  double _prevFraction = 0.0;

  @override
  void didUpdateWidget(PatternProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _prevFraction = oldWidget.fraction;
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    final effectiveFraction = widget.fraction.clamp(0.0, 1.0);

    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              // Track
              Container(
                decoration: BoxDecoration(
                  color: AppColors.progressBorderDefault,
                  borderRadius: BorderRadius.circular(widget.height / 2),
                ),
              ),
              // Fill
              TweenAnimationBuilder<double>(
                tween: Tween(begin: _prevFraction, end: effectiveFraction),
                duration: (widget.animate && !reducedMotion)
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
                          borderRadius: BorderRadius.circular(widget.height / 2),
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
