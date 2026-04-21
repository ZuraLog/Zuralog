import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/data/domain/category_summary.dart';
import 'package:zuralog/features/data/domain/data_models.dart';

void main() {
  group('categorySummaryFor', () {
    test('prefers AI headline when present and non-empty', () {
      final result = categorySummaryFor(
        category: HealthCategory.sleep,
        todayValue: 440,
        weekAverage: 420,
        aiHeadline: 'You slept deeper than any night this week.',
      );
      expect(result, 'You slept deeper than any night this week.');
    });

    test('falls through when AI headline is whitespace only', () {
      final result = categorySummaryFor(
        category: HealthCategory.sleep,
        todayValue: 440,
        weekAverage: 420,
        aiHeadline: '   ',
      );
      expect(result, 'Slightly better than your usual.');
    });

    test('returns "No data yet." when today value is null', () {
      final result = categorySummaryFor(
        category: HealthCategory.activity,
        todayValue: null,
        weekAverage: 7000,
      );
      expect(result, 'No data yet.');
    });

    test('returns "No data yet." when average is null', () {
      final result = categorySummaryFor(
        category: HealthCategory.activity,
        todayValue: 8000,
        weekAverage: null,
      );
      expect(result, 'No data yet.');
    });

    test('buckets big positive deltas → "Best this week."', () {
      expect(
        categorySummaryFor(
          category: HealthCategory.activity,
          todayValue: 12000,
          weekAverage: 8000,
        ),
        'Best this week.',
      );
    });

    test('buckets small positive deltas → "Slightly better than your usual."', () {
      expect(
        categorySummaryFor(
          category: HealthCategory.activity,
          todayValue: 8400,
          weekAverage: 8000,
        ),
        'Slightly better than your usual.',
      );
    });

    test('buckets near-zero deltas → "Right on your usual."', () {
      expect(
        categorySummaryFor(
          category: HealthCategory.activity,
          todayValue: 8010,
          weekAverage: 8000,
        ),
        'Right on your usual.',
      );
    });

    test('buckets small negative deltas → "A bit below lately."', () {
      expect(
        categorySummaryFor(
          category: HealthCategory.activity,
          todayValue: 7600,
          weekAverage: 8000,
        ),
        'A bit below lately.',
      );
    });

    test('buckets big negative deltas → "Lower than your usual."', () {
      expect(
        categorySummaryFor(
          category: HealthCategory.activity,
          todayValue: 5000,
          weekAverage: 8000,
        ),
        'Lower than your usual.',
      );
    });

    test('heart: lower resting heart rate is treated as better', () {
      expect(
        categorySummaryFor(
          category: HealthCategory.heart,
          todayValue: 63,
          weekAverage: 70,
        ),
        'Slightly better than your usual.',
      );
    });

    test('heart: rising resting heart rate shows as below', () {
      expect(
        categorySummaryFor(
          category: HealthCategory.heart,
          todayValue: 80,
          weekAverage: 70,
        ),
        'A bit below lately.',
      );
    });
  });
}
