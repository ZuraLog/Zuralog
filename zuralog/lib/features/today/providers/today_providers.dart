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
/// - [snapshotProvider]               — list of snapshot card data
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
/// Used by [snapshotProvider] to determine which snapshot cards to display.
/// On failure: returns an empty set — the UI shows no snapshot cards rather
/// than crashing.
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

// ── Snapshot Cards ────────────────────────────────────────────────────────────

/// Notifier for the snapshot card list.
///
/// Watches both [todayLogSummaryProvider] and [userLoggedTypesProvider].
/// Shows one card per metric type the user has ever logged, ordered to
/// match the log grid. Cards with no data today show an empty state.
class SnapshotNotifier extends AsyncNotifier<List<SnapshotCardData>> {
  @override
  Future<List<SnapshotCardData>> build() async {
    final summary = await ref.watch(todayLogSummaryProvider.future);
    final allTypes = await ref.watch(userLoggedTypesProvider.future);

    // Ordered list matching the log grid tile order.
    const orderedTypes = [
      'mood', 'energy', 'stress', 'water', 'sleep', 'weight',
      'steps', 'run', 'meal', 'supplement', 'symptom',
    ];

    return orderedTypes
        .where((type) => allTypes.contains(type))
        .map((type) => _buildSnapshotCard(type, summary))
        .toList();
  }
}

/// Provider for snapshot card data. Rebuilds automatically when
/// [todayLogSummaryProvider] or [userLoggedTypesProvider] change.
final snapshotProvider =
    AsyncNotifierProvider<SnapshotNotifier, List<SnapshotCardData>>(
  SnapshotNotifier.new,
);

// ── Snapshot card builder ─────────────────────────────────────────────────────

SnapshotCardData _buildSnapshotCard(String metricType, TodayLogSummary summary) {
  final value = summary.latestValues[metricType];
  final hasData = summary.loggedTypes.contains(metricType);

  return switch (metricType) {
    'mood' => SnapshotCardData(
        metricType: metricType,
        label: 'Mood',
        icon: '😊',
        value: hasData
            ? (value as num?)?.toDouble().toStringAsFixed(1) ?? '—'
            : null,
        unit: hasData ? '/10' : null,
        isEmpty: !hasData,
      ),
    'energy' => SnapshotCardData(
        metricType: metricType,
        label: 'Energy',
        icon: '⚡',
        value: hasData
            ? (value as num?)?.toDouble().toStringAsFixed(1) ?? '—'
            : null,
        unit: hasData ? '/10' : null,
        isEmpty: !hasData,
      ),
    'stress' => SnapshotCardData(
        metricType: metricType,
        label: 'Stress',
        icon: '😤',
        value: hasData
            ? (value as num?)?.toDouble().toStringAsFixed(1) ?? '—'
            : null,
        unit: hasData ? '/10' : null,
        isEmpty: !hasData,
      ),
    'water' => SnapshotCardData(
        metricType: metricType,
        label: 'Water',
        icon: '💧',
        value: hasData
            ? (value as num?)?.toDouble().toStringAsFixed(0) ?? '—'
            : null,
        unit: hasData ? 'ml' : null,
        isEmpty: !hasData,
      ),
    // unit is null — the formatted string '7h 30m' is self-describing
    'sleep' => SnapshotCardData(
        metricType: metricType,
        label: 'Sleep',
        icon: '😴',
        value: hasData
            ? (value != null ? _formatSleep((value as num).toDouble()) : null)
            : null,
        isEmpty: !hasData,
      ),
    'weight' => SnapshotCardData(
        metricType: metricType,
        label: 'Weight',
        icon: '⚖️',
        value: hasData
            ? (value as num?)?.toDouble().toStringAsFixed(1) ?? '—'
            : null,
        unit: hasData ? 'kg' : null,
        isEmpty: !hasData,
      ),
    'steps' => SnapshotCardData(
        metricType: metricType,
        label: 'Steps',
        icon: '👟',
        value: hasData
            ? (value != null ? _formatSteps((value as num).toInt()) : null)
            : null,
        isEmpty: !hasData,
      ),
    'run' => SnapshotCardData(
        metricType: metricType,
        label: 'Run',
        icon: '🏃',
        value: hasData
            ? (value as num?)?.toDouble().toStringAsFixed(1) ?? '—'
            : null,
        unit: hasData ? 'km' : null,
        isEmpty: !hasData,
      ),
    'meal' => SnapshotCardData(
        metricType: metricType,
        label: 'Calories',
        icon: '🍽️',
        value: hasData
            ? (value as num?)?.toDouble().toStringAsFixed(0) ?? '—'
            : null,
        unit: hasData ? 'kcal' : null,
        isEmpty: !hasData,
      ),
    'supplement' => SnapshotCardData(
        metricType: metricType,
        label: 'Supplements',
        icon: '💊',
        value: hasData
            ? (value as num?)?.toInt().toString() ?? '—'
            : null,
        unit: hasData ? 'taken' : null,
        isEmpty: !hasData,
      ),
    // reads from 'symptom_severity' key, not 'symptom' — severity is a string, not a numeric value
    'symptom' => SnapshotCardData(
        metricType: metricType,
        label: 'Symptom',
        icon: '🩹',
        value: hasData
            ? (summary.latestValues['symptom_severity'] as String?) ?? '—'
            : null,
        isEmpty: !hasData,
      ),
    _ => SnapshotCardData(
        metricType: metricType,
        label: metricType,
        icon: '📊',
        isEmpty: true,
      ),
  };
}

String _formatSteps(int steps) {
  if (steps >= 1000) return '${(steps / 1000).toStringAsFixed(1)}k';
  return steps.toString();
}

String _formatSleep(double minutes) {
  final h = (minutes / 60).floor();
  final m = (minutes % 60).toInt();
  return '${h}h ${m}m';
}

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

  @override
  Future<List<String>> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPinnedMetricsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = (jsonDecode(raw) as List<dynamic>).cast<String>();
      return decoded;
    } catch (_) {
      return [];
    }
  }

  /// Adds [metricType] to the end of the pinned list.
  /// No-op if [metricType] is already present.
  Future<void> addMetric(String metricType) async {
    final current = await future;
    if (current.contains(metricType)) return;
    final updated = [...current, metricType];
    await _persist(updated);
    state = AsyncData(updated);
  }

  /// Removes [metricType] from the pinned list.
  /// No-op if [metricType] is not in the list.
  Future<void> removeMetric(String metricType) async {
    final current = await future;
    final updated = current.where((m) => m != metricType).toList();
    await _persist(updated);
    state = AsyncData(updated);
  }

  Future<void> _persist(List<String> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPinnedMetricsKey, jsonEncode(list));
  }
}

/// Provider for the user's ordered list of pinned metric type strings.
final pinnedMetricsProvider =
    AsyncNotifierProvider<PinnedMetricsNotifier, List<String>>(
  PinnedMetricsNotifier.new,
);
