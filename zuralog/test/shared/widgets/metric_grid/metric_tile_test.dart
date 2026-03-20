// zuralog/test/shared/widgets/metric_grid/metric_tile_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/today/domain/metric_grid_models.dart';
import 'package:zuralog/shared/widgets/metric_grid/metric_tile.dart';
import 'package:zuralog/features/data/domain/data_models.dart';
import 'package:zuralog/features/data/domain/tile_models.dart';
import 'package:zuralog/features/data/presentation/widgets/metric_tile.dart'
    as data_tile;

const _litTile = MetricTileData(
  metricType: 'water',
  label: 'Water',
  emoji: '💧',
  categoryColor: 0xFF64D2FF,
  value: '2.1L',
);

const _greyTile = MetricTileData(
  metricType: 'steps',
  label: 'Steps',
  emoji: '👣',
  categoryColor: 0xFF30D158,
);

void main() {
  group('MetricTile — lit state', () {
    testWidgets('shows the emoji', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: MetricTile(data: _litTile))),
      );
      expect(find.text('💧'), findsOneWidget);
    });

    testWidgets('shows the value when lit', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: MetricTile(data: _litTile))),
      );
      expect(find.text('2.1L'), findsOneWidget);
    });

    testWidgets('shows the label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: MetricTile(data: _litTile))),
      );
      expect(find.text('Water'), findsOneWidget);
    });

    testWidgets('is NOT wrapped in a ColorFiltered greyscale when lit', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: MetricTile(data: _litTile))),
      );
      // A lit tile should not use ColorFiltered (greyscale is only for unlit tiles)
      expect(find.byType(ColorFiltered), findsNothing);
    });
  });

  group('MetricTile — greyscale state', () {
    testWidgets('shows dash placeholder when not lit', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: MetricTile(data: _greyTile))),
      );
      expect(find.text('—'), findsOneWidget);
    });

    testWidgets('is wrapped in ColorFiltered when not lit', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: MetricTile(data: _greyTile))),
      );
      expect(find.byType(ColorFiltered), findsOneWidget);
    });
  });

  group('MetricTile — edit mode', () {
    testWidgets('shows remove button when inEditMode is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MetricTile(data: _litTile, inEditMode: true),
          ),
        ),
      );
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });

    testWidgets('calls onRemove when remove button tapped', (tester) async {
      var called = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MetricTile(
              data: _litTile,
              inEditMode: true,
              onRemove: () { called = true; },
            ),
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.close_rounded));
      expect(called, isTrue);
    });
  });

  group('MetricTile stats footer', () {
    testWidgets('stats footer visible on tall tile when avgLabel + deltaLabel provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: data_tile.MetricTile(
              tileId: TileId.steps,
              dataState: TileDataState.loaded,
              size: TileSize.tall,
              primaryValue: '8,432',
              unit: 'steps',
              avgLabel: 'Avg 8.2k',
              deltaLabel: '↑ 12%',
            ),
          ),
        ),
      );
      expect(find.text('Avg 8.2k'), findsOneWidget);
      expect(find.text('↑ 12%'), findsOneWidget);
    });
  });
}
