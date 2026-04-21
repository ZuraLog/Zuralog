/// Zuralog — Active Workout Session Providers.
///
/// Exposes:
/// - [workoutSessionProvider]        — `StateNotifierProvider<WorkoutSessionNotifier,
///                                      WorkoutSession?>`; live session.
///                                      Not autoDispose: must survive the push
///                                      to the Exercise Catalogue.
/// - [workoutDurationProvider]       — 1 Hz stream of `Duration` since
///                                      `session.startedAt`. `Duration.zero`
///                                      when no session.
/// - [workoutVolumeProvider]         — sum of `weight * reps` for completed
///                                      sets, in the user-entered unit.
/// - [workoutSetsCompletedProvider]  — integer count of completed sets.
///
/// SharedPreferences keys:
/// - `workout_active_draft`                  — in-progress session JSON.
/// - `workout_exercise_unit_<exerciseId>`    — per-exercise unit override.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:zuralog/core/storage/prefs_service.dart';
import 'package:zuralog/features/settings/domain/user_preferences_model.dart';
import 'package:zuralog/features/settings/providers/settings_providers.dart';
import 'package:zuralog/features/workout/data/workout_history_repository.dart';
import 'package:zuralog/features/workout/domain/completed_workout.dart';
import 'package:zuralog/features/workout/domain/exercise.dart';
import 'package:zuralog/features/workout/domain/workout_session.dart';

const String kWorkoutActiveDraftKey = 'workout_active_draft';
const String kWorkoutExerciseUnitKeyPrefix = 'workout_exercise_unit_';
const Object _kNotSet = Object();
const _uuid = Uuid();

class WorkoutSessionNotifier extends StateNotifier<WorkoutSession?> {
  WorkoutSessionNotifier(this._prefs, this._globalUnitDefault) : super(null);

  final SharedPreferences _prefs;
  String _globalUnitDefault;

