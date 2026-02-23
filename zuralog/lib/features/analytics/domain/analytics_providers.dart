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
/// **Native merge strategy (all six primary metrics):**
/// The Cloud Brain API is always the primary source. For every field that
/// the API returns as zero/null, the provider fans out a parallel native read
/// from Apple HealthKit / Google Health Connect so that on-device data
/// (Apple Watch, Pixel Watch, etc.) surfaces even when no OAuth integration
/// is connected or when the Cloud Brain has not yet ingested a value for today.
///
/// Merge priority: API value (non-zero / non-null) > native bridge value > zero/null.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/di/providers.dart';
import 'package:zuralog/features/analytics/domain/daily_summary.dart';
import 'package:zuralog/features/analytics/domain/weekly_trends.dart';
import 'package:zuralog/features/analytics/domain/dashboard_insight.dart';

/// Sums the total sleep duration from a list of raw native sleep segments.
///
/// Each segment map contains `startDate` and `endDate` as millisecond epoch
/// integers (iOS) or `startTime` / `endTime` (Android). Both variants are
/// handled. Returns total hours as a [double], capped at 24.
double _sumSleepHours(List<Map<String, dynamic>> segments) {
  var totalMs = 0.0;
  for (final seg in segments) {
    // iOS key names: startDate / endDate. Android key names: startTime / endTime.
    final start =
        (seg['startDate'] as num?)?.toDouble() ??
        (seg['startTime'] as num?)?.toDouble();
    final end =
        (seg['endDate'] as num?)?.toDouble() ??
        (seg['endTime'] as num?)?.toDouble();
    if (start != null && end != null && end > start) {
      totalMs += end - start;
    }
  }
  final hours = totalMs / (1000 * 60 * 60);
  return hours.clamp(0.0, 24.0);
}

/// Fetches today's [DailySummary] from the Cloud Brain API, then fills any
/// zero/null primary metric fields from the local native health store
/// (HealthKit on iOS / Health Connect on Android).
///
/// **Merge order (for each metric):**
/// 1. Use the Cloud Brain API value if it is non-zero (or non-null for
///    nullable fields).
/// 2. Otherwise fan out a parallel native bridge read and use that value.
/// 3. Fall back to the original API value (zero/null) if the native read
///    also returns nothing.
///
/// Uses [DateTime.now()] as the target date. Auto-disposes when no widget
/// is subscribed. Throws [DioException] as [AsyncError] only when the API
/// is unreachable AND no cached fallback exists.
final dailySummaryProvider = FutureProvider.autoDispose<DailySummary>((
  ref,
) async {
  final today = DateTime.now();

  // 1. Fetch primary data from the Cloud Brain API (cached for 15 min).
  final summary = await ref
      .watch(analyticsRepositoryProvider)
      .getDailySummary(today);

  // 2. Determine which fields need a native fallback read.
  final needsSteps = summary.steps == 0;
  final needsSleep = summary.sleepHours == 0.0;
  final needsCalBurned = summary.caloriesBurned == 0;
  final needsCalConsumed = summary.caloriesConsumed == 0;
  final needsRhr = summary.restingHeartRate == null;
  final needsHrv = summary.hrv == null;
  final needsCardio = summary.cardioFitnessLevel == null;

  final anyNativeReadNeeded =
      needsSteps ||
      needsSleep ||
      needsCalBurned ||
      needsCalConsumed ||
      needsRhr ||
      needsHrv ||
      needsCardio;

  if (!anyNativeReadNeeded) return summary;

  // 3. Fan out all required native reads in parallel.
  final healthRepo = ref.read(healthRepositoryProvider);

  // Sleep segments need to be fetched over a window (last night: yesterday
  // 6 pm → today 12 noon) to capture cross-midnight sessions.
  final sleepStart = today.subtract(const Duration(hours: 18));
  final sleepEnd = today.copyWith(hour: 12, minute: 0, second: 0);

  final results = await Future.wait<Object?>([
    needsSteps
        ? healthRepo.getSteps(today)
        : Future<double>.value(0),
    needsSleep
        ? healthRepo.getSleep(sleepStart, sleepEnd)
        : Future<List<Map<String, dynamic>>>.value([]),
    needsCalBurned
        ? healthRepo.getCaloriesBurned(today)
        : Future<double?>.value(null),
    needsCalConsumed
        ? healthRepo.getNutritionCalories(today)
        : Future<double?>.value(null),
    needsRhr
        ? healthRepo.getRestingHeartRate()
        : Future<double?>.value(null),
    needsHrv
        ? healthRepo.getHRV()
        : Future<double?>.value(null),
    needsCardio
        ? healthRepo.getCardioFitness()
        : Future<double?>.value(null),
  ]);

  final nativeSteps = needsSteps ? (results[0] as double?) : null;
  final nativeSleepSegments =
      needsSleep
          ? (results[1] as List<Map<String, dynamic>>?)
          : null;
  final nativeCalBurned = needsCalBurned ? (results[2] as double?) : null;
  final nativeCalConsumed = needsCalConsumed ? (results[3] as double?) : null;
  final nativeRhr = needsRhr ? (results[4] as double?) : null;
  final nativeHrv = needsHrv ? (results[5] as double?) : null;
  final nativeCardio = needsCardio ? (results[6] as double?) : null;

  // 4. Compute sleep hours from raw segments if fetched.
  final nativeSleepHours =
      nativeSleepSegments != null && nativeSleepSegments.isNotEmpty
          ? _sumSleepHours(nativeSleepSegments)
          : null;

  // 5. Merge — only replace a field when the native value is meaningful.
  return summary.copyWith(
    steps:
        (needsSteps && nativeSteps != null && nativeSteps > 0)
            ? nativeSteps.round()
            : null,
    sleepHours:
        (needsSleep && nativeSleepHours != null && nativeSleepHours > 0)
            ? nativeSleepHours
            : null,
    caloriesBurned:
        (needsCalBurned && nativeCalBurned != null && nativeCalBurned > 0)
            ? nativeCalBurned.round()
            : null,
    caloriesConsumed:
        (needsCalConsumed &&
                nativeCalConsumed != null &&
                nativeCalConsumed > 0)
            ? nativeCalConsumed.round()
            : null,
    restingHeartRate:
        (needsRhr && nativeRhr != null) ? nativeRhr.round() : null,
    hrv: (needsHrv && nativeHrv != null) ? nativeHrv : null,
    cardioFitnessLevel:
        (needsCardio && nativeCardio != null) ? nativeCardio : null,
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
