/// Zuralog Edge Agent — Daily Summary Domain Model.
///
/// Represents a single day's aggregated health data as returned by the
/// Cloud Brain analytics API (`/analytics/daily-summary`). Used by the
/// dashboard to display today's snapshot of steps, calories, workouts,
/// sleep, weight, and cardiovascular metrics (RHR, HRV, Cardio Fitness).
library;

/// Domain model for a single day's aggregated health data.
///
/// Maps to the `DailySummaryResponse` from the Cloud Brain analytics API.
/// All numeric fields default to zero when the backend omits them, keeping
/// the UI safe from null-related rendering errors.
///
/// Cardiovascular fields ([restingHeartRate], [hrv], [cardioFitnessLevel])
/// are nullable — they are omitted when the connected device has not yet
/// reported a reading for the day.
class DailySummary {
  /// Creates a [DailySummary] with the given health metrics for one day.
  ///
  /// [date] is an ISO-8601 date string (`YYYY-MM-DD`).
  /// [weightKg], [restingHeartRate], [hrv], and [cardioFitnessLevel] are
  /// optional — `null` when no value was recorded.
  const DailySummary({
    required this.date,
    required this.steps,
    required this.caloriesConsumed,
    required this.caloriesBurned,
    required this.workoutsCount,
    required this.sleepHours,
    this.weightKg,
    this.restingHeartRate,
    this.hrv,
    this.cardioFitnessLevel,
  });

  /// Deserializes a [DailySummary] from a JSON map.
  ///
  /// Missing or `null` numeric fields default to `0` (or `0.0` for doubles).
  /// Nullable fields ([weightKg], [restingHeartRate], [hrv],
  /// [cardioFitnessLevel]) remain `null` when absent in the payload.
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
      restingHeartRate: json['resting_heart_rate'] as int?,
      hrv: (json['hrv'] as num?)?.toDouble(),
      cardioFitnessLevel: (json['cardio_fitness_level'] as num?)?.toDouble(),
    );
  }

  /// Returns a copy of this [DailySummary] with selected fields replaced.
  ///
  /// Used by [dailySummaryProvider] to merge native bridge fallback values
  /// into an API-sourced summary without constructing a full new object.
  /// A field is only replaced when a non-null argument is supplied.
  DailySummary copyWith({
    String? date,
    int? steps,
    int? caloriesConsumed,
    int? caloriesBurned,
    int? workoutsCount,
    double? sleepHours,
    double? weightKg,
    int? restingHeartRate,
    double? hrv,
    double? cardioFitnessLevel,
  }) {
    return DailySummary(
      date: date ?? this.date,
      steps: steps ?? this.steps,
      caloriesConsumed: caloriesConsumed ?? this.caloriesConsumed,
      caloriesBurned: caloriesBurned ?? this.caloriesBurned,
      workoutsCount: workoutsCount ?? this.workoutsCount,
      sleepHours: sleepHours ?? this.sleepHours,
      weightKg: weightKg ?? this.weightKg,
      restingHeartRate: restingHeartRate ?? this.restingHeartRate,
      hrv: hrv ?? this.hrv,
      cardioFitnessLevel: cardioFitnessLevel ?? this.cardioFitnessLevel,
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

  /// Resting heart rate in beats per minute, or `null` if not available.
  ///
  /// Typically the lowest measured BPM over a 24-hour period.
  final int? restingHeartRate;

  /// Heart rate variability in milliseconds (RMSSD), or `null` if not available.
  ///
  /// Higher values generally indicate better cardiovascular readiness.
  final double? hrv;

  /// VO2 max estimate (cardio fitness level) in mL/kg/min, or `null` if not available.
  ///
  /// Derived from workout and heart rate data by the connected device.
  final double? cardioFitnessLevel;
}
