/// Zuralog Edge Agent — Daily Summary Domain Model.
///
/// Represents a single day's aggregated health data as returned by the
/// Cloud Brain analytics API (`/analytics/daily-summary`). Used by the
/// dashboard to display today's snapshot of steps, calories, workouts,
/// sleep, and weight.
library;

/// Domain model for a single day's aggregated health data.
///
/// Maps to the `DailySummaryResponse` from the Cloud Brain analytics API.
/// All numeric fields default to zero when the backend omits them, keeping
/// the UI safe from null-related rendering errors.
class DailySummary {
  /// Creates a [DailySummary] with the given health metrics for one day.
  ///
  /// [date] is an ISO-8601 date string (`YYYY-MM-DD`).
  /// [weightKg] is optional — `null` when no weight was recorded.
  const DailySummary({
    required this.date,
    required this.steps,
    required this.caloriesConsumed,
    required this.caloriesBurned,
    required this.workoutsCount,
    required this.sleepHours,
    this.weightKg,
  });

  /// Deserializes a [DailySummary] from a JSON map.
  ///
  /// Missing or `null` numeric fields default to `0` (or `0.0` for doubles).
  /// [weightKg] remains `null` when absent in the payload.
  ///
  /// Throws a [TypeError] if [json] does not contain a `date` key of type
  /// [String].
  factory DailySummary.fromJson(Map<String, dynamic> json) {
    return DailySummary(
      date: json['date'] as String,
      steps: json['steps'] as int? ?? 0,
      caloriesConsumed: json['calories_consumed'] as int? ?? 0,
      caloriesBurned: json['calories_burned'] as int? ?? 0,
      workoutsCount: json['workouts_count'] as int? ?? 0,
      sleepHours: (json['sleep_hours'] as num?)?.toDouble() ?? 0.0,
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
    );
  }

  /// ISO-8601 date string (`YYYY-MM-DD`) this summary represents.
  final String date;

  /// Total step count for the day.
  final int steps;

  /// Total dietary calories consumed (kcal).
  final int caloriesConsumed;

  /// Total active calories burned (kcal).
  final int caloriesBurned;

  /// Number of distinct workouts recorded.
  final int workoutsCount;

  /// Total hours of sleep recorded.
  final double sleepHours;

  /// Most recent body weight in kilograms, or `null` if not recorded.
  final double? weightKg;
}
