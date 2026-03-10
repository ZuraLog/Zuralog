/// Zuralog Design System — Loading Skeleton / Shimmer Placeholder.
library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';

/// A shimmer placeholder used during loading states.
///
/// Displays a rounded rectangle that sweeps a highlight from left to right
/// on a 1200ms loop, using theme-relative colors (not hardcoded white).
///
/// Acceptable StatefulWidget exception: requires [TickerProviderStateMixin]
/// for the shimmer [AnimationController].
///
/// Example:
/// ```dart
/// ZLoadingSkeleton(width: 200, height: 20)
/// ZLoadingSkeleton(width: double.infinity, height: 80, borderRadius: 20)
/// ```
class ZLoadingSkeleton extends StatefulWidget {
  const ZLoadingSkeleton({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = AppDimens.shapeXs,
  });

  /// Width of the skeleton placeholder.
  final double width;

  /// Height of the skeleton placeholder.
  final double height;

  /// Corner radius. Defaults to [AppDimens.shapeXs] (8px).
  final double borderRadius;

  @override
  State<ZLoadingSkeleton> createState() => _ZLoadingSkeletonState();
}

class _ZLoadingSkeletonState extends State<ZLoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Surface-relative shimmer colors sourced from AppColors tokens.
    final baseColor = isDark ? AppColors.shimmerBase : AppColors.shimmerBaseLight;
    final highlightColor =
        isDark ? AppColors.shimmerHighlight : AppColors.shimmerHighlightLight;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        // Compute strictly-increasing gradient stops to avoid the debug
        // assertion crash that fires when two stops share the same value.
        // The sweep window slides from [-w, 0+w] to [1-w, 1+w] across the
        // normalised [0, 1] range. Each stop is clamped then nudged so that
        // stop[n] is always strictly less than stop[n+1].
        const w = 0.3;
        final t = _controller.value * (1.0 + 2 * w) - w;
        final stop0 = (t - w).clamp(0.0, 0.999);
        final stop1 = t.clamp(stop0 + 0.001, 0.999);
        final stop2 = (t + w).clamp(stop1 + 0.001, 1.0);

        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [baseColor, highlightColor, baseColor],
              stops: [stop0, stop1, stop2],
            ),
          ),
        );
      },
    );
  }
}
