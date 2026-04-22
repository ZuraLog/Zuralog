/// ZuraLog — Nutrition Riverpod Providers.
///
/// All state for the Nutrition feature is managed here. Screens read from
/// these providers and trigger invalidations via [ref.invalidate] after
/// mutations (e.g. logging or deleting a meal).
///
/// Every async provider follows the **never-error** pattern: network and
/// parse failures are caught and resolved to safe empty/default values so the
/// UI always reaches the `data:` branch and never needs an error widget.
///
/// Provider inventory:
/// - [nutritionRepositoryProvider]  — singleton repository (mock or API)
/// - [todayMealsProvider]           — async list of today's meals
/// - [nutritionDaySummaryProvider]  — async aggregated day summary
/// - [todayExerciseProvider]        — async list of today's exercise entries
/// - [mealDetailProvider]           — family: detail for a single meal by ID
/// - [foodSearchQueryProvider]      — state: current search query text
/// - [foodSearchResultsProvider]    — async search results for current query
/// - [recentFoodsProvider]          — async list of recently logged foods
/// - [nutritionRulesProvider]       — async list of user's nutrition rules
/// - [nutritionGoalsProvider]       — async structured nutrition goals from goal list
/// - [nutritionTrendProvider]       — family: per-day calorie/protein for trend charts
library;

import 'dart:async' show Timer;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/di/providers.dart';
import 'package:zuralog/features/nutrition/data/api_nutrition_repository.dart';
import 'package:zuralog/features/nutrition/data/mock_nutrition_repository.dart';
import 'package:zuralog/features/nutrition/domain/nutrition_goals_model.dart';
import 'package:zuralog/features/nutrition/domain/nutrition_models.dart';
import 'package:zuralog/features/progress/providers/progress_providers.dart';

const _useMock = bool.fromEnvironment('USE_MOCK_DATA', defaultValue: false);

// -- Repository ---------------------------------------------------------------

/// Singleton [NutritionRepositoryInterface] for the nutrition feature.
///
/// Returns [MockNutritionRepository] when the app is compiled with
/// `--dart-define=USE_MOCK_DATA=true`. Otherwise uses [ApiNutritionRepository].
final nutritionRepositoryProvider =
    Provider<NutritionRepositoryInterface>((ref) {
  if (_useMock) return const MockNutritionRepository();
  return ApiNutritionRepository(apiClient: ref.read(apiClientProvider));
});

// -- Today Meals --------------------------------------------------------------

/// Represents a meal that has been removed from the list pending a 4-second
/// undo window. Holds the resources needed to either restore the meal (on
/// undo) or fire the backend delete (on timer expiry).
class _PendingDelete {
  const _PendingDelete({
    required this.timer,
    required this.meal,
  });

  final Timer timer;
  final Meal meal;
}

/// Async notifier backing [todayMealsProvider]. Owns the list of today's
/// meals and exposes optimistic-delete with 4-second undo semantics.
class TodayMealsNotifier extends AsyncNotifier<List<Meal>> {
  final Map<String, _PendingDelete> _pending = {};

  @override
  Future<List<Meal>> build() async {
    final repo = ref.read(nutritionRepositoryProvider);
    ref.onDispose(() {
      for (final pending in _pending.values) {
        pending.timer.cancel();
        // Fire-and-forget: we're being disposed, we can't restore on failure.
        repo.deleteMeal(pending.meal.id).catchError((Object e, StackTrace st) {
          debugPrint('deleteMeal during dispose failed for ${pending.meal.id}: $e');
        });
      }
      _pending.clear();
    });
    try {
      return await repo.getTodayMeals();
    } catch (e, st) {
      debugPrint('todayMealsProvider failed: $e\n$st');
      return const [];
    }
  }

  /// Remove [meal] from local state immediately and schedule a backend
  /// delete in 4 seconds. Cancel the schedule via [undoDelete] within the
  /// window to restore the row.
  void deleteOptimistic(Meal meal) {
    final current = state.valueOrNull ?? const <Meal>[];
    final index = current.indexWhere((m) => m.id == meal.id);
    if (index < 0) return;

    final next = [...current]..removeAt(index);
    state = AsyncData(next);

    final repo = ref.read(nutritionRepositoryProvider);
    final timer = Timer(const Duration(seconds: 4), () async {
      final stillPending = _pending.remove(meal.id);
      if (stillPending == null) return; // Already handled by dispose or undo.
      try {
        await repo.deleteMeal(meal.id);
      } catch (e, st) {
        debugPrint('deleteMeal failed for ${meal.id}: $e\n$st');
        final latest = state.valueOrNull ?? const <Meal>[];
        final restored = [...latest, meal]
          ..sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
        state = AsyncData(restored);
      }
    });

    _pending[meal.id] = _PendingDelete(
      timer: timer,
      meal: meal,
    );
  }

