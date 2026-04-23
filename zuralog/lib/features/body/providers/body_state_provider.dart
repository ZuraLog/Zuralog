/// Provider + pure compute function for the hero body map state.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/features/body/domain/body_state.dart';
import 'package:zuralog/features/body/domain/muscle_state.dart';
import 'package:zuralog/features/workout/domain/exercise.dart' show MuscleGroup;
import 'package:zuralog/features/workout/providers/workout_history_provider.dart'
    show recentMuscleLoadProvider, muscleLoadBaselineProvider;

/// Pure compute function — exposed for tests and for the provider.
BodyState computeBodyState({
  required Map<MuscleGroup, double> recentLoadByMuscle,
  required Map<MuscleGroup, double> baselineByMuscle,
  required DateTime now,
}) {
  final muscles = <MuscleGroup, MuscleState>{};
  for (final group in MuscleGroup.values) {
    if (group == MuscleGroup.cardio ||
        group == MuscleGroup.fullBody ||
        group == MuscleGroup.other) {
      continue;
    }
    final load = recentLoadByMuscle[group] ?? 0.0;
    if (load <= 0) {
      muscles[group] = MuscleState.neutral;
      continue;
    }
    final baseline = baselineByMuscle[group];
    if (baseline == null || baseline <= 0) {
      // Conservative default — had load but no baseline yet.
      muscles[group] = MuscleState.worked;
      continue;
    }
    final ratio = load / baseline;
    if (ratio >= 1.2) {
      muscles[group] = MuscleState.sore;
    } else if (ratio >= 0.4) {
      muscles[group] = MuscleState.worked;
    } else {
      muscles[group] = MuscleState.fresh;
    }
  }
  return BodyState(muscles: muscles, computedAt: now);
}

/// Riverpod provider: resolves workout history + baselines and feeds them
/// into [computeBodyState].
final bodyStateProvider = FutureProvider<BodyState>((ref) async {
  final recent = await ref.watch(recentMuscleLoadProvider.future);
  final baseline = await ref.watch(muscleLoadBaselineProvider.future);
  return computeBodyState(
    recentLoadByMuscle: recent,
    baselineByMuscle: baseline,
    now: DateTime.now(),
  );
});
