library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zuralog/core/storage/prefs_service.dart';
import 'package:zuralog/features/settings/domain/user_preferences_model.dart';
import 'package:zuralog/features/settings/providers/settings_providers.dart';
import 'package:zuralog/features/workout/domain/exercise.dart';
import 'package:zuralog/features/workout/presentation/workout_session_screen.dart';
import 'package:zuralog/features/workout/providers/workout_session_providers.dart';

Widget _harness(SharedPreferences prefs) {
  final router = GoRouter(
    initialLocation: '/session',
    routes: [
      GoRoute(
        path: '/session',
        pageBuilder: (_, state) =>
            const MaterialPage(child: WorkoutSessionScreen()),
      ),
      GoRoute(
        path: '/log/workout/summary',
        builder: (_, state) => const Scaffold(body: Text('summary')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      prefsProvider.overrideWithValue(prefs),
      unitsSystemProvider.overrideWithValue(UnitsSystem.metric),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('renders stats row and empty-state when no exercises added',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_harness(prefs));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Duration'), findsOneWidget);
    expect(find.text('Volume'), findsOneWidget);
    expect(find.text('Sets'), findsOneWidget);
    expect(find.text('Add Exercises'), findsOneWidget);
  });

  testWidgets('adding an exercise shows an exercise card', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_harness(prefs));
    await tester.pump(const Duration(milliseconds: 50));
    final ctx = tester.element(find.byType(WorkoutSessionScreen));
    final container = ProviderScope.containerOf(ctx);
    container.read(workoutSessionProvider.notifier).addExercises(const [
      Exercise(
        id: 'bench_press',
        name: 'Bench Press',
        muscleGroup: MuscleGroup.chest,
        equipment: Equipment.barbell,
        instructions: '',
      ),
    ]);
    await tester.pump();
    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.text('Add Set'), findsOneWidget);
  });

  testWidgets('Finish with no completed sets opens the confirm dialog',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_harness(prefs));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Finish'));
    await tester.pump();
    expect(find.text('No sets completed'), findsOneWidget);
  });

  testWidgets('Discard clears the session and persisted draft',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_harness(prefs));
    await tester.pump(const Duration(milliseconds: 50));
    final ctx = tester.element(find.byType(WorkoutSessionScreen));
    final container = ProviderScope.containerOf(ctx);
    container.read(workoutSessionProvider.notifier).addExercises(const [
      Exercise(
        id: 'bench_press',
        name: 'Bench Press',
        muscleGroup: MuscleGroup.chest,
        equipment: Equipment.barbell,
        instructions: '',
      ),
    ]);
    await tester.pump();
    expect(prefs.getString('workout_active_draft'), isNotNull);

    await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
    await tester.pump();
    await tester.tap(find.text('Discard').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(container.read(workoutSessionProvider), isNull);
    expect(prefs.getString('workout_active_draft'), isNull);
  });
}
