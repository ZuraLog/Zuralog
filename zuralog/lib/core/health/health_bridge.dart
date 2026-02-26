/// Dart wrapper for native health platform access via platform channels.
///
/// Communicates with the native health bridge on each platform:
/// - **iOS:** Swift `HealthKitBridge` via `AppDelegate`.
/// - **Android:** Kotlin `HealthConnectBridge` via `MainActivity`.
///
/// Both platforms share the same `MethodChannel('com.zuralog/health')`
/// and identical method names, so this class works transparently
/// on either OS.
///
/// **Usage:** Injected via Riverpod. Do NOT call directly from UI --
/// use `HealthRepository` instead.
library;

import 'package:flutter/services.dart';

/// Dart-side platform channel wrapper for native health data access.
///
/// Each method corresponds to a native handler registered in
/// `AppDelegate.swift` (iOS) or `MainActivity.kt` (Android).
/// Arguments are serialized as Maps with millisecondsSinceEpoch timestamps.
class HealthBridge {
  /// Creates a new [HealthBridge].
  ///
  /// Accepts an optional [MethodChannel] for testing.
  HealthBridge({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('com.zuralog/health');

  final MethodChannel _channel;

  /// Checks if the native health platform is available on this device.
  ///
  /// Returns `false` on unsupported devices, or if Health Connect
  /// is not installed (Android 13 and below).
  Future<bool> isAvailable() async {
    try {
      final result = await _channel.invokeMethod<bool>('isAvailable');
      return result ?? false;
    } on PlatformException catch (e) {
      assert(() {
        // ignore: avoid_print
        print('HealthBridge.isAvailable PlatformException: ${e.message}');
        return true;
      }());
      return false;
    }
  }

  /// Requests health data read/write authorization from the user.
  ///
  /// On iOS, shows the HealthKit permission dialog. On Android,
  /// checks if Health Connect permissions are granted.
  ///
  /// Returns `true` if authorization was successful.
  /// Throws nothing -- returns `false` on any failure.
  Future<bool> requestAuthorization() async {
    try {
      final result = await _channel.invokeMethod<bool>('requestAuthorization');
      return result ?? false;
    } on PlatformException catch (e) {
      assert(() {
        // ignore: avoid_print
        print(
          'HealthBridge.requestAuthorization PlatformException: ${e.message}',
        );
        return true;
      }());
      return false;
    }
  }

  /// Passively checks if health permissions are currently granted.
  ///
  /// Unlike [requestAuthorization], this does NOT show a permission dialog.
  /// On Android, checks if all Health Connect permissions are granted.
  /// On iOS, checks HealthKit write authorization without showing a dialog.
  ///
  /// Returns `true` if permissions are confirmed granted, `false` otherwise.
  /// Returns `false` on any error without throwing.
  /// Throws nothing — returns `false` on any failure.
  Future<bool> checkPermissions() async {
    try {
      final result = await _channel.invokeMethod<bool>('checkPermissions');
      return result ?? false;
    } on PlatformException catch (e) {
      assert(() {
        // ignore: avoid_print
        print('HealthBridge.checkPermissions PlatformException: ${e.message}');
        return true;
      }());
      return false;
    }
  }

  /// Fetches total step count for a specific [date].
  ///
  /// Returns `0.0` if no data exists or on error.
  Future<double> getSteps(DateTime date) async {
    try {
      final result = await _channel.invokeMethod<num>('getSteps', {
        'date': date.millisecondsSinceEpoch,
      });
      return result?.toDouble() ?? 0.0;
    } on PlatformException catch (e) {
      assert(() {
        // ignore: avoid_print
        print('HealthBridge.getSteps PlatformException: ${e.message}');
        return true;
      }());
      return 0.0;
    }
  }

  /// Fetches workouts within a date range.
  ///
  /// Returns an empty list if no workouts exist or on error.
  /// Each workout is a Map with keys:
  /// `id`, `activityType`, `duration`, `startDate`, `endDate`, `energyBurned`.
  Future<List<Map<String, dynamic>>> getWorkouts(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>('getWorkouts', {
        'startDate': startDate.millisecondsSinceEpoch,
        'endDate': endDate.millisecondsSinceEpoch,
      });
      if (result == null) return [];
      return result
          .cast<Map<dynamic, dynamic>>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    } on PlatformException catch (e) {
      assert(() {
        // ignore: avoid_print
        print('HealthBridge.getWorkouts PlatformException: ${e.message}');
        return true;
      }());
      return [];
    }
  }

  /// Fetches sleep analysis samples within a date range.
  ///
  /// Returns an empty list if no data exists or on error.
  /// Each sample is a Map with keys:
  /// `value` (HKCategoryValueSleepAnalysis), `startDate`, `endDate`, `source`.
  Future<List<Map<String, dynamic>>> getSleep(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>('getSleep', {
        'startDate': startDate.millisecondsSinceEpoch,
        'endDate': endDate.millisecondsSinceEpoch,
      });
      if (result == null) return [];
      return result
          .cast<Map<dynamic, dynamic>>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    } on PlatformException catch (e) {
      assert(() {
        // ignore: avoid_print
        print('HealthBridge.getSleep PlatformException: ${e.message}');
        return true;
      }());
      return [];
    }
  }

