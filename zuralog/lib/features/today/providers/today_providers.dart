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
/// - [dataMaturityBannerDismissed]    — whether the progress banner was dismissed
/// - [todayBannerSessionDismissed]    — whether the "still building" banner was dismissed this session
library;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/di/providers.dart';
import 'package:zuralog/features/today/data/mock_today_repository.dart';
import 'package:zuralog/features/today/data/today_repository.dart';
import 'package:zuralog/features/today/domain/today_models.dart';

// ── Repository ────────────────────────────────────────────────────────────────

/// Singleton [TodayRepositoryInterface] wired to the shared [apiClientProvider].
///
/// In debug builds (`kDebugMode`) a [MockTodayRepository] is returned so the
/// Today tab renders correctly without a running backend.
final todayRepositoryProvider = Provider<TodayRepositoryInterface>((ref) {
  if (kDebugMode) return const MockTodayRepository();
  return TodayRepository(apiClient: ref.read(apiClientProvider));
});

// ── Health Score ──────────────────────────────────────────────────────────────

/// Async provider for the current health score and 7-day trend.
///
/// Invalidate with [ref.invalidate(healthScoreProvider)] to trigger a
/// fresh fetch (e.g., after a pull-to-refresh).
final healthScoreProvider = FutureProvider<HealthScoreData>((ref) async {
  final repo = ref.read(todayRepositoryProvider);
  return repo.getHealthScore();
});

// ── Today Feed ─────────────────────────────────────────────────────────────────

/// Async provider for the aggregated Today feed (insights + quick actions + streak).
///
/// Invalidate with [ref.invalidate(todayFeedProvider)] to trigger a
/// fresh fetch (e.g., after a pull-to-refresh or quick-log submission).
final todayFeedProvider = FutureProvider<TodayFeedData>((ref) async {
  final repo = ref.read(todayRepositoryProvider);
  return repo.getTodayFeed();
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

/// Whether the data maturity progress banner has been dismissed this session.
///
/// Session-scoped only. Permanent dismissal is stored via [DashboardLayout.bannerDismissed]
/// (Data tab) and SharedPreferences (Today tab).
final dataMaturityBannerDismissed = StateProvider<bool>((ref) => false);

/// Whether the "still building" reminder banner has been dismissed this session.
///
/// Resets on cold start — the banner will re-appear next session if data is
/// still insufficient. Permanent dismissal is handled separately via
/// [todayBannerPermanentlyDismissed].
final todayBannerSessionDismissed = StateProvider<bool>((ref) => false);

// ── Quick Log Loading ─────────────────────────────────────────────────────────

/// Whether a quick-log submission is currently in flight.
///
/// Set to `true` when the submit button is tapped and `false` when the
/// API call completes (success or failure).
final quickLogLoadingProvider = StateProvider<bool>((ref) => false);
