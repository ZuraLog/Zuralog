// zuralog/test/features/today/domain/metric_grid_models_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/today/domain/metric_grid_models.dart';

void main() {
  group('MetricTileData', () {
    test('isLit is false when value is null', () {
      const tile = MetricTileData(
        metricType: 'water',
        label: 'Water',
        emoji: '💧',
        categoryColor: 0xFF64D2FF,
        value: null,
        unit: null,
      );
      expect(tile.isLit, isFalse);
    });

    test('isLit is true when value is non-null', () {
      const tile = MetricTileData(
        metricType: 'water',
        label: 'Water',
        emoji: '💧',
        categoryColor: 0xFF64D2FF,
        value: '2.1L',
        unit: null,
      );
      expect(tile.isLit, isTrue);
    });

    test('copyWith preserves unchanged fields', () {
      const tile = MetricTileData(
        metricType: 'steps',
        label: 'Steps',
        emoji: '👣',
        categoryColor: 0xFF30D158,
        value: null,
        unit: null,
      );
      final updated = tile.copyWith(value: '8,432');
      expect(updated.metricType, 'steps');
      expect(updated.value, '8,432');
      expect(updated.isLit, isTrue);
    });

    test('copyWith can clear value back to null', () {
      const tile = MetricTileData(
        metricType: 'water',
        label: 'Water',
        emoji: '💧',
        categoryColor: 0xFF64D2FF,
        value: '2.1L',
      );
      final cleared = tile.copyWith(value: null);
      expect(cleared.value, isNull);
      expect(cleared.isLit, isFalse);
    });
  });
}
