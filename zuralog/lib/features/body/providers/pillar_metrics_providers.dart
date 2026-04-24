library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuralog/core/di/providers.dart';

const _useMock = bool.fromEnvironment('USE_MOCK_DATA', defaultValue: false);

class PillarMetrics {
  const PillarMetrics({
    this.caloriesKcal,
    this.caloriesPrevKcal,
    this.stepsToday,
    this.stepsPrev,
    this.sleepHours,
    this.sleepHoursPrev,
    this.avgHrBpm,
    this.avgHrBpmPrev,
  });

  final int? caloriesKcal;
  final int? caloriesPrevKcal;
  final int? stepsToday;
  final int? stepsPrev;
  final double? sleepHours;
  final double? sleepHoursPrev;
  final int? avgHrBpm;
  final int? avgHrBpmPrev;

  static const PillarMetrics empty = PillarMetrics();
}

const PillarMetrics _mockMetrics = PillarMetrics(
  caloriesKcal: 1240,
  caloriesPrevKcal: 1800,
  stepsToday: 6432,
  stepsPrev: 5200,
  sleepHours: 7.7,
  sleepHoursPrev: 7.4,
  avgHrBpm: 78,
  avgHrBpmPrev: 74,
);

final pillarMetricsProvider = FutureProvider<PillarMetrics>((ref) async {
  if (_useMock) return _mockMetrics;

  final client = ref.watch(apiClientProvider);
  try {
    final response = await client.get(
      '/api/v1/metrics/latest',
      queryParameters: {
        'types': 'calories,steps,sleep_duration,heart_rate_avg',
      },
    );
    final data = response.data as Map<String, dynamic>?;
    final metrics = (data?['metrics'] as List<dynamic>?) ?? [];
    int? calories, steps, hr;
    double? sleep;
    for (final m in metrics) {
      final map = m as Map<String, dynamic>;
      final type = map['metric_type'] as String;
      final value = (map['value'] as num).toDouble();
      switch (type) {
        case 'calories':
          calories = value.round();
        case 'steps':
          steps = value.round();
        case 'sleep_duration':
          sleep = value;
        case 'heart_rate_avg':
          hr = value.round();
      }
    }
    return PillarMetrics(
      caloriesKcal: calories,
      stepsToday: steps,
      sleepHours: sleep,
      avgHrBpm: hr,
    );
  } catch (_) {
    return PillarMetrics.empty;
  }
});
