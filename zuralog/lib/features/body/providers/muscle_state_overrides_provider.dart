library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/features/body/data/muscle_log_repository.dart';
import 'package:zuralog/features/body/domain/muscle_state.dart';
import 'package:zuralog/features/workout/domain/exercise.dart' show MuscleGroup;

String _todayIso() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

class MuscleStateOverridesNotifier
    extends StateNotifier<Map<MuscleGroup, MuscleState>> {
  MuscleStateOverridesNotifier(MuscleLogRepository repo)
      : super(_loadFromRepo(repo));

  static Map<MuscleGroup, MuscleState> _loadFromRepo(
      MuscleLogRepository repo) {
    final logs = repo.getLogsForDate(_todayIso());
    return {for (final l in logs) l.muscleGroup: l.state};
  }

  void cycle(MuscleGroup group) {
    final next = _nextState(state[group]);
    if (next == null) {
      state = Map<MuscleGroup, MuscleState>.from(state)..remove(group);
    } else {
      state = {...state, group: next};
    }
  }

  void setMuscle(MuscleGroup group, MuscleState muscleState) {
    state = {...state, group: muscleState};
  }

  void clearMuscle(MuscleGroup group) {
    state = Map<MuscleGroup, MuscleState>.from(state)..remove(group);
  }

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
  final repo = ref.watch(muscleLogRepositoryProvider);
  return MuscleStateOverridesNotifier(repo);
});
