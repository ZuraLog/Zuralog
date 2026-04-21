/// Zuralog — Active Workout Provider Tests.
///
/// Verifies the composition layer on top of [workoutSessionProvider] and
/// [restTimerProvider] produces a consistent atomic snapshot for downstream
/// systems (notifications, Live Activity, cross-tab pill, background service).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zuralog/core/storage/prefs_service.dart';
import 'package:zuralog/features/settings/domain/user_preferences_model.dart';
import 'package:zuralog/features/settings/providers/settings_providers.dart';
import 'package:zuralog/features/workout/providers/active_workout_provider.dart';
import 'package:zuralog/features/workout/providers/rest_timer_provider.dart';
import 'package:zuralog/features/workout/providers/workout_session_providers.dart';

ProviderContainer _containerWith(
  SharedPreferences prefs, {
  UnitsSystem units = UnitsSystem.metric,
}) {
  return ProviderContainer(
    overrides: [
      prefsProvider.overrideWithValue(prefs),
      unitsSystemProvider.overrideWithValue(units),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('isWorkoutActiveProvider', () {
    test('is false when no session', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = _containerWith(prefs);
      addTearDown(container.dispose);

      expect(container.read(isWorkoutActiveProvider), isFalse);
    });

    test('is true after session starts', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = _containerWith(prefs);
      addTearDown(container.dispose);

      container.read(workoutSessionProvider.notifier).startSession();

      expect(container.read(isWorkoutActiveProvider), isTrue);
    });

    test('returns to false after session is discarded', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = _containerWith(prefs);
      addTearDown(container.dispose);

      final notifier = container.read(workoutSessionProvider.notifier);
      notifier.startSession();
      expect(container.read(isWorkoutActiveProvider), isTrue);

      notifier.discardSession();
      expect(container.read(isWorkoutActiveProvider), isFalse);
    });
  });

  group('workoutElapsedProvider', () {
    test('returns Duration.zero when no session', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = _containerWith(prefs);
      addTearDown(container.dispose);

      expect(container.read(workoutElapsedProvider), Duration.zero);
    });

    test('returns non-negative duration after session starts', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = _containerWith(prefs);
      addTearDown(container.dispose);

      container.read(workoutSessionProvider.notifier).startSession();

      final elapsed = container.read(workoutElapsedProvider);
      expect(elapsed, greaterThanOrEqualTo(Duration.zero));
      // Should be small since we just started the session.
      expect(elapsed.inSeconds, lessThan(2));
    });
  });

  group('restRemainingProvider', () {
    test('returns Duration.zero when rest timer is not running', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = _containerWith(prefs);
      addTearDown(container.dispose);

      expect(container.read(restRemainingProvider), Duration.zero);
    });

    test('returns a positive duration shortly after rest starts', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = _containerWith(prefs);
      addTearDown(container.dispose);

      container.read(restTimerProvider.notifier).start(60);

      final remaining = container.read(restRemainingProvider);
      expect(remaining, greaterThan(Duration.zero));
      expect(remaining.inSeconds, lessThanOrEqualTo(60));
    });
  });

  group('activeWorkoutSnapshotProvider', () {
    test('reflects empty state when nothing is active', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = _containerWith(prefs);
      addTearDown(container.dispose);

      final snap = container.read(activeWorkoutSnapshotProvider);
      expect(snap.hasActiveSession, isFalse);
      expect(snap.workoutStartedAt, isNull);
      expect(snap.workoutElapsed, Duration.zero);
      expect(snap.rest.isVisible, isFalse);
      expect(snap.isResting, isFalse);
      expect(snap.isRestingOrJustExpired, isFalse);
    });

    test('returns session + rest atomically when both are active', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = _containerWith(prefs);
      addTearDown(container.dispose);

      container.read(workoutSessionProvider.notifier).startSession();
      container.read(restTimerProvider.notifier).start(90);

      final snap = container.read(activeWorkoutSnapshotProvider);
      expect(snap.hasActiveSession, isTrue);
      expect(snap.workoutStartedAt, isNotNull);
      expect(snap.workoutElapsed, greaterThanOrEqualTo(Duration.zero));
      expect(snap.rest.isVisible, isTrue);
      expect(snap.isResting, isTrue);
      expect(snap.isRestingOrJustExpired, isTrue);
      expect(snap.rest.plannedDurationSeconds, 90);
    });

    test('workoutStartedAt matches the session startedAt', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = _containerWith(prefs);
      addTearDown(container.dispose);

      container.read(workoutSessionProvider.notifier).startSession();

      final session = container.read(workoutSessionProvider)!;
      final snap = container.read(activeWorkoutSnapshotProvider);
      expect(snap.workoutStartedAt, session.startedAt);
    });
  });
}
