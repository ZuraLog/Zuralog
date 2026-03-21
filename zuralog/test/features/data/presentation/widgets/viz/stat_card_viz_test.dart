import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/data/domain/data_models.dart';
import 'package:zuralog/features/data/domain/tile_visualization_config.dart';
import 'package:zuralog/features/data/presentation/widgets/viz/stat_card_viz.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  final config = StatCardConfig(
    value: '16',
    unit: 'breaths/min',
    statusColor: Colors.green,
    statusLabel: 'Normal',
  );

  testWidgets('square: shows value and status label', (tester) async {
    await tester.pumpWidget(_wrap(
      StatCardViz(config: config, color: Colors.blue, size: TileSize.square),
    ));
    expect(find.text('16'), findsOneWidget);
    expect(find.text('Normal'), findsOneWidget);
  });

  testWidgets('wide: shows secondary stats panel', (tester) async {
    final cfg = StatCardConfig(
      value: '16', unit: 'breaths/min',
      secondaryValue: '14–18 avg', trendNote: 'Stable this week',
    );
    await tester.pumpWidget(_wrap(
      StatCardViz(config: cfg, color: Colors.blue, size: TileSize.wide),
    ));
    expect(find.text('14–18 avg'), findsOneWidget);
  });

  testWidgets('renders without exception for all sizes', (tester) async {
    for (final size in TileSize.values) {
      await tester.pumpWidget(_wrap(
        StatCardViz(config: config, color: Colors.blue, size: size),
      ));
    }
  });
}
