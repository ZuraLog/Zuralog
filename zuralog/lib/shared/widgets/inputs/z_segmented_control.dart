/// Zuralog Design System — Segmented Control Component.
///
/// A pill-shaped segmented control with a sliding active indicator.
/// Background track has a subtle pattern overlay; the active segment
/// is warmWhite with dark text.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/shared/widgets/pattern/z_pattern_overlay.dart';

/// A brand-styled segmented control with a sliding pill indicator.
///
/// The background track is Surface (#1E1E20) with a faint topographic pattern.
/// The active segment slides to the selected position with warmWhite fill and
/// dark text. Inactive segments show textSecondary text on transparent.
class ZSegmentedControl extends StatelessWidget {
  const ZSegmentedControl({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
    required this.segments,
    this.enabled = true,
  });

  /// Index of the currently selected segment.
  final int selectedIndex;

  /// Called when the user taps a segment.
  final ValueChanged<int> onChanged;

  /// Labels for each segment.
  final List<String> segments;

  /// Whether the segmented control is interactive.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final padding = 4.0;
        final usableWidth = totalWidth - (padding * 2);
        final segmentWidth = usableWidth / segments.length;

        return ClipRRect(
          borderRadius: BorderRadius.circular(AppDimens.shapePill),
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(AppDimens.shapePill),
            ),
            child: Stack(
              children: [
                // Pattern overlay on the track.
                const Positioned.fill(
                  child: ZPatternOverlay(
                    variant: ZPatternVariant.original,
                    opacity: 0.04,
                    blendMode: BlendMode.screen,
                  ),
                ),
                // Sliding active pill.
                AnimatedPositioned(
                  duration: AppMotion.durationMedium,
                  curve: AppMotion.curveTransition,
                  left: padding + (selectedIndex * segmentWidth),
                  top: padding,
                  bottom: padding,
                  width: segmentWidth,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.warmWhite,
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                ),
                // Segment labels.
                Padding(
                  padding: EdgeInsets.all(padding),
                  child: Row(
                    children: [
                      for (int i = 0; i < segments.length; i++)
                        Expanded(
                          child: GestureDetector(
                            onTap: enabled ? () => onChanged(i) : null,
                            behavior: HitTestBehavior.opaque,
                            child: Center(
                              child: AnimatedDefaultTextStyle(
                                duration: AppMotion.durationFast,
                                style: AppTextStyles.labelMedium.copyWith(
                                  color: i == selectedIndex
                                      ? AppColors.textOnWarmWhite
                                      : colors.textSecondary,
                                ),
                                child: Text(segments[i]),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
    );
  }
}
