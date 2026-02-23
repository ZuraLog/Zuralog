/// Zuralog Edge Agent — Analytics Riverpod Providers.
///
/// Bridges the [AnalyticsRepository] to the UI layer via Riverpod
/// [FutureProvider]s. Each provider fetches a specific analytics dataset
/// and exposes it as an [AsyncValue] for straightforward loading/error/data
/// handling in widgets.
///
/// **Providers:**
/// - [dailySummaryProvider] — Today's aggregated health metrics.
/// - [weeklyTrendsProvider] — Seven-day trend data for sparkline charts.
/// - [dashboardInsightProvider] — AI-generated natural-language insight.
///
/// All providers are [autoDispose] so they release resources automatically
/// when no widget is listening, which is important for background data that
/// should not be held indefinitely in memory.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/di/providers.dart';
import 'package:zuralog/features/analytics/domain/daily_summary.dart';
import 'package:zuralog/features/analytics/domain/weekly_trends.dart';
import 'package:zuralog/features/analytics/domain/dashboard_insight.dart';

/// Fetches today's [DailySummary] from the analytics repository.
///
/// Uses [DateTime.now()] as the target date so the data always reflects
/// the current calendar day. Auto-disposes when no widget is subscribed.
///
/// Throws a [DioException] if the backend is unreachable and no cached
/// data is available (the repository manages the cache internally).
final dailySummaryProvider = FutureProvider.autoDispose<DailySummary>((ref) {
  return ref.read(analyticsRepositoryProvider).getDailySummary(DateTime.now());
});

/// Fetches the most recent 7-day [WeeklyTrends] from the analytics repository.
///
/// The backend determines the date range (trailing 7 days from today).
/// Auto-disposes when no widget is subscribed.
///
/// Throws a [DioException] on network failure.
final weeklyTrendsProvider = FutureProvider.autoDispose<WeeklyTrends>((ref) {
  return ref.read(analyticsRepositoryProvider).getWeeklyTrends();
});

/// Fetches the AI-generated [DashboardInsight] from the analytics repository.
///
/// The insight is a natural-language summary of recent health trends,
/// produced by the Cloud Brain AI layer. Auto-disposes when no widget
/// is subscribed.
///
/// Throws a [DioException] on network failure.
final dashboardInsightProvider =
    FutureProvider.autoDispose<DashboardInsight>((ref) {
  return ref.read(analyticsRepositoryProvider).getDashboardInsight();
});
