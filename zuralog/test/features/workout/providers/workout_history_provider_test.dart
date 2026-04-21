import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zuralog/core/storage/prefs_service.dart';
import 'package:zuralog/features/workout/data/workout_history_repository.dart';
import 'package:zuralog/features/workout/domain/completed_workout.dart';
import 'package:zuralog/features/workout/providers/workout_session_providers.dart';

void main() {
  group('workoutHistoryProvider', () {
    test('returns empty list when prefs is empty', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [prefsProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final result = await container.read(workoutHistoryProvider.future);
      expect(result, isEmpty);
    });

    test('exposes stored workouts, most-recent-first', () async {
      final older = CompletedWorkout(
        id: 'a',
        completedAt: DateTime.utc(2026, 4, 20),
        durationSeconds: 60,
        exercises: const [],
        totalVolumeKg: 0,
        totalSetsCompleted: 0,
      );
      final newer = CompletedWorkout(
        id: 'b',
        completedAt: DateTime.utc(2026, 4, 21),
        durationSeconds: 60,
        exercises: const [],
        totalVolumeKg: 0,
        totalSetsCompleted: 0,
      );
      SharedPreferences.setMockInitialValues({
        kWorkoutHistoryKey: jsonEncode([older.toJson(), newer.toJson()]),
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [prefsProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final result = await container.read(workoutHistoryProvider.future);
      expect(result.map((w) => w.id), ['b', 'a']);
    });
  });
}
