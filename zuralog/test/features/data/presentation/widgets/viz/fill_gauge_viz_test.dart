import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/data/domain/data_models.dart';
import 'package:zuralog/features/data/domain/tile_visualization_config.dart';
import 'package:zuralog/features/data/presentation/widgets/viz/fill_gauge_viz.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  final config = FillGaugeConfig(
    value: 1.5,
    maxValue: 2.5,
    unit: 'L',
    unitIcon: '💧',
    unitSize: 0.3,
  );

  testWidgets('shows value text', (tester) async {
    await tester.pumpWidget(_wrap(SizedBox(
      height: 120, width: 150,
      child: FillGaugeViz(config: config, color: Colors.blue, size: TileSize.square),
    )));
    expect(find.text('1.5 L'), findsOneWidget);
  });

  testWidgets('renders without exception for all sizes', (tester) async {
    for (final size in TileSize.values) {
      await tester.pumpWidget(_wrap(SizedBox(
        height: 150, width: 200,
        child: FillGaugeViz(config: config, color: Colors.blue, size: size),
      )));
    }
  });
}
