import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/body/domain/muscle_state.dart';

void main() {
  group('MuscleState', () {
    test('exposes a slug and label for every value', () {
      for (final state in MuscleState.values) {
        expect(state.slug, isNotEmpty);
        expect(state.label, isNotEmpty);
      }
    });

    test('fromSlug round-trips every value', () {
      for (final state in MuscleState.values) {
        expect(MuscleState.fromSlug(state.slug), state);
      }
    });

    test('fromSlug falls back to neutral for unknown slugs', () {
      expect(MuscleState.fromSlug('not_a_state'), MuscleState.neutral);
    });
  });
}