  /// Cancel the pending delete for [mealId] and restore the meal at its
  /// original index. Returns `true` if a pending delete existed.
  bool undoDelete(String mealId) {
    final pending = _pending.remove(mealId);
    if (pending == null) return false;
    pending.timer.cancel();

    final current = state.valueOrNull ?? const <Meal>[];
    final restored = [...current, pending.meal]
      ..sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
    state = AsyncData(restored);
    return true;
  }
}

/// Async provider for today's meals.
///
/// Never puts the UI into an error state — repo failures resolve to an
/// empty list so the `data:` branch always renders a sensible empty state.
/// Backed by [TodayMealsNotifier], which exposes [deleteOptimistic] and
/// [undoDelete] for swipe-driven mutations on the Nutrition home screen.
final todayMealsProvider =
    AsyncNotifierProvider<TodayMealsNotifier, List<Meal>>(
  TodayMealsNotifier.new,
);

// -- Day Summary --------------------------------------------------------------

/// Async provider for today's aggregated calorie and macro totals.
///
/// Never puts the UI into an error state. All failures resolve to
/// [NutritionDaySummary.empty] so the dashboard always has safe values
/// to display.
///
/// Invalidate alongside [todayMealsProvider] after any mutation.
final nutritionDaySummaryProvider =
    FutureProvider<NutritionDaySummary>((ref) async {
  final repo = ref.read(nutritionRepositoryProvider);
  try {
    return await repo.getTodaySummary();
  } catch (e, st) {
    debugPrint('nutritionDaySummaryProvider failed: $e\n$st');
    return NutritionDaySummary.empty;
  }
});

// -- Today Exercise ----------------------------------------------------------

/// Async notifier backing [todayExerciseProvider]. Owns the list of today's
/// exercise entries and exposes mutations for adding and removing exercises.
class TodayExerciseNotifier extends AsyncNotifier<List<ExerciseEntry>> {
  @override
  Future<List<ExerciseEntry>> build() async {
    final repo = ref.read(nutritionRepositoryProvider);
    try {
      return await repo.getExerciseToday();
    } catch (e) {
      debugPrint('todayExerciseProvider failed: $e');
      return const [];
    }
  }

  /// Log a new exercise session and add it to the current list.
  Future<void> logExercise({
    required String activity,
    required int durationMinutes,
    required int caloriesBurned,
  }) async {
    final repo = ref.read(nutritionRepositoryProvider);
    final entry = await repo.logExercise(
      activity: activity,
      durationMinutes: durationMinutes,
      caloriesBurned: caloriesBurned,
    );
    state = AsyncData([...?state.valueOrNull, entry]);
    ref.invalidate(nutritionDaySummaryProvider);
  }

  /// Delete an exercise entry by its ID.
  Future<void> deleteExercise(String id) async {
    state = AsyncData(
      (state.valueOrNull ?? []).where((e) => e.id != id).toList(),
    );
    await ref.read(nutritionRepositoryProvider).deleteExercise(id);
    ref.invalidate(nutritionDaySummaryProvider);
  }
}

/// Async provider for today's exercise entries.
///
/// Never puts the UI into an error state — repo failures resolve to an
/// empty list so the `data:` branch always renders a sensible empty state.
/// Backed by [TodayExerciseNotifier], which exposes [logExercise] and
/// [deleteExercise] for mutations on the Nutrition feature screens.
final todayExerciseProvider =
    AsyncNotifierProvider<TodayExerciseNotifier, List<ExerciseEntry>>(
  TodayExerciseNotifier.new,
);

// -- Meal Detail --------------------------------------------------------------

/// Async family provider for a single meal's full detail.
///
/// Keyed by the meal [id] string. The detail screen uses
/// `ref.watch(mealDetailProvider(mealId))`.
///
/// Returns `null` for unknown IDs or on failure so the UI can show a
/// "not found" state without entering an error branch.
final mealDetailProvider =
    FutureProvider.family<Meal?, String>((ref, id) async {
  final repo = ref.read(nutritionRepositoryProvider);
  try {
    return await repo.getMealById(id);
  } catch (e, st) {
    debugPrint('mealDetailProvider($id) failed: $e\n$st');
    return null;
  }
});

