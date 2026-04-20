library;

import 'package:zuralog/features/heart/data/heart_repository_interface.dart';
import 'package:zuralog/features/heart/domain/heart_models.dart';
import 'package:zuralog/shared/all_data/all_data_models.dart';

class MockHeartRepository implements HeartRepositoryInterface {
  @override
  Future<HeartDaySummary> getHeartSummary() async {
    return HeartDaySummary(
      hasData: true,
      restingHr: 62.0,
      hrvMs: 48.0,
      avgHr: 74.0,
      respiratoryRate: 14.2,
      vo2Max: 41.5,
      spo2: 97.8,
      bpSystolic: 118.0,
      bpDiastolic: 76.0,
      restingHrVs7Day: -3.0,
      hrvVs7Day: 4.0,
      aiSummary: 'Your resting heart rate dropped 3 bpm below your weekly '
          'average — a strong sign your cardiovascular system is recovering '
          "well. HRV is also up 4 ms, which suggests yesterday's rest day "
          'paid off.',
      aiGeneratedAt: DateTime(2026, 4, 20, 5, 0),
      sources: const [
        HeartSource(
          name: 'Apple Health',
          icon: 'apple_health',
          brandColor: '#FF375F',
        ),
      ],
    );
  }

  @override
  Future<List<HeartTrendDay>> getHeartTrend(String range) async {
    final dayCount = const {'7d': 7, '30d': 30}[range] ?? 7;
    final today = DateTime.now();
    const baseRhr = 63.0;
    const baseHrv = 44.0;
    return List.generate(dayCount, (i) {
      final day = today.subtract(Duration(days: dayCount - 1 - i));
      final seed = i % 7;
      return HeartTrendDay(
        date: day.toIso8601String().substring(0, 10),
        restingHr: baseRhr + (seed % 3) - 1.0,
        hrvMs: baseHrv + (seed % 4) - 1.0,
        isToday: i == dayCount - 1,
      );
    });
  }

  @override
  Future<List<AllDataDay>> getHeartAllData(String range) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final dayCount =
        const {'7d': 7, '30d': 30, '3m': 90, '6m': 180, '1y': 365}[range] ??
            7;
    final today = DateTime.now();
    return List.generate(dayCount, (i) {
      final day = today.subtract(Duration(days: dayCount - 1 - i));
      final isToday = i == dayCount - 1;
      final seed = i % 7;
      return AllDataDay(
        date: day.toIso8601String().substring(0, 10),
        isToday: isToday,
        values: isToday
            ? {
                'resting_hr': null,
                'hrv': null,
                'avg_hr': null,
                'respiratory_rate': null,
                'vo2_max': null,
                'spo2': null,
                'bp_systolic': null,
                'bp_diastolic': null,
              }
            : {
                'resting_hr': 58.0 + seed * 2,
                'hrv': 40.0 + seed * 2,
                'avg_hr': 70.0 + seed.toDouble(),
                'respiratory_rate': 13.5 + seed * 0.2,
                'vo2_max': 41.0 + seed * 0.3,
                'spo2': 97.0 + (seed % 2 == 0 ? 0.5 : 0.0),
                'bp_systolic': 115.0 + seed.toDouble(),
                'bp_diastolic': 74.0 + (seed % 3).toDouble(),
              },
      );
    });
  }
}
