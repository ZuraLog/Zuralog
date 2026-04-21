import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/data/domain/mandala_data.dart';

void main() {
  group('computeSpokeRatio', () {
    test('returns 1.0 when today equals baseline (regular metric)', () {
      expect(computeSpokeRatio(todayValue: 100, baseline: 100, inverted: false),
          closeTo(1.0, 1e-9));
    });

    test('returns >1 when today is above baseline (regular metric)', () {
      expect(computeSpokeRatio(todayValue: 120, baseline: 100, inverted: false),
          closeTo(1.2, 1e-9));
    });

    test('returns <1 when today is below baseline (regular metric)', () {
      expect(computeSpokeRatio(todayValue: 80, baseline: 100, inverted: false),
          closeTo(0.8, 1e-9));
    });

    test('FLIPS for inverted metric: lower today value -> longer spoke', () {
      // Resting HR: 50 today vs baseline 60 = "good day" = long spoke (>1)
      expect(computeSpokeRatio(todayValue: 50, baseline: 60, inverted: true),
          closeTo(1.2, 1e-9));
    });

    test('clamps extreme highs to 1.5', () {
      expect(computeSpokeRatio(todayValue: 1000, baseline: 100, inverted: false),
          1.5);
    });

    test('clamps extreme lows to 0.5', () {
      expect(computeSpokeRatio(todayValue: 1, baseline: 100, inverted: false),
          0.5);
    });

    test('returns null when baseline is zero', () {
      expect(computeSpokeRatio(todayValue: 100, baseline: 0, inverted: false),
          isNull);
    });

    test('returns null when todayValue is null', () {
      expect(computeSpokeRatio(todayValue: null, baseline: 100, inverted: false),
          isNull);
    });

    test('returns null when value is non-finite', () {
      expect(
        computeSpokeRatio(
            todayValue: double.nan, baseline: 100, inverted: false),
        isNull,
      );
      expect(
        computeSpokeRatio(
            todayValue: double.infinity, baseline: 100, inverted: false),
        isNull,
      );
    });
  });

  group('kInvertedMetricIds', () {
    test('contains the six known inverted metric ids', () {
      expect(kInvertedMetricIds, containsAll(<String>{
        'resting_heart_rate',
        'stress',
        'body_fat',
        'body_fat_percent',
        'respiratory_rate',
        'awake_time',
      }));
    });
  });
}
