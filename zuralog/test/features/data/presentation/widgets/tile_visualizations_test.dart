/// Factory dispatch tests for buildTileVisualization.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/data/domain/data_models.dart';
import 'package:zuralog/features/data/domain/tile_visualization_config.dart';
import 'package:zuralog/features/data/presentation/widgets/tile_visualizations.dart';
import 'package:zuralog/features/data/presentation/widgets/viz/stat_card_viz.dart';
import 'package:zuralog/features/data/presentation/widgets/viz/dual_value_viz.dart';
import 'package:zuralog/shared/widgets/charts/z_chart.dart';

void main() {
  group('buildTileVisualization factory', () {
    test('returns ZChart for BarChartConfig', () {
      // Non-empty bars required — empty bars → hasChartData=false → _VizEmptyPlaceholder
      final config = BarChartConfig(
        bars: [BarPoint(label: 'Mon', value: 8000, isToday: false)],
        showAvgLine: false,
      );
      final widget = buildTileVisualization(
        config: config,
        categoryColor: Colors.blue,
        size: TileSize.square,
      );
      expect(widget, isA<ZChart>());
    });

    test('returns StatCardViz for StatCardConfig', () {
      final config = StatCardConfig(value: '16', unit: 'bpm');
      final widget = buildTileVisualization(
        config: config,
        categoryColor: Colors.red,
        size: TileSize.wide,
      );
      expect(widget, isA<StatCardViz>());
    });

    test('returns ZChart for RingConfig', () {
      final config = RingConfig(value: 7500, maxValue: 10000, unit: 'steps');
      final widget = buildTileVisualization(
        config: config,
        categoryColor: Colors.green,
        size: TileSize.square,
      );
      expect(widget, isA<ZChart>());
    });

    test('returns DualValueViz for DualValueConfig', () {
      final config = DualValueConfig(value1: '120', label1: 'SYS', value2: '78', label2: 'DIA');
      final widget = buildTileVisualization(
        config: config,
        categoryColor: Colors.red,
        size: TileSize.square,
      );
      expect(widget, isA<DualValueViz>());
    });

    test('returns ZChart for empty LineChartConfig (ZChart handles its own empty state)', () {
      const config = LineChartConfig(points: []);
      final widget = buildTileVisualization(
        config: config,
        categoryColor: Colors.blue,
        size: TileSize.square,
      );
      // ZChart is returned even for empty data — it handles its own empty state internally
      expect(widget, isA<ZChart>());
    });

    test('returns ZChart for empty BarChartConfig (ZChart handles its own empty state)', () {
      const config = BarChartConfig(bars: []);
      final widget = buildTileVisualization(
        config: config,
        categoryColor: Colors.blue,
        size: TileSize.square,
      );
      // ZChart is returned even for empty data — it handles its own empty state internally
      expect(widget, isA<ZChart>());
    });
  });
}
