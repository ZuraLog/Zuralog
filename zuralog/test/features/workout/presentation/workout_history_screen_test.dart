import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zuralog/core/storage/prefs_service.dart';
import 'package:zuralog/features/settings/domain/user_preferences_model.dart';
import 'package:zuralog/features/settings/providers/settings_providers.dart';
import 'package:zuralog/features/workout/data/workout_history_repository.dart';
import 'package:zuralog/features/workout/domain/completed_workout.dart';
import 'package:zuralog/features/workout/presentation/workout_history_screen.dart';

Widget _wrap(Widget child, SharedPreferences prefs) => ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        unitsSystemProvider.overrideWithValue(UnitsSystem.metric),
      ],
      child: MaterialApp(home: child),
    );

void main() {
  group('WorkoutHistoryScreen', () {
    testWidgets('renders empty state when no history', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(_wrap(const WorkoutHistoryScreen(), prefs));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.textContaining('No workouts yet'), findsOneWidget);
    });

    testWidgets('renders one row per stored workout', (tester) async {
      final a = CompletedWorkout(
        id: 'a',
        completedAt: DateTime.utc(2026, 4, 20, 10, 0),
        durationSeconds: 1800,
        exercises: const [
          CompletedExercise(
            exerciseId: 'bench-press',
            exerciseName: 'Bench Press',
            muscleGroup: 'chest',
            sets: [],
          ),
        ],
        totalVolumeKg: 500.0,
        totalSetsCompleted: 3,
      );
      SharedPreferences.setMockInitialValues({
        kWorkoutHistoryKey: jsonEncode([a.toJson()]),
      });
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(_wrap(const WorkoutHistoryScreen(), prefs));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.textContaining('1 exercise'), findsOneWidget);
      expect(find.textContaining('0:30:00'), findsOneWidget);
    });
  });
}
