import Flutter
import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

/// Bridges Flutter MethodChannel calls to ActivityKit.
///
/// All methods are guarded by `#available(iOS 16.1, *)` and `#if canImport(ActivityKit)`
/// so older iOS versions (and hypothetical Mac builds) silently return success
/// with no-op side effects. The Live Activity is a nice-to-have surface — the
/// workout screen must keep running even when this bridge does nothing.
///
/// See `docs/ios-live-activity-setup.md` for the one-time Xcode target setup
/// required to actually render the UI.
@objc class WorkoutLiveActivityBridge: NSObject {
    static let channelName = "com.zuralog/workout_live_activity"

    @objc static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: registrar.messenger()
        )
        let instance = WorkoutLiveActivityBridge()
        channel.setMethodCallHandler { call, result in
            instance.handle(call, result: result)
        }
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if #available(iOS 16.1, *) {
            switch call.method {
            case "start":
                startActivity(args: call.arguments as? [String: Any] ?? [:])
                result(nil)
            case "update":
                updateActivity(args: call.arguments as? [String: Any] ?? [:])
                result(nil)
            case "end":
                endActivity()
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        } else {
            // Graceful no-op on older iOS.
            result(nil)
        }
    }

    @available(iOS 16.1, *)
    private func startActivity(args: [String: Any]) {
        // NOTE: This implementation is complete once the ZuralogWorkoutLiveActivity
        // Widget Extension target has been added in Xcode. Until then, the
        // WorkoutAttributes type below must be kept in sync with the
        // ZuralogWorkoutLiveActivity.swift file in the extension target.
        //
        // See docs/ios-live-activity-setup.md.
        //
        // The code below is gated behind #if canImport to let the Runner target
        // continue to build even without the extension.
        #if canImport(ActivityKit)
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let (attrs, state) = parseArgs(args)
        do {
            _ = try Activity<WorkoutAttributes>.request(
                attributes: attrs,
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
        } catch {
            NSLog("LiveActivity start failed: \(error)")
        }
        #endif
    }

    @available(iOS 16.1, *)
    private func updateActivity(args: [String: Any]) {
        #if canImport(ActivityKit)
        let (_, state) = parseArgs(args)
        Task {
            for activity in Activity<WorkoutAttributes>.activities {
                await activity.update(.init(state: state, staleDate: nil))
            }
        }
        #endif
    }

    @available(iOS 16.1, *)
    private func endActivity() {
        #if canImport(ActivityKit)
        Task {
            for activity in Activity<WorkoutAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        #endif
    }

    #if canImport(ActivityKit)
    @available(iOS 16.1, *)
    private func parseArgs(
        _ args: [String: Any]
    ) -> (WorkoutAttributes, WorkoutAttributes.ContentState) {
        // Flutter's StandardMethodCodec bridges Dart ints through NSNumber —
        // read through NSNumber so we tolerate Int, Int64, and Double alike.
        let workoutStartMs = (args["workoutStartedAtMs"] as? NSNumber)?.doubleValue ?? 0
        let restStartMs = (args["restStartedAtMs"] as? NSNumber)?.doubleValue
        let planned = (args["plannedRestDurationSeconds"] as? NSNumber)?.intValue ?? 0
        let added = (args["addedRestSeconds"] as? NSNumber)?.intValue ?? 0
        let exerciseName = args["exerciseName"] as? String ?? ""
        let setLabel = args["setLabel"] as? String ?? ""

        let attrs = WorkoutAttributes(
            workoutStartedAt: Date(timeIntervalSince1970: workoutStartMs / 1000.0)
        )
        let state = WorkoutAttributes.ContentState(
            restStartedAt: restStartMs.map {
                Date(timeIntervalSince1970: $0 / 1000.0)
            },
            plannedRestDurationSeconds: planned,
            addedRestSeconds: added,
            exerciseName: exerciseName,
            setLabel: setLabel
        )
        return (attrs, state)
    }
    #endif
}

#if canImport(ActivityKit)
/// Shared attribute type — MUST be kept in lock-step with the identical
/// definition in `ios/ZuralogWorkoutLiveActivity/ZuralogWorkoutLiveActivity.swift`.
/// The extension target renders the UI from the same struct shape.
@available(iOS 16.1, *)
public struct WorkoutAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var restStartedAt: Date?
        public var plannedRestDurationSeconds: Int
        public var addedRestSeconds: Int
        public var exerciseName: String
        public var setLabel: String
    }
    public var workoutStartedAt: Date
}
#endif
