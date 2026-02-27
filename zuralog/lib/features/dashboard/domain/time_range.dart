/// Zuralog Dashboard — Time Range Enum.
///
/// Defines the five selectable time windows that the user can switch between
/// on any metric detail graph. Each value carries its UI label and the number
/// of calendar days it spans, so charting code can compute date boundaries
/// without hard-coding magic numbers.
library;

/// A selectable time window for metric detail graphs.
///
/// The user taps one of the five segment-control pills ("D", "W", "M", "6M",
/// "Y") to switch between time windows. Charting code reads [days] to compute
/// the query date range and [label] for the segment pill text.
enum TimeRange {
  /// 24-hour view — 24 hourly data points.
  day(label: 'D', days: 1),

  /// 7-day view — 7 daily data points.
  week(label: 'W', days: 7),

  /// 30-day view — 30 daily data points.
  month(label: 'M', days: 30),

  /// 6-month view — 26 weekly aggregated data points.
  sixMonths(label: '6M', days: 180),

  /// 1-year view — 52 weekly aggregated data points.
  year(label: 'Y', days: 365);

  /// Creates a [TimeRange] value.
  const TimeRange({required this.label, required this.days});

  /// Short label rendered inside the segment-control pill (e.g. "D", "6M").
  final String label;

  /// Number of calendar days this time window spans.
  ///
  /// Used to compute the query start date: `DateTime.now().subtract(Duration(days: days))`.
  final int days;
}
