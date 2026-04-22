library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/workout/domain/exercise.dart';

void main() {
  group('MuscleGroup', () {
    test('fromString maps every known slug', () {
      expect(MuscleGroup.fromString('chest'), MuscleGroup.chest);
      expect(MuscleGroup.fromString('back'), MuscleGroup.back);
      expect(MuscleGroup.fromString('shoulders'), MuscleGroup.shoulders);
      expect(MuscleGroup.fromString('biceps'), MuscleGroup.biceps);
      expect(MuscleGroup.fromString('triceps'), MuscleGroup.triceps);
      expect(MuscleGroup.fromString('forearms'), MuscleGroup.forearms);
      expect(MuscleGroup.fromString('abs'), MuscleGroup.abs);
      expect(MuscleGroup.fromString('quads'), MuscleGroup.quads);
      expect(MuscleGroup.fromString('hamstrings'), MuscleGroup.hamstrings);
      expect(MuscleGroup.fromString('glutes'), MuscleGroup.glutes);
      expect(MuscleGroup.fromString('calves'), MuscleGroup.calves);
      expect(MuscleGroup.fromString('cardio'), MuscleGroup.cardio);
      expect(MuscleGroup.fromString('full_body'), MuscleGroup.fullBody);
    });

    test('fromString returns other for unknown slugs', () {
      expect(MuscleGroup.fromString('unknown'), MuscleGroup.other);
      expect(MuscleGroup.fromString(''), MuscleGroup.other);
    });

    test('label returns a human-readable string for every value', () {
      for (final group in MuscleGroup.values) {
        expect(group.label, isNotEmpty, reason: 'every group must have a label');
      }
      expect(MuscleGroup.fullBody.label, 'Full Body');
      expect(MuscleGroup.chest.label, 'Chest');
    });

    test('slug is the wire-format string', () {
      expect(MuscleGroup.chest.slug, 'chest');
      expect(MuscleGroup.fullBody.slug, 'full_body');
    });
  });

  group('Equipment', () {
    test('fromString maps every known slug', () {
      expect(Equipment.fromString('barbell'), Equipment.barbell);
      expect(Equipment.fromString('dumbbell'), Equipment.dumbbell);
      expect(Equipment.fromString('cable'), Equipment.cable);
      expect(Equipment.fromString('bodyweight'), Equipment.bodyweight);
      expect(Equipment.fromString('kettlebell'), Equipment.kettlebell);
      expect(Equipment.fromString('machine'), Equipment.machine);
      expect(Equipment.fromString('resistance_band'), Equipment.resistanceBand);
      expect(Equipment.fromString('ez_bar'), Equipment.ezBar);
      expect(Equipment.fromString('other'), Equipment.other);
    });

    test('fromString returns other for unknown slugs', () {
      expect(Equipment.fromString('kayak'), Equipment.other);
    });
  });

  group('Exercise.fromJson', () {
    test('parses a complete record', () {
      final json = <String, dynamic>{
        'id': 'bench_press',
        'name': 'Bench Press',
        'muscleGroup': 'chest',
        'equipment': 'barbell',
        'instructions': 'Lie down, press up.',
      };
      final exercise = Exercise.fromJson(json);
      expect(exercise.id, 'bench_press');
      expect(exercise.name, 'Bench Press');
      expect(exercise.muscleGroup, MuscleGroup.chest);
      expect(exercise.secondaryMuscles, isEmpty);
      expect(exercise.equipment, Equipment.barbell);
      expect(exercise.instructions, 'Lie down, press up.');
    });

    test('parses secondaryMuscles when present', () {
      final json = <String, dynamic>{
        'id': 'bench_press',
        'name': 'Bench Press',
        'muscleGroup': 'chest',
        'secondaryMuscles': ['shoulders', 'triceps'],
        'equipment': 'barbell',
        'instructions': 'Press.',
      };
      final exercise = Exercise.fromJson(json);
      expect(exercise.secondaryMuscles, [MuscleGroup.shoulders, MuscleGroup.triceps]);
    });

    test('secondaryMuscles defaults to empty list when field absent', () {
      final json = <String, dynamic>{
        'id': 'pull_up',
        'name': 'Pull-Up',
        'muscleGroup': 'back',
        'equipment': 'bodyweight',
        'instructions': 'Pull.',
      };
      expect(Exercise.fromJson(json).secondaryMuscles, isEmpty);
    });

    test('falls back to MuscleGroup.other on unknown muscleGroup', () {
      final json = <String, dynamic>{
        'id': 'x',
        'name': 'X',
        'muscleGroup': 'moonwalk',
        'equipment': 'barbell',
        'instructions': '',
      };
      expect(Exercise.fromJson(json).muscleGroup, MuscleGroup.other);
    });

    test('unknown slug in secondaryMuscles falls back to MuscleGroup.other', () {
      final json = <String, dynamic>{
        'id': 'x',
        'name': 'X',
        'muscleGroup': 'chest',
        'secondaryMuscles': ['triceps', 'notARealMuscle'],
        'equipment': 'barbell',
        'instructions': '',
      };
      final exercise = Exercise.fromJson(json);
      expect(exercise.secondaryMuscles, [MuscleGroup.triceps, MuscleGroup.other]);
    });

    test('equality is value-based via id', () {
      const a = Exercise(id: 'bench_press', name: 'A',
          muscleGroup: MuscleGroup.chest, equipment: Equipment.barbell,
          instructions: '');
      const b = Exercise(id: 'bench_press', name: 'B',
          muscleGroup: MuscleGroup.back, equipment: Equipment.dumbbell,
          instructions: '');
      expect(a == b, isTrue);
      expect(a.hashCode, b.hashCode);
    });
  });
}
