import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/nutrition/domain/nutrition_models.dart';

void main() {
  group('NutritionTrendDay', () {
    test('fromJson parses all fields correctly', () {
      final day = NutritionTrendDay.fromJson({
        'date': '2026-04-19',
        'is_today': true,
        'calories': 1850.0,
        'protein_g': 120.5,
      });
      expect(day.date, '2026-04-19');
      expect(day.isToday, true);
      expect(day.calories, 1850.0);
      expect(day.proteinG, 120.5);
    });

    test('fromJson tolerates null optional fields', () {
      final day = NutritionTrendDay.fromJson({
        'date': '2026-04-18',
        'is_today': false,
      });
      expect(day.calories, isNull);
      expect(day.proteinG, isNull);
    });

    test('fromJson defaults isToday to false when missing', () {
      final day = NutritionTrendDay.fromJson({'date': '2026-04-17'});
      expect(day.isToday, false);
    });
  });

  group('NutritionDaySummary', () {
    test('fromJson parses aiSummary and aiGeneratedAt', () {
      final summary = NutritionDaySummary.fromJson({
        'total_calories': 1800,
        'total_protein_g': 110.0,
        'total_carbs_g': 220.0,
        'total_fat_g': 60.0,
        'meal_count': 3,
        'ai_summary': 'Great day of eating!',
        'ai_generated_at': '2026-04-19T10:00:00.000Z',
      });
      expect(summary.aiSummary, 'Great day of eating!');
      expect(summary.aiGeneratedAt, isNotNull);
    });

    test('fromJson tolerates missing ai fields', () {
      final summary = NutritionDaySummary.fromJson({
        'total_calories': 1500,
        'total_protein_g': 90.0,
        'total_carbs_g': 200.0,
        'total_fat_g': 50.0,
        'meal_count': 2,
      });
      expect(summary.aiSummary, isNull);
      expect(summary.aiGeneratedAt, isNull);
    });

    test('empty constant has null ai fields', () {
      expect(NutritionDaySummary.empty.aiSummary, isNull);
      expect(NutritionDaySummary.empty.aiGeneratedAt, isNull);
    });
  });
}
