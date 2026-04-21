import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zuralog/features/workout/data/workout_history_repository.dart';
import 'package:zuralog/features/workout/domain/completed_workout.dart';
import 'package:zuralog/features/workout/domain/workout_session.dart';

CompletedWorkout _make(String id, DateTime when) => CompletedWorkout(
      id: id,
      completedAt: when,
      durationSeconds: 60,
      exercises: const [
        CompletedExercise(
          exerciseId: 'bench-press',
          exerciseName: 'Bench Press',
          muscleGroup: 'chest',
          sets: [
            WorkoutSet(
              setNumber: 1,
              type: SetType.working,
              weightValue: 60.0,
              reps: 10,
              isCompleted: true,
            ),
          ],
        ),
      ],
      totalVolumeKg: 600.0,
      totalSetsCompleted: 1,
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('WorkoutHistoryRepository', () {
    test('loadAll on empty prefs returns empty list', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = WorkoutHistoryRepository(prefs);
      expect(await repo.loadAll(), isEmpty);
    });

    test('saveWorkout persists and loadAll returns most-recent-first',
        () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = WorkoutHistoryRepository(prefs);

      final older = _make('a', DateTime.utc(2026, 4, 20));
      final newer = _make('b', DateTime.utc(2026, 4, 21));
      await repo.saveWorkout(older);
      await repo.saveWorkout(newer);

      final all = await repo.loadAll();
      expect(all.map((w) => w.id), ['b', 'a']);
    });

    test('caps stored history at 100 entries', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = WorkoutHistoryRepository(prefs);

      for (var i = 0; i < 105; i++) {
        await repo.saveWorkout(
          _make('id-$i', DateTime.utc(2026, 1, 1).add(Duration(hours: i))),
        );
      }

      final all = await repo.loadAll();
      expect(all.length, 100);
      // most-recent-first → the freshest survived, the oldest dropped
      expect(all.first.id, 'id-104');
      expect(all.last.id, 'id-5');
    });

    test('loadAll tolerates corrupt JSON by returning empty', () async {
      SharedPreferences.setMockInitialValues({
        'workout_history': '{not valid json',
      });
      final prefs = await SharedPreferences.getInstance();
      final repo = WorkoutHistoryRepository(prefs);
      expect(await repo.loadAll(), isEmpty);
    });

    test('loadAll skips malformed entries but keeps good ones', () async {
      final good = _make('good', DateTime.utc(2026, 4, 21));
      SharedPreferences.setMockInitialValues({
        'workout_history': jsonEncode([
          good.toJson(),
          'not-a-map',
          42,
        ]),
      });
      final prefs = await SharedPreferences.getInstance();
      final repo = WorkoutHistoryRepository(prefs);
      final all = await repo.loadAll();
      expect(all, [good]);
    });
  });
}