// ── Food Search ───────────────────────────────────────────────────────────────

/// Holds the current food search query text.
/// Updated by the LogMealSheet with a 300ms debounce.
final foodSearchQueryProvider = StateProvider<String>((ref) => '');

/// Async results for the current food search query.
/// Returns empty list when query is too short or on error.
final foodSearchResultsProvider =
    FutureProvider<List<FoodSearchResult>>((ref) async {
  final query = ref.watch(foodSearchQueryProvider);
  if (query.trim().length < 2) return const [];

  final repo = ref.read(nutritionRepositoryProvider);
  try {
    return await repo.searchFoods(query);
  } catch (e, st) {
    debugPrint('foodSearchResultsProvider failed: $e\n$st');
    return const [];
  }
});

// ── Recent Foods ──────────────────────────────────────────────────────────────

/// Async provider for the user's recently logged foods.
/// Used by the LogMealSheet recents row.
final recentFoodsProvider = FutureProvider<List<RecentFood>>((ref) async {
  final repo = ref.read(nutritionRepositoryProvider);
  try {
    return await repo.getRecentFoods();
  } catch (e, st) {
    debugPrint('recentFoodsProvider failed: $e\n$st');
    return const [];
  }
});

// ── Nutrition Rules ──────────────────────────────────────────────────────────

/// Async provider for the user's nutrition rules.
///
/// Rules give the AI persistent context about dietary preferences so it
/// asks fewer clarifying questions when parsing meals. Each user may have
/// up to 20 rules.
///
/// Invalidate with `ref.invalidate(nutritionRulesProvider)` after any
/// create, update, or delete operation.
final nutritionRulesProvider =
    FutureProvider<List<NutritionRule>>((ref) async {
  final repo = ref.read(nutritionRepositoryProvider);
  try {
    return await repo.getRules();
  } catch (e, st) {
    debugPrint('nutritionRulesProvider failed: $e\n$st');
    return const [];
  }
});

// ── Nutrition Goals ──────────────────────────────────────────────────────────

/// Async provider for the user's structured nutrition goals.
///
/// Reads from the progress feature's [goalsProvider] and extracts nutrition-relevant
/// goals (daily calorie budget, macro/mineral targets) into a [NutritionGoals] object.
///
/// All fields are optional — null means that goal is not set.
/// Use [NutritionGoals.hasGoals] to check whether any goal is active.
///
/// Invalidate with `ref.invalidate(nutritionGoalsProvider)` after any goal
/// create, update, or delete operation (the progress feature invalidates
/// [goalsProvider] which this provider depends on).
final nutritionGoalsProvider =
    FutureProvider<NutritionGoals>((ref) async {
  try {
    final goalList = await ref.watch(goalsProvider.future);
    return NutritionGoals.fromGoalList(goalList.goals);
  } catch (e, st) {
    debugPrint('nutritionGoalsProvider failed: $e\n$st');
    return const NutritionGoals();
  }
});

// ── Meal Templates ───────────────────────────────────────────────────────────

/// Async provider for the user's saved meal templates.
///
/// Never puts the UI into an error state — repo failures resolve to an
/// empty list so screens can safely assume a list is available.
///
/// Invalidate with `ref.invalidate(mealTemplatesProvider)` after any
/// create, update, or delete operation on meal templates.
final mealTemplatesProvider =
    FutureProvider<List<MealTemplate>>((ref) async {
  final repo = ref.read(nutritionRepositoryProvider);
  try {
    return await repo.getTemplates();
  } catch (e, st) {
    debugPrint('mealTemplatesProvider failed: $e\n$st');
    return const [];
  }
});

// ── Nutrition Trend ──────────────────────────────────────────────────────────

/// Async family provider for per-day calorie and protein totals.
///
/// Keyed by the range string (`'7d'` or `'30d'`).
/// Never puts the UI into an error state — failures resolve to an empty list.
final nutritionTrendProvider =
    FutureProvider.family<List<NutritionTrendDay>, String>((ref, range) async {
  final repo = ref.read(nutritionRepositoryProvider);
  try {
    return await repo.getTrend(range);
  } catch (e, st) {
    debugPrint('nutritionTrendProvider($range) failed: $e\n$st');
    return const [];
  }
});
