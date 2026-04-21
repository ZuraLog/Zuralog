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
