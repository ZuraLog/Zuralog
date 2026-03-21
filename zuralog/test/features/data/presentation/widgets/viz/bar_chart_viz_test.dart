import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/data/domain/data_models.dart';
import 'package:zuralog/features/data/domain/tile_visualization_config.dart';
import 'package:zuralog/features/data/presentation/widgets/viz/bar_chart_viz.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  final bars = List.generate(7, (i) =>
    BarPoint(label: ['M','T','W','T','F','S','S'][i], value: 5000.0 + i * 1000, isToday: i == 6));

  testWidgets('square: renders 5 bars', (tester) async {
    final config = BarChartConfig(bars: bars);
    await tester.pumpWidget(_wrap(
      SizedBox(height: 80, child: BarChartViz(config: config, color: Colors.green, size: TileSize.square)),
    ));
    expect(find.byKey(const Key('bar_chart_bar')), findsNWidgets(5));
  });

  testWidgets('wide: renders 7 bars', (tester) async {
    final config = BarChartConfig(bars: bars);
    await tester.pumpWidget(_wrap(
      SizedBox(height: 100, child: BarChartViz(config: config, color: Colors.green, size: TileSize.wide)),
    ));
    expect(find.byKey(const Key('bar_chart_bar')), findsNWidgets(7));
  });

  testWidgets('renders without exception for all sizes', (tester) async {
    final config = BarChartConfig(bars: bars);
    for (final size in TileSize.values) {
      await tester.pumpWidget(_wrap(
        SizedBox(height: 120, child: BarChartViz(config: config, color: Colors.green, size: size)),
      ));
    }
  });
}
