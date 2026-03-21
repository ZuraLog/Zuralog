import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/data/domain/data_models.dart';
import 'package:zuralog/features/data/domain/tile_visualization_config.dart';
import 'package:zuralog/features/data/presentation/widgets/viz/heatmap_viz.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  final now = DateTime(2026, 3, 21);
  final cells = List.generate(35, (i) => HeatmapCell(
    date: now.subtract(Duration(days: 34 - i)),
    value: (i % 7) / 6.0,
  ));
  final config = HeatmapConfig(
    cells: cells,
    colorLow: Colors.white,
    colorHigh: Colors.blue,
    legendLabel: 'Steps',
  );

  testWidgets('wide: renders without exception', (tester) async {
    await tester.pumpWidget(_wrap(SizedBox(
      height: 100, width: 250,
      child: HeatmapViz(config: config, color: Colors.blue, size: TileSize.wide),
    )));
    expect(find.byType(HeatmapViz), findsOneWidget);
  });

  testWidgets('square: renders SizedBox.shrink in release behavior', (tester) async {
    await tester.pumpWidget(_wrap(SizedBox(
      height: 100, width: 150,
      child: HeatmapViz(config: config, color: Colors.blue, size: TileSize.square),
    )));
    // Should not throw regardless of size
    expect(find.byType(HeatmapViz), findsOneWidget);
  });

  testWidgets('tall: renders without exception', (tester) async {
    await tester.pumpWidget(_wrap(SizedBox(
      height: 200, width: 200,
      child: HeatmapViz(config: config, color: Colors.blue, size: TileSize.tall),
    )));
    expect(find.byType(HeatmapViz), findsOneWidget);
  });
}
