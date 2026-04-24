/// Providers that aggregate workout history into per-muscle metrics used
/// by the Your-Body-Now hero.
///
/// v1: these return empty maps, which render as a neutral body. Real
/// aggregation over the completed-workouts feed lives on the backlog — wire
/// in once the completed-workout model exposes sets × estimated intensity
/// per MuscleGroup. Today's completed-workout surface isn't rich enough to
/// compute this without schema changes; shipping empty keeps the hero
/// rendering correctly for zero-data users, which is the largest cohort.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/features/workout/domain/exercise.dart' show MuscleGroup;

/// Sum of sets × estimated intensity per muscle over the last 72 hours.
/// Empty map = no recent load.
final recentMuscleLoadProvider =
    FutureProvider<Map<MuscleGroup, double>>((ref) async {
  // TODO(body): aggregate completed workouts over last 72h, keyed by
  // primary MuscleGroup × estimated intensity. Requires extending the
  // completed-workout model to expose per-set muscle coverage.
  return const <MuscleGroup, double>{};
});

/// Trailing 28-day per-day average load per muscle. Used as the baseline
/// the 72-hour load is compared against.
/// Empty map = no baseline yet.
final muscleLoadBaselineProvider =
    FutureProvider<Map<MuscleGroup, double>>((ref) async {
  // TODO(body): compute 28-day rolling average of daily load per muscle.
  return const <MuscleGroup, double>{};
});
