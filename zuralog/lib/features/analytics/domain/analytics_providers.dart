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
///
/// **Cardio metric merge strategy:**
/// For [restingHeartRate], [hrv], and [cardioFitnessLevel], the Cloud Brain
/// API is the primary source (it aggregates data from Oura, Garmin, etc.).
/// If the API returns null for any of these, the provider falls back to a
/// direct native read from Apple HealthKit / Google Health Connect so that
/// Apple Watch and Pixel Watch data is shown even when no OAuth integration
/// is connected.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/di/providers.dart';
import 'package:zuralog/features/analytics/domain/daily_summary.dart';
import 'package:zuralog/features/analytics/domain/weekly_trends.dart';
import 'package:zuralog/features/analytics/domain/dashboard_insight.dart';

/// Fetches today's [DailySummary] from the analytics repository, then fills
/// any null cardiovascular fields (RHR, HRV, VO2 max) from the local native
/// health store (HealthKit on iOS / Health Connect on Android).
///
/// Uses [DateTime.now()] as the target date so the data always reflects
/// the current calendar day. Auto-disposes when no widget is subscribed.
///
/// Exposes a [DioException] as [AsyncError] if the backend is unreachable
/// and no cached data is available (the repository manages the cache internally).
final dailySummaryProvider = FutureProvider.autoDispose<DailySummary>((
  ref,
) async {
  // 1. Fetch primary data from the Cloud Brain API.
  final summary = await ref
      .watch(analyticsRepositoryProvider)
      .getDailySummary(DateTime.now());

  // 2. If all three cardio metrics are already present, skip the native read.
  if (summary.restingHeartRate != null &&
      summary.hrv != null &&
      summary.cardioFitnessLevel != null) {
    return summary;
  }

  // 3. Read the missing metrics from the device health store as a fallback.
  final healthRepo = ref.read(healthRepositoryProvider);

  final results = await Future.wait([
    summary.restingHeartRate == null
        ? healthRepo.getRestingHeartRate()
        : Future.value(null),
    summary.hrv == null ? healthRepo.getHRV() : Future.value(null),
    summary.cardioFitnessLevel == null
        ? healthRepo.getCardioFitness()
        : Future.value(null),
  ]);

  final nativeRhr = results[0];
  final nativeHrv = results[1];
  final nativeCardio = results[2];

  // 4. Return the merged summary only if at least one native value was found.
  if (nativeRhr == null && nativeHrv == null && nativeCardio == null) {
    return summary;
  }

  return DailySummary(
    date: summary.date,
    steps: summary.steps,
    caloriesConsumed: summary.caloriesConsumed,
    caloriesBurned: summary.caloriesBurned,
    workoutsCount: summary.workoutsCount,
    sleepHours: summary.sleepHours,
    weightKg: summary.weightKg,
    restingHeartRate:
        summary.restingHeartRate ?? nativeRhr?.round(),
    hrv: summary.hrv ?? nativeHrv,
    cardioFitnessLevel: summary.cardioFitnessLevel ?? nativeCardio,
  );
});

/// Fetches the most recent 7-day [WeeklyTrends] from the analytics repository.
///
/// The backend determines the date range (trailing 7 days from today).
/// Auto-disposes when no widget is subscribed.
///
/// Exposes a [DioException] as [AsyncError] if the backend is unreachable.
final weeklyTrendsProvider = FutureProvider.autoDispose<WeeklyTrends>((ref) {
  return ref.watch(analyticsRepositoryProvider).getWeeklyTrends();
});

/// Fetches the AI-generated [DashboardInsight] from the analytics repository.
///
/// The insight is a natural-language summary of recent health trends,
/// produced by the Cloud Brain AI layer. Auto-disposes when no widget
/// is subscribed.
///
/// Exposes a [DioException] as [AsyncError] if the backend is unreachable.
final dashboardInsightProvider =
    FutureProvider.autoDispose<DashboardInsight>((ref) {
  return ref.watch(analyticsRepositoryProvider).getDashboardInsight();
});
