library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuralog/core/di/providers.dart';
import 'package:zuralog/features/sleep/data/api_sleep_repository.dart';
import 'package:zuralog/features/sleep/data/mock_sleep_repository.dart';
import 'package:zuralog/features/sleep/data/sleep_repository_interface.dart';
import 'package:zuralog/features/sleep/domain/sleep_models.dart';

const _useMock = bool.fromEnvironment('USE_MOCK_DATA', defaultValue: false);

final sleepRepositoryProvider = Provider<SleepRepositoryInterface>((ref) {
  if (_useMock) return MockSleepRepository();
  return ApiSleepRepository(apiClient: ref.read(apiClientProvider));
});

final sleepDaySummaryProvider = FutureProvider<SleepDaySummary>((ref) async {
  try {
    return await ref.read(sleepRepositoryProvider).getSleepSummary();
  } catch (_) {
    return SleepDaySummary.empty;
  }
});

final sleepTrendProvider =
    FutureProvider.family<List<SleepTrendDay>, String>((ref, range) async {
  try {
    return await ref.read(sleepRepositoryProvider).getSleepTrend(range);
  } catch (_) {
    return const [];
  }
});

/// Today's sleep quality normalized against the user's 28-day baseline (0–100).
///
/// TODO(body): wire to HealthKit/Health Connect sleep stages. Null = no data.
final sleepQualityNormalizedProvider =
    FutureProvider<double?>((ref) async => null);

/// User's 7-day rolling average readiness score for delta computation.
///
/// TODO(body): aggregate from stored daily readiness history. Null = no history.
final readinessSevenDayAverageProvider =
    FutureProvider<double?>((ref) async => null);
