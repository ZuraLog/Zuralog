/// Zuralog Dashboard — Shared Graph Utilities.
///
/// Provides common helpers shared across all graph widget files:
///
/// - [graphXLabel]: formats an x-axis timestamp label for a given [TimeRange].
/// - [GraphEmptyState]: the dashed-border "No data" placeholder widget.
/// - [GraphDashedBorderPainter]: the [CustomPainter] that draws the dashed
///   rounded-rectangle border used by [GraphEmptyState].
///
/// Import this file instead of replicating the implementations in each graph.
library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/dashboard/domain/time_range.dart';

// ── X-axis label ──────────────────────────────────────────────────────────────

/// Formats a [DateTime] as a short x-axis label appropriate for [range].
///
/// - [TimeRange.day] → `"9am"` / `"3pm"` / `"12am"`.
/// - [TimeRange.week] → single-letter day initial (`"M"`, `"T"`, …).
/// - [TimeRange.month] → day-of-month number (`"1"`, `"15"`, …).
/// - [TimeRange.sixMonths] / [TimeRange.year] → month initial (`"J"`, `"F"`, …).
///
/// Parameters:
/// - [ts] — the timestamp of the data point.
/// - [range] — the currently selected [TimeRange].
///
/// Returns a short [String] suitable for use in `SideTitles.getTitlesWidget`.
String graphXLabel(DateTime ts, TimeRange range) {
  switch (range) {
    case TimeRange.day:
      final h = ts.hour;
      final suffix = h < 12 ? 'am' : 'pm';
      final display = h == 0 ? 12 : (h > 12 ? h - 12 : h);
      return '$display$suffix';
    case TimeRange.week:
      const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
      return days[(ts.weekday - 1) % 7];
    case TimeRange.month:
      return '${ts.day}';
    case TimeRange.sixMonths:
    case TimeRange.year:
      const months = [
        'J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D',
      ];
      return months[ts.month - 1];
  }
}

// ── Empty state widget ────────────────────────────────────────────────────────

/// A dashed rounded-rectangle "No data" placeholder used by all graph widgets.
///
/// In [compact] mode it fills the standard 48 px sparkline height and shows
/// nothing inside the border. In full mode it expands to fill available space
/// and shows a centred "No data" caption.
///
/// Parameters:
/// - [compact] — when `true`, renders a 48 px tall silent placeholder.
class GraphEmptyState extends StatelessWidget {
  /// Creates a [GraphEmptyState].
  const GraphEmptyState({super.key, required this.compact});

  /// When `true`, renders a silent 48 px placeholder; otherwise expands with
  /// a "No data" label.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 48 : null,
      child: CustomPaint(
        painter: GraphDashedBorderPainter(
          color: AppColors.textSecondary.withValues(alpha: 0.4),
          radius: AppDimens.radiusSm,
        ),
        child: Center(
          child: compact
              ? const SizedBox.shrink()
              : Text(
                  'No data',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
        ),
      ),
    );
  }
}

// ── Dashed border painter ─────────────────────────────────────────────────────

/// Paints a dashed rounded-rectangle border.
///
/// Used by [GraphEmptyState] to render the "No data" placeholder frame.
///
/// Parameters:
/// - [color] — the dash stroke colour.
/// - [radius] — the corner radius of the rounded rectangle.
class GraphDashedBorderPainter extends CustomPainter {
  /// Creates a [GraphDashedBorderPainter].
  const GraphDashedBorderPainter({
    required this.color,
    required this.radius,
  });

  /// The dash stroke colour.
  final Color color;

  /// The corner radius of the rounded rectangle.
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    const dashWidth = 6.0;
    const dashSpace = 4.0;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + dashWidth),
          paint,
        );
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(GraphDashedBorderPainter oldDelegate) =>
      color != oldDelegate.color || radius != oldDelegate.radius;
}
