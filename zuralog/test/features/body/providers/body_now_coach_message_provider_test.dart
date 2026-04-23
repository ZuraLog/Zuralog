import 'package:flutter_test/flutter_test.dart';

import 'package:zuralog/features/body/domain/body_state.dart';
import 'package:zuralog/features/body/domain/muscle_state.dart';
import 'package:zuralog/features/body/providers/body_now_coach_message_provider.dart';
import 'package:zuralog/features/workout/domain/exercise.dart' show MuscleGroup;

BodyState _state(Map<MuscleGroup, MuscleState> m) =>
    BodyState(muscles: m, computedAt: DateTime.utc(2026, 4, 23));

void main() {
  group('buildCoachMessage', () {
    test('no signals -> calm welcoming message', () {
      final msg = buildCoachMessage(_state(const {}));
      expect(msg.text.toLowerCase(), contains('meet your body'));
      expect(msg.ctaLabel, isNotEmpty);
      expect(msg.ctaRoute, isNotEmpty);
    });

    test('shoulders sore + legs fresh -> lower-body-focus template', () {
      final msg = buildCoachMessage(_state({
        MuscleGroup.shoulders: MuscleState.sore,
        MuscleGroup.quads: MuscleState.fresh,
        MuscleGroup.hamstrings: MuscleState.fresh,
      }));
      expect(msg.text.toLowerCase(), contains('shoulders'));
      expect(msg.text.toLowerCase(), contains('legs'));
      expect(msg.ctaLabel, 'View session');
    });

    test('everything fresh -> push-day template', () {
      final msg = buildCoachMessage(_state({
        for (final g in [
          MuscleGroup.chest,
          MuscleGroup.back,
          MuscleGroup.quads,
          MuscleGroup.hamstrings,
        ])
          g: MuscleState.fresh,
      }));
      expect(msg.text.toLowerCase(),
          anyOf(contains('primed'), contains('push'), contains('strong day')));
    });

    test('everything sore -> rest-day template', () {
      final msg = buildCoachMessage(_state({
        for (final g in [
          MuscleGroup.chest,
          MuscleGroup.back,
          MuscleGroup.shoulders,
          MuscleGroup.quads,
        ])
          g: MuscleState.sore,
      }));
      expect(msg.text.toLowerCase(),
          anyOf(contains('rest'), contains('take it easy'), contains('recover')));
    });
  });
}
