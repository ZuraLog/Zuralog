/// Health data repository -- abstraction over the native HealthKit bridge.
///
/// Wraps the low-level [HealthBridge] platform channel calls into a
/// clean, testable API. Manages authorization state centrally and
/// provides the public surface for UI and background services.
///
/// Injected via Riverpod (`healthRepositoryProvider`).
library;

import 'package:life_logger/core/health/health_bridge.dart';

/// Repository for reading and writing health data.
///
/// All methods are safe to call even if HealthKit is unavailable --
/// they return sensible defaults (empty lists, `false`, `0.0`).
class HealthRepository {
  /// Creates a [HealthRepository] backed by the given [HealthBridge].
  ///
  /// The bridge is injected to allow swapping with a mock in tests.
  HealthRepository({required HealthBridge bridge}) : _bridge = bridge;

  final HealthBridge _bridge;

  /// Whether HealthKit is available on this device.
  ///
  /// Returns `false` on Android and non-supported iOS devices.
  Future<bool> get isAvailable => _bridge.isAvailable();

  /// Requests HealthKit authorization from the user.
  ///
  /// Shows the iOS system permission dialog. Returns `true` if the
  /// dialog was presented successfully (does NOT mean all types
  /// were granted -- HealthKit hides per-type denial).
  Future<bool> requestAuthorization() => _bridge.requestAuthorization();

  // -- Read Methods --

  /// Fetches total step count for a specific [date].
  ///
  /// Returns `0.0` if no data exists or HealthKit is unavailable.
  Future<double> getSteps(DateTime date) => _bridge.getSteps(date);

  /// Fetches workouts within a date range.
  ///
  /// Returns an empty list if no workouts exist.
  Future<List<Map<String, dynamic>>> getWorkouts(
    DateTime startDate,
    DateTime endDate,
  ) => _bridge.getWorkouts(startDate, endDate);

  /// Fetches sleep analysis within a date range.
  ///
  /// Returns an empty list if no sleep data exists.
  Future<List<Map<String, dynamic>>> getSleep(
    DateTime startDate,
    DateTime endDate,
  ) => _bridge.getSleep(startDate, endDate);

  /// Fetches the most recent body weight in kilograms.
  ///
  /// Returns `null` if no weight data exists.
  Future<double?> getWeight() => _bridge.getWeight();

  // -- Write Methods --

  /// Writes a workout entry to HealthKit.
  ///
  /// Returns `true` on success, `false` on failure.
  Future<bool> writeWorkout({
    required String activityType,
    required DateTime startDate,
    required DateTime endDate,
    required double energyBurned,
  }) => _bridge.writeWorkout(
    activityType: activityType,
    startDate: startDate,
    endDate: endDate,
    energyBurned: energyBurned,
  );

  /// Writes a nutrition (calorie) entry to HealthKit.
  ///
  /// Returns `true` on success, `false` on failure.
  Future<bool> writeNutrition({
    required double calories,
    required DateTime date,
  }) => _bridge.writeNutrition(calories: calories, date: date);

  /// Writes a body mass entry to HealthKit.
  ///
  /// Returns `true` on success, `false` on failure.
  Future<bool> writeWeight({
    required double weightKg,
    required DateTime date,
  }) => _bridge.writeWeight(weightKg: weightKg, date: date);
}
