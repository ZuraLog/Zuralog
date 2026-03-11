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
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/di/providers.dart';
import 'package:zuralog/features/today/data/today_repository.dart';
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

/// Async provider for the aggregated Today feed (insights + quick actions + streak).
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
    return TodayFeedData(insights: [], quickActions: [], streak: null);
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
  return repo.getNotifications(page: 1);
});

// ── Data Maturity Banner ───────────────────────────────────────────────────────

/// Whether the "still building" reminder banner has been dismissed this session.
///
/// Resets on cold start — the banner will re-appear next session if data is
/// still insufficient. Permanent dismissal is handled separately via
/// [dataMaturityBannerDismissedProvider] in `settings_providers.dart`.
final todayBannerSessionDismissed = StateProvider<bool>((ref) => false);

// ── Quick Log Loading ─────────────────────────────────────────────────────────

/// Whether a quick-log submission is currently in flight.
///
/// Set to `true` when the submit button is tapped and `false` when the
/// API call completes (success or failure).
final quickLogLoadingProvider = StateProvider<bool>((ref) => false);
