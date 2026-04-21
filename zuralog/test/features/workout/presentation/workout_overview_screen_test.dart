import 'dart:async';
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
import 'package:zuralog/features/workout/presentation/workout_overview_screen.dart';
import 'package:zuralog/features/workout/providers/workout_session_providers.dart';

Widget _wrap(Widget child, SharedPreferences prefs) => ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        unitsSystemProvider.overrideWithValue(UnitsSystem.metric),
      ],
      child: MaterialApp(home: child),
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('WorkoutOverviewScreen', () {
    testWidgets('shows empty hero message when no history', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(_wrap(const WorkoutOverviewScreen(), prefs));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.textContaining('No workouts yet'), findsOneWidget);
      expect(find.text('Start Workout'), findsOneWidget);
      expect(find.text('View All History'), findsOneWidget);
    });

    testWidgets('renders most-recent workout in hero card', (tester) async {
      final recent = CompletedWorkout(
        id: 'r',
        completedAt: DateTime.utc(2026, 4, 20, 10, 0),
        durationSeconds: 1800,
        exercises: const [],
        totalVolumeKg: 500.0,
        totalSetsCompleted: 3,
      );
      SharedPreferences.setMockInitialValues({
        kWorkoutHistoryKey: jsonEncode([recent.toJson()]),
      });
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(_wrap(const WorkoutOverviewScreen(), prefs));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Last Workout'), findsOneWidget);
      expect(find.textContaining('0:30:00'), findsOneWidget);
    });

    testWidgets('shows AI Summary and This Week sections', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(_wrap(const WorkoutOverviewScreen(), prefs));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('AI Summary'), findsOneWidget);
      expect(find.text('This Week'), findsOneWidget);
    });

    testWidgets('renders skeleton while history is loading', (tester) async {
      final completer = Completer<List<CompletedWorkout>>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            unitsSystemProvider.overrideWithValue(UnitsSystem.metric),
            workoutHistoryProvider.overrideWith((_) => completer.future),
          ],
          child: const MaterialApp(home: WorkoutOverviewScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.textContaining('No workouts yet'), findsNothing);
      expect(find.text('Last Workout'), findsNothing);

      // Complete the future so the provider can dispose cleanly.
      completer.complete([]);
      await tester.pump();
    });
  });
}
