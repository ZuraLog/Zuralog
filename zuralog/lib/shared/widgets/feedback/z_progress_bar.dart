/// Zuralog Design System — Progress Bar Component.
///
/// Horizontal progress indicator with Sage fill, pattern overlay on
/// the active portion, and optional label/value text above the bar.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/shared/widgets/pattern/z_pattern_overlay.dart'
    show ZPatternVariant;

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
                    color: AppColors.primary,
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final totalWidth = constraints.maxWidth;
                final fillWidth = totalWidth * value;

                return Stack(
                  children: [
                    // Inactive track (full width).
                    Container(
                      width: totalWidth,
                      height: 6,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceRaised,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),

                    // Active track — sage pattern as the fill.
                    AnimatedContainer(
                      duration: animate
                          ? AppMotion.durationMedium
                          : Duration.zero,
                      curve: AppMotion.curveEntrance,
                      width: fillWidth,
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        image: DecorationImage(
                          image:
                              AssetImage(ZPatternVariant.sage.assetPath),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
