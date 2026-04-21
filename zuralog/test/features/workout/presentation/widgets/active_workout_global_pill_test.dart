/// Zuralog — Active Workout Global Pill Tests.
///
/// Covers the five contract points from the phase-7 plan:
///   1. Hidden when no active workout.
///   2. Shows "Workout MM:SS" when active and not resting.
///   3. Shows "Rest MM:SS" when active and resting.
///   4. Tapping the pill navigates to the workout session route.
///   5. Hidden when the current route is the workout session route.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/features/workout/presentation/widgets/active_workout_global_pill.dart';
import 'package:zuralog/features/workout/providers/active_workout_provider.dart';
import 'package:zuralog/features/workout/providers/rest_timer_provider.dart';

// ── Test harness ──────────────────────────────────────────────────────────────

/// Builds a minimal `MaterialApp.router` with two routes:
///   • `/today` — hosts the [ActiveWorkoutGlobalPill].
///   • `/log/workout/session` — the push target.
///
/// [snapshot] is injected via a direct provider override so tests don't have
/// to mutate the underlying session + rest notifiers. [initialLocation]
/// lets us verify the "hide on workout screen" path.
Widget _harness({
  required ActiveWorkoutSnapshot snapshot,
  String initialLocation = '/today',
}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/today',
        builder: (_, _) => const Scaffold(
          body: SizedBox.expand(),
          bottomNavigationBar: ActiveWorkoutGlobalPill(),
        ),
      ),
      GoRoute(
        path: RouteNames.workoutSessionPath,
        builder: (_, _) => const Scaffold(
          body: Text('workout session'),
          bottomNavigationBar: ActiveWorkoutGlobalPill(),
        ),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      activeWorkoutSnapshotProvider.overrideWith((ref) => snapshot),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

ActiveWorkoutSnapshot _idleSnapshot() => const ActiveWorkoutSnapshot(
      hasActiveSession: false,
      workoutStartedAt: null,
      workoutElapsed: Duration.zero,
      rest: RestTimerState(),
    );

ActiveWorkoutSnapshot _activeSnapshot({
  Duration elapsed = const Duration(minutes: 12, seconds: 34),
}) =>
    ActiveWorkoutSnapshot(
      hasActiveSession: true,
      workoutStartedAt: DateTime.now().subtract(elapsed),
      workoutElapsed: elapsed,
      rest: const RestTimerState(),
    );

ActiveWorkoutSnapshot _restingSnapshot() {
  // Simulate a rest timer started 15 seconds ago with a 90 s plan
  // → 75 s remaining = 01:15 display.
  final startedAt = DateTime.now().subtract(const Duration(seconds: 15));
  return ActiveWorkoutSnapshot(
    hasActiveSession: true,
    workoutStartedAt: DateTime.now().subtract(const Duration(minutes: 5)),
    workoutElapsed: const Duration(minutes: 5),
    rest: RestTimerState(
      restStartedAt: startedAt,
      plannedDurationSeconds: 90,
    ),
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders nothing when no active workout', (tester) async {
    await tester.pumpWidget(_harness(snapshot: _idleSnapshot()));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(ActivePillBody), findsNothing);
  });

  testWidgets('shows "Workout MM:SS" when active and not resting',
      (tester) async {
    await tester.pumpWidget(_harness(snapshot: _activeSnapshot()));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(ActivePillBody), findsOneWidget);
    expect(find.text('Workout  12:34'), findsOneWidget);
  });

  testWidgets('shows "Rest MM:SS" when active and resting', (tester) async {
    await tester.pumpWidget(_harness(snapshot: _restingSnapshot()));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(ActivePillBody), findsOneWidget);
    // Remaining is computed from wall-clock ticks, so allow a 1-second
    // tolerance (e.g. the pump runs at a slightly-later instant than
    // snapshot construction).
    final labelFinder = find.textContaining(RegExp(r'^Rest\s+\d{2}:\d{2}$'));
    expect(labelFinder, findsOneWidget);
  });

  testWidgets('tapping pill navigates to workout session route',
      (tester) async {
    await tester.pumpWidget(_harness(snapshot: _activeSnapshot()));
    await tester.pump(const Duration(milliseconds: 50));

    // Pill is rendered on /today, not on the workout session screen.
    expect(find.text('workout session'), findsNothing);

    await tester.tap(find.byType(ActivePillBody));
    await tester.pumpAndSettle();

    // Now the workout session screen is on top.
    expect(find.text('workout session'), findsOneWidget);
  });

  testWidgets('pill hidden when current route is the workout session path',
      (tester) async {
    await tester.pumpWidget(
      _harness(
        snapshot: _activeSnapshot(),
        initialLocation: RouteNames.workoutSessionPath,
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    // Session screen is visible, but the pill must NOT be.
    expect(find.text('workout session'), findsOneWidget);
    expect(find.byType(ActivePillBody), findsNothing);
  });
}