  /// Fetches the most recent body weight in kilograms.
  ///
  /// Returns `null` if no weight data exists.
  Future<double?> getWeight() async {
    try {
      final result = await _channel.invokeMethod<num>('getWeight');
      return result?.toDouble();
    } on PlatformException catch (e) {
      assert(() {
        // ignore: avoid_print
        print('HealthBridge.getWeight PlatformException: ${e.message}');
        return true;
      }());
      return null;
    }
  }

  /// Fetches total active calories burned for a specific [date] in kcal.
  ///
  /// Sums all active energy records for the midnight-to-midnight window.
  /// Returns `null` if no data exists or on error.
  Future<double?> getCaloriesBurned(DateTime date) async {
    try {
      final result = await _channel.invokeMethod<num>('getCaloriesBurned', {
        'date': date.millisecondsSinceEpoch,
      });
      return result?.toDouble();
    } on PlatformException catch (e) {
      assert(() {
        // ignore: avoid_print
        print('HealthBridge.getCaloriesBurned PlatformException: ${e.message}');
        return true;
      }());
      return null;
    }
  }

  /// Fetches total dietary energy (calories consumed) for a specific [date] in kcal.
  ///
  /// Sums all nutrition records for the midnight-to-midnight window.
  /// Returns `null` if no data exists or on error.
  Future<double?> getNutritionCalories(DateTime date) async {
    try {
      final result = await _channel.invokeMethod<num>('getNutrition', {
        'date': date.millisecondsSinceEpoch,
      });
      return result?.toDouble();
    } on PlatformException catch (e) {
      assert(() {
        // ignore: avoid_print
        print(
          'HealthBridge.getNutritionCalories PlatformException: ${e.message}',
        );
        return true;
      }());
      return null;
    }
  }

  /// Fetches the most recent resting heart rate in beats-per-minute.
  ///
  /// Returns `null` if no data exists or on error.
  Future<double?> getRestingHeartRate() async {
    try {
      final result = await _channel.invokeMethod<num>('getRestingHeartRate');
      return result?.toDouble();
    } on PlatformException catch (e) {
      assert(() {
        // ignore: avoid_print
        print(
          'HealthBridge.getRestingHeartRate PlatformException: ${e.message}',
        );
        return true;
      }());
      return null;
    }
  }

  /// Fetches the most recent heart rate variability in milliseconds.
  ///
  /// iOS uses SDNN; Android uses RMSSD. Both are surfaced in ms.
  /// Returns `null` if no data exists or on error.
  Future<double?> getHRV() async {
    try {
      final result = await _channel.invokeMethod<num>('getHRV');
      return result?.toDouble();
    } on PlatformException catch (e) {
      assert(() {
        // ignore: avoid_print
        print('HealthBridge.getHRV PlatformException: ${e.message}');
        return true;
      }());
      return null;
    }
  }

