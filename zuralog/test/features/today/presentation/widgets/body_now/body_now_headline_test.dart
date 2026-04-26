import 'package:flutter_test/flutter_test.dart';

import 'package:zuralog/features/body/domain/body_state.dart';
import 'package:zuralog/features/body/domain/muscle_state.dart';
import 'package:zuralog/features/today/presentation/widgets/body_now/body_now_headline.dart';
import 'package:zuralog/features/workout/domain/exercise.dart' show MuscleGroup;

BodyState _s(Map<MuscleGroup, MuscleState> m) =>
    BodyState(muscles: m, computedAt: DateTime.utc(2026, 4, 23));

void main() {
  group('headlineFor', () {
    test('no signal -> welcoming zero-data headline', () {
      expect(headlineFor(_s(const {})), "Let's meet your body.");
    });

    test('legs fresh + shoulders sore -> named two-part headline', () {
      final h = headlineFor(_s({
        MuscleGroup.quads: MuscleState.fresh,
        MuscleGroup.shoulders: MuscleState.sore,
      }));
      expect(h.toLowerCase(), contains('legs'));
      expect(h.toLowerCase(), contains('fresh'));
      expect(h.toLowerCase(), contains('shoulders'));
      expect(h.toLowerCase(), contains('tight'));
    });

    test('everything fresh -> single-part positive headline', () {
      final h = headlineFor(_s({
        for (final g in [
          MuscleGroup.chest,
          MuscleGroup.back,
          MuscleGroup.quads,
        ])
          g: MuscleState.fresh,
      }));
      expect(h.toLowerCase(), contains('primed'));
    });
  });
}
