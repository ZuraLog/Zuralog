/// Zuralog — Today Tab Riverpod Providers.
///
/// All state for the Today tab is managed here. Screens read from these
/// providers and trigger invalidations via [ref.invalidate] / repository
/// mutation helpers.
///
/// Provider inventory:
/// - [todayRepositoryProvider]        — singleton repository
/// - [healthScoreProvider]            — async health score + trend
/// - [todayFeedProvider]              — async aggregated feed data
/// - [insightDetailProvider]          — family: detail for a single insight
/// - [notificationsProvider]          — async first page of notifications
/// - [todayBannerSessionDismissed]    — whether the "still building" banner was dismissed this session
/// - [todayLogSummaryProvider]        — aggregated summary of today's logged data
/// - [userLoggedTypesProvider]        — set of metric types user has ever logged
/// - [dailyGoalsProvider]             — user's daily goals with today's progress
/// - [supplementsListProvider]        — user's saved supplement and medication list
/// - [stepsLogModeProvider]           — persisted steps log mode (add vs override)
/// - [mealLogModeProvider]             — persisted meal log mode (quick vs full)
/// (quickLogLoadingProvider removed — superseded by FAB system in Part 2)
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zuralog/core/di/providers.dart';
import 'package:zuralog/features/today/data/today_repository.dart';
import 'package:zuralog/features/today/domain/log_summary_models.dart';
import 'package:zuralog/features/today/domain/today_models.dart';

// ── Repository ────────────────────────────────────────────────────────────────

/// Singleton [TodayRepositoryInterface] wired to the shared [apiClientProvider].
///
/// Always uses the real [TodayRepository] backed by the Cloud Brain API.
/// Mock repositories are available for unit tests via provider overrides.
final todayRepositoryProvider = Provider<TodayRepositoryInterface>((ref) {
  return TodayRepository(apiClient: ref.read(apiClientProvider));
});

// ── Health Score ──────────────────────────────────────────────────────────────

/// Async provider for the current health score and 7-day trend.
///
/// Never puts the UI into an error state. All network / parse failures are
/// caught and resolved to an empty [HealthScoreData] (score 0, no trend).
/// The UI distinguishes "no data yet" from "has data" via [HealthScoreData.score]
/// being 0 and [HealthScoreData.dataDays] being 0 — it never needs to handle
/// an async error branch.
///
/// Invalidate with [ref.invalidate(healthScoreProvider)] to trigger a
/// fresh fetch (e.g., after a pull-to-refresh).
final healthScoreProvider = FutureProvider<HealthScoreData>((ref) async {
  final repo = ref.read(todayRepositoryProvider);
  try {
    return await repo.getHealthScore();
  } catch (_) {
    return const HealthScoreData(score: 0, trend: [], dataDays: 0);
  }
});

// ── Today Feed ─────────────────────────────────────────────────────────────────

/// Async provider for the aggregated Today feed (insights + streak).
///
/// Never puts the UI into an error state. All failures resolve to an empty
/// [TodayFeedData] so the UI always reaches the [data:] branch and renders
/// the appropriate empty / zero-data state instead of a connection error.
///
/// Invalidate with [ref.invalidate(todayFeedProvider)] to trigger a
/// fresh fetch (e.g., after a pull-to-refresh or quick-log submission).
final todayFeedProvider = FutureProvider<TodayFeedData>((ref) async {
  final repo = ref.read(todayRepositoryProvider);
  try {
    return await repo.getTodayFeed();
  } catch (_) {
    return TodayFeedData(insights: [], streak: null);
  }
});

// ── Insight Detail ────────────────────────────────────────────────────────────

/// Async family provider for a single insight's full detail.
///
/// Keyed by the insight [id] string. The detail screen uses
/// `ref.watch(insightDetailProvider(insightId))`.
final insightDetailProvider =
    FutureProvider.family<InsightDetail, String>((ref, id) async {
  final repo = ref.read(todayRepositoryProvider);
  return repo.getInsightDetail(id);
});

// ── Notifications ─────────────────────────────────────────────────────────────

/// Async provider for the first page of notification history.
///
/// Invalidate after [TodayRepository.markNotificationRead] to refresh
/// the read state.
final notificationsProvider = FutureProvider<NotificationPage>((ref) async {
  final repo = ref.read(todayRepositoryProvider);
  try {
    return await repo.getNotifications(page: 1);
  } catch (_) {
    return const NotificationPage(
      items: [],
      totalCount: 0,
      page: 1,
      hasMore: false,
    );
  }
});

// ── Data Maturity Banner ───────────────────────────────────────────────────────

