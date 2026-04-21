import 'package:flutter_test/flutter_test.dart';

import 'package:zuralog/features/workout/domain/completed_workout.dart';
import 'package:zuralog/features/workout/domain/workout_session.dart';

void main() {
  group('CompletedWorkout', () {
    final sampleSet = const WorkoutSet(
      setNumber: 1,
      type: SetType.working,
      weightValue: 60.0,
      reps: 10,
      isCompleted: true,
    );
    final sampleExercise = CompletedExercise(
      exerciseId: 'bench-press',
      exerciseName: 'Bench Press',
      muscleGroup: 'chest',
      sets: [sampleSet],
      unitOverride: null,
    );
    final sample = CompletedWorkout(
      id: 'w1',
      completedAt: DateTime.utc(2026, 4, 21, 8, 30),
      durationSeconds: 3600,
      exercises: [sampleExercise],
      totalVolumeKg: 600.0,
      totalSetsCompleted: 1,
    );

    test('round-trips through JSON', () {
      final json = sample.toJson();
      final restored = CompletedWorkout.fromJson(json);
      expect(restored, sample);
    });

    test('structural equality ignores list identity', () {
      final copy = CompletedWorkout(
        id: 'w1',
        completedAt: DateTime.utc(2026, 4, 21, 8, 30),
        durationSeconds: 3600,
        exercises: [
          CompletedExercise(
            exerciseId: 'bench-press',
            exerciseName: 'Bench Press',
            muscleGroup: 'chest',
            sets: [
              const WorkoutSet(
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
      expect(copy, sample);
      expect(copy.hashCode, sample.hashCode);
    });

    test('fromSession normalizes mixed-unit volume to kg', () {
      final session = WorkoutSession(
        id: 's1',
        startedAt: DateTime.utc(2026, 4, 21, 8, 0),
        exercises: [
          WorkoutExercise(
            exerciseId: 'bench-press',
            exerciseName: 'Bench Press',
            muscleGroup: 'chest',
            sets: [
              const WorkoutSet(
                setNumber: 1,
                type: SetType.working,
                weightValue: 60.0,
                reps: 10,
                isCompleted: true,
              ),
            ],
          ),
          WorkoutExercise(
            exerciseId: 'squat',
            exerciseName: 'Squat',
            muscleGroup: 'quads',
            sets: [
              const WorkoutSet(
                setNumber: 1,
                type: SetType.working,
                weightValue: 100.0, // 100 lbs = ~45.36 kg
                reps: 5,
                isCompleted: true,
              ),
            ],
            unitOverride: 'imperial',
          ),
        ],
      );
      final completed = CompletedWorkout.fromSession(
        session,
        completedAt: DateTime.utc(2026, 4, 21, 9, 0),
        globalUnitSystem: 'metric',
      );
      expect(completed.totalSetsCompleted, 2);
      // 60 kg * 10 reps = 600 kg-reps; 100 lbs = 45.359 kg * 5 = 226.795
      expect(completed.totalVolumeKg, closeTo(600 + 226.796, 0.01));
      expect(completed.durationSeconds, 3600);
      expect(completed.id, isNotEmpty);
    });

    test('ignores incomplete sets in totals', () {
      final session = WorkoutSession(
        id: 's1',
        startedAt: DateTime.utc(2026, 4, 21, 8, 0),
        exercises: [
          WorkoutExercise(
            exerciseId: 'bench-press',
            exerciseName: 'Bench Press',
            muscleGroup: 'chest',
            sets: [
              const WorkoutSet(
                setNumber: 1,
                type: SetType.working,
                weightValue: 60.0,
                reps: 10,
                isCompleted: false,
              ),
              const WorkoutSet(
                setNumber: 2,
                type: SetType.working,
                weightValue: 70.0,
                reps: 8,
                isCompleted: true,
              ),
            ],
          ),
        ],
      );
      final completed = CompletedWorkout.fromSession(
        session,
        completedAt: DateTime.utc(2026, 4, 21, 9, 0),
        globalUnitSystem: 'metric',
      );
      expect(completed.totalSetsCompleted, 1);
      expect(completed.totalVolumeKg, 70.0 * 8);
    });
  });
}
