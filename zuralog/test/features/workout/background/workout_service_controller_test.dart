/// Zuralog — WorkoutServiceController smoke test.
///
/// The controller wraps flutter_foreground_task. On non-Android platforms
/// (including the Dart VM that runs `flutter test` on Windows/macOS/Linux
/// host machines) every method must no-op and must not throw. This test
/// locks that graceful-degradation contract in place — it protects against
/// a regression where someone removes the `_supported` guard.
///
/// Real runtime behavior of the Android service itself can only be verified
/// on a device and is covered by the manual verification in the plan's
/// "Done-when" list.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:zuralog/features/workout/background/workout_service_controller.dart';

void main() {
  group('WorkoutServiceController', () {
    test('start/stop/nudge are no-ops on non-Android platforms', () async {
      final c = WorkoutServiceController();

      // None of these may throw on the test host. On a real Android device
      // they delegate to the plugin; here they hit the `_supported` guard.
      await c.start();
      await c.stop();
      await c.nudge();
    });

    test('attach/detach main receiver no-op on non-Android', () {
      final c = WorkoutServiceController();
      void handler(Object data) {}

      // Must not throw even without the plugin's platform side being set up.
      c.attachMainReceiver(handler);
      c.detachMainReceiver(handler);
    });
  });
}