/// Whether the "still building" reminder banner has been dismissed this session.
///
/// Resets on cold start — the banner will re-appear next session if data is
/// still insufficient. Permanent dismissal is handled separately via
/// [dataMaturityBannerDismissedProvider] in `settings_providers.dart`.
final todayBannerSessionDismissed = StateProvider<bool>((ref) => false);

// ── Today Log Summary ─────────────────────────────────────────────────────────

/// Aggregated summary of what the user has logged today.
///
/// On success: returns populated [TodayLogSummary] from the API.
/// On failure: returns [TodayLogSummary.empty] — the UI stays functional
/// in an empty state rather than showing an error.
///
/// Invalidate after every successful log submission so the Streak Hero Card and
/// Snapshot Cards reflect the new entry immediately.
final todayLogSummaryProvider = FutureProvider<TodayLogSummary>((ref) async {
  final repo = ref.read(todayRepositoryProvider);
  try {
    return await repo.getTodayLogSummary();
  } catch (e, st) {
    debugPrint('todayLogSummaryProvider failed: $e\n$st');
    return TodayLogSummary.empty;
  }
});

// ── User Logged Types ─────────────────────────────────────────────────────────

/// The set of metric type strings the user has *ever* logged (not just today).
///
/// On failure: returns an empty set.
///
/// Cached until a new metric type is submitted for the first time.
final userLoggedTypesProvider = FutureProvider<Set<String>>((ref) async {
  final repo = ref.read(todayRepositoryProvider);
  try {
    return await repo.getUserLoggedTypes();
  } catch (e, st) {
    debugPrint('userLoggedTypesProvider failed: $e\n$st');
    return const <String>{};
  }
});

// ── Daily Goals ───────────────────────────────────────────────────────────────

/// User's configured daily goals with today's progress.
///
/// Cached — does not re-fetch on every rebuild. Invalidate only after the
/// user changes a goal in settings.
///
/// Returns an empty list if the user has no goals configured — the daily
/// goals card shows a "Set a daily goal →" prompt in that case.
final dailyGoalsProvider = FutureProvider<List<DailyGoal>>((ref) async {
  final repo = ref.read(todayRepositoryProvider);
  try {
    return await repo.getDailyGoals();
  } catch (e, st) {
    debugPrint('dailyGoalsProvider failed: $e\n$st');
    return const [];
  }
});

// ── Supplements List ──────────────────────────────────────────────────────────

/// The user's saved supplement and medication list.
///
/// Cached — only invalidated when the user edits their list.
/// The supplements log screen reads this to build the tap-to-check-off list.
final supplementsListProvider =
    FutureProvider<List<SupplementEntry>>((ref) async {
  final repo = ref.read(todayRepositoryProvider);
  try {
    return await repo.getSupplementsList();
  } catch (e, st) {
    debugPrint('supplementsListProvider failed: $e\n$st');
    return const [];
  }
});

// ── Steps Log Mode ────────────────────────────────────────────────────────────

/// Whether the user is adding to their running step total or overriding it.
enum StepsLogMode { add, override_ }

/// Notifier that persists the last-used steps log mode via SharedPreferences.
///
/// Default: [StepsLogMode.add] — each entry adds to today's running total.
class StepsLogModeNotifier extends AsyncNotifier<StepsLogMode> {
  static const _key = 'steps_log_mode';

  @override
  Future<StepsLogMode> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    return raw == 'override' ? StepsLogMode.override_ : StepsLogMode.add;
  }

  Future<void> setMode(StepsLogMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      mode == StepsLogMode.override_ ? 'override' : 'add',
    );
    state = AsyncData(mode);
  }
}

/// Provider for the steps log mode. Remembered across app restarts.
final stepsLogModeProvider =
    AsyncNotifierProvider<StepsLogModeNotifier, StepsLogMode>(
  StepsLogModeNotifier.new,
);

// ── Meal Log Mode ─────────────────────────────────────────────────────────────

/// Notifier that persists the meal log quick-mode toggle via SharedPreferences.
///
/// Default: `false` — full mode (description required).
/// When `true`, the meal log screen shows a simplified calorie-only form.
class MealLogModeNotifier extends AsyncNotifier<bool> {
  static const _key = 'meal_log_quick_mode';

  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  Future<void> setMode(bool quickMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, quickMode);
    state = AsyncData(quickMode);
  }
}

/// Provider for the meal log quick-mode toggle. Remembered across app restarts.
final mealLogModeProvider =
    AsyncNotifierProvider<MealLogModeNotifier, bool>(
  MealLogModeNotifier.new,
);

// ── Latest Log Values ─────────────────────────────────────────────────────────

