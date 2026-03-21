import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/data/domain/data_models.dart';
import 'package:zuralog/features/data/domain/tile_visualization_config.dart';
import 'package:zuralog/features/data/presentation/widgets/viz/dual_value_viz.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  final config = DualValueConfig(
    value1: '120', label1: 'SYS',
    value2: '78',  label2: 'DIA',
  );

  testWidgets('square: shows both values and labels', (tester) async {
    await tester.pumpWidget(_wrap(
      DualValueViz(config: config, color: Colors.red, size: TileSize.square),
    ));
    expect(find.text('120'), findsOneWidget);
    expect(find.text('78'), findsOneWidget);
    expect(find.text('SYS'), findsOneWidget);
    expect(find.text('DIA'), findsOneWidget);
  });

  testWidgets('renders without exception for all sizes', (tester) async {
    for (final size in TileSize.values) {
      await tester.pumpWidget(_wrap(
        DualValueViz(config: config, color: Colors.red, size: size),
      ));
    }
  });
}
