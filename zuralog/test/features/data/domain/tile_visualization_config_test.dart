import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/data/domain/tile_visualization_config.dart';

void main() {
  group('TileVisualizationConfig sealed class', () {
    test('LineChartConfig stores fields', () {
      final now = DateTime(2026, 3, 21);
      final config = LineChartConfig(
        points: [ChartPoint(date: now, value: 60.0)],
        positiveIsUp: true,
      );
      expect(config.points.length, 1);
      expect(config.referenceLine, isNull);
      expect(config.positiveIsUp, isTrue);
    });

    test('BarChartConfig stores fields', () {
      final config = BarChartConfig(
        bars: [BarPoint(label: 'Mon', value: 8000, isToday: false)],
        goalValue: 10000,
        showAvgLine: true,
      );
      expect(config.bars.length, 1);
      expect(config.goalValue, 10000);
    });

    test('RingConfig weeklyBars null means no bars', () {
      final config = RingConfig(value: 7500, maxValue: 10000, unit: 'steps');
      expect(config.weeklyBars, isNull);
    });

    test('RingConfig weeklyBars non-null enables bar row', () {
      final config = RingConfig(
        value: 7500,
        maxValue: 10000,
        unit: 'steps',
        weeklyBars: [BarPoint(label: 'M', value: 7500, isToday: true)],
      );
      expect(config.weeklyBars, isNotNull);
      expect(config.weeklyBars!.length, 1);
    });

    test('GaugeConfig stores zones', () {
      final config = GaugeConfig(
        value: 45.0,
        minValue: 0,
        maxValue: 70,
        zones: [
          GaugeZone(min: 0, max: 30, label: 'Poor', color: Colors.red),
          GaugeZone(min: 30, max: 70, label: 'Good', color: Colors.green),
        ],
      );
      expect(config.zones.length, 2);
    });

    test('HeatmapConfig is a TileVisualizationConfig', () {
      final config = HeatmapConfig(
        cells: [],
        colorLow: Colors.white,
        colorHigh: Colors.blue,
        legendLabel: 'Steps',
      );
      expect(config, isA<TileVisualizationConfig>());
    });
  });
}
