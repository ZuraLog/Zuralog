/// Zuralog Design System — Loading Skeleton / Shimmer Placeholder.
library;

import 'package:flutter/material.dart';
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
    // Surface-relative shimmer colors — work on both light and dark themes.
    final baseColor = isDark
        ? const Color(0x26FFFFFF) // 15% white overlay on dark
        : const Color(0x1A000000); // 10% black overlay on light
    final highlightColor = isDark
        ? const Color(0x66FFFFFF) // 40% white overlay on dark
        : const Color(0x33000000); // 20% black overlay on light

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: [
                (_controller.value - 0.3).clamp(0.0, 1.0),
                _controller.value.clamp(0.0, 1.0),
                (_controller.value + 0.3).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}
