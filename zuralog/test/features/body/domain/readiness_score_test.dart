import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/body/domain/readiness_score.dart';

void main() {
  group('ReadinessScore', () {
    test('empty returns null value + null delta + no signals', () {
      expect(ReadinessScore.empty.value, isNull);
      expect(ReadinessScore.empty.delta, isNull);
      expect(ReadinessScore.empty.hasSignal, isFalse);
    });

    test('hasSignal is true when value is set', () {
      const score = ReadinessScore(value: 72, delta: 4);
      expect(score.hasSignal, isTrue);
    });

    test('clamp clamps to [0, 100]', () {
      expect(ReadinessScore.clamp(-10), 0);
      expect(ReadinessScore.clamp(150), 100);
      expect(ReadinessScore.clamp(42), 42);
    });
  });
}
