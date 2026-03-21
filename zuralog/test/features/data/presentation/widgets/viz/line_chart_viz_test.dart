import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/data/domain/data_models.dart';
import 'package:zuralog/features/data/domain/tile_visualization_config.dart';
import 'package:zuralog/features/data/presentation/widgets/viz/line_chart_viz.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  final now = DateTime(2026, 3, 21);
  final points = List.generate(7, (i) =>
    ChartPoint(date: now.subtract(Duration(days: 6 - i)), value: 60.0 + i));

  testWidgets('square: renders without exception', (tester) async {
    final config = LineChartConfig(points: points, positiveIsUp: true);
    await tester.pumpWidget(_wrap(SizedBox(
      height: 60, width: 120,
      child: LineChartViz(config: config, color: Colors.red, size: TileSize.square),
    )));
    expect(find.byType(LineChartViz), findsOneWidget);
  });

  testWidgets('empty points: renders without crash', (tester) async {
    final config = LineChartConfig(points: [], positiveIsUp: true);
    await tester.pumpWidget(_wrap(SizedBox(
      height: 60, width: 120,
      child: LineChartViz(config: config, color: Colors.red, size: TileSize.square),
    )));
    expect(find.byType(LineChartViz), findsOneWidget);
  });

  testWidgets('renders without exception for all sizes', (tester) async {
    final config = LineChartConfig(points: points, positiveIsUp: true);
    for (final size in TileSize.values) {
      await tester.pumpWidget(_wrap(SizedBox(
        height: 120, width: 200,
        child: LineChartViz(config: config, color: Colors.red, size: size),
      )));
    }
  });
}
