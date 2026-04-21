/// Derived metrics for a [Goal]. Pure functions — no Flutter, no async.
library;

import 'package:zuralog/features/progress/domain/progress_models.dart';

/// Average change per day in the goal's value, computed from
/// [Goal.progressHistory]. Returns 0 when history has fewer than two
/// entries. Negative for goals where the trend is going down (e.g. weight).
double velocityPerDay(Goal goal) {
  final h = goal.progressHistory;
  if (h.length < 2) return 0.0;
  final delta = h.last - h.first;
  // Each entry represents one day, so divide by elapsed entries.
  final days = h.length - 1;
  return delta / days;
}

/// Number of whole days between today and [Goal.deadline]. Negative when
/// past, zero when today. Returns null when no deadline is set.
int? daysRemaining(Goal goal, {DateTime? today}) {
  final deadline = goal.deadline;
  if (deadline == null || deadline.isEmpty) return null;
  final parsed = DateTime.tryParse(deadline);
  if (parsed == null) return null;
  final now = today ?? DateTime.now();
  // Compare dates only (ignore time of day).
  final today0 = DateTime(now.year, now.month, now.day);
  final deadline0 = DateTime(parsed.year, parsed.month, parsed.day);
  return deadline0.difference(today0).inDays;
}

/// Projected date the goal will be reached at the current velocity.
/// Returns null when velocity is zero. Returns today when the goal is
/// already complete or over.
DateTime? projectedEndDate(Goal goal, {DateTime? today}) {
  final now = today ?? DateTime.now();
  final today0 = DateTime(now.year, now.month, now.day);
  final remaining = goal.targetValue - goal.currentValue;
  // Already met or exceeded.
  if (remaining <= 0) return today0;
  final v = velocityPerDay(goal);
  if (v == 0) return null;
  final daysToCompletion = (remaining / v.abs()).ceil();
  return today0.add(Duration(days: daysToCompletion));
}

/// How many consecutive trailing entries in [Goal.progressHistory] are
/// positive (non-zero, indicating a logged value for that day).
int logStreak(Goal goal) {
  final h = goal.progressHistory;
  var count = 0;
  for (var i = h.length - 1; i >= 0; i--) {
    if (h[i] <= 0) break;
    count++;
  }
  return count;
}

/// Number of 25%-step milestones (25, 50, 75, 100) reached by the goal's
/// max-ever progress. Range: 0..4.
int milestonesReached(Goal goal) {
  if (goal.targetValue <= 0) return 0;
  final h = goal.progressHistory;
  if (h.isEmpty) {
    final pct = goal.currentValue / goal.targetValue;
    return _milestonesFor(pct);
  }
  final maxValue = h.reduce((a, b) => a > b ? a : b);
  final pct = maxValue / goal.targetValue;
  return _milestonesFor(pct);
}

int _milestonesFor(double fraction) {
  if (fraction >= 1.0) return 4;
  if (fraction >= 0.75) return 3;
  if (fraction >= 0.50) return 2;
  if (fraction >= 0.25) return 1;
  return 0;
}
