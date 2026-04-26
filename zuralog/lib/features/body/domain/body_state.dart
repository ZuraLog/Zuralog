/// Per-muscle state snapshot computed for a given moment in time.
library;

import 'package:zuralog/features/body/domain/muscle_state.dart';
import 'package:zuralog/features/workout/domain/exercise.dart' show MuscleGroup;

class BodyState {
  const BodyState({
    required this.muscles,
    required this.computedAt,
  });

  /// Map of every MuscleGroup the hero cares about → current state.
  /// Missing keys are treated as [MuscleState.neutral].
  final Map<MuscleGroup, MuscleState> muscles;
  final DateTime computedAt;

  static final BodyState empty =
      BodyState(muscles: const {}, computedAt: _epoch);

  MuscleState stateOf(MuscleGroup group) =>
      muscles[group] ?? MuscleState.neutral;

  bool get hasAnySignal =>
      muscles.values.any((s) => s != MuscleState.neutral);
}

final DateTime _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
