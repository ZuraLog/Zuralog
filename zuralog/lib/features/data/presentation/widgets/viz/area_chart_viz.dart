library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:zuralog/features/data/domain/data_models.dart';
import 'package:zuralog/features/data/domain/tile_visualization_config.dart';

class AreaChartViz extends StatelessWidget {
  const AreaChartViz({
    super.key,
    required this.config,
    required this.color,
    required this.size,
  });

  final AreaChartConfig config;
  final Color color;
  final TileSize size;

  @override
  Widget build(BuildContext context) {
    if (config.points.isEmpty) return const SizedBox.shrink();
    return Stack(
      children: [
        CustomPaint(
          painter: _AreaPainter(
            points: config.points,
            color: color,
            fillOpacity: config.fillOpacity,
            targetLine: config.targetLine,
          ),
          child: const SizedBox.expand(),
        ),
        if (config.delta != null)
          Positioned(
            top: 4,
            right: 4,
            child: _DeltaBadge(delta: config.delta!, positiveIsUp: config.positiveIsUp),
          ),
      ],
    );
  }
}

class _AreaPainter extends CustomPainter {
  const _AreaPainter({
    required this.points,
    required this.color,
    required this.fillOpacity,
    this.targetLine,
  });

  final List<ChartPoint> points;
  final Color color;
  final double fillOpacity;
  final double? targetLine;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final values = points.map((p) => p.value).toList();
    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final range = math.max((maxV - minV).abs(), 1.0);

    double toX(int i) => size.width * i / (points.length - 1);
    double toY(double v) => size.height * (1 - (v - minV) / range);

    // Build area path
    final areaPath = Path();
    areaPath.moveTo(toX(0), size.height);
    areaPath.lineTo(toX(0), toY(points[0].value));
    for (var i = 1; i < points.length; i++) {
      areaPath.lineTo(toX(i), toY(points[i].value));
    }
    areaPath.lineTo(toX(points.length - 1), size.height);
    areaPath.close();

    canvas.drawPath(areaPath, Paint()..color = color.withOpacity(fillOpacity));

    // Line on top
    final linePath = Path();
    for (var i = 0; i < points.length; i++) {
      if (i == 0) linePath.moveTo(toX(i), toY(points[i].value));
      else linePath.lineTo(toX(i), toY(points[i].value));
    }
    canvas.drawPath(linePath, Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round);

    // Target dashed line
    if (targetLine != null) {
      final ty = toY(targetLine!);
      final dashPaint = Paint()
        ..color = color.withOpacity(0.5)
        ..strokeWidth = 0.75;
      const dashWidth = 4.0, dashGap = 3.0;
      double x = 0;
      while (x < size.width) {
        canvas.drawLine(Offset(x, ty), Offset((x + dashWidth).clamp(0.0, size.width), ty), dashPaint);
        x += dashWidth + dashGap;
      }
    }

    // Today dot
    canvas.drawCircle(
      Offset(toX(points.length - 1), toY(points.last.value)),
      3,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DeltaBadge extends StatelessWidget {
  const _DeltaBadge({required this.delta, required this.positiveIsUp});
  final double delta;
  final bool positiveIsUp;

  @override
  Widget build(BuildContext context) {
    final isPositive = delta >= 0;
    final isGood = positiveIsUp ? isPositive : !isPositive;
    final badgeColor = isGood ? Colors.green : Colors.red;
    final arrow = isPositive ? '▲' : '▼';
    final pct = '${arrow} ${(delta.abs() * 100).toStringAsFixed(1)}%';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(pct, style: TextStyle(fontSize: 8, color: badgeColor, fontWeight: FontWeight.bold)),
    );
  }
}
