/// Zuralog — WorkoutCompanionBridge contract tests.
///
/// Phase 10 ships only scaffolding: there is no real companion app yet,
/// so the native MethodChannel handlers aren't registered in the
/// `flutter test` host. These tests lock down the Dart-side contract:
///
///   1. `isPaired` returns `false` when the channel has no impl
///      (expected steady state until the companion ships).
///   2. `broadcast` does not throw when the channel has no impl, so
///      state-change listeners in `active_workout_provider.dart` remain
///      safe to invoke every tick.
///   3. The action-id constants stay stable — they're shared with the
///      notification dispatcher.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:zuralog/features/workout/companion/workout_companion_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WorkoutCompanionBridge', () {
    test('isPaired returns false when channel not implemented', () async {
      final bridge = WorkoutCompanionBridge();
      expect(await bridge.isPaired(), isFalse);
    });

    test('broadcast does not throw when channel not implemented', () async {
      final bridge = WorkoutCompanionBridge();
      await bridge.broadcast(
        CompanionPayload(workoutStartedAt: DateTime.now()),
      );
    });

    test('CompanionActions ids stay stable', () {
      // These strings are the cross-platform contract — the notification
      // dispatcher in active_workout_provider.dart switches on them.
      expect(CompanionActions.restSkip, 'rest_skip');
      expect(CompanionActions.restAdd30, 'rest_add30');
      expect(CompanionActions.workoutFinish, 'workout_finish');
    });

    test('CompanionPayload.toMap serializes times as ms epochs', () {
      final started = DateTime.fromMillisecondsSinceEpoch(1_700_000_000_000);
      final restStarted = DateTime.fromMillisecondsSinceEpoch(1_700_000_030_000);
      final payload = CompanionPayload(
        workoutStartedAt: started,
        restStartedAt: restStarted,
        plannedRestDurationSeconds: 90,
        addedRestSeconds: 30,
        exerciseName: 'Bench Press',
        setLabel: '2 / 3',
      );
      expect(payload.toMap(), {
        'workoutStartedAtMs': 1_700_000_000_000,
        'restStartedAtMs': 1_700_000_030_000,
        'plannedRestDurationSeconds': 90,
        'addedRestSeconds': 30,
        'exerciseName': 'Bench Press',
        'setLabel': '2 / 3',
      });
    });

    test('CompanionPayload.toMap tolerates null restStartedAt', () {
      final payload = CompanionPayload(
        workoutStartedAt: DateTime.fromMillisecondsSinceEpoch(1),
      );
      expect(payload.toMap()['restStartedAtMs'], isNull);
    });
  });
}
