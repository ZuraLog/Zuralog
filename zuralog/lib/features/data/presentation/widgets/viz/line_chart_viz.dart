library;

import 'package:flutter/material.dart';
import 'package:zuralog/features/data/domain/data_models.dart';
import 'package:zuralog/features/data/domain/tile_visualization_config.dart';

class LineChartViz extends StatelessWidget {
  const LineChartViz({
    super.key,
    required this.config,
    required this.color,
    required this.size,
  });

  final LineChartConfig config;
  final Color color;
  final TileSize size;

  @override
  Widget build(BuildContext context) {
    if (config.points.isEmpty) return const SizedBox.shrink();
    return switch (size) {
      TileSize.square => _buildSquare(),
      TileSize.wide   => _buildWide(),
      TileSize.tall   => _buildTall(),
    };
  }

  Widget _buildSquare() {
    return CustomPaint(
      painter: _LinePainter(
        points: config.points,
        color: color,
        showDot: true,
        referenceLine: config.referenceLine,
        rangeMin: config.rangeMin,
        rangeMax: config.rangeMax,
      ),
      child: const SizedBox.expand(),
    );
  }

  Widget _buildWide() {
    return CustomPaint(
      painter: _LinePainter(
        points: config.points,
        color: color,
        showDot: true,
        referenceLine: config.referenceLine,
        rangeMin: config.rangeMin,
        rangeMax: config.rangeMax,
      ),
      child: const SizedBox.expand(),
    );
  }

  Widget _buildTall() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: CustomPaint(
            painter: _LinePainter(
              points: config.points,
              color: color,
              showDot: true,
              referenceLine: config.referenceLine,
              rangeMin: config.rangeMin,
              rangeMax: config.rangeMax,
            ),
            child: const SizedBox.expand(),
          ),
        ),
        _StatsRow(points: config.points, color: color),
      ],
    );
  }
}

class _LinePainter extends CustomPainter {
  const _LinePainter({
    required this.points,
    required this.color,
    this.showDot = false,
    this.referenceLine,
    this.rangeMin,
    this.rangeMax,
  });

  final List<ChartPoint> points;
  final Color color;
  final bool showDot;
  final double? referenceLine;
  final double? rangeMin;
  final double? rangeMax;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final values = points.map((p) => p.value).toList();
    final minV = rangeMin ?? values.reduce((a, b) => a < b ? a : b);
    final maxV = rangeMax ?? values.reduce((a, b) => a > b ? a : b);
    final range = (maxV - minV).abs();

    double toX(int i) => size.width * i / (points.length - 1);
    double toY(double v) => range == 0 ? size.height / 2 : size.height * (1 - (v - minV) / range);

    // Range band
    if (rangeMin != null && rangeMax != null) {
      final bandPaint = Paint()..color = color.withOpacity(0.08);
      canvas.drawRect(Rect.fromLTRB(0, toY(maxV), size.width, toY(minV)), bandPaint);
    }

    // Reference line
    if (referenceLine != null) {
      final refY = toY(referenceLine!);
      final refPaint = Paint()
        ..color = color.withOpacity(0.4)
        ..strokeWidth = 0.75
        ..style = PaintingStyle.stroke;
      const dashWidth = 4.0, dashGap = 3.0;
      double x = 0;
      while (x < size.width) {
        canvas.drawLine(Offset(x, refY), Offset((x + dashWidth).clamp(0.0, size.width), refY), refPaint);
        x += dashWidth + dashGap;
      }
    }

    // Line
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = toX(i);
      final y = toY(points[i].value);
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    canvas.drawPath(path, linePaint);

    // Today dot
    if (showDot) {
      final lastX = toX(points.length - 1);
      final lastY = toY(points.last.value);
      canvas.drawCircle(Offset(lastX, lastY), 3, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.points, required this.color});
  final List<ChartPoint> points;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();
    final values = points.map((p) => p.value).toList();
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final avg = values.reduce((a, b) => a + b) / values.length;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Stat(label: 'MIN', value: min.round().toString(), color: color),
          _Stat(label: 'AVG', value: avg.round().toString(), color: color),
          _Stat(label: 'MAX', value: max.round().toString(), color: color),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 8, color: Colors.grey[600])),
      ],
    );
  }
}
