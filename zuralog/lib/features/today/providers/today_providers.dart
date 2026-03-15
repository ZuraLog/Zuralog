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
/// - [logRingProvider]                — state for the Log Ring widget
/// - [snapshotProvider]               — list of snapshot card data
/// (quickLogLoadingProvider removed — superseded by FAB system in Part 2)
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

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
/// **MVP stub:** Returns an empty summary until Part 4 adds the backend log
/// endpoints and wires the real fetch. Swap the implementation here when
/// the endpoint is ready — all UI code reads from this provider and will
/// update automatically.
///
/// Invalidate after every successful log submission so the Log Ring and
/// Snapshot Cards reflect the new entry immediately.
final todayLogSummaryProvider = FutureProvider<TodayLogSummary>((ref) async {
  // TODO(Part 4): Replace stub with real API call once log endpoints exist.
  // final repo = ref.read(todayRepositoryProvider);
  // return repo.getTodayLogSummary();
  return TodayLogSummary.empty;
});

// ── User Logged Types ─────────────────────────────────────────────────────────

/// The set of metric type strings the user has *ever* logged (not just today).
///
/// Used by [snapshotProvider] to determine which snapshot cards to display.
/// Cards are shown for all types the user has ever used, even if no data
/// exists today — they render an empty state rather than disappearing.
///
/// **MVP stub:** Returns an empty set until Part 4 adds the backend endpoint
/// `GET /api/v1/quick-logs/my-metric-types`.
final userLoggedTypesProvider = FutureProvider<Set<String>>((ref) async {
  // TODO(Part 4): Replace stub with real API call.
  // final repo = ref.read(todayRepositoryProvider);
  // return repo.getUserLoggedTypes();
  return const <String>{};
});

// ── Log Ring ──────────────────────────────────────────────────────────────────

/// State for the Log Ring widget.
///
/// Derived from [todayLogSummaryProvider] (what was logged today) and
/// [userLoggedTypesProvider] (all types the user has ever used).
///
/// Uses `ref.watch(provider.future)` — the correct pattern inside a
/// FutureProvider body for establishing reactive dependencies on other
/// async providers.
final logRingProvider = FutureProvider<LogRingState>((ref) async {
  final summary = await ref.watch(todayLogSummaryProvider.future);
  final allTypes = await ref.watch(userLoggedTypesProvider.future);

  return LogRingState(
    loggedCount: summary.loggedTypes.length,
    totalCount: allTypes.length,
  );
});

// ── Snapshot Cards ────────────────────────────────────────────────────────────

/// List of snapshot card data for the horizontally scrollable row.
///
/// Watches both [todayLogSummaryProvider] and [userLoggedTypesProvider].
/// Shows one card per metric type the user has ever logged, ordered to
/// match the log grid. Cards with no data today show an empty state.
///
/// **Part 4 note:** The spec describes this as `AsyncNotifierProvider`.
/// It is `FutureProvider` for Part 1 (stub data). Upgrade to `AsyncNotifier`
/// in Part 4 when real data is wired in.
final snapshotProvider = FutureProvider<List<SnapshotCardData>>((ref) async {
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
});

// ── Snapshot card builder ─────────────────────────────────────────────────────

SnapshotCardData _buildSnapshotCard(String metricType, TodayLogSummary summary) {
  final value = summary.latestValues[metricType];
  final hasData = summary.loggedTypes.contains(metricType);

  return switch (metricType) {
    'mood' => SnapshotCardData(
        metricType: metricType,
        label: 'Mood',
        icon: '😊',
        value: hasData ? (value as double?)?.toStringAsFixed(1) ?? '—' : null,
        unit: hasData ? '/10' : null,
        isEmpty: !hasData,
      ),
    'energy' => SnapshotCardData(
        metricType: metricType,
        label: 'Energy',
        icon: '⚡',
        value: hasData ? (value as double?)?.toStringAsFixed(1) ?? '—' : null,
        unit: hasData ? '/10' : null,
        isEmpty: !hasData,
      ),
    'stress' => SnapshotCardData(
        metricType: metricType,
        label: 'Stress',
        icon: '😤',
        value: hasData ? (value as double?)?.toStringAsFixed(1) ?? '—' : null,
        unit: hasData ? '/10' : null,
        isEmpty: !hasData,
      ),
    'water' => SnapshotCardData(
        metricType: metricType,
        label: 'Water',
        icon: '💧',
        value: hasData ? (value as double?)?.toStringAsFixed(0) ?? '—' : null,
        unit: hasData ? 'ml' : null,
        isEmpty: !hasData,
      ),
    // unit is null — the formatted string '7h 30m' is self-describing
    'sleep' => SnapshotCardData(
        metricType: metricType,
        label: 'Sleep',
        icon: '😴',
        value: hasData
            ? (value != null ? _formatSleep(value as double) : null)
            : null,
        isEmpty: !hasData,
      ),
    'weight' => SnapshotCardData(
        metricType: metricType,
        label: 'Weight',
        icon: '⚖️',
        value: hasData ? (value as double?)?.toStringAsFixed(1) ?? '—' : null,
        unit: hasData ? 'kg' : null,
        isEmpty: !hasData,
      ),
    'steps' => SnapshotCardData(
        metricType: metricType,
        label: 'Steps',
        icon: '👟',
        value: hasData ? _formatSteps((value as double?)?.toInt() ?? 0) : null,
        isEmpty: !hasData,
      ),
    'run' => SnapshotCardData(
        metricType: metricType,
        label: 'Run',
        icon: '🏃',
        value: hasData ? (value as double?)?.toStringAsFixed(1) ?? '—' : null,
        unit: hasData ? 'km' : null,
        isEmpty: !hasData,
      ),
    'meal' => SnapshotCardData(
        metricType: metricType,
        label: 'Calories',
        icon: '🍽️',
        value: hasData ? (value as double?)?.toStringAsFixed(0) ?? '—' : null,
        unit: hasData ? 'kcal' : null,
        isEmpty: !hasData,
      ),
    'supplement' => SnapshotCardData(
        metricType: metricType,
        label: 'Supplements',
        icon: '💊',
        value: hasData ? (value as double?)?.toInt().toString() ?? '—' : null,
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
