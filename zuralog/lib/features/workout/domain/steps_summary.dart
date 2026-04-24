library;

import 'package:zuralog/features/data/domain/data_models.dart' show MetricDataPoint;

class StepsSummary {
  const StepsSummary({
    required this.dataPoints,
    required this.todayCount,
    required this.weekAverage,
    required this.bestThisWeek,
    required this.consecutiveDays,
    required this.smartTarget,
    this.sourceName,
  });

  /// 7 daily data points, oldest → newest. May have fewer if data is sparse.
  final List<MetricDataPoint> dataPoints;

  /// Today's step count (last data point's value, rounded).
  final int todayCount;

  /// Mean of all days in the window that had at least 1 step.
  final double weekAverage;

  /// Highest single-day count in the 7-day window.
  final int bestThisWeek;

  /// How many consecutive days ending today had steps > 0.
  final int consecutiveDays;

  /// Adaptive sweet-spot target: weekAverage × 1.05, rounded to nearest 100.
  /// 0 when insufficient history.
  final int smartTarget;

  /// Human-readable source name (e.g. "Apple Watch", "iPhone").
  final String? sourceName;

  static const empty = StepsSummary(
    dataPoints: [],
    todayCount: 0,
    weekAverage: 0,
    bestThisWeek: 0,
    consecutiveDays: 0,
    smartTarget: 0,
  );
}
