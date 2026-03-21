library;

import 'package:flutter/material.dart';
import 'package:zuralog/features/data/domain/data_models.dart';
import 'package:zuralog/features/data/domain/tile_visualization_config.dart';

class DualValueViz extends StatelessWidget {
  const DualValueViz({
    super.key,
    required this.config,
    required this.color,
    required this.size,
  });

  final DualValueConfig config;
  final Color color;
  final TileSize size;

  @override
  Widget build(BuildContext context) {
    return switch (size) {
      TileSize.square => _Square(config: config, color: color),
      TileSize.wide   => _Wide(config: config, color: color),
      TileSize.tall   => _Tall(config: config, color: color),
    };
  }
}

class _ValueColumn extends StatelessWidget {
  const _ValueColumn({required this.value, required this.label, required this.color});
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 9, color: Colors.grey[600])),
      ],
    );
  }
}

class _Square extends StatelessWidget {
  const _Square({required this.config, required this.color});
  final DualValueConfig config;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _ValueColumn(value: config.value1, label: config.label1, color: color),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text('/', style: TextStyle(fontSize: 20, color: Colors.grey[400])),
        ),
        _ValueColumn(value: config.value2, label: config.label2, color: color),
      ],
    );
  }
}

class _Wide extends StatelessWidget {
  const _Wide({required this.config, required this.color});
  final DualValueConfig config;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Square(config: config, color: color),
        ),
        if (config.points1 != null || config.points2 != null)
          SizedBox(
            width: 60,
            height: 40,
            child: CustomPaint(
              painter: _MiniLinePainter(
                points1: config.points1 ?? [],
                points2: config.points2 ?? [],
                color: color,
              ),
            ),
          ),
      ],
    );
  }
}

class _Tall extends StatelessWidget {
  const _Tall({required this.config, required this.color});
  final DualValueConfig config;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _ValueColumn(value: config.value1, label: config.label1, color: color),
        const SizedBox(height: 8),
        _ValueColumn(value: config.value2, label: config.label2, color: color),
      ],
    );
  }
}

class _MiniLinePainter extends CustomPainter {
  const _MiniLinePainter({required this.points1, required this.points2, required this.color});
  final List<ChartPoint> points1;
  final List<ChartPoint> points2;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points1.isEmpty && points2.isEmpty) return;
    final paint = Paint()..color = color..strokeWidth = 1.5..style = PaintingStyle.stroke;
    _drawLine(canvas, size, points1, paint);
    _drawLine(canvas, size, points2, paint..color = color.withOpacity(0.5));
  }

  void _drawLine(Canvas canvas, Size size, List<ChartPoint> pts, Paint paint) {
    if (pts.length < 2) return;
    final minVal = pts.map((p) => p.value).reduce((a, b) => a < b ? a : b);
    final maxVal = pts.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    final range = (maxVal - minVal).abs();
    final path = Path();
    for (var i = 0; i < pts.length; i++) {
      final x = size.width * i / (pts.length - 1);
      final y = range == 0 ? size.height / 2 : size.height * (1 - (pts[i].value - minVal) / range);
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
