/// Tests for the GoalTypeCategory extension that maps goal types to
/// category colors and brand pattern variants.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/features/progress/domain/progress_models.dart';
import 'package:zuralog/shared/widgets/pattern/z_pattern_overlay.dart';

void main() {
  group('GoalTypeCategory', () {
    test('stepCount → Activity green / Green pattern', () {
      expect(GoalType.stepCount.categoryColor, AppColors.categoryActivity);
      expect(GoalType.stepCount.patternVariant, ZPatternVariant.green);
    });

    test('weeklyRunCount → Activity green / Green pattern', () {
      expect(GoalType.weeklyRunCount.categoryColor, AppColors.categoryActivity);
      expect(GoalType.weeklyRunCount.patternVariant, ZPatternVariant.green);
    });

    test('weightTarget → Body sky blue / SkyBlue pattern', () {
      expect(GoalType.weightTarget.categoryColor, AppColors.categoryBody);
      expect(GoalType.weightTarget.patternVariant, ZPatternVariant.skyBlue);
    });

    test('dailyCalorieLimit → Nutrition orange / Amber pattern', () {
      expect(GoalType.dailyCalorieLimit.categoryColor, AppColors.categoryNutrition);
      expect(GoalType.dailyCalorieLimit.patternVariant, ZPatternVariant.amber);
    });

    test('sleepDuration → Sleep indigo / Periwinkle pattern', () {
      expect(GoalType.sleepDuration.categoryColor, AppColors.categorySleep);
      expect(GoalType.sleepDuration.patternVariant, ZPatternVariant.periwinkle);
    });

    test('waterIntake → Vitals teal / Teal pattern', () {
      expect(GoalType.waterIntake.categoryColor, AppColors.categoryVitals);
      expect(GoalType.waterIntake.patternVariant, ZPatternVariant.teal);
    });

    test('custom → brand primary / original pattern (fallback)', () {
      expect(GoalType.custom.categoryColor, AppColors.primary);
      expect(GoalType.custom.patternVariant, ZPatternVariant.original);
    });

    test('every GoalType has a non-null mapping', () {
      for (final t in GoalType.values) {
        expect(t.categoryColor, isA<Color>());
        expect(t.patternVariant, isA<ZPatternVariant>());
      }
    });
  });
}
