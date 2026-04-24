/// User-driven overrides for the hero body map state.
///
/// In v1 these are an in-memory Riverpod state only — they reset when the
/// app restarts. A follow-up pass will persist them to local storage so
/// "I'm sore today" stays sticky across sessions.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/features/body/domain/muscle_state.dart';
import 'package:zuralog/features/workout/domain/exercise.dart' show MuscleGroup;

/// Notifier that lets the user cycle a muscle's state manually.
///
/// Cycle order: (no override) → fresh → worked → sore → (cleared).
class MuscleStateOverridesNotifier
    extends StateNotifier<Map<MuscleGroup, MuscleState>> {
  MuscleStateOverridesNotifier() : super(const {});

  /// Cycles the override for [group] to the next state, or clears it if
  /// it was already `sore`.
  void cycle(MuscleGroup group) {
    final next = _nextState(state[group]);
    if (next == null) {
      state = Map<MuscleGroup, MuscleState>.from(state)..remove(group);
    } else {
      state = {...state, group: next};
    }
  }

  /// Sets [group] to the given [muscleState] (used by the tap-a-muscle
  /// picker sheet so the user can jump straight to a state instead of
  /// cycling through all of them).
  void setMuscle(MuscleGroup group, MuscleState muscleState) {
    state = {...state, group: muscleState};
  }

  /// Drops any manual override for [group] (reverts to the computed
  /// state from workouts + wearables).
  void clearMuscle(MuscleGroup group) {
    state = Map<MuscleGroup, MuscleState>.from(state)..remove(group);
  }

  /// Clears every manual override.
  void clearAll() => state = const {};

  static MuscleState? _nextState(MuscleState? current) {
    return switch (current) {
      null => MuscleState.fresh,
      MuscleState.fresh => MuscleState.worked,
      MuscleState.worked => MuscleState.sore,
      MuscleState.sore => null,
      MuscleState.neutral => MuscleState.fresh,
    };
  }
}

final muscleStateOverridesProvider = StateNotifierProvider<
    MuscleStateOverridesNotifier, Map<MuscleGroup, MuscleState>>((ref) {
  return MuscleStateOverridesNotifier();
});
