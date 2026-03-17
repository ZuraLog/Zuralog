// zuralog/test/shared/widgets/metric_grid/metric_grid_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/today/domain/metric_grid_models.dart';
import 'package:zuralog/shared/widgets/metric_grid/metric_grid.dart';

MetricTileData _tile(String type) => MetricTileData(
  metricType: type, label: type, emoji: '📊',
  categoryColor: 0xFF30D158, value: '1',
);

void main() {
  group('MetricGrid layout', () {
    testWidgets('shows add-prompt tile when tiles list is empty', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: MetricGrid(tiles: const [], onAddTap: () {}))),
      );
      // Both the header action and the prompt tile show '+ Add metric' when empty
      expect(find.text('+ Add metric'), findsNWidgets(2));
    });

    testWidgets('renders correct number of MetricTile widgets', (tester) async {
      final tiles = List.generate(4, (i) => _tile('m$i'));
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: MetricGrid(tiles: tiles, onAddTap: () {}))),
      );
      // 4 tiles should each show their label
      for (var i = 0; i < 4; i++) {
        expect(find.text('m$i'), findsOneWidget);
      }
    });

    testWidgets('enters edit mode on long press', (tester) async {
      final tiles = List.generate(2, (i) => _tile('m$i'));
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: MetricGrid(tiles: tiles, onAddTap: () {}))),
      );
      // Long press the grid section
      await tester.longPress(find.text('m0'));
      await tester.pump();
      // In edit mode a remove icon should appear
      expect(find.byIcon(Icons.close_rounded), findsWidgets);
    });
  });

  group('MetricGrid layout computation', () {
    test('1 tile → 1 row of 1', () {
      expect(computeGridLayout(1), [1]);
    });
    test('4 tiles → 2×2', () {
      expect(computeGridLayout(4), [2, 2]);
    });
    test('5 tiles → 3+2', () {
      expect(computeGridLayout(5), [3, 2]);
    });
    test('6 tiles → 2×3', () {
      expect(computeGridLayout(6), [3, 3]);
    });
    test('9 tiles → 3×3', () {
      expect(computeGridLayout(9), [3, 3, 3]);
    });
    test('10+ tiles → still 3 rows of 3 (scrollable beyond)', () {
      expect(computeGridLayout(12), [3, 3, 3]);
    });
  });
}
