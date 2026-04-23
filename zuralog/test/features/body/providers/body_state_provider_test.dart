import 'package:flutter_test/flutter_test.dart';

import 'package:zuralog/features/body/domain/body_state.dart';
import 'package:zuralog/features/body/domain/muscle_state.dart';
import 'package:zuralog/features/body/providers/body_state_provider.dart';
import 'package:zuralog/features/workout/domain/exercise.dart' show MuscleGroup;

void main() {
  group('computeBodyState', () {
    test('empty history yields all-neutral state with hasAnySignal=false',
        () {
      final state = computeBodyState(
        recentLoadByMuscle: const {},
        baselineByMuscle: const {},
        now: DateTime.utc(2026, 4, 23),
      );
      for (final m in MuscleGroup.values) {
        expect(state.stateOf(m), MuscleState.neutral);
      }
      expect(state.hasAnySignal, isFalse);
    });

    test('load >= 1.2x baseline -> sore', () {
      final state = computeBodyState(
        recentLoadByMuscle: const {MuscleGroup.shoulders: 12.0},
        baselineByMuscle: const {MuscleGroup.shoulders: 10.0},
        now: DateTime.utc(2026, 4, 23),
      );
      expect(state.stateOf(MuscleGroup.shoulders), MuscleState.sore);
    });

    test('load between 0.4x and 1.2x baseline -> worked', () {
      final state = computeBodyState(
        recentLoadByMuscle: const {MuscleGroup.chest: 7.0},
        baselineByMuscle: const {MuscleGroup.chest: 10.0},
        now: DateTime.utc(2026, 4, 23),
      );
      expect(state.stateOf(MuscleGroup.chest), MuscleState.worked);
    });

    test('load < 0.4x baseline -> fresh', () {
      final state = computeBodyState(
        recentLoadByMuscle: const {MuscleGroup.quads: 1.0},
        baselineByMuscle: const {MuscleGroup.quads: 10.0},
        now: DateTime.utc(2026, 4, 23),
      );
      expect(state.stateOf(MuscleGroup.quads), MuscleState.fresh);
    });

    test('no baseline for a loaded muscle -> worked (conservative default)',
        () {
      final state = computeBodyState(
        recentLoadByMuscle: const {MuscleGroup.biceps: 5.0},
        baselineByMuscle: const {},
        now: DateTime.utc(2026, 4, 23),
      );
      expect(state.stateOf(MuscleGroup.biceps), MuscleState.worked);
    });
  });
}
