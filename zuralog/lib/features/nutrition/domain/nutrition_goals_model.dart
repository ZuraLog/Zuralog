/// Zuralog — Nutrition Goals Domain Model.
///
/// Provides a structured interface to the app's goal list, extracting
/// and exposing nutrition-specific goal values in a type-safe, domain-focused way.
///
/// [NutritionGoals] reads from [Goal] objects and extracts only the nutrition-relevant
/// ones (calorie budget, macro targets, mineral limits). A null value means that goal
/// is not set.
///
/// [nutritionGoalStatus] evaluates whether an actual value meets the target,
/// returning on-track, at-risk, or off-track status based on whether the goal is
/// a minimum (hit it) or maximum (stay under).
library;

import 'package:zuralog/features/progress/domain/progress_models.dart';

// ── NutritionGoalStatus ────────────────────────────────────────────────────────

/// Whether a nutrition goal's actual value is on track, at risk, or off track.
enum NutritionGoalStatus { onTrack, atRisk, offTrack }

/// Evaluates whether an actual value meets a nutrition target.
///
/// - For minimum goals (proteins, fiber): on-track ≥ 100%, at-risk 50-99%, off-track < 50%
/// - For maximum goals (carbs, fat, sodium, sugar): on-track ≤ 75%, at-risk 75-100%, off-track > 100%
/// - When target is zero, always returns on-track to avoid division errors
NutritionGoalStatus nutritionGoalStatus({
  required double actual,
  required double target,
  required bool isMin,
}) {
  if (target == 0) return NutritionGoalStatus.onTrack;
  final pct = actual / target;
  if (isMin) {
    if (pct >= 1.0) return NutritionGoalStatus.onTrack;
    if (pct >= 0.5) return NutritionGoalStatus.atRisk;
    return NutritionGoalStatus.offTrack;
  } else {
    if (pct <= 0.75) return NutritionGoalStatus.onTrack;
    if (pct <= 1.0) return NutritionGoalStatus.atRisk;
    return NutritionGoalStatus.offTrack;
  }
}

// ── NutritionGoals ────────────────────────────────────────────────────────────

/// User's active nutrition goals extracted from the goal list.
///
/// All fields are optional — null means that goal is not set.
/// Use [hasGoals] to check whether any goal is active.
class NutritionGoals {
  /// Creates a [NutritionGoals].
  const NutritionGoals({
    this.calorieBudget,
    this.proteinMinG,
    this.carbsMaxG,
    this.fatMaxG,
    this.fiberMinG,
    this.sodiumMaxMg,
    this.sugarMaxG,
  });

  /// Daily calorie budget (maximum).
  final double? calorieBudget;

  /// Daily protein minimum (grams).
  final double? proteinMinG;

  /// Daily carbohydrates maximum (grams).
  final double? carbsMaxG;

  /// Daily fat maximum (grams).
  final double? fatMaxG;

  /// Daily fiber minimum (grams).
  final double? fiberMinG;

  /// Daily sodium maximum (milligrams).
  final double? sodiumMaxMg;

  /// Daily sugar maximum (grams).
  final double? sugarMaxG;

  /// True when at least one nutrition goal is set.
  bool get hasGoals =>
      calorieBudget != null ||
      proteinMinG != null ||
      carbsMaxG != null ||
      fatMaxG != null ||
      fiberMinG != null ||
      sodiumMaxMg != null ||
      sugarMaxG != null;

  /// Extracts active nutrition goals from the provided goal list.
  ///
  /// Only includes goals with [isCompleted] == false. If a goal type is not
  /// found or is inactive, the corresponding field is null.
  ///
  /// Note: This will be updated to use the nutrition-specific GoalType enum values
  /// once they are added: dailyProteinTarget, dailyCarbLimit, dailyFatLimit,
  /// dailyFiberTarget, dailySodiumLimit, dailySugarLimit.
  factory NutritionGoals.fromGoalList(List<Goal> goals) {
    double? find(GoalType type) => goals
        .where((g) => g.type == type && !g.isCompleted)
        .map((g) => g.targetValue)
        .cast<double?>()
        .firstOrNull;

    return NutritionGoals(
      calorieBudget: find(GoalType.dailyCalorieLimit),
      // TODO: Update these to use actual enum values once added
      // proteinMinG: find(GoalType.dailyProteinTarget),
      // carbsMaxG: find(GoalType.dailyCarbLimit),
      // fatMaxG: find(GoalType.dailyFatLimit),
      // fiberMinG: find(GoalType.dailyFiberTarget),
      // sodiumMaxMg: find(GoalType.dailySodiumLimit),
      // sugarMaxG: find(GoalType.dailySugarLimit),
    );
  }
}
