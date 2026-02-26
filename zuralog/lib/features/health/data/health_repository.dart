/// Health data repository -- abstraction over the native health bridge.
///
/// Wraps the low-level [HealthBridge] platform channel calls into a
/// clean, testable API. Works transparently on both iOS (HealthKit)
/// and Android (Health Connect). Manages authorization state
/// centrally and provides the public surface for UI and background
/// services.
///
/// Injected via Riverpod (`healthRepositoryProvider`).
library;

import 'package:zuralog/core/health/health_bridge.dart';

/// Repository for reading and writing health data.
///
/// All methods are safe to call on any platform -- they return
/// sensible defaults (empty lists, `false`, `0.0`) when the
/// native health platform is unavailable.
class HealthRepository {
  /// Creates a [HealthRepository] backed by the given [HealthBridge].
  ///
  /// The bridge is injected to allow swapping with a mock in tests.
  HealthRepository({required HealthBridge bridge}) : _bridge = bridge;

  final HealthBridge _bridge;

  /// Returns whether the health platform (Health Connect on Android,
  /// HealthKit on iOS) is available on this device.
  ///
  /// Returns:
  ///   `true` if the platform is available, `false` otherwise.
  Future<bool> isAvailable() => _bridge.isAvailable();

  /// Requests health data authorization from the user.
  ///
  /// On iOS, shows the HealthKit permission dialog.
  /// On Android, checks Health Connect permissions.
  ///
  /// Returns:
  ///   `true` if the user granted all required permissions, `false` otherwise.
  Future<bool> requestAuthorization() => _bridge.requestAuthorization();

  /// Passively checks if health permissions are currently granted.
  ///
  /// Does NOT show a permission dialog. Safe to call on app resume
  /// to verify permission state without user interaction.
  /// On iOS, uses a write-authorization proxy; may not reflect all permission
  /// types due to HealthKit privacy restrictions.
  ///
  /// Returns:
  ///   `true` if all required permissions are granted, `false` otherwise.
  Future<bool> checkPermissions() => _bridge.checkPermissions();

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

  /// Fetches total active calories burned for a specific [date] in kcal.
  ///
  /// Returns `null` if no data exists or the health platform is unavailable.
  Future<double?> getCaloriesBurned(DateTime date) =>
      _bridge.getCaloriesBurned(date);

  /// Fetches total dietary energy consumed (calories) for a specific [date] in kcal.
  ///
  /// Returns `null` if no data exists or the health platform is unavailable.
  Future<double?> getNutritionCalories(DateTime date) =>
      _bridge.getNutritionCalories(date);

  /// Fetches the most recent resting heart rate in beats-per-minute.
  ///
  /// Returns `null` if no data exists or the health platform is unavailable.
  Future<double?> getRestingHeartRate() => _bridge.getRestingHeartRate();

  /// Fetches the most recent heart rate variability in milliseconds.
  ///
  /// iOS surfaces SDNN; Android surfaces RMSSD. Both are in ms.
  /// Returns `null` if no data exists or the health platform is unavailable.
  Future<double?> getHRV() => _bridge.getHRV();

  /// Fetches the most recent VO2 max (cardio fitness level) in mL/kg/min.
  ///
  /// Returns `null` if no data exists or the health platform is unavailable.
  Future<double?> getCardioFitness() => _bridge.getCardioFitness();

  /// Fetches total walking + running distance for a specific [date] in meters.
  Future<double> getDistance(DateTime date) => _bridge.getDistance(date);

  /// Fetches total flights of stairs climbed for a specific [date].
  Future<double> getFlights(DateTime date) => _bridge.getFlights(date);

  /// Fetches the most recent body fat percentage (0-100).
  Future<double?> getBodyFat() => _bridge.getBodyFat();

  /// Fetches the most recent respiratory rate in breaths-per-minute.
  Future<double?> getRespiratoryRate() => _bridge.getRespiratoryRate();

  /// Fetches the most recent blood oxygen saturation (SpO2) percentage (0-100).
  Future<double?> getOxygenSaturation() => _bridge.getOxygenSaturation();

  /// Fetches the most recent instantaneous heart rate in beats-per-minute.
  Future<double?> getHeartRate() => _bridge.getHeartRate();

  /// Fetches the most recent blood pressure reading.
  ///
  /// Returns a Map with `systolic`, `diastolic`, and `date` (ms).
  Future<Map<String, dynamic>?> getBloodPressure() => _bridge.getBloodPressure();

  /// Starts native background observers for health data changes.
  ///
  /// On iOS, registers [HKObserverQuery] instances for all tracked data types.
  /// Changes detected from external apps (Apple Watch, CalAI, etc.) will
  /// eventually trigger a background sync to the Cloud Brain.
  ///
  /// Returns `true` if observers started successfully, `false` otherwise.
  Future<bool> startBackgroundObservers() => _bridge.startBackgroundObservers();

  /// Configures background sync credentials (auth token and API URL)
  /// in the native platform's secure storage (Keychain on iOS).
  ///
  /// This must be called before [startBackgroundObservers] so the
  /// native layer has the necessary credentials to sync data
  /// directly to the Cloud Brain.
  Future<bool> configureBackgroundSync({
    required String authToken,
    required String apiBaseUrl,
  }) => _bridge.configureBackgroundSync(
    authToken: authToken,
    apiBaseUrl: apiBaseUrl,
  );

  /// Manually triggers a native background sync for a specific [type].
  /// Used by FCM 'read_health' action.
  Future<bool> triggerSync(String type) => _bridge.triggerSync(type);

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