/// Produces a stable cache key for [latestLogValuesProvider] from a set of
/// metric type strings. Always sorts alphabetically so the same set of types
/// always produces the same string, regardless of insertion order.
///
/// Usage: `ref.watch(latestLogValuesProvider(latestLogValuesKey({'weight', 'steps'})))`
String latestLogValuesKey(Set<String> types) =>
    (types.toList()..sort()).join(',');

/// The most recent logged value per requested metric type, across all time.
///
/// The Cloud Brain is the deduplicated source of truth — values ingested from
/// Apple Health, Health Connect, Strava, and manual entries are all surfaced
/// here.
///
/// Keyed by a sorted comma-joined [String] produced by [latestLogValuesKey].
/// Using a [String] key (rather than [Set<String>]) guarantees correct Riverpod
/// cache hits — Dart sets do not override `==` for value equality, so two
/// non-const sets with identical contents are treated as different keys.
///
/// Returns an empty map if [typesKey] is empty or the request fails.
/// Individual types the user has never logged are absent from the returned map.
///
/// Automatically re-fetches whenever [todayLogSummaryProvider] is invalidated
/// (i.e. after any successful log submission), keeping pre-fill values fresh.
final latestLogValuesProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, typesKey) async {
  // typesKey is a sorted comma-joined string, e.g. 'steps,weight'.
  // Use latestLogValuesKey({'weight', 'steps'}) at call sites to
  // produce a stable cache key.
  //
  // Establish a reactive dependency so this provider auto-refreshes when
  // a new log is submitted (same invalidation trigger as todayLogSummaryProvider).
  ref.watch(todayLogSummaryProvider);

  if (typesKey.isEmpty) return const {};
  final repo = ref.read(todayRepositoryProvider);
  try {
    return await repo.getLatestLogValues(typesKey.split(',').toSet());
  } catch (e, st) {
    debugPrint('latestLogValuesProvider failed: $e\n$st');
    return const {};
  }
});

// ── Pinned Metrics ────────────────────────────────────────────────────────────

/// Notifier that persists the user's ordered list of pinned metric type
/// strings for the Today tab's adaptive metric grid.
///
/// The list is stored as a JSON-encoded string in SharedPreferences under
/// the key [_kPinnedMetricsKey].
///
/// Call [addMetric] / [removeMetric] to update the list. Both methods
/// persist immediately and update the state synchronously.
class PinnedMetricsNotifier extends AsyncNotifier<List<String>> {
  static const _kPinnedMetricsKey = 'today_pinned_metrics';

  /// Used to expose the key for testing.
  @visibleForTesting
  static const kPinnedMetricsKeyForTest = _kPinnedMetricsKey;

  // Serializes read-modify-write operations so concurrent calls don't clobber each other.
  Future<void> _pendingOperation = Future.value();

  @override
  Future<List<String>> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPinnedMetricsKey);
    if (raw == null || raw.isEmpty) return List.unmodifiable([]);
    try {
      final decoded = (jsonDecode(raw) as List<dynamic>).cast<String>();
      return List.unmodifiable(decoded);
    } catch (_) {
      return List.unmodifiable([]);
    }
  }

  /// Adds [metricType] to the end of the pinned list.
  /// No-op if [metricType] is already present.
  Future<void> addMetric(String metricType) {
    _pendingOperation = _pendingOperation.then((_) async {
      final current = await future;
      if (current.contains(metricType)) return;
      final updated = [...current, metricType];
      await _persist(updated);
      state = AsyncData(List.unmodifiable(updated));
    }).catchError((Object e, StackTrace st) {
      debugPrint('PinnedMetricsNotifier.addMetric: $e\n$st');
    });
    return _pendingOperation;
  }

  /// Removes [metricType] from the pinned list.
  /// No-op if [metricType] is not in the list.
  Future<void> removeMetric(String metricType) {
    _pendingOperation = _pendingOperation.then((_) async {
      final current = await future;
      if (!current.contains(metricType)) return; // no-op guard
      final updated = current.where((m) => m != metricType).toList();
      await _persist(updated);
      state = AsyncData(List.unmodifiable(updated));
    }).catchError((Object e, StackTrace st) {
      debugPrint('PinnedMetricsNotifier.removeMetric: $e\n$st');
    });
    return _pendingOperation;
  }

  Future<void> _persist(List<String> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPinnedMetricsKey, jsonEncode(list));
    } catch (e, st) {
      // Persistence failed — state is already updated in memory.
      // Log for diagnostics; do not rethrow so the UI remains functional.
      debugPrint('PinnedMetricsNotifier: failed to persist: $e\n$st');
    }
  }
}

/// Provider for the user's ordered list of pinned metric type strings.
final pinnedMetricsProvider =
    AsyncNotifierProvider<PinnedMetricsNotifier, List<String>>(
  PinnedMetricsNotifier.new,
);
