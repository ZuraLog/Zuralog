/// Zuralog Design System — Circular Progress Indicator.
///
/// A Sage-colored spinning arc on a raised-surface track.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/theme.dart';

/// Themed circular progress indicator.
///
/// When [value] is null the indicator spins indefinitely (indeterminate).
/// When [value] is between 0.0 and 1.0 the arc fills to that proportion.
/// The spinning arc uses Sage Green; the background track uses the
/// theme's raised surface color.
class ZCircularProgress extends StatelessWidget {
  /// Creates a [ZCircularProgress].
  const ZCircularProgress({
    super.key,
    this.size = 32.0,
    this.strokeWidth = 3.0,
    this.value,
    this.color,
  });

  /// Overall width and height of the indicator.
  final double size;

  /// Thickness of the arc and track.
  final double strokeWidth;

  /// Progress value between 0.0 and 1.0, or null for indeterminate.
  final double? value;

  /// Arc color. Defaults to the theme's primary (Sage Green in dark mode, Forest Green in light mode).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final effectiveColor = color ?? colors.primary;

    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        value: value,
        strokeWidth: strokeWidth,
        color: effectiveColor,
        backgroundColor: colors.surfaceRaised,
      ),
    );
  }
}
