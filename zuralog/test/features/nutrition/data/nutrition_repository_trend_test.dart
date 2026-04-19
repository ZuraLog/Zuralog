import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/nutrition/data/mock_nutrition_repository.dart';
import 'package:zuralog/features/nutrition/domain/nutrition_models.dart';

void main() {
  const repo = MockNutritionRepository();

  group('MockNutritionRepository.getTrend', () {
    test('returns exactly 7 items for "7d"', () async {
      final days = await repo.getTrend('7d');
      expect(days.length, 7);
    });

    test('returns exactly 30 items for "30d"', () async {
      final days = await repo.getTrend('30d');
      expect(days.length, 30);
    });

    test('last entry is marked as today', () async {
      final days = await repo.getTrend('7d');
      expect(days.last.isToday, true);
    });

    test('all entries before today have non-null calories and protein', () async {
      final days = await repo.getTrend('7d');
      for (final day in days.take(days.length - 1)) {
        expect(day.calories, isNotNull,
            reason: 'day ${day.date} should have calories');
        expect(day.proteinG, isNotNull,
            reason: 'day ${day.date} should have protein');
      }
    });

    test('date strings are ISO-format substrings (YYYY-MM-DD)', () async {
      final days = await repo.getTrend('7d');
      for (final day in days) {
        expect(RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(day.date), true,
            reason: '${day.date} is not YYYY-MM-DD');
      }
    });
  });

  group('MockNutritionRepository.getTodaySummary AI fields', () {
    test('returns a non-null aiSummary string', () async {
      final summary = await repo.getTodaySummary();
      expect(summary.aiSummary, isA<String>());
      expect(summary.aiSummary, isNotEmpty);
    });

    test('returns a non-null aiGeneratedAt timestamp', () async {
      final summary = await repo.getTodaySummary();
      expect(summary.aiGeneratedAt, isA<DateTime>());
    });
  });
}