  void startSession() {
    if (state != null) return;
    final raw = _prefs.getString(kWorkoutActiveDraftKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        state = WorkoutSession.fromJson(json);
        return;
      } catch (e, st) {
        debugPrint(
            '[WorkoutSessionNotifier] corrupt draft, discarding: $e\n$st');
        _prefs.remove(kWorkoutActiveDraftKey);
      }
    }
    state = WorkoutSession(
      id: _uuid.v4(),
      startedAt: DateTime.now(),
      exercises: const [],
    );
    _saveDraft();
  }

  void discardSession() {
    final session = state;
    if (session != null) {
      for (final ex in session.exercises) {
        unawaited(
          _prefs
              .remove('$kWorkoutExerciseUnitKeyPrefix${ex.exerciseId}')
              .catchError(
            (Object e, StackTrace st) {
              debugPrint(
                  '[WorkoutSessionNotifier] remove unit key failed: $e\n$st');
              return false;
            },
          ),
        );
      }
    }
    state = null;
    unawaited(
      _prefs.remove(kWorkoutActiveDraftKey).catchError(
        (Object e, StackTrace st) {
          debugPrint('[WorkoutSessionNotifier] remove draft failed: $e\n$st');
          return false;
        },
      ),
    );
  }

  void addExercises(List<Exercise> exercises) {
    final session = state;
    if (session == null || exercises.isEmpty) return;
    final additions = exercises.map((e) {
      final override =
          _prefs.getString('$kWorkoutExerciseUnitKeyPrefix${e.id}');
      return WorkoutExercise(
        exerciseId: e.id,
        exerciseName: e.name,
        muscleGroup: e.muscleGroup.slug,
        sets: const [WorkoutSet(setNumber: 1, type: SetType.warmUp)],
        unitOverride: override,
      );
    }).toList(growable: false);
    state = session.copyWith(
      exercises: [...session.exercises, ...additions],
    );
    _saveDraft();
  }

  void addSet(String exerciseId) {
    _mutateExercise(exerciseId, (ex) {
      final nextNumber = ex.sets.length + 1;
      final nextType = ex.sets.isEmpty ? SetType.warmUp : SetType.working;
      return ex.copyWith(
        sets: [
          ...ex.sets,
          WorkoutSet(setNumber: nextNumber, type: nextType),
        ],
      );
    });
  }

  void updateSet(
    String exerciseId,
    int setIndex, {
    Object? weightValue = _kNotSet,
    Object? reps = _kNotSet,
    bool? isCompleted,
    SetType? type,
  }) {
    _mutateExercise(exerciseId, (ex) {
      if (setIndex < 0 || setIndex >= ex.sets.length) return ex;
      final sets = [...ex.sets];
      final s = sets[setIndex];
      sets[setIndex] = WorkoutSet(
        setNumber: s.setNumber,
        type: type ?? s.type,
        weightValue: identical(weightValue, _kNotSet)
            ? s.weightValue
            : (weightValue as num?)?.toDouble(),
        reps: identical(reps, _kNotSet)
            ? s.reps
            : (reps as num?)?.toInt(),
        isCompleted: isCompleted ?? s.isCompleted,
        previousRecord: s.previousRecord,
      );
      return ex.copyWith(sets: sets);
    });
  }

  void updateExerciseNotes(String exerciseId, String notes) {
    _mutateExercise(exerciseId, (ex) => ex.copyWith(notes: notes));
  }

  void updateRestTimer(String exerciseId, bool enabled) {
    _mutateExercise(
      exerciseId,
      (ex) => ex.copyWith(restTimerEnabled: enabled),
    );
  }

  void toggleUnit(String exerciseId) {
    _mutateExercise(exerciseId, (ex) {
      final current = ex.unitOverride ?? _globalUnitDefault;
      final next = current == 'metric' ? 'imperial' : 'metric';
      final sets = ex.sets.map((s) {
        final w = s.weightValue;
        if (w == null) return s;
        final converted = next == 'imperial' ? kgToLbs(w) : lbsToKg(w);
        return s.copyWith(
          weightValue: double.parse(converted.toStringAsFixed(2)),
        );
      }).toList(growable: false);
      unawaited(_prefs.setString(
        '$kWorkoutExerciseUnitKeyPrefix$exerciseId',
        next,
      ));
      return ex.copyWith(unitOverride: next, sets: sets);
    });
  }

  void updateGlobalDefault(String newDefault) {
    _globalUnitDefault = newDefault;
  }

  /// Converts the current session to a [CompletedWorkout], appends it to
  /// history, and clears the in-memory + draft session. Returns the
  /// persisted record so the caller can navigate to the summary screen.
  /// Returns `null` if there is no active session.
  Future<CompletedWorkout?> finishSession(
    WorkoutHistoryRepository history,
  ) async {
    final session = state;
    if (session == null) return null;
    final completed = CompletedWorkout.fromSession(
      session,
      completedAt: DateTime.now(),
      globalUnitSystem: _globalUnitDefault,
    );
    try {
      await history.saveWorkout(completed);
    } catch (e, st) {
      debugPrint(
          '[WorkoutSessionNotifier] finishSession save failed: $e\n$st');
    }
    discardSession();
    return completed;
  }

  void removeExercise(String exerciseId) {
    final session = state;
    if (session == null) return;
    state = session.copyWith(
      exercises: session.exercises
          .where((e) => e.exerciseId != exerciseId)
          .toList(growable: false),
    );
    _saveDraft();
  }

  void _mutateExercise(
    String exerciseId,
    WorkoutExercise Function(WorkoutExercise) transform,
  ) {
    final session = state;
    if (session == null) return;
    final idx =
        session.exercises.indexWhere((e) => e.exerciseId == exerciseId);
    if (idx == -1) return;
    final updated = [...session.exercises];
    updated[idx] = transform(updated[idx]);
    state = session.copyWith(exercises: updated);
    _saveDraft();
  }

  void _saveDraft() {
    final session = state;
    if (session == null) {
      unawaited(
        _prefs.remove(kWorkoutActiveDraftKey).catchError(
          (Object e, StackTrace st) {
            debugPrint('[WorkoutSessionNotifier] remove draft failed: $e\n$st');
            return false;
          },
        ),
      );
      return;
    }
    String encoded;
    try {
      encoded = jsonEncode(session.toJson());
    } catch (e, st) {
      debugPrint('[WorkoutSessionNotifier] saveDraft encode failed: $e\n$st');
      return;
    }
    unawaited(
      _prefs.setString(kWorkoutActiveDraftKey, encoded).catchError(
        (Object e, StackTrace st) {
          debugPrint('[WorkoutSessionNotifier] saveDraft write failed: $e\n$st');
          return false;
        },
      ),
    );
  }
}

