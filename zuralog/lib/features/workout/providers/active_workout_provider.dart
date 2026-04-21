/// Zuralog — Active Workout Providers.
///
/// Composition layer that combines the independent session and rest-timer
/// providers into a single snapshot. Downstream systems (notifications,
/// Live Activity, cross-tab pill, background service) read from these
/// composed providers so their payload is always atomic.
///
/// The underlying providers ([workoutSessionProvider], [restTimerProvider])
/// remain the source of truth for mutations.
library;

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/features/workout/background/workout_service_controller.dart';
import 'package:zuralog/features/workout/providers/rest_timer_provider.dart';
import 'package:zuralog/features/workout/providers/workout_session_providers.dart';

// ── Snapshot model ───────────────────────────────────────────────────────────

/// Atomic read-only view combining session + rest state at a single instant.
class ActiveWorkoutSnapshot {
  const ActiveWorkoutSnapshot({
    required this.hasActiveSession,
    required this.workoutStartedAt,
    required this.workoutElapsed,
    required this.rest,
  });

  final bool hasActiveSession;
  final DateTime? workoutStartedAt;
  final Duration workoutElapsed;
  final RestTimerState rest;

  bool get isResting => rest.isActive;
  bool get isRestingOrJustExpired => rest.isVisible;
}

// ── Boolean predicate ────────────────────────────────────────────────────────

/// True iff the user has an active workout session.
final isWorkoutActiveProvider = Provider<bool>((ref) {
  return ref.watch(workoutSessionProvider) != null;
});

// ── 1 Hz rebuild trigger ─────────────────────────────────────────────────────
//
// The rest-timer notifier already runs a 1 Hz ticker that rebuilds whenever
// state.tick changes. Elapsed time needs a similar heartbeat even when rest
// isn't active. This Stream yields once per second whenever a workout is live
// and no rest timer is running (so we don't double-tick).
final _workoutElapsedHeartbeatProvider = StreamProvider<int>((ref) {
  final controller = StreamController<int>();
  Timer? ticker;

  void restart() {
    ticker?.cancel();
    ticker = null;
    final workoutActive = ref.read(isWorkoutActiveProvider);
    final restVisible = ref.read(restTimerProvider).isVisible;
    if (workoutActive && !restVisible) {
      var i = 0;
      ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!controller.isClosed) controller.add(i++);
      });
    }
  }

  restart();

  final sub1 =
      ref.listen(isWorkoutActiveProvider, (prev, next) => restart());
  final sub2 = ref.listen(
    restTimerProvider.select((s) => s.isVisible),
    (prev, next) => restart(),
  );

  ref.onDispose(() {
    ticker?.cancel();
    sub1.close();
    sub2.close();
    controller.close();
  });

  return controller.stream;
});

// ── Elapsed workout time ─────────────────────────────────────────────────────

/// Live elapsed duration of the current workout. Rebuilds every second via
/// either the rest-timer tick OR the dedicated heartbeat when no rest is active.
///
/// Uses [clock] for time reads so tests can swap in a fake clock via
/// `withClock` / `fake_async`. In production this is a zero-cost indirection
/// that delegates to `DateTime.now()`.
final workoutElapsedProvider = Provider<Duration>((ref) {
  final session = ref.watch(workoutSessionProvider);
  if (session == null) return Duration.zero;
  // Subscribe to both heartbeats so we rebuild every second regardless of
  // whether a rest timer is currently running.
  ref.watch(restTimerProvider.select((s) => s.tick));
  ref.watch(_workoutElapsedHeartbeatProvider);
  return clock.now().difference(session.startedAt);
});

// ── Rest remaining ───────────────────────────────────────────────────────────

/// Current rest-remaining duration (Duration.zero when not resting).
/// Derived from [restTimerProvider] so it auto-ticks.
final restRemainingProvider = Provider<Duration>((ref) {
  final rest = ref.watch(restTimerProvider);
  return rest.remaining;
});

// ── Snapshot ─────────────────────────────────────────────────────────────────

/// Single atomic read of everything downstream systems need.
final activeWorkoutSnapshotProvider = Provider<ActiveWorkoutSnapshot>((ref) {
  final session = ref.watch(workoutSessionProvider);
  final elapsed = ref.watch(workoutElapsedProvider);
  final rest = ref.watch(restTimerProvider);
  return ActiveWorkoutSnapshot(
    hasActiveSession: session != null,
    workoutStartedAt: session?.startedAt,
    workoutElapsed: elapsed,
    rest: rest,
  );
});

// ── Background-service bridge ────────────────────────────────────────────────

/// Bridges Riverpod state mutations to the Android foreground service.
///
/// Read this provider once from the app root (e.g. `ZuralogApp.build`) so it
/// stays alive for the process lifetime. On every workout start/stop, the
/// bridge starts or stops the foreground service. On every rest-timer change
/// it nudges the service isolate so the ongoing notification updates
/// promptly. It also receives notification-button actions that the service
/// isolate forwards back here and dispatches them to the appropriate notifier.
///
/// On iOS, web, and desktop the underlying controller is a no-op; the
/// listeners still run but perform no platform work.
final workoutServiceBridgeProvider = Provider<void>((ref) {
  final controller = ref.watch(workoutServiceControllerProvider);

  // Translate notification-button actions that the foreground-service isolate
  // forwards back to us into Riverpod mutations. Keep a stable reference so
  // we can detach on dispose.
  void handleTaskData(Object data) {
    if (data is! Map) return;
    final action = data['action'];
    if (action is! String) return;
    switch (action) {
      case 'rest_skip':
        ref.read(restTimerProvider.notifier).skip();
        break;
      case 'rest_add30':
        ref.read(restTimerProvider.notifier).addTime(30);
        break;
      case 'workout_finish':
        // Wired in Phase 5 — the finish flow needs notification scheduling
        // that isn't implemented yet. Leaving this branch explicit so the
        // action round-trip is visible in logs once Phase 5 lands.
        break;
    }
  }

  controller.attachMainReceiver(handleTaskData);
  ref.onDispose(() => controller.detachMainReceiver(handleTaskData));

  ref.listen<bool>(isWorkoutActiveProvider, (prev, next) {
    if (prev == next) return;
    if (next) {
      controller.start();
    } else {
      controller.stop();
    }
  }, fireImmediately: true);

  // Nudge the service on rest changes so its SharedPreferences re-reads
  // happen promptly (rather than waiting for the next 1 Hz tick).
  ref.listen(
    restTimerProvider.select((s) => s.restStartedAt),
    (_, _) => controller.nudge(),
  );
  ref.listen(
    restTimerProvider.select((s) => s.addedSeconds),
    (_, _) => controller.nudge(),
  );
});
