import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zuralog/core/storage/prefs_service.dart';
import 'package:zuralog/features/settings/domain/user_preferences_model.dart';
import 'package:zuralog/features/settings/providers/settings_providers.dart';
import 'package:zuralog/features/workout/domain/completed_workout.dart';
import 'package:zuralog/features/workout/domain/workout_session.dart';
import 'package:zuralog/features/workout/presentation/workout_summary_screen.dart';

Widget _wrap(Widget child, SharedPreferences prefs) => ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        unitsSystemProvider.overrideWithValue(UnitsSystem.metric),
      ],
      child: MaterialApp(home: child),
    );

CompletedWorkout _sample() => CompletedWorkout(
      id: 'w1',
      completedAt: DateTime.utc(2026, 4, 21, 16, 30),
      durationSeconds: 3665, // 1:01:05
      exercises: const [
        CompletedExercise(
          exerciseId: 'bench-press',
          exerciseName: 'Bench Press',
          muscleGroup: 'chest',
          sets: [
            WorkoutSet(
              setNumber: 1,
              type: SetType.warmUp,
              weightValue: 40,
              reps: 10,
              isCompleted: true,
            ),
            WorkoutSet(
              setNumber: 2,
              type: SetType.working,
              weightValue: 60,
              reps: 10,
              isCompleted: true,
            ),
          ],
        ),
      ],
      totalVolumeKg: 1000.0,
      totalSetsCompleted: 2,
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('WorkoutSummaryScreen', () {
    testWidgets('renders header, totals, per-exercise block', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester
          .pumpWidget(_wrap(WorkoutSummaryScreen(workout: _sample()), prefs));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Workout Complete'), findsOneWidget);
      expect(find.text('Bench Press'), findsOneWidget);
      expect(find.text('1:01:05'), findsOneWidget);
      expect(find.textContaining('1000'), findsWidgets);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('shows error state when workout is null', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester
          .pumpWidget(_wrap(const WorkoutSummaryScreen(workout: null), prefs));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.textContaining('summary is not available'), findsOneWidget);
    });
  });
}
