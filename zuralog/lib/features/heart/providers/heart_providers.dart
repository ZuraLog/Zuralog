library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuralog/core/di/providers.dart';
import 'package:zuralog/features/heart/data/api_heart_repository.dart';
import 'package:zuralog/features/heart/data/heart_repository_interface.dart';
import 'package:zuralog/features/heart/data/mock_heart_repository.dart';
import 'package:zuralog/features/heart/domain/heart_models.dart';

const _useMock = bool.fromEnvironment('USE_MOCK_DATA', defaultValue: false);

final heartRepositoryProvider = Provider<HeartRepositoryInterface>((ref) {
  if (_useMock) return MockHeartRepository();
  return ApiHeartRepository(apiClient: ref.read(apiClientProvider));
});

final heartDaySummaryProvider = FutureProvider<HeartDaySummary>((ref) async {
  try {
    return await ref.read(heartRepositoryProvider).getHeartSummary();
  } catch (_) {
    return HeartDaySummary.empty;
  }
});

final heartTrendProvider =
    FutureProvider.family<List<HeartTrendDay>, String>((ref, range) async {
  try {
    return await ref.read(heartRepositoryProvider).getHeartTrend(range);
  } catch (_) {
    return const [];
  }
});

/// Today's HRV normalized against the user's 28-day baseline (0–100).
///
/// TODO(body): wire to HealthKit/Health Connect HRV samples. Null = no data.
final hrvBaselineNormalizedProvider =
    FutureProvider<double?>((ref) async => null);

/// Today's resting heart rate normalized against the user's 28-day baseline (0–100).
///
/// TODO(body): wire to HealthKit/Health Connect RHR samples. Null = no data.
final rhrBaselineNormalizedProvider =
    FutureProvider<double?>((ref) async => null);

/// Today's HRV reading + delta vs 14-day baseline. Null = no data.
class HrvTodayReading {
  const HrvTodayReading({required this.valueMs, required this.deltaPct});
  final int valueMs;
  final int? deltaPct;
}

/// TODO(body): wire to the real HRV source. Null = no data today.
final hrvTodayProvider =
    FutureProvider<HrvTodayReading?>((ref) async => null);

/// Today's resting HR + delta vs 14-day baseline. Null = no data.
class RhrTodayReading {
  const RhrTodayReading({required this.valueBpm, required this.deltaBpm});
  final int valueBpm;
  final int? deltaBpm;
}

/// TODO(body): wire to the real RHR source. Null = no data today.
final rhrTodayProvider =
    FutureProvider<RhrTodayReading?>((ref) async => null);
