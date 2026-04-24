/// Provider + pure compute function for the hero body map state.
library;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/features/body/domain/body_state.dart';
import 'package:zuralog/features/body/domain/muscle_state.dart';
import 'package:zuralog/features/body/providers/muscle_state_overrides_provider.dart';
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
///
/// Until the real muscle-load aggregation is wired (see TODOs in
/// [recentMuscleLoadProvider] / [muscleLoadBaselineProvider]), debug
/// builds fall back to a demo state so designers and product can see the
/// hero alive. Release builds never return demo data — they render the
/// zero state until real signals come through.
final bodyStateProvider = FutureProvider<BodyState>((ref) async {
  final overrides = ref.watch(muscleStateOverridesProvider);
  final recent = await ref.watch(recentMuscleLoadProvider.future);
  final baseline = await ref.watch(muscleLoadBaselineProvider.future);
  final real = computeBodyState(
    recentLoadByMuscle: recent,
    baselineByMuscle: baseline,
    now: DateTime.now(),
  );
  var base = real;
  if (kDebugMode && !real.hasAnySignal) base = _demoBodyState();

  // Merge user overrides on top of the computed/demo state. Overrides win
  // so the manual "I'm sore today" flow is always honoured.
  if (overrides.isEmpty) return base;
  return BodyState(
    muscles: {...base.muscles, ...overrides},
    computedAt: base.computedAt,
  );
});

/// Hand-picked example that lights every state colour exactly once, so
/// the hero visually exercises all three legend entries.
BodyState _demoBodyState() {
  return BodyState(
    muscles: const {
      // Sore (red) — shoulders took a beating recently
      MuscleGroup.shoulders: MuscleState.sore,
      // Worked (amber) — yesterday's push session
      MuscleGroup.chest: MuscleState.worked,
      MuscleGroup.triceps: MuscleState.worked,
      MuscleGroup.biceps: MuscleState.worked,
      MuscleGroup.abs: MuscleState.worked,
      // Fresh (green) — legs + back ready to train
      MuscleGroup.quads: MuscleState.fresh,
      MuscleGroup.hamstrings: MuscleState.fresh,
      MuscleGroup.glutes: MuscleState.fresh,
      MuscleGroup.calves: MuscleState.fresh,
      MuscleGroup.back: MuscleState.fresh,
    },
    computedAt: DateTime.now(),
  );
}
