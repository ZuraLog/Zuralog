/// Zuralog — Rest Timer Storage Tests.
///
/// Exercises the round-trip behavior of [RestTimerStorage] against the
/// in-memory SharedPreferences mock. Save writes scalars, load rebuilds a
/// [RestTimerState], clear wipes all keys, and saving a blank state is
/// equivalent to clearing.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zuralog/features/workout/data/rest_timer_storage.dart';
import 'package:zuralog/features/workout/providers/rest_timer_provider.dart';

void main() {
  group('RestTimerStorage', () {
    late SharedPreferences prefs;
    late RestTimerStorage storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      prefs = await SharedPreferences.getInstance();
      storage = RestTimerStorage(prefs);
    });

    test('save then load returns equivalent state', () async {
      // Round to whole ms since SharedPreferences stores epoch ms.
      final startedAt = DateTime.fromMillisecondsSinceEpoch(
        DateTime.now().millisecondsSinceEpoch,
      );
      final original = RestTimerState(
        restStartedAt: startedAt,
        plannedDurationSeconds: 90,
        addedSeconds: 30,
      );

      await storage.save(original);
      final restored = await storage.load();

      expect(restored, isNotNull);
      expect(restored!.restStartedAt, equals(startedAt));
      expect(restored.plannedDurationSeconds, 90);
      expect(restored.addedSeconds, 30);
    });

    test('clear removes all keys', () async {
      final original = RestTimerState(
        restStartedAt: DateTime.now(),
        plannedDurationSeconds: 60,
        addedSeconds: 15,
      );
      await storage.save(original);

      await storage.clear();

      expect(await storage.load(), isNull);
      expect(prefs.getInt('workout_rest_started_at_ms'), isNull);
      expect(prefs.getInt('workout_rest_planned_duration_s'), isNull);
      expect(prefs.getInt('workout_rest_added_seconds'), isNull);
    });

    test('load returns null when no stored state', () async {
      expect(await storage.load(), isNull);
    });

    test('save with null restStartedAt clears storage', () async {
      // Seed storage with a valid state first.
      await storage.save(RestTimerState(
        restStartedAt: DateTime.now(),
        plannedDurationSeconds: 45,
      ));
      expect(await storage.load(), isNotNull);

      // Saving a blank state should wipe everything.
      await storage.save(const RestTimerState());

      expect(await storage.load(), isNull);
    });
  });
}
