/// Life Logger Edge Agent -- iOS Application Delegate.
///
/// Registers the HealthKit platform channel (`com.lifelogger/health`)
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

        // Register HealthKit platform channel
        let controller = engineBridge.engine.viewController!
        let healthChannel = FlutterMethodChannel(
            name: "com.lifelogger/health",
            binaryMessenger: controller.binaryMessenger
        )

        healthChannel.setMethodCallHandler { [weak self] (call, result) in
            guard let self = self else {
                result(FlutterError(code: "BRIDGE_GONE", message: "HealthKit bridge deallocated", details: nil))
                return
            }
            self.handleMethodCall(call: call, result: result)
        }
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
                  let dateMs = args["date"] as? Int else {
                result(FlutterError(code: "BAD_ARGS", message: "Missing 'date' argument", details: nil))
                return
            }
            let date = Date(timeIntervalSince1970: Double(dateMs) / 1000.0)
            healthKitBridge.fetchSteps(date: date) { steps, error in
                if let error = error {
                    result(FlutterError(code: "STEPS_ERROR", message: error.localizedDescription, details: nil))
                } else {
                    result(steps ?? 0.0)
                }
            }

        case "getWorkouts":
            guard let args = call.arguments as? [String: Any],
                  let startMs = args["startDate"] as? Int,
                  let endMs = args["endDate"] as? Int else {
                result(FlutterError(code: "BAD_ARGS", message: "Missing 'startDate' or 'endDate'", details: nil))
                return
            }
            let start = Date(timeIntervalSince1970: Double(startMs) / 1000.0)
            let end = Date(timeIntervalSince1970: Double(endMs) / 1000.0)
            healthKitBridge.fetchWorkouts(startDate: start, endDate: end) { workouts, error in
                if let error = error {
                    result(FlutterError(code: "WORKOUTS_ERROR", message: error.localizedDescription, details: nil))
                } else {
                    result(workouts ?? [])
                }
            }

        case "getSleep":
            guard let args = call.arguments as? [String: Any],
                  let startMs = args["startDate"] as? Int,
                  let endMs = args["endDate"] as? Int else {
                result(FlutterError(code: "BAD_ARGS", message: "Missing 'startDate' or 'endDate'", details: nil))
                return
            }
            let start = Date(timeIntervalSince1970: Double(startMs) / 1000.0)
            let end = Date(timeIntervalSince1970: Double(endMs) / 1000.0)
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
                  let startMs = args["startDate"] as? Int,
                  let endMs = args["endDate"] as? Int,
                  let energy = args["energyBurned"] as? Double else {
                result(FlutterError(code: "BAD_ARGS", message: "Missing workout arguments", details: nil))
                return
            }
            let start = Date(timeIntervalSince1970: Double(startMs) / 1000.0)
            let end = Date(timeIntervalSince1970: Double(endMs) / 1000.0)
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
                  let dateMs = args["date"] as? Int else {
                result(FlutterError(code: "BAD_ARGS", message: "Missing nutrition arguments", details: nil))
                return
            }
            let date = Date(timeIntervalSince1970: Double(dateMs) / 1000.0)
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
                  let dateMs = args["date"] as? Int else {
                result(FlutterError(code: "BAD_ARGS", message: "Missing weight arguments", details: nil))
                return
            }
            let date = Date(timeIntervalSince1970: Double(dateMs) / 1000.0)
            healthKitBridge.writeWeight(weightKg: weightKg, date: date) { success, error in
                if let error = error {
                    result(FlutterError(code: "WRITE_ERROR", message: error.localizedDescription, details: nil))
                } else {
                    result(success)
                }
            }

        case "startBackgroundObservers":
            healthKitBridge.startBackgroundObservers { success in
                result(success)
            }

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
