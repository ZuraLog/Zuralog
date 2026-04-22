import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuralog/features/nutrition/domain/nutrition_models.dart';
import 'package:zuralog/features/nutrition/providers/nutrition_providers.dart';
import 'package:zuralog/features/nutrition/presentation/exercise_entries_sheet.dart';

Widget wrapInApp(Widget child) =>
    ProviderScope(child: MaterialApp(home: Scaffold(body: child)));

/// Stub notifier that returns a fixed list without hitting the repository.
class _StubExerciseNotifier extends TodayExerciseNotifier {
  _StubExerciseNotifier(this._entries);
  final List<ExerciseEntry> _entries;

  @override
  Future<List<ExerciseEntry>> build() async => _entries;
}

void main() {
  testWidgets('shows empty state when no entries', (tester) async {
    await tester.pumpWidget(wrapInApp(
      ProviderScope(overrides: [
        todayExerciseProvider
            .overrideWith(() => _StubExerciseNotifier(const [])),
      ], child: const ExerciseEntriesSheet()),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('No exercise'), findsOneWidget);
  });

  testWidgets('shows entry when logged', (tester) async {
    final entry = ExerciseEntry(
      id: '1',
      activity: 'Running',
      durationMinutes: 30,
      caloriesBurned: 320,
      loggedAt: DateTime.now(),
    );
    await tester.pumpWidget(wrapInApp(
      ProviderScope(overrides: [
        todayExerciseProvider
            .overrideWith(() => _StubExerciseNotifier([entry])),
      ], child: const ExerciseEntriesSheet()),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Running'), findsOneWidget);
    expect(find.textContaining('320'), findsAtLeastNWidgets(1));
  });
}
