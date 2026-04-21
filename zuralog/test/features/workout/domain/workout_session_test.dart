library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/workout/domain/workout_session.dart';

void main() {
  group('SetType', () {
    test('labels are stable human-readable strings', () {
      expect(SetType.warmUp.label, 'Warm-Up');
      expect(SetType.working.label, 'Working');
      expect(SetType.dropSet.label, 'Drop Set');
      expect(SetType.failure.label, 'Failure');
      expect(SetType.amrap.label, 'AMRAP');
    });

    test('fromName round-trips every value', () {
      for (final t in SetType.values) {
        expect(SetType.fromName(t.name), t);
      }
    });

    test('fromName falls back to working for unknown input', () {
      expect(SetType.fromName('moonwalk'), SetType.working);
    });
  });

  group('WorkoutSet', () {
    test('copyWith replaces only the requested fields', () {
      const s = WorkoutSet(setNumber: 1, type: SetType.warmUp);
      final updated = s.copyWith(weightValue: 50, reps: 12, isCompleted: true);
      expect(updated.setNumber, 1);
      expect(updated.type, SetType.warmUp);
      expect(updated.weightValue, 50);
      expect(updated.reps, 12);
      expect(updated.isCompleted, isTrue);
    });

    test('nullable fields can be cleared via sentinel copyWith', () {
      const s = WorkoutSet(
        setNumber: 1,
        type: SetType.working,
        weightValue: 50,
        reps: 12,
      );
      final cleared = s.copyWith(clearWeightValue: true, clearReps: true);
      expect(cleared.weightValue, isNull);
      expect(cleared.reps, isNull);
    });

    test('round-trips through JSON', () {
      const s = WorkoutSet(
        setNumber: 2,
        type: SetType.dropSet,
        weightValue: 42.5,
        reps: 8,
        isCompleted: true,
        previousRecord: '40 kg x 8',
      );
      final decoded = WorkoutSet.fromJson(
        jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>,
      );
      expect(decoded.setNumber, 2);
      expect(decoded.type, SetType.dropSet);
      expect(decoded.weightValue, 42.5);
      expect(decoded.reps, 8);
      expect(decoded.isCompleted, isTrue);
      expect(decoded.previousRecord, '40 kg x 8');
    });
  });

  group('WorkoutExercise', () {
    test('default rest timer settings match plan spec', () {
      const e = WorkoutExercise(
        exerciseId: 'bench_press',
        exerciseName: 'Bench Press',
        muscleGroup: 'chest',
        sets: [],
      );
      expect(e.restTimerEnabled, isTrue);
      expect(e.restTimerWarmUpSeconds, 90);
      expect(e.restTimerWorkingSeconds, 90);
      expect(e.notes, isEmpty);
      expect(e.unitOverride, isNull);
    });

    test('copyWith replaces sets and notes', () {
      const e = WorkoutExercise(
        exerciseId: 'bench_press',
        exerciseName: 'Bench Press',
        muscleGroup: 'chest',
        sets: [],
      );
      final updated = e.copyWith(
        sets: const [WorkoutSet(setNumber: 1, type: SetType.warmUp)],
        notes: 'Go slow.',
        unitOverride: 'imperial',
      );
      expect(updated.sets, hasLength(1));
      expect(updated.notes, 'Go slow.');
      expect(updated.unitOverride, 'imperial');
    });

    test('round-trips through JSON including nested sets', () {
      const e = WorkoutExercise(
        exerciseId: 'bench_press',
        exerciseName: 'Bench Press',
        muscleGroup: 'chest',
        sets: [
          WorkoutSet(setNumber: 1, type: SetType.warmUp),
          WorkoutSet(
            setNumber: 2,
            type: SetType.working,
            weightValue: 60,
            reps: 8,
            isCompleted: true,
          ),
        ],
        notes: 'Keep elbows tucked.',
        restTimerEnabled: false,
        restTimerWarmUpSeconds: 60,
        restTimerWorkingSeconds: 120,
        unitOverride: 'imperial',
      );
      final decoded = WorkoutExercise.fromJson(
        jsonDecode(jsonEncode(e.toJson())) as Map<String, dynamic>,
      );
      expect(decoded.exerciseId, 'bench_press');
      expect(decoded.sets, hasLength(2));
      expect(decoded.sets[1].weightValue, 60);
      expect(decoded.sets[1].isCompleted, isTrue);
      expect(decoded.notes, 'Keep elbows tucked.');
      expect(decoded.restTimerEnabled, isFalse);
      expect(decoded.restTimerWarmUpSeconds, 60);
      expect(decoded.restTimerWorkingSeconds, 120);
      expect(decoded.unitOverride, 'imperial');
    });
  });

  group('WorkoutSession', () {
    test('round-trips through JSON', () {
      final started = DateTime.utc(2026, 4, 21, 14, 30);
      final s = WorkoutSession(
        id: 'abc-123',
        startedAt: started,
        exercises: const [
          WorkoutExercise(
            exerciseId: 'bench_press',
            exerciseName: 'Bench Press',
            muscleGroup: 'chest',
            sets: [WorkoutSet(setNumber: 1, type: SetType.warmUp)],
          ),
        ],
      );
      final decoded = WorkoutSession.fromJson(
        jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>,
      );
      expect(decoded.id, 'abc-123');
      expect(decoded.startedAt.toUtc(), started);
      expect(decoded.exercises, hasLength(1));
      expect(decoded.exercises.first.sets, hasLength(1));
    });

    test('copyWith replaces only requested fields', () {
      final started = DateTime.utc(2026, 4, 21);
      final s = WorkoutSession(
        id: 'abc',
        startedAt: started,
        exercises: const [],
      );
      final updated = s.copyWith(
        exercises: const [
          WorkoutExercise(
            exerciseId: 'x',
            exerciseName: 'X',
            muscleGroup: 'chest',
            sets: [],
          ),
        ],
      );
      expect(updated.id, 'abc');
      expect(updated.startedAt, started);
      expect(updated.exercises, hasLength(1));
    });
  });

  group('effectiveUnitSystem + unitLabel helpers', () {
    test('null unitOverride uses the global default', () {
      const e = WorkoutExercise(
        exerciseId: 'x',
        exerciseName: 'X',
        muscleGroup: 'chest',
        sets: [],
      );
      expect(effectiveUnitSystem(e, 'metric'), 'metric');
      expect(effectiveUnitSystem(e, 'imperial'), 'imperial');
    });

    test('unitOverride wins over the global default', () {
      const e = WorkoutExercise(
        exerciseId: 'x',
        exerciseName: 'X',
        muscleGroup: 'chest',
        sets: [],
        unitOverride: 'imperial',
      );
      expect(effectiveUnitSystem(e, 'metric'), 'imperial');
    });

    test('unitLabel returns kg for metric and lbs for imperial', () {
      expect(unitLabel('metric'), 'kg');
      expect(unitLabel('imperial'), 'lbs');
    });
  });
}
