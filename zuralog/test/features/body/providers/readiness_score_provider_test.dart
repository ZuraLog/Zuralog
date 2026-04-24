import 'package:flutter_test/flutter_test.dart';

import 'package:zuralog/features/body/domain/readiness_score.dart';
import 'package:zuralog/features/body/providers/readiness_score_provider.dart';

void main() {
  group('computeReadiness', () {
    test('all signals present -> weighted composite', () {
      final s = computeReadiness(
        hrvNormalized: 80,
        rhrNormalized: 60,
        sleepNormalized: 70,
        sevenDayAverage: null,
      );
      expect(s.value, 72); // 0.5*80 + 0.3*60 + 0.2*70 = 72
      expect(s.hasSignal, isTrue);
      expect(s.delta, isNull);
    });

    test('missing signals -> weights redistribute proportionally', () {
      final s = computeReadiness(
        hrvNormalized: 80,
        rhrNormalized: null,
        sleepNormalized: null,
        sevenDayAverage: null,
      );
      expect(s.value, 80);
    });

    test('no signals -> ReadinessScore.empty', () {
      final s = computeReadiness(
        hrvNormalized: null,
        rhrNormalized: null,
        sleepNormalized: null,
        sevenDayAverage: null,
      );
      expect(s.value, isNull);
      expect(s.hasSignal, isFalse);
    });

    test('delta is computed relative to sevenDayAverage when provided', () {
      final s = computeReadiness(
        hrvNormalized: 80,
        rhrNormalized: 60,
        sleepNormalized: 70,
        sevenDayAverage: 68,
      );
      expect(s.value, 72);
      expect(s.delta, 4);
    });

    test('value is clamped to [0, 100]', () {
      final low = computeReadiness(
        hrvNormalized: -50,
        rhrNormalized: -50,
        sleepNormalized: -50,
        sevenDayAverage: null,
      );
      expect(low.value, 0);
      final high = computeReadiness(
        hrvNormalized: 500,
        rhrNormalized: 500,
        sleepNormalized: 500,
        sevenDayAverage: null,
      );
      expect(high.value, 100);
    });
  });
}
