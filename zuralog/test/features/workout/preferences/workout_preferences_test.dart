/// Zuralog — Workout Preferences Tests.
///
/// Verifies the local SharedPreferences-backed toggles for workout UX.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zuralog/features/workout/preferences/workout_preferences.dart';

void main() {
  group('WorkoutPreferences', () {
    setUp(() {
      // Empty in-memory backing store for every test.
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('restSoundEnabled defaults to true when no value is stored', () async {
      final prefs = await SharedPreferences.getInstance();
      final workout = WorkoutPreferences(prefs);

      expect(workout.restSoundEnabled, isTrue);
    });

    test('setRestSoundEnabled(false) persists and reads back as false',
        () async {
      final prefs = await SharedPreferences.getInstance();
      final workout = WorkoutPreferences(prefs);

      await workout.setRestSoundEnabled(false);

      expect(workout.restSoundEnabled, isFalse);
      // Verify a fresh wrapper over the same store also reads false.
      expect(WorkoutPreferences(prefs).restSoundEnabled, isFalse);
    });

    test('setRestSoundEnabled(true) overwrites a prior false', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        WorkoutPreferences.kRestSoundEnabledKey: false,
      });
      final prefs = await SharedPreferences.getInstance();
      final workout = WorkoutPreferences(prefs);

      expect(workout.restSoundEnabled, isFalse);

      await workout.setRestSoundEnabled(true);

      expect(workout.restSoundEnabled, isTrue);
    });
  });
}
