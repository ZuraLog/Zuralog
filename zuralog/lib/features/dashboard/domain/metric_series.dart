/// Zuralog Dashboard — Metric Series Model.
///
/// Bundles a complete time-series for one health metric: the raw data points,
/// the selected [TimeRange], pre-computed aggregate [MetricStats], and the
/// metric identifier. This is the primary data structure consumed by the
/// graph widgets on the metric detail screen.
library;

import 'package:zuralog/features/dashboard/domain/metric_data_point.dart';
import 'package:zuralog/features/dashboard/domain/metric_stats.dart';
import 'package:zuralog/features/dashboard/domain/time_range.dart';

/// A complete time-series dataset for a single health metric.
///
/// Combines the ordered list of [MetricDataPoint]s with the [TimeRange]
/// they span and the pre-computed [MetricStats] aggregates. The charting
/// layer receives a [MetricSeries] and renders the appropriate graph type
/// without needing to re-aggregate data.
///
/// Example:
/// ```dart
/// final series = MetricSeries(
///   metricId: 'steps',
///   timeRange: TimeRange.week,
///   dataPoints: [...],
///   stats: MetricStats(average: 8000, min: 3200, max: 14500, total: 56000, trendPercent: 12.4),
/// );
/// ```
class MetricSeries {
  /// Creates a [MetricSeries].
  ///
  /// [metricId] — the unique identifier matching [HealthMetric.id].
  ///
  /// [timeRange] — the time window these data points span.
  ///
  /// [dataPoints] — chronologically ordered measurements. May be empty if
  /// no data is available for the selected window.
  ///
  /// [stats] — pre-computed aggregates over [dataPoints].
  const MetricSeries({
    required this.metricId,
    required this.timeRange,
    required this.dataPoints,
    required this.stats,
  });

  /// Unique metric identifier (matches [HealthMetric.id], e.g. `'steps'`).
  final String metricId;

  /// The time window this series covers.
  final TimeRange timeRange;

  /// Chronologically ordered data points within [timeRange].
  ///
  /// May be empty when no data has been recorded for the selected period.
  final List<MetricDataPoint> dataPoints;

  /// Pre-computed aggregate statistics over [dataPoints].
  final MetricStats stats;

  @override
  String toString() =>
      'MetricSeries(metricId: $metricId, timeRange: ${timeRange.label}, '
      'points: ${dataPoints.length}, stats: $stats)';
}
