/// Resolves the icon, category color, and pattern variant for a [Goal].
///
/// Typed goals (stepCount, sleepDuration, etc.) use a fixed mapping. Custom
/// goals first try keyword matching on the goal's title; unmatched custom
/// goals fall back to a deterministic hash of the title that picks from a
/// curated category-colored palette so each goal renders distinctly.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/features/progress/domain/progress_models.dart';
import 'package:zuralog/shared/widgets/pattern/z_pattern_overlay.dart';

typedef GoalVisuals = ({IconData icon, Color color, ZPatternVariant variant});

/// Returns the visual identity (icon + category color + pattern variant)
/// for the given [goal].
GoalVisuals goalVisuals(Goal goal) {
  // 1. Typed goals win — fixed mapping.
  final typed = _typedVisuals[goal.type];
  if (typed != null) return typed;

  // 2. Custom goals — keyword match on the (lowercased) title.
  final lower = goal.title.toLowerCase();
  for (final entry in _keywordVisuals.entries) {
    for (final keyword in entry.key) {
      if (lower.contains(keyword)) return entry.value;
    }
  }

  // 3. Fallback — deterministic hash → curated palette.
  final idx = goal.title.hashCode.abs() % _fallbackPalette.length;
  return _fallbackPalette[idx];
}

// ── Typed goal mapping (matches the enum-level GoalTypeCategory) ────────────

const Map<GoalType, GoalVisuals> _typedVisuals = {
  GoalType.stepCount: (
    icon: Icons.directions_walk_rounded,
    color: AppColors.categoryActivity,
    variant: ZPatternVariant.green,
  ),
  GoalType.weeklyRunCount: (
    icon: Icons.directions_run_rounded,
    color: AppColors.categoryActivity,
    variant: ZPatternVariant.green,
  ),
  GoalType.weightTarget: (
    icon: Icons.gps_fixed_rounded,
    color: AppColors.categoryBody,
    variant: ZPatternVariant.skyBlue,
  ),
  GoalType.dailyCalorieLimit: (
    icon: Icons.restaurant_rounded,
    color: AppColors.categoryNutrition,
    variant: ZPatternVariant.amber,
  ),
  GoalType.sleepDuration: (
    icon: Icons.bedtime_rounded,
    color: AppColors.categorySleep,
    variant: ZPatternVariant.periwinkle,
  ),
  GoalType.waterIntake: (
    icon: Icons.water_drop_rounded,
    color: AppColors.categoryVitals,
    variant: ZPatternVariant.teal,
  ),
};

// ── Keyword-driven mapping for custom goals ────────────────────────────────
// Order matters — first match wins. Multi-word phrases come before single
// words to avoid premature matches (e.g. "step" before "stand").

final Map<List<String>, GoalVisuals> _keywordVisuals = {
  ['step', 'walk']: _typedVisuals[GoalType.stepCount]!,
  ['run', 'jog', 'sprint']: _typedVisuals[GoalType.weeklyRunCount]!,
  ['sleep', 'bed', 'rest']: _typedVisuals[GoalType.sleepDuration]!,
  ['water', 'hydra', 'drink']: _typedVisuals[GoalType.waterIntake]!,
  ['calor', 'food', 'eat', 'meal', 'diet', 'macros']: _typedVisuals[GoalType.dailyCalorieLimit]!,
  ['weight', 'pound', 'kg', 'lbs', 'lift', 'press', 'bench', 'squat', 'gym', 'muscle', 'strength']: (
    icon: Icons.fitness_center_rounded,
    color: AppColors.categoryBody,
    variant: ZPatternVariant.skyBlue,
  ),
  ['heart', 'bpm', 'cardio', 'pulse']: (
    icon: Icons.favorite_rounded,
    color: AppColors.categoryHeart,
    variant: ZPatternVariant.rose,
  ),
  ['yoga', 'stretch', 'flex', 'mobility', 'pilates']: (
    icon: Icons.spa_rounded,
    color: AppColors.categoryMobility,
    variant: ZPatternVariant.yellow,
  ),
  ['meditat', 'mindful', 'breath', 'mood', 'stress', 'wellness']: (
    icon: Icons.self_improvement_rounded,
    color: AppColors.categoryWellness,
    variant: ZPatternVariant.purple,
  ),
  ['cycle', 'bike', 'ride']: (
    icon: Icons.directions_bike_rounded,
    color: AppColors.categoryActivity,
    variant: ZPatternVariant.green,
  ),
  ['swim']: (
    icon: Icons.pool_rounded,
    color: AppColors.categoryBody,
    variant: ZPatternVariant.skyBlue,
  ),
};

// ── Fallback palette for unmatched custom goals ────────────────────────────
// Hash-indexed so each unique title gets a stable, distinct visual identity.
// Uses real category colors only — never Sage default (which would defeat
// the point of the variety).

const List<GoalVisuals> _fallbackPalette = [
  (icon: Icons.local_fire_department_rounded, color: AppColors.streakWarm, variant: ZPatternVariant.amber),
  (icon: Icons.spa_rounded, color: AppColors.categoryMobility, variant: ZPatternVariant.yellow),
  (icon: Icons.favorite_rounded, color: AppColors.categoryHeart, variant: ZPatternVariant.rose),
  (icon: Icons.fitness_center_rounded, color: AppColors.categoryBody, variant: ZPatternVariant.skyBlue),
  (icon: Icons.self_improvement_rounded, color: AppColors.categoryWellness, variant: ZPatternVariant.purple),
  (icon: Icons.bedtime_rounded, color: AppColors.categorySleep, variant: ZPatternVariant.periwinkle),
  (icon: Icons.water_drop_rounded, color: AppColors.categoryVitals, variant: ZPatternVariant.teal),
  (icon: Icons.restaurant_rounded, color: AppColors.categoryNutrition, variant: ZPatternVariant.amber),
  (icon: Icons.directions_walk_rounded, color: AppColors.categoryActivity, variant: ZPatternVariant.green),
  (icon: Icons.eco_rounded, color: AppColors.categoryEnvironment, variant: ZPatternVariant.teal),
];
