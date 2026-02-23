/// Zuralog Edge Agent — Weekly Trends Domain Model.
///
/// Represents seven consecutive days of health metrics for trend-line
/// charts on the dashboard. Returned by the Cloud Brain analytics API
/// endpoint `/analytics/weekly-trends`.
library;

/// Domain model for 7-day trend chart data.
///
/// Each list has the same length (7 entries) with index 0 representing the
/// oldest day and index 6 the most recent. The [dates] list provides the
/// corresponding ISO-8601 date strings for labeling the x-axis.
class WeeklyTrends {
  /// Creates a [WeeklyTrends] with parallel lists of daily metric values.
  ///
  /// All lists must have the same length.
  const WeeklyTrends({
    required this.dates,
    required this.steps,
    required this.caloriesIn,
    required this.caloriesOut,
    required this.sleepHours,
  });

  /// Deserializes a [WeeklyTrends] from a JSON map.
  ///
  /// Expects top-level keys `dates`, `steps`, `calories_in`, `calories_out`,
  /// and `sleep_hours`, each containing a JSON array.
  ///
  /// Throws a [TypeError] if any expected key is missing or has an
  /// incompatible type.
  factory WeeklyTrends.fromJson(Map<String, dynamic> json) {
    return WeeklyTrends(
      dates: List<String>.from(json['dates'] as List<dynamic>),
      steps: List<int>.from(json['steps'] as List<dynamic>),
      caloriesIn: List<int>.from(json['calories_in'] as List<dynamic>),
      caloriesOut: List<int>.from(json['calories_out'] as List<dynamic>),
      sleepHours: (json['sleep_hours'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList(),
    );
  }

  /// ISO-8601 date strings (`YYYY-MM-DD`) for each day in the trend window.
  final List<String> dates;

  /// Daily step totals corresponding to [dates].
  final List<int> steps;

  /// Daily calories consumed (kcal) corresponding to [dates].
  final List<int> caloriesIn;

  /// Daily calories burned (kcal) corresponding to [dates].
  final List<int> caloriesOut;

  /// Daily sleep durations in hours corresponding to [dates].
  final List<double> sleepHours;
}
