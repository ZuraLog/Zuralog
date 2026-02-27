/// Zuralog Dashboard — Metric Stats Model.
///
/// Holds pre-computed aggregate statistics for a health metric over a given
/// [TimeRange]. These numbers populate the summary row below a detail graph
/// (average, min, max, total) and drive the trend arrow / percentage badge.
library;

/// Pre-computed aggregate statistics for a metric over a time window.
///
/// Populated by the data layer after fetching and aggregating raw data
/// points. The UI uses these to render the stats strip below the graph
/// and to show a trend badge (e.g. "+12 %" or "-5 %").
///
/// Example usage:
/// ```dart
/// final stats = MetricStats(
///   average: 7832,
///   min: 3200,
///   max: 14500,
///   total: 54824,
///   trendPercent: 12.4,
/// );
/// ```
class MetricStats {
  /// Creates a [MetricStats] instance.
  ///
  /// All values are required and must represent the same time window.
  ///
  /// [average] — arithmetic mean of all data points in the period.
  ///
  /// [min] — lowest single reading in the period.
  ///
  /// [max] — highest single reading in the period.
  ///
  /// [total] — sum of all readings in the period (meaningful for
  /// cumulative metrics like steps; may equal [average] for non-cumulative).
  ///
  /// [trendPercent] — percentage change compared with the preceding
  /// period of equal length. Positive means increase, negative means decrease.
  const MetricStats({
    required this.average,
    required this.min,
    required this.max,
    required this.total,
    required this.trendPercent,
  });

  /// Arithmetic mean across all data points in the time window.
  final double average;

  /// Lowest single reading in the time window.
  final double min;

  /// Highest single reading in the time window.
  final double max;

  /// Sum of all readings in the time window.
  ///
  /// For cumulative metrics (steps, calories) this is the meaningful total.
  /// For non-cumulative metrics (weight, heart rate) this is usually equal
  /// to [average] and can be ignored by the UI.
  final double total;

  /// Percentage change relative to the previous period of equal length.
  ///
  /// Positive values indicate an upward trend, negative values a downward
  /// trend. A value of `0.0` means no change.
  final double trendPercent;

  @override
  String toString() =>
      'MetricStats(avg: $average, min: $min, max: $max, '
      'total: $total, trend: $trendPercent%)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MetricStats &&
          runtimeType == other.runtimeType &&
          average == other.average &&
          min == other.min &&
          max == other.max &&
          total == other.total &&
          trendPercent == other.trendPercent;

  @override
  int get hashCode => Object.hash(average, min, max, total, trendPercent);
}
