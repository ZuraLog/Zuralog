/// Tests for goalVisuals(Goal) — the per-goal icon + category resolver.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/features/progress/domain/progress_models.dart';
import 'package:zuralog/features/progress/presentation/widgets/goal_visuals.dart';
import 'package:zuralog/shared/widgets/pattern/z_pattern_overlay.dart';

Goal _g({required GoalType type, String title = 'My goal'}) => Goal(
      id: 'g',
      userId: 'u',
      type: type,
      period: GoalPeriod.weekly,
      title: title,
      targetValue: 10,
      currentValue: 5,
      unit: 'units',
      startDate: '2026-04-21',
      progressHistory: const [],
    );

void main() {
  group('goalVisuals — typed goals', () {
    test('stepCount → walking shoe + Activity', () {
      final v = goalVisuals(_g(type: GoalType.stepCount));
      expect(v.icon, Icons.directions_walk_rounded);
      expect(v.color, AppColors.categoryActivity);
      expect(v.variant, ZPatternVariant.green);
    });

    test('sleepDuration → moon + Sleep', () {
      final v = goalVisuals(_g(type: GoalType.sleepDuration));
      expect(v.icon, Icons.bedtime_rounded);
      expect(v.color, AppColors.categorySleep);
    });

    test('waterIntake → water drop + Vitals', () {
      final v = goalVisuals(_g(type: GoalType.waterIntake));
      expect(v.icon, Icons.water_drop_rounded);
      expect(v.color, AppColors.categoryVitals);
    });
  });

  group('goalVisuals — custom goals, keyword match', () {
    test('"Daily steps" matches step keyword', () {
      final v = goalVisuals(_g(type: GoalType.custom, title: 'Daily steps'));
      expect(v.icon, Icons.directions_walk_rounded);
      expect(v.color, AppColors.categoryActivity);
    });

    test('"Drink more water" matches water keyword', () {
      final v = goalVisuals(_g(type: GoalType.custom, title: 'Drink more water'));
      expect(v.icon, Icons.water_drop_rounded);
      expect(v.color, AppColors.categoryVitals);
    });

    test('"Sleep 8 hours" matches sleep keyword', () {
      final v = goalVisuals(_g(type: GoalType.custom, title: 'Sleep 8 hours'));
      expect(v.icon, Icons.bedtime_rounded);
      expect(v.color, AppColors.categorySleep);
    });

    test('"Calorie limit" matches calorie keyword', () {
      final v = goalVisuals(_g(type: GoalType.custom, title: 'Calorie limit'));
      expect(v.icon, Icons.restaurant_rounded);
      expect(v.color, AppColors.categoryNutrition);
    });

    test('"Weekly runs" matches run keyword', () {
      final v = goalVisuals(_g(type: GoalType.custom, title: 'Weekly runs'));
      expect(v.icon, Icons.directions_run_rounded);
      expect(v.color, AppColors.categoryActivity);
    });

    test('"Bench press 100kg" matches weight keyword', () {
      final v = goalVisuals(_g(type: GoalType.custom, title: 'Bench press 100kg'));
      expect(v.icon, Icons.fitness_center_rounded);
      expect(v.color, AppColors.categoryBody);
    });

    test('"Yoga 3x a week" matches yoga keyword', () {
      final v = goalVisuals(_g(type: GoalType.custom, title: 'Yoga 3x a week'));
      expect(v.icon, Icons.spa_rounded);
      expect(v.color, AppColors.categoryMobility);
    });

    test('"Meditate daily" matches meditate keyword', () {
      final v = goalVisuals(_g(type: GoalType.custom, title: 'Meditate daily'));
      expect(v.icon, Icons.self_improvement_rounded);
      expect(v.color, AppColors.categoryWellness);
    });
  });

  group('goalVisuals — custom goals, hash fallback', () {
    test('two unrelated titles get different visuals', () {
      final a = goalVisuals(_g(type: GoalType.custom, title: 'Quux'));
      final b = goalVisuals(_g(type: GoalType.custom, title: 'Wibble wobble'));
      expect(a.icon == b.icon && a.color == b.color, isFalse,
        reason: 'Different titles should hash to different palette entries (most of the time)');
    });

    test('same title always returns the same visuals', () {
      final a = goalVisuals(_g(type: GoalType.custom, title: 'Foo bar'));
      final b = goalVisuals(_g(type: GoalType.custom, title: 'Foo bar'));
      expect(a.icon, b.icon);
      expect(a.color, b.color);
      expect(a.variant, b.variant);
    });

    test('hash fallback never returns Sage default (uses category palette)', () {
      // The fallback palette uses real category colors so cards don't look
      // identical. Sage is reserved for sage-typed cards (none in fallback).
      for (final title in ['Foo', 'Bar', 'Baz', 'Qux', 'Frob', 'Glorp', 'Wibble', 'Quux', 'Mxyzptlk']) {
        final v = goalVisuals(_g(type: GoalType.custom, title: title));
        expect(v.color, isNot(AppColors.primary),
          reason: 'Fallback palette should use category colors, not Sage default');
      }
    });
  });
}
