import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zuralog/features/nutrition/data/mock_nutrition_repository.dart';
import 'package:zuralog/features/nutrition/domain/nutrition_models.dart';
import 'package:zuralog/features/nutrition/presentation/nutrition_home_screen.dart';
import 'package:zuralog/features/nutrition/providers/nutrition_providers.dart';

class _Repo extends MockNutritionRepository {
  _Repo(this.meals);
  List<Meal> meals;
  final List<String> deleteCalls = [];

  @override
  Future<List<Meal>> getTodayMeals() async => List<Meal>.of(meals);

  @override
  Future<void> deleteMeal(String id) async {
    deleteCalls.add(id);
    meals = meals.where((m) => m.id != id).toList();
  }
}

Meal _meal(String id, String name, {int minute = 0}) => Meal(
      id: id,
      name: name,
      type: MealType.breakfast,
      loggedAt: DateTime(2026, 4, 18, 8, minute),
      foods: const [],
    );

Widget _host(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: MediaQuery(
        // Disable enter animations so ZFadeSlideIn delay timers don't
        // interfere with pump calls.
        data: const MediaQueryData(disableAnimations: true),
        child: const NutritionHomeScreen(),
      ),
    ),
  );
}

/// Advances the clock enough for async Riverpod providers to deliver data and
/// for the rebuilt widget tree to lay out.
///
/// Avoids pumpAndSettle because ZLoadingSkeleton has a repeating shimmer
/// animation that never settles.
///
/// Pumps 500ms to clear the MockNutritionRepository._readDelay (400ms) used
/// by getTodaySummary (not overridden in _Repo).
Future<void> _load(WidgetTester tester) async {
  await tester.pump(); // resolves immediate Future microtasks
  await tester.pump(const Duration(milliseconds: 500)); // clears 400ms mock delay
  await tester.pump(); // flush final rebuild
}

/// Performs a swipe-to-dismiss: timedDrag to let DismissiblePane mount, then
/// explicit pumps to complete all animation phases including the 4-second
/// delete timer, so no pending timers remain when the test ends.
///
/// Uses timedDrag (which fires many PointerMoveEvents) rather than pumpAndSettle
/// (which hangs on the ZLoadingSkeleton repeating shimmer animation).
Future<void> _fullSwipeAndSettle(WidgetTester tester, Finder finder) async {
  await tester.timedDrag(
    finder,
    const Offset(-500, 0),
    const Duration(milliseconds: 400),
  );

  // dismissalDuration (300ms) + resizeDuration (300ms) = ~600ms to remove row.
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump(); // flush provider rebuild + snackbar show
}

/// Drains the 4-second delete timer so the test ends without pending timers.
/// Call at the end of any test that triggers a deleteOptimistic.
Future<void> _drainDeleteTimer(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
}

void main() {
  group('Meal card swipe actions', () {
    testWidgets('slidable renders for each meal', (tester) async {
      final repo = _Repo([
        _meal('a', 'eggs', minute: 10),
        _meal('b', 'toast', minute: 5),
      ]);
      final c = ProviderContainer(
        overrides: [nutritionRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(c.dispose);

      await tester.pumpWidget(_host(c));
      await _load(tester);

      expect(find.byType(Slidable), findsNWidgets(2));
    });

    testWidgets('partial swipe reveals Edit and Delete labels',
        (tester) async {
      final repo = _Repo([_meal('a', 'eggs with toast')]);
      final c = ProviderContainer(
        overrides: [nutritionRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(c.dispose);

      await tester.pumpWidget(_host(c));
      await _load(tester);

      // Partial drag opens action pane far enough to show buttons.
      await tester.drag(find.byType(Slidable).first, const Offset(-250, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('full-swipe removes the row and shows UNDO snackbar',
        (tester) async {
      final repo = _Repo([_meal('a', 'eggs with toast')]);
      final c = ProviderContainer(
        overrides: [nutritionRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(c.dispose);

      await tester.pumpWidget(_host(c));
      await _load(tester);

      await _fullSwipeAndSettle(tester, find.byType(Slidable).first);

      expect(find.text('eggs with toast'), findsNothing);
      expect(find.text('Deleted eggs with toast'), findsOneWidget);
      expect(find.text('UNDO'), findsOneWidget);
      expect(repo.deleteCalls, isEmpty);

      // Drain the 4-second delete timer so no pending timer remains.
      await _drainDeleteTimer(tester);
    });

    testWidgets('tapping UNDO restores the row', (tester) async {
      final repo = _Repo([_meal('a', 'eggs with toast')]);
      final c = ProviderContainer(
        overrides: [nutritionRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(c.dispose);

      await tester.pumpWidget(_host(c));
      await _load(tester);

      await _fullSwipeAndSettle(tester, find.byType(Slidable).first);
      await tester.tap(find.text('UNDO'));
      await _load(tester);

      expect(find.text('eggs with toast'), findsOneWidget);
      expect(repo.deleteCalls, isEmpty);
    });

    testWidgets('waiting past 4s fires deleteMeal on the repo',
        (tester) async {
      final repo = _Repo([_meal('a', 'eggs with toast')]);
      final c = ProviderContainer(
        overrides: [nutritionRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(c.dispose);

      await tester.pumpWidget(_host(c));
      await _load(tester);

      await _fullSwipeAndSettle(tester, find.byType(Slidable).first);
      // Advance past the 4-second snackbar/delete timer.
      await tester.pump(const Duration(seconds: 5));

      expect(repo.deleteCalls, ['a']);
    });
  });
}
