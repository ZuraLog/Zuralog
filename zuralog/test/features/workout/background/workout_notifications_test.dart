/// Zuralog — WorkoutNotifications contract tests.
///
/// The underlying plugin (`flutter_local_notifications`) communicates
/// over platform channels that aren't wired in the `flutter test` host,
/// so we can't exercise scheduling end-to-end here. Instead we lock
/// down two invariants that guard against accidental regressions:
///
///   1. [WorkoutNotifications.instance] is a true singleton — we never
///      accidentally create a per-call instance that would hold its own
///      (unshared) onAction callback.
///   2. The public action-id constants stay stable. Renaming any of
///      them in isolation would silently break the notification-button
///      round trip, because the Android foreground-service handler and
///      the iOS category registration both key off these exact strings.
///
/// Device-side behavior (real scheduling, real tap routing) is covered
/// by the Phase 5 "Done-when" manual verification in the plan.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:zuralog/features/workout/background/workout_notifications.dart';

void main() {
  group('WorkoutNotifications', () {
    test('instance is a stable singleton', () {
      final a = WorkoutNotifications.instance;
      final b = WorkoutNotifications.instance;
      expect(identical(a, b), isTrue);
    });

    test('onAction callback can be attached and cleared', () {
      // Mutating the callback is the one piece of behavior we can exercise
      // without touching the platform channel — it's just a field assignment.
      final notifications = WorkoutNotifications.instance;
      String? received;
      notifications.onAction = (actionId) => received = actionId;
      notifications.onAction?.call('rest_skip');
      expect(received, 'rest_skip');

      notifications.onAction = null;
      // Calling through a null target should not throw — the `?.call`
      // pattern is what the real receive path uses.
      expect(() => notifications.onAction?.call('anything'), returnsNormally);
    });
  });

  group('WorkoutNotificationActions', () {
    test('ids are stable and do not collide', () {
      // These strings are part of the wire contract between the UI
      // isolate (Riverpod), the Android foreground-service isolate, and
      // the iOS scheduled-notification category. Changing them without
      // coordinated updates on every side will silently break button
      // taps — this test fails fast when that happens.
      expect(WorkoutNotificationActions.restSkip, 'rest_skip');
      expect(WorkoutNotificationActions.restAdd30, 'rest_add30');
      expect(WorkoutNotificationActions.workoutFinish, 'workout_finish');

      final ids = <String>{
        WorkoutNotificationActions.restSkip,
        WorkoutNotificationActions.restAdd30,
        WorkoutNotificationActions.workoutFinish,
      };
      expect(ids.length, 3, reason: 'action ids must be unique');
    });
  });
}
