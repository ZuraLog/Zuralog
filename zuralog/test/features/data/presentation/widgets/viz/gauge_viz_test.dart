import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/data/domain/data_models.dart';
import 'package:zuralog/features/data/domain/tile_visualization_config.dart';
import 'package:zuralog/features/data/presentation/widgets/viz/gauge_viz.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  final config = GaugeConfig(
    value: 45.0,
    minValue: 0,
    maxValue: 70,
    zones: [
      GaugeZone(min: 0, max: 30, label: 'Poor', color: Colors.red),
      GaugeZone(min: 30, max: 50, label: 'Average', color: Colors.orange),
      GaugeZone(min: 50, max: 70, label: 'Good', color: Colors.green),
    ],
  );

  testWidgets('renders value text', (tester) async {
    await tester.pumpWidget(_wrap(SizedBox(
      height: 120, width: 150,
      child: GaugeViz(config: config, color: Colors.blue, size: TileSize.square),
    )));
    expect(find.text('45.0'), findsOneWidget);
  });

  testWidgets('renders without exception for all sizes', (tester) async {
    for (final size in TileSize.values) {
      await tester.pumpWidget(_wrap(SizedBox(
        height: 220, width: 200,
        child: GaugeViz(config: config, color: Colors.blue, size: size),
      )));
    }
  });
}
