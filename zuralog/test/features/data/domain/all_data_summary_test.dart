import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/data/domain/all_data_summary.dart';
import 'package:zuralog/features/data/domain/data_models.dart' show HealthCategory;
import 'package:zuralog/features/data/domain/mandala_data.dart';

MandalaSpoke _spoke(String id, String name, double today, double baseline,
        {bool inverted = false}) =>
    MandalaSpoke(
      metricId: id,
      displayName: name,
      todayValue: today,
      baseline30d: baseline,
      inverted: inverted,
    );

void main() {
  group('AllDataSummaryGenerator.generate', () {
    test('produces empty summary when no spokes have data', () {
      const data = MandalaData(wedges: <MandalaWedge>[]);
      final summary = AllDataSummaryGenerator.generate(data);
      expect(summary.body, isEmpty);
      expect(summary.sections, isEmpty);
      expect(summary.headline, isNotEmpty);
      expect(summary.referenceCount, 0);
    });

    test('headline says "strong" when all top deviations are positive', () {
      final data = MandalaData(wedges: [
        MandalaWedge(category: HealthCategory.activity, spokes: [
          _spoke('steps', 'Steps', 12000, 8000),
          _spoke('active_minutes', 'Active mins', 60, 30),
        ]),
        MandalaWedge(category: HealthCategory.sleep, spokes: [
          _spoke('deep_sleep', 'Deep sleep', 1.8, 1.4),
        ]),
      ]);
      final summary = AllDataSummaryGenerator.generate(data);
      expect(summary.headline.toLowerCase(), contains('strong'));
    });

    test('headline non-empty for mixed positive + negative day', () {
      final data = MandalaData(wedges: [
        MandalaWedge(category: HealthCategory.activity, spokes: [
          _spoke('steps', 'Steps', 12000, 8000),
        ]),
        MandalaWedge(category: HealthCategory.heart, spokes: [
          _spoke('resting_heart_rate', 'Resting HR', 50, 60, inverted: true),
        ]),
        MandalaWedge(category: HealthCategory.wellness, spokes: [
          _spoke('stress', 'Stress', 8, 4, inverted: true),
        ]),
      ]);
      final summary = AllDataSummaryGenerator.generate(data);
      expect(summary.headline, isNotEmpty);
    });

    test('body references at most three metrics with metricId tags', () {
      final data = MandalaData(wedges: [
        MandalaWedge(category: HealthCategory.activity, spokes: [
          _spoke('steps', 'Steps', 12000, 8000),
          _spoke('active_minutes', 'Active mins', 60, 30),
        ]),
        MandalaWedge(category: HealthCategory.sleep, spokes: [
          _spoke('deep_sleep', 'Deep sleep', 1.8, 1.4),
          _spoke('rem_sleep', 'REM sleep', 1.0, 1.5),
        ]),
        MandalaWedge(category: HealthCategory.heart, spokes: [
          _spoke('resting_heart_rate', 'Resting HR', 50, 60, inverted: true),
        ]),
      ]);
      final summary = AllDataSummaryGenerator.generate(data);
      final taggedCount = summary.body.where((s) => s.metricId != null).length;
      expect(taggedCount, lessThanOrEqualTo(3));
    });

    test('sections are sorted by absolute deviation (largest first)', () {
      final data = MandalaData(wedges: [
        MandalaWedge(category: HealthCategory.activity, spokes: [
          _spoke('steps', 'Steps', 12000, 8000), // +50% (clamped to +50% via 1.5 cap)
        ]),
        MandalaWedge(category: HealthCategory.sleep, spokes: [
          _spoke('deep_sleep', 'Deep sleep', 1.5, 1.4), // +7%
        ]),
        MandalaWedge(category: HealthCategory.heart, spokes: [
          _spoke('hrv', 'HRV', 70, 50), // +40%
        ]),
      ]);
      final summary = AllDataSummaryGenerator.generate(data);
      expect(summary.sections.first.primaryMetricId, 'steps');
    });

    test('referenceCount equals total spokes with valid baseline + value', () {
      final data = MandalaData(wedges: [
        MandalaWedge(category: HealthCategory.activity, spokes: [
          _spoke('steps', 'Steps', 12000, 8000),
          _spoke('active_minutes', 'Active mins', 60, 30),
          const MandalaSpoke(
            metricId: 'distance',
            displayName: 'Distance',
            todayValue: null,
            baseline30d: 5.0,
            inverted: false,
          ), // skipped
        ]),
      ]);
      final summary = AllDataSummaryGenerator.generate(data);
      expect(summary.referenceCount, 2);
    });
  });
}
