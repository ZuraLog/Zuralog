import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/data/domain/metric_descriptions.dart';

void main() {
  group('MetricDescriptions.lookup', () {
    test('returns the deep-sleep description for "deep_sleep"', () {
      expect(
        MetricDescriptions.lookup('deep_sleep'),
        'Time your body spent in deep, restorative sleep.',
      );
    });

    test('returns the steps description for "steps"', () {
      expect(
        MetricDescriptions.lookup('steps'),
        'Total steps you took today.',
      );
    });

    test('returns the resting-HR description for "resting_heart_rate"', () {
      expect(
        MetricDescriptions.lookup('resting_heart_rate'),
        'Your heart rate at full rest — lower usually means better recovery.',
      );
    });

    test('returns the same description for active_minutes and exercise_minutes', () {
      expect(
        MetricDescriptions.lookup('active_minutes'),
        MetricDescriptions.lookup('exercise_minutes'),
      );
    });

    test('returns generic fallback for unknown id', () {
      expect(
        MetricDescriptions.lookup('totally_unknown_metric_xyz'),
        'Tracked measurement from your connected sources.',
      );
    });
  });
}
