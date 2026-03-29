/// Zuralog Design System — Progress Bar Component.
///
/// Horizontal progress indicator with Sage fill, pattern overlay on
/// the active portion, and optional label/value text above the bar.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/shared/widgets/pattern/z_pattern_overlay.dart'
    show ZPatternVariant, effectivePatternVariant, effectivePatternOpacity;

/// A horizontal progress bar with a Sage-colored fill and brand pattern.
///
/// The active (filled) portion uses [AppColors.primary] with a
/// [ZPatternOverlay] on top. The inactive track is [surfaceRaised].
///
/// When [animate] is true (the default), value changes transition over
/// 600ms with an easeOut curve.
class ZProgressBar extends StatelessWidget {
  const ZProgressBar({
    super.key,
    required this.value,
    this.label,
    this.valueLabel,
    this.animate = true,
  }) : assert(value >= 0.0 && value <= 1.0);

  /// Current progress from 0.0 (empty) to 1.0 (full).
  final double value;

  /// Optional label shown above the bar, left-aligned.
  final String? label;

  /// Optional value text shown above the bar, right-aligned, in Sage.
  final String? valueLabel;

  /// Whether to animate value changes. Defaults to true.
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final patternImage = effectivePatternVariant(ZPatternVariant.sage, isLight).assetPath;
    final patternOpacity = effectivePatternOpacity(1.0, isLight);
    final hasLabels = label != null || valueLabel != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Labels row.
        if (hasLabels) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (label != null)
                Text(
                  label!,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: colors.textSecondary,
                  ),
                )
              else
                const SizedBox.shrink(),
              if (valueLabel != null)
                Text(
                  valueLabel!,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: colors.primary,
                  ),
                )
              else
                const SizedBox.shrink(),
            ],
          ),
          const SizedBox(height: AppDimens.spaceXs),
        ],

        // Track.
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: SizedBox(
            height: 6,
            child: Stack(
              children: [
                // Inactive track (full width).
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: colors.surfaceRaised,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),

                // Active track — TweenAnimationBuilder ensures the animation
                // actually fires on a StatelessWidget (AnimatedContainer
                // requires prior state to interpolate from).
                Positioned.fill(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: value.clamp(0.0, 1.0)),
                    duration: animate
                        ? AppMotion.durationMedium
                        : Duration.zero,
                    curve: AppMotion.curveEntrance,
                    builder: (context, animatedValue, _) {
                      if (animatedValue == 0) return const SizedBox.shrink();
                      return FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: animatedValue,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            image: DecorationImage(
                              image: AssetImage(patternImage),
                              fit: BoxFit.cover,
                              opacity: patternOpacity,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
