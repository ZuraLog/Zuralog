import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zuralog/features/nutrition/data/mock_nutrition_repository.dart';
import 'package:zuralog/features/nutrition/domain/nutrition_models.dart';
import 'package:zuralog/features/nutrition/providers/nutrition_providers.dart';

/// Test-only repo — extends MockNutritionRepository so we get every
/// interface method for free, then overrides only the two we care about.
class _TestRepo extends MockNutritionRepository {
  _TestRepo(this._meals);

  final List<Meal> _meals;
  final List<String> deleteCalls = [];
  bool deleteShouldFail = false;

  @override
  Future<List<Meal>> getTodayMeals() async => List<Meal>.of(_meals);

  @override
  Future<void> deleteMeal(String id) async {
    deleteCalls.add(id);
    if (deleteShouldFail) {
      throw Exception('boom');
    }
  }
}

Meal _meal(String id, String name, {int minute = 0}) => Meal(
      id: id,
      name: name,
      type: MealType.breakfast,
      loggedAt: DateTime(2026, 4, 18, 8, minute),
      foods: const [],
    );

ProviderContainer _container(_TestRepo repo) => ProviderContainer(
      overrides: [
        nutritionRepositoryProvider.overrideWithValue(repo),
      ],
    );

void main() {
  group('TodayMealsNotifier', () {
    test('deleteOptimistic removes the meal from state immediately',
        () async {
      final repo = _TestRepo([_meal('a', 'eggs', minute: 10), _meal('b', 'toast', minute: 5)]);
      final c = _container(repo);
      addTearDown(c.dispose);

      final loaded = await c.read(todayMealsProvider.future);
      expect(loaded.map((m) => m.id), ['a', 'b']);

      c.read(todayMealsProvider.notifier).deleteOptimistic(loaded.first);

      final after = c.read(todayMealsProvider).valueOrNull!;
      expect(after.map((m) => m.id), ['b']);
      expect(repo.deleteCalls, isEmpty);
    });

    test('undoDelete restores the row and cancels the timer', () {
      fakeAsync((async) {
        final repo = _TestRepo([_meal('a', 'eggs', minute: 10), _meal('b', 'toast', minute: 5)]);
        final c = _container(repo);
        addTearDown(c.dispose);

        c.read(todayMealsProvider.future);
        async.flushMicrotasks();

        final meal = c.read(todayMealsProvider).valueOrNull!.first;
        c.read(todayMealsProvider.notifier).deleteOptimistic(meal);

        final restored = c
            .read(todayMealsProvider.notifier)
            .undoDelete(meal.id);
        expect(restored, isTrue);

        final after = c.read(todayMealsProvider).valueOrNull!;
        expect(after.map((m) => m.id), ['a', 'b']);

        async.elapse(const Duration(seconds: 5));
        expect(repo.deleteCalls, isEmpty);
      });
    });

    test('timer expiry calls repo.deleteMeal', () {
      fakeAsync((async) {
        final repo = _TestRepo([_meal('a', 'eggs')]);
        final c = _container(repo);
        addTearDown(c.dispose);

        c.read(todayMealsProvider.future);
        async.flushMicrotasks();

        final meal = c.read(todayMealsProvider).valueOrNull!.first;
        c.read(todayMealsProvider.notifier).deleteOptimistic(meal);

        async.elapse(const Duration(seconds: 4));
        async.flushMicrotasks();

        expect(repo.deleteCalls, ['a']);
      });
    });

    test('two quick deletes get independent pending entries', () {
      fakeAsync((async) {
        final repo = _TestRepo([_meal('a', 'eggs', minute: 10), _meal('b', 'toast', minute: 5)]);
        final c = _container(repo);
        addTearDown(c.dispose);

        c.read(todayMealsProvider.future);
        async.flushMicrotasks();

        final meals = c.read(todayMealsProvider).valueOrNull!;
        final notifier = c.read(todayMealsProvider.notifier);

        notifier.deleteOptimistic(meals[0]);
        notifier.deleteOptimistic(meals[1]);

        expect(notifier.undoDelete('a'), isTrue);

        async.elapse(const Duration(seconds: 4));
        async.flushMicrotasks();

        expect(repo.deleteCalls, ['b']);
        final finalList = c.read(todayMealsProvider).valueOrNull!;
        expect(finalList.map((m) => m.id), ['a']);
      });
    });

    test('backend failure during scheduled delete restores the meal', () {
      fakeAsync((async) {
        final repo = _TestRepo([_meal('a', 'eggs', minute: 10), _meal('b', 'toast', minute: 5)]);
        repo.deleteShouldFail = true;
        final c = _container(repo);
        addTearDown(c.dispose);

        c.read(todayMealsProvider.future);
        async.flushMicrotasks();

        final meal = c.read(todayMealsProvider).valueOrNull!.first;
        c.read(todayMealsProvider.notifier).deleteOptimistic(meal);

        async.elapse(const Duration(seconds: 4));
        async.flushMicrotasks();

        final finalList = c.read(todayMealsProvider).valueOrNull!;
        expect(finalList.map((m) => m.id), ['a', 'b']);
      });
    });
  });
}
