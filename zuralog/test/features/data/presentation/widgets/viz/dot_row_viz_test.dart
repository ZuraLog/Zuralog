import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/data/domain/data_models.dart';
import 'package:zuralog/features/data/domain/tile_visualization_config.dart';
import 'package:zuralog/features/data/presentation/widgets/viz/dot_row_viz.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  final points = List.generate(7, (i) => DotPoint(value: 0.5 + i * 0.05, label: 'Day $i'));
  final config = DotRowConfig(points: points);

  testWidgets('renders 7 dots', (tester) async {
    await tester.pumpWidget(_wrap(SizedBox(
      height: 60, width: 200,
      child: DotRowViz(config: config, color: Colors.green, size: TileSize.square),
    )));
    expect(find.byKey(const Key('dot_row_dot')), findsNWidgets(7));
  });

  testWidgets('renders without exception for all sizes', (tester) async {
    for (final size in TileSize.values) {
      await tester.pumpWidget(_wrap(SizedBox(
        height: 120, width: 200,
        child: DotRowViz(config: config, color: Colors.green, size: size),
      )));
    }
  });
}