final workoutSessionProvider =
    StateNotifierProvider<WorkoutSessionNotifier, WorkoutSession?>((ref) {
  final prefs = ref.read(prefsProvider);
  final units = ref.read(unitsSystemProvider);
  final globalDefault = units == UnitsSystem.metric ? 'metric' : 'imperial';
  final notifier = WorkoutSessionNotifier(prefs, globalDefault);
  ref.listen<UnitsSystem>(unitsSystemProvider, (_, next) {
    notifier.updateGlobalDefault(
      next == UnitsSystem.metric ? 'metric' : 'imperial',
    );
  });
  return notifier;
});

final workoutDurationProvider = StreamProvider<Duration>((ref) {
  // Only watch startedAt — set updates must not restart the timer.
  final started = ref.watch(
    workoutSessionProvider.select((s) => s?.startedAt),
  );
  if (started == null) {
    return Stream<Duration>.value(Duration.zero);
  }
  final controller = StreamController<Duration>(sync: true);
  controller.add(DateTime.now().difference(started));
  final timer = Timer.periodic(const Duration(seconds: 1), (_) {
    controller.add(DateTime.now().difference(started));
  });
  ref.onDispose(() {
    timer.cancel();
    controller.close();
  });
  return controller.stream;
});

final workoutVolumeProvider = Provider<double>((ref) {
  final session = ref.watch(workoutSessionProvider);
  if (session == null) return 0.0;
  final globalUnits = ref.watch(unitsSystemProvider);
  final globalDefault = globalUnits == UnitsSystem.metric ? 'metric' : 'imperial';
  var totalKg = 0.0;
  for (final ex in session.exercises) {
    final unitSystem = effectiveUnitSystem(ex, globalDefault);
    for (final s in ex.sets) {
      if (s.isCompleted && s.weightValue != null && s.reps != null) {
        final weightKg = unitSystem == 'imperial'
            ? lbsToKg(s.weightValue!)
            : s.weightValue!;
        totalKg += weightKg * s.reps!;
      }
    }
  }
  return globalUnits == UnitsSystem.imperial ? kgToLbs(totalKg) : totalKg;
});

final workoutHistoryRepositoryProvider =
    Provider<WorkoutHistoryRepository>((ref) {
  final prefs = ref.read(prefsProvider);
  return WorkoutHistoryRepository(prefs);
});

/// One-shot read of the user's workout history, most-recent-first.
/// Invalidated by the finish flow so the history screen refreshes.
final workoutHistoryProvider =
    FutureProvider.autoDispose<List<CompletedWorkout>>((ref) async {
  final repo = ref.watch(workoutHistoryRepositoryProvider);
  return repo.loadAll();
});

final workoutSetsCompletedProvider = Provider<int>((ref) {
  final session = ref.watch(workoutSessionProvider);
  if (session == null) return 0;
  var count = 0;
  for (final ex in session.exercises) {
    for (final s in ex.sets) {
      if (s.isCompleted) count++;
    }
  }
  return count;
});
