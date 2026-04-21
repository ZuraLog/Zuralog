import Flutter
import Foundation
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

/// Bridges Flutter MethodChannel calls to WatchConnectivity.
///
/// Phase 10 of `docs/superpowers/plans/2026-04-22-workout-background-system.md`
/// ships this as a stub: `isPaired` reflects the real `WCSession` state where
/// supported, but `broadcast` currently returns success without actually
/// transmitting payloads to a watchOS app (there is no companion app yet).
///
/// When the watchOS companion ships, the `broadcast` case should send via
/// `WCSession.updateApplicationContext(_:)` (for the latest rest state) or
/// `sendMessage(_:replyHandler:errorHandler:)` (for transient events).
@objc class WorkoutCompanionBridge: NSObject {
    static let channelName = "com.zuralog/workout_companion"

    @objc static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: registrar.messenger()
        )
        let instance = WorkoutCompanionBridge()
        channel.setMethodCallHandler { call, result in
            instance.handle(call, result: result)
        }
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isPaired":
            #if canImport(WatchConnectivity)
            if WCSession.isSupported() {
                let session = WCSession.default
                if session.activationState == .notActivated {
                    session.activate()
                }
                result(session.isPaired)
            } else {
                result(false)
            }
            #else
            result(false)
            #endif
        case "broadcast":
            // TODO: full implementation sends via WCSession.updateApplicationContext
            // or sendMessage when the watchOS companion app ships. For now, report
            // success without transmitting anything.
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
