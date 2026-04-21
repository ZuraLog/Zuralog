/// Zuralog Design System — shared 7-day mini sparkline.
///
/// A compact line chart with a gentle gradient fill and a glowing
/// "today" dot. Used by the Today insight card and the Data tab
/// category summary card so both surfaces share one visual.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

/// Shared sparkline used by feature cards that visualise a short trend.
///
/// Pass 5–7 numeric values. Any zero/negative value is treated as a
/// missing data point and hidden from the normalisation so it does not
/// flatten the chart. Set [todayIndex] to the position of today's value
/// — that dot renders with a soft glow so it pops against the line.
class ZMiniSparkline extends StatelessWidget {
  /// Creates a [ZMiniSparkline].
  const ZMiniSparkline({
    super.key,
    required this.values,
    required this.todayIndex,
    required this.color,
    this.trendLabel = '',
    this.height = 36,
  });

  /// Ordered values, oldest first.
  final List<double> values;

  /// Index of today's value in [values]; pass -1 to hide the glow dot.
  final int todayIndex;

  /// Accent color for the line, fill, and glow dot.
  final Color color;

  /// Optional caption below the chart ("7-night duration"). Hidden when empty.
  final String trendLabel;

  /// Chart height in logical pixels.
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: height,
          child: CustomPaint(
            painter: _ZMiniSparklinePainter(
              values: values,
              todayIndex: todayIndex,
              color: color,
            ),
            size: Size.infinite,
          ),
        ),
        if (trendLabel.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            trendLabel,
            style: AppTextStyles.labelSmall.copyWith(
              color: colors.textTertiary,
              fontSize: 10,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ],
    );
  }
}

class _ZMiniSparklinePainter extends CustomPainter {
  _ZMiniSparklinePainter({
    required this.values,
    required this.todayIndex,
    required this.color,
  });

  final List<double> values;
  final int todayIndex;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final nonZero = values.where((v) => v > 0).toList();
    if (nonZero.isEmpty) return;

    final minV = nonZero.reduce(math.min);
    final maxV = nonZero.reduce(math.max);
    final range = (maxV - minV).abs() < 0.0001 ? 1.0 : maxV - minV;

    final points = <Offset>[];
    final step = size.width / (values.length - 1);
    const topPad = 4.0;
    const bottomPad = 4.0;
    final drawHeight = size.height - topPad - bottomPad;
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      final normalized = v <= 0 ? 0.0 : (v - minV) / range;
      final y = topPad + drawHeight * (1 - normalized);
      points.add(Offset(step * i, y));
    }

    final fillPath = Path()..moveTo(points.first.dx, size.height);
    for (final p in points) {
      fillPath.lineTo(p.dx, p.dy);
    }
    fillPath.lineTo(points.last.dx, size.height);
    fillPath.close();
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.28),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      linePath.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(linePath, linePaint);

    if (todayIndex >= 0 && todayIndex < points.length) {
      final p = points[todayIndex];
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(p, 6, glowPaint);
      canvas.drawCircle(p, 3.5, Paint()..color = color);
      canvas.drawCircle(
        p,
        3.5,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ZMiniSparklinePainter old) =>
      old.values != values ||
      old.todayIndex != todayIndex ||
      old.color != color;
}
