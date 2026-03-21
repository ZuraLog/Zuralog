import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/data/domain/data_models.dart';
import 'package:zuralog/features/data/domain/tile_visualization_config.dart';
import 'package:zuralog/features/data/presentation/widgets/viz/area_chart_viz.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  final now = DateTime(2026, 3, 21);
  final points = List.generate(7, (i) =>
    ChartPoint(date: now.subtract(Duration(days: 6 - i)), value: 72.0 + i));

  testWidgets('renders without exception for all sizes', (tester) async {
    final config = AreaChartConfig(points: points, positiveIsUp: true);
    for (final size in TileSize.values) {
      await tester.pumpWidget(_wrap(SizedBox(
        height: 120, width: 200,
        child: AreaChartViz(config: config, color: Colors.orange, size: size),
      )));
    }
  });

  testWidgets('shows delta badge when delta non-null', (tester) async {
    final config = AreaChartConfig(points: points, delta: -0.03, positiveIsUp: true);
    await tester.pumpWidget(_wrap(SizedBox(
      height: 120, width: 200,
      child: AreaChartViz(config: config, color: Colors.orange, size: TileSize.wide),
    )));
    expect(find.textContaining('%'), findsWidgets);
  });

  testWidgets('empty points: renders without crash', (tester) async {
    final config = AreaChartConfig(points: [], positiveIsUp: true);
    await tester.pumpWidget(_wrap(SizedBox(
      height: 80, width: 150,
      child: AreaChartViz(config: config, color: Colors.orange, size: TileSize.square),
    )));
  });
}
