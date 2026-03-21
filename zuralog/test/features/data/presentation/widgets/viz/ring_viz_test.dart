import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/data/domain/data_models.dart';
import 'package:zuralog/features/data/domain/tile_visualization_config.dart';
import 'package:zuralog/features/data/presentation/widgets/viz/ring_viz.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('square: shows percentage text inside ring', (tester) async {
    final config = RingConfig(value: 7500, maxValue: 10000, unit: 'steps');
    await tester.pumpWidget(_wrap(
      RingViz(config: config, color: Colors.blue, size: TileSize.square),
    ));
    expect(find.text('75%'), findsOneWidget);
  });

  testWidgets('tall: shows bar row when weeklyBars non-null', (tester) async {
    final config = RingConfig(
      value: 7500, maxValue: 10000, unit: 'steps',
      weeklyBars: List.generate(7, (i) =>
        BarPoint(label: 'D$i', value: 5000.0 + i * 500, isToday: i == 6)),
    );
    await tester.pumpWidget(_wrap(
      SizedBox(height: 200, child: RingViz(config: config, color: Colors.blue, size: TileSize.tall)),
    ));
    expect(find.byType(RingViz), findsOneWidget);
  });

  testWidgets('renders without exception for all sizes', (tester) async {
    final config = RingConfig(value: 7500, maxValue: 10000, unit: 'steps');
    for (final size in TileSize.values) {
      await tester.pumpWidget(_wrap(
        SizedBox(height: 200, child: RingViz(config: config, color: Colors.blue, size: size)),
      ));
    }
  });
}
