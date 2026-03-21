import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/data/domain/data_models.dart';
import 'package:zuralog/features/data/domain/tile_visualization_config.dart';
import 'package:zuralog/features/data/presentation/widgets/viz/segmented_bar_viz.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  final config = SegmentedBarConfig(
    segments: [
      Segment(label: 'Deep', value: 90, color: Colors.indigo),
      Segment(label: 'Light', value: 210, color: Colors.blue),
      Segment(label: 'REM', value: 60, color: Colors.purple),
      Segment(label: 'Awake', value: 20, color: Colors.orange),
    ],
    totalLabel: '6h 20m',
  );

  testWidgets('shows total label', (tester) async {
    await tester.pumpWidget(_wrap(SizedBox(
      height: 80, width: 200,
      child: SegmentedBarViz(config: config, color: Colors.blue, size: TileSize.square),
    )));
    expect(find.text('6h 20m'), findsOneWidget);
  });

  testWidgets('renders without exception for all sizes', (tester) async {
    for (final size in TileSize.values) {
      await tester.pumpWidget(_wrap(SizedBox(
        height: 120, width: 200,
        child: SegmentedBarViz(config: config, color: Colors.blue, size: size),
      )));
    }
  });
}
