/// Zuralog Edge Agent -- iOS Application Delegate.
///
/// Registers the HealthKit platform channel (`com.zuralog/health`)
/// that bridges Flutter Dart calls to the native `HealthKitBridge`.
///
/// Uses Scene-based lifecycle with `FlutterImplicitEngineBridge`.

import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

    private let healthKitBridge = HealthKitBridge()

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

        // Register HealthKit platform channel.
        // Use engine.binaryMessenger directly (not viewController) to avoid
        // force-unwrap crashes during background delivery wakeups.
        let healthChannel = FlutterMethodChannel(
            name: "com.zuralog/health",
            binaryMessenger: engineBridge.applicationRegistrar.messenger()
        )

        healthChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            guard let self = self else {
                result(FlutterError(code: "BRIDGE_GONE", message: "HealthKit bridge deallocated", details: nil))
                return
            }
            self.handleMethodCall(call: call, result: result)
        }
    }

    // MARK: - Timestamp Helpers

    /// Safely extracts a millisecond epoch timestamp from a platform channel argument.
    ///
    /// Flutter's `StandardMethodCodec` serializes Dart `int` values as `NSNumber`,
    /// which may bridge to `Int`, `Int64`, or `Double` depending on magnitude.
    /// This helper handles all representations safely.
    ///
    /// - Parameter value: The raw argument value from the method channel.
    /// - Returns: A `Date` if the value is a valid numeric timestamp, or `nil`.
    private func dateFromMs(_ value: Any?) -> Date? {
        guard let number = value as? NSNumber else { return nil }
        let ms = number.doubleValue
        return Date(timeIntervalSince1970: ms / 1000.0)
    }

    // MARK: - Method Channel Handler

    /// Routes incoming platform channel calls to the appropriate
    /// HealthKitBridge method.
    ///
    /// - Parameters:
    ///   - call: The method call from Dart (name + arguments).
    ///   - result: The callback to return data or errors to Dart.
    private func handleMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {

        case "isAvailable":
            result(healthKitBridge.isAvailable())

        case "requestAuthorization":
            healthKitBridge.requestAuthorization { success, error in
                if let error = error {
                    result(FlutterError(code: "AUTH_ERROR", message: error.localizedDescription, details: nil))
                } else {
                    result(success)
                }
            }

        case "getSteps":
            guard let args = call.arguments as? [String: Any],
                  let date = dateFromMs(args["date"]) else {
                result(FlutterError(code: "BAD_ARGS", message: "Missing 'date' argument", details: nil))
                return
            }
            healthKitBridge.fetchSteps(date: date) { steps, error in
                if let error = error {
                    result(FlutterError(code: "STEPS_ERROR", message: error.localizedDescription, details: nil))
                } else {
                    result(steps ?? 0.0)
                }
            }

        case "getWorkouts":
            guard let args = call.arguments as? [String: Any],
                  let start = dateFromMs(args["startDate"]),
                  let end = dateFromMs(args["endDate"]) else {
                result(FlutterError(code: "BAD_ARGS", message: "Missing 'startDate' or 'endDate'", details: nil))
                return
            }
            healthKitBridge.fetchWorkouts(startDate: start, endDate: end) { workouts, error in
                if let error = error {
                    result(FlutterError(code: "WORKOUTS_ERROR", message: error.localizedDescription, details: nil))
                } else {
                    result(workouts ?? [])
                }
            }

        case "getSleep":
            guard let args = call.arguments as? [String: Any],
                  let start = dateFromMs(args["startDate"]),
                  let end = dateFromMs(args["endDate"]) else {
                result(FlutterError(code: "BAD_ARGS", message: "Missing 'startDate' or 'endDate'", details: nil))
                return
            }
            healthKitBridge.fetchSleep(startDate: start, endDate: end) { sleep, error in
                if let error = error {
                    result(FlutterError(code: "SLEEP_ERROR", message: error.localizedDescription, details: nil))
                } else {
                    result(sleep ?? [])
                }
            }

        case "getWeight":
            healthKitBridge.fetchWeight { weight, error in
                if let error = error {
                    result(FlutterError(code: "WEIGHT_ERROR", message: error.localizedDescription, details: nil))
                } else {
                    result(weight)
                }
            }

        case "writeWorkout":
            guard let args = call.arguments as? [String: Any],
                  let activityType = args["activityType"] as? String,
                  let start = dateFromMs(args["startDate"]),
                  let end = dateFromMs(args["endDate"]),
                  let energy = args["energyBurned"] as? Double else {
                result(FlutterError(code: "BAD_ARGS", message: "Missing workout arguments", details: nil))
                return
            }
            healthKitBridge.writeWorkout(activityType: activityType, startDate: start, endDate: end, energyBurned: energy) { success, error in
                if let error = error {
                    result(FlutterError(code: "WRITE_ERROR", message: error.localizedDescription, details: nil))
                } else {
                    result(success)
                }
            }

        case "writeNutrition":
            guard let args = call.arguments as? [String: Any],
                  let calories = args["calories"] as? Double,
                  let date = dateFromMs(args["date"]) else {
                result(FlutterError(code: "BAD_ARGS", message: "Missing nutrition arguments", details: nil))
                return
            }
            healthKitBridge.writeNutrition(calories: calories, date: date) { success, error in
                if let error = error {
                    result(FlutterError(code: "WRITE_ERROR", message: error.localizedDescription, details: nil))
                } else {
                    result(success)
                }
            }

        case "writeWeight":
            guard let args = call.arguments as? [String: Any],
                  let weightKg = args["weightKg"] as? Double,
                  let date = dateFromMs(args["date"]) else {
                result(FlutterError(code: "BAD_ARGS", message: "Missing weight arguments", details: nil))
                return
            }
            healthKitBridge.writeWeight(weightKg: weightKg, date: date) { success, error in
                if let error = error {
                    result(FlutterError(code: "WRITE_ERROR", message: error.localizedDescription, details: nil))
                } else {
                    result(success)
                }
            }

        case "getCaloriesBurned":
            guard let args = call.arguments as? [String: Any],
                  let date = dateFromMs(args["date"]) else {
                result(FlutterError(code: "BAD_ARGS", message: "Missing 'date' argument", details: nil))
                return
            }
            healthKitBridge.fetchActiveCaloriesBurned(date: date) { kcal, error in
                if let error = error {
                    result(FlutterError(code: "CALORIES_ERROR", message: error.localizedDescription, details: nil))
                } else {
                    result(kcal)
                }
            }

        case "getNutrition":
            guard let args = call.arguments as? [String: Any],
                  let date = dateFromMs(args["date"]) else {
                result(FlutterError(code: "BAD_ARGS", message: "Missing 'date' argument", details: nil))
                return
            }
            healthKitBridge.fetchNutritionCalories(date: date) { kcal, error in
                if let error = error {
                    result(FlutterError(code: "NUTRITION_ERROR", message: error.localizedDescription, details: nil))
                } else {
                    result(kcal)
                }
            }

        case "getRestingHeartRate":
            healthKitBridge.fetchRestingHeartRate { bpm, error in
                if let error = error {
                    result(FlutterError(code: "RHR_ERROR", message: error.localizedDescription, details: nil))
                } else {
                    result(bpm)
                }
            }

        case "getHRV":
            healthKitBridge.fetchHRV { ms, error in
                if let error = error {
                    result(FlutterError(code: "HRV_ERROR", message: error.localizedDescription, details: nil))
                } else {
                    result(ms)
                }
            }

        case "getCardioFitness":
            healthKitBridge.fetchCardioFitness { vo2, error in
                if let error = error {
                    result(FlutterError(code: "CARDIO_ERROR", message: error.localizedDescription, details: nil))
                } else {
                    result(vo2)
                }
            }

        case "startBackgroundObservers":
            healthKitBridge.startBackgroundObservers { success in
                result(success)
            }

        case "checkPermissions":
            // Passive check — no dialog. Completion is synchronous,
            // so no dispatch is needed.
            healthKitBridge.checkPermissionsGranted { granted in
                result(granted)
            }

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