  /// Fetches the most recent VO2 max (cardio fitness) in mL/kg/min.
  ///
  /// Returns `null` if no data exists or on error.
  Future<double?> getCardioFitness() async {
    try {
      final result = await _channel.invokeMethod<num>('getCardioFitness');
      return result?.toDouble();
    } on PlatformException catch (e) {
      assert(() {
        // ignore: avoid_print
        print('HealthBridge.getCardioFitness PlatformException: ${e.message}');
        return true;
      }());
      return null;
    }
  }

  /// Writes a workout entry to HealthKit.
  ///
  /// - [activityType]: e.g., "running", "cycling", "walking".
  /// - [startDate]: Workout start time.
  /// - [endDate]: Workout end time.
  /// - [energyBurned]: Calories burned (kcal).
  ///
  /// Returns `true` on success, `false` on failure.
  Future<bool> writeWorkout({
    required String activityType,
    required DateTime startDate,
    required DateTime endDate,
    required double energyBurned,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('writeWorkout', {
        'activityType': activityType,
        'startDate': startDate.millisecondsSinceEpoch,
        'endDate': endDate.millisecondsSinceEpoch,
        'energyBurned': energyBurned,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      assert(() {
        // ignore: avoid_print
        print('HealthBridge.writeWorkout PlatformException: ${e.message}');
        return true;
      }());
      return false;
    }
  }

  /// Writes a dietary energy (calorie) entry to HealthKit.
  ///
  /// - [calories]: Kilocalories consumed.
  /// - [date]: The date/time of the meal.
  ///
  /// Returns `true` on success, `false` on failure.
  Future<bool> writeNutrition({
    required double calories,
    required DateTime date,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('writeNutrition', {
        'calories': calories,
        'date': date.millisecondsSinceEpoch,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      assert(() {
        // ignore: avoid_print
        print('HealthBridge.writeNutrition PlatformException: ${e.message}');
        return true;
      }());
      return false;
    }
  }

  /// Writes a body mass entry to HealthKit.
  ///
  /// - [weightKg]: Weight in kilograms.
  /// - [date]: The date of the measurement.
  ///
  /// Returns `true` on success, `false` on failure.
  Future<bool> writeWeight({
    required double weightKg,
    required DateTime date,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('writeWeight', {
        'weightKg': weightKg,
        'date': date.millisecondsSinceEpoch,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      assert(() {
        // ignore: avoid_print
        print('HealthBridge.writeWeight PlatformException: ${e.message}');
        return true;
      }());
      return false;
    }
  }

  /// Stores the JWT auth token and Cloud Brain API base URL in the iOS
  /// Keychain so that native background sync code (running in
  /// HKObserverQuery callbacks outside the Flutter engine) can
  /// authenticate directly with the Cloud Brain.
  ///
  /// Must be called after successful Apple Health authorization and
  /// before [startBackgroundObservers] — the native observers need
  /// the credentials to be present when they fire.
  ///
  /// - [authToken]: The current JWT bearer token for the logged-in user.
  /// - [apiBaseUrl]: The Cloud Brain base URL (e.g. https://api.zuralog.com).
  ///
  /// Returns `true` if the credentials were saved successfully.
  Future<bool> configureBackgroundSync({
    required String authToken,
    required String apiBaseUrl,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'configureBackgroundSync',
        {'auth_token': authToken, 'api_base_url': apiBaseUrl},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      assert(() {
        // ignore: avoid_print
        print(
          'HealthBridge.configureBackgroundSync PlatformException: ${e.message}',
        );
        return true;
      }());
      return false;
    }
  }

  /// Starts background observers for health data changes.
  ///
  /// When HealthKit detects new data (e.g., from Apple Watch),
  /// the native layer will be notified. In Phase 1.10, this
  /// will trigger background sync to the Cloud Brain.
  ///
  /// Returns `true` if observers started successfully.
  Future<bool> startBackgroundObservers() async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'startBackgroundObservers',
      );
      return result ?? false;
    } on PlatformException catch (e) {
      assert(() {
        // ignore: avoid_print
        print(
          'HealthBridge.startBackgroundObservers PlatformException: ${e.message}',
        );
        return true;
      }());
      return false;
    }
  }
}
