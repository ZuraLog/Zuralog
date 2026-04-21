library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zuralog/core/storage/prefs_service.dart';
import 'package:zuralog/features/settings/domain/user_preferences_model.dart';
import 'package:zuralog/features/settings/providers/settings_providers.dart';
import 'package:zuralog/features/workout/domain/exercise.dart';
import 'package:zuralog/features/workout/domain/workout_session.dart';
import 'package:zuralog/features/workout/data/workout_history_repository.dart';
import 'package:zuralog/features/workout/providers/workout_session_providers.dart';

ProviderContainer _containerWith(
  SharedPreferences prefs, {
  UnitsSystem units = UnitsSystem.metric,
}) {
  return ProviderContainer(
    overrides: [
      prefsProvider.overrideWithValue(prefs),
      unitsSystemProvider.overrideWithValue(units),
    ],
  );
}

String _encode(WorkoutSession s) => jsonEncode(s.toJson());

const _bench = Exercise(
  id: 'bench_press',
  name: 'Bench Press',
  muscleGroup: MuscleGroup.chest,
  equipment: Equipment.barbell,
  instructions: '',
);

const _squat = Exercise(
  id: 'squat',
  name: 'Back Squat',
  muscleGroup: MuscleGroup.quads,
  equipment: Equipment.barbell,
  instructions: '',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('WorkoutSessionNotifier', () {
    test('initial state is null', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = _containerWith(prefs);
      addTearDown(container.dispose);
      expect(container.read(workoutSessionProvider), isNull);
    });

    test('startSession creates a session with a uuid and now timestamp',
        () async {
      final prefs = await SharedPreferences.getInstance();
      final container = _containerWith(prefs);
      addTearDown(container.dispose);
      container.read(workoutSessionProvider.notifier).startSession();
      final session = container.read(workoutSessionProvider)!;
      expect(session.id, isNotEmpty);
      expect(session.exercises, isEmpty);
      expect(
        DateTime.now().difference(session.startedAt).inSeconds,
        lessThan(2),
      );
      expect(prefs.getString('workout_active_draft'), isNotNull);
    });

    test('startSession with an existing draft restores it', () async {
      final draft = WorkoutSession(
        id: 'restored-id',
        startedAt: DateTime.utc(2026, 4, 20),
        exercises: const [
          WorkoutExercise(
            exerciseId: 'bench_press',
            exerciseName: 'Bench Press',
            muscleGroup: 'chest',
            sets: [WorkoutSet(setNumber: 1, type: SetType.warmUp)],
          ),
        ],
      );
      SharedPreferences.setMockInitialValues({
        'workout_active_draft': _encode(draft),
      });
      final prefs = await SharedPreferences.getInstance();
      final container = _containerWith(prefs);
      addTearDown(container.dispose);
      container.read(workoutSessionProvider.notifier).startSession();
      final session = container.read(workoutSessionProvider)!;
      expect(session.id, 'restored-id');
      expect(session.exercises, hasLength(1));
    });

    test(
        'addExercises appends WorkoutExercise entries with default 2 sets '
        'when no history is cached', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = _containerWith(prefs);
      addTearDown(container.dispose);
      final notifier = container.read(workoutSessionProvider.notifier);
      notifier.startSession();
      notifier.addExercises([_bench, _squat]);
      final session = container.read(workoutSessionProvider)!;
      expect(session.exercises, hasLength(2));
      expect(session.exercises[0].exerciseId, 'bench_press');
      expect(session.exercises[0].sets, hasLength(2));
      expect(session.exercises[0].sets[0].type, SetType.warmUp);
      expect(session.exercises[0].sets[1].type, SetType.working);
      expect(session.exercises[0].muscleGroup, 'chest');
    });

    test('addExercises reads per-exercise unit override from prefs',
        () async {
      SharedPreferences.setMockInitialValues({
        'workout_exercise_unit_bench_press': 'imperial',
      });
      final prefs = await SharedPreferences.getInstance();
      final container = _containerWith(prefs);
      addTearDown(container.dispose);
      final notifier = container.read(workoutSessionProvider.notifier);
      notifier.startSession();
      notifier.addExercises([_bench]);
      expect(
        container.read(workoutSessionProvider)!.exercises.single.unitOverride,
        'imperial',
      );
    });

    test('addSet on an exercise with existing sets appends a working set',
        () async {
      final prefs = await SharedPreferences.getInstance();
      final container = _containerWith(prefs);
      addTearDown(container.dispose);
      final notifier = container.read(workoutSessionProvider.notifier);
      notifier.startSession();
      notifier.addExercises([_bench]);
      notifier.addSet('bench_press');
      final sets =
          container.read(workoutSessionProvider)!.exercises.single.sets;
      // Default is 2 sets (warmUp + working); addSet appends a third.
      expect(sets, hasLength(3));
      expect(sets[0].type, SetType.warmUp);
      expect(sets[1].type, SetType.working);
      expect(sets[2].type, SetType.working);
      expect(sets[2].setNumber, 3);
    });

    test('updateSet applies partial edits immutably', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = _containerWith(prefs);
      addTearDown(container.dispose);
      final notifier = container.read(workoutSessionProvider.notifier);
      notifier.startSession();
      notifier.addExercises([_bench]);
      notifier.updateSet(
        'bench_press',
        0,
        weightValue: 50,
        reps: 10,
        isCompleted: true,
        type: SetType.working,
      );
      final set =
          container.read(workoutSessionProvider)!.exercises.single.sets[0];
      expect(set.weightValue, 50);
      expect(set.reps, 10);
      expect(set.isCompleted, isTrue);
      expect(set.type, SetType.working);
    });

    test('updateExerciseNotes persists the new text', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = _containerWith(prefs);
      addTearDown(container.dispose);
      final notifier = container.read(workoutSessionProvider.notifier);
      notifier.startSession();
      notifier.addExercises([_bench]);
      notifier.updateExerciseNotes('bench_press', 'Slow eccentrics.');
      expect(
        container.read(workoutSessionProvider)!.exercises.single.notes,
        'Slow eccentrics.',
      );
    });

    test('updateRestTimer toggles the enabled flag', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = _containerWith(prefs);
      addTearDown(container.dispose);
      final notifier = container.read(workoutSessionProvider.notifier);
      notifier.startSession();
      notifier.addExercises([_bench]);
      notifier.updateRestTimer('bench_press', false);
      expect(
        container
            .read(workoutSessionProvider)!
            .exercises
            .single
            .restTimerEnabled,
        isFalse,
      );
    });

    test('toggleUnit flips metric to imperial, converts weights, persists',
        () async {
      final prefs = await SharedPreferences.getInstance();
      final container = _containerWith(prefs);
      addTearDown(container.dispose);
      final notifier = container.read(workoutSessionProvider.notifier);
      notifier.startSession();
      notifier.addExercises([_bench]);
      notifier.updateSet('bench_press', 0, weightValue: 50, reps: 10);
      notifier.toggleUnit('bench_press');
      final ex = container.read(workoutSessionProvider)!.exercises.single;
      expect(ex.unitOverride, 'imperial');
      // Default is 2 sets; set[0] had a weight, set[1] did not.
      expect(ex.sets[0].weightValue, closeTo(110.23, 0.1));
      expect(prefs.getString('workout_exercise_unit_bench_press'), 'imperial');

      notifier.toggleUnit('bench_press');
      final ex2 = container.read(workoutSessionProvider)!.exercises.single;
      expect(ex2.unitOverride, 'metric');
      expect(ex2.sets[0].weightValue, closeTo(50, 0.01));
    });

    test('removeExercise drops the matching entry', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = _containerWith(prefs);
      addTearDown(container.dispose);
      final notifier = container.read(workoutSessionProvider.notifier);
      notifier.startSession();
      notifier.addExercises([_bench, _squat]);
      notifier.removeExercise('bench_press');
      final exs = container.read(workoutSessionProvider)!.exercises;
      expect(exs, hasLength(1));
      expect(exs.single.exerciseId, 'squat');
    });

    test('discardSession clears state and removes draft', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = _containerWith(prefs);
      addTearDown(container.dispose);
      final notifier = container.read(workoutSessionProvider.notifier);
      notifier.startSession();
      notifier.addExercises([_bench]);
      expect(prefs.getString('workout_active_draft'), isNotNull);
      notifier.discardSession();
      expect(container.read(workoutSessionProvider), isNull);
      expect(prefs.getString('workout_active_draft'), isNull);
    });

    test('startSession with corrupt draft discards it and creates fresh session',
        () async {
      SharedPreferences.setMockInitialValues({
        'workout_active_draft': 'not-valid-json',
      });
      final prefs = await SharedPreferences.getInstance();
      final container = _containerWith(prefs);
      addTearDown(container.dispose);
      container.read(workoutSessionProvider.notifier).startSession();
      final session = container.read(workoutSessionProvider)!;
      expect(session.id, isNotEmpty);
      expect(session.exercises, isEmpty);
      expect(prefs.getString('workout_active_draft'), isNotNull);
    });

    test('updateSet with out-of-bounds index leaves state unchanged', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = _containerWith(prefs);
      addTearDown(container.dispose);
      final notifier = container.read(workoutSessionProvider.notifier);
      notifier.startSession();
      notifier.addExercises([_bench]);
      final before = container.read(workoutSessionProvider)!;
      notifier.updateSet('bench_press', 99, weightValue: 100, reps: 5);
      expect(container.read(workoutSessionProvider), equals(before));
    });
  });

  group('finishSession', () {
    test('persists workout, clears draft, returns record', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final history = WorkoutHistoryRepository(prefs);

      final container = ProviderContainer(
        overrides: [
          prefsProvider.overrideWithValue(prefs),
          unitsSystemProvider.overrideWithValue(UnitsSystem.metric),
          workoutHistoryRepositoryProvider.overrideWithValue(history),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(workoutSessionProvider.notifier);
      notifier.startSession();
      notifier.addExercises([
        const Exercise(
          id: 'bench-press',
          name: 'Bench Press',
          muscleGroup: MuscleGroup.chest,
          equipment: Equipment.barbell,
          instructions: '',
        ),
      ]);
      notifier.updateSet('bench-press', 0,
          weightValue: 60, reps: 10, isCompleted: true);

      final result = await notifier.finishSession(history);

      expect(result, isNotNull);
      expect(result!.totalSetsCompleted, 1);
      expect(result.totalVolumeKg, 600.0);
      expect(container.read(workoutSessionProvider), isNull);
      expect(prefs.getString(kWorkoutActiveDraftKey), isNull);

      final saved = await history.loadAll();
      expect(saved, [result]);
    });

    test('returns null when no session', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final history = WorkoutHistoryRepository(prefs);

      final container = ProviderContainer(
        overrides: [
          prefsProvider.overrideWithValue(prefs),
          unitsSystemProvider.overrideWithValue(UnitsSystem.metric),
          workoutHistoryRepositoryProvider.overrideWithValue(history),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(workoutSessionProvider.notifier);
      final result = await notifier.finishSession(history);
      expect(result, isNull);
    });
  });

  group('derived providers', () {
    test('workoutVolumeProvider sums weight x reps for completed sets only',
        () async {
      final prefs = await SharedPreferences.getInstance();
      final container = _containerWith(prefs);
      addTearDown(container.dispose);
      final notifier = container.read(workoutSessionProvider.notifier);
      notifier.startSession();
      notifier.addExercises([_bench]);
      notifier.addSet('bench_press');
      notifier.updateSet('bench_press', 0,
          weightValue: 40, reps: 10, isCompleted: true);
      notifier.updateSet('bench_press', 1,
          weightValue: 60, reps: 8, isCompleted: false);
      expect(container.read(workoutVolumeProvider), closeTo(400, 0.001));
    });

    test('workoutSetsCompletedProvider counts only completed sets',
        () async {
      final prefs = await SharedPreferences.getInstance();
      final container = _containerWith(prefs);
      addTearDown(container.dispose);
      final notifier = container.read(workoutSessionProvider.notifier);
      notifier.startSession();
      notifier.addExercises([_bench]);
      notifier.addSet('bench_press');
      notifier.updateSet('bench_press', 0,
          weightValue: 40, reps: 10, isCompleted: true);
      expect(container.read(workoutSetsCompletedProvider), 1);
    });

    test('volume and sets are zero when no session exists', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = _containerWith(prefs);
      addTearDown(container.dispose);
      expect(container.read(workoutVolumeProvider), 0.0);
      expect(container.read(workoutSetsCompletedProvider), 0);
    });
  });
}
