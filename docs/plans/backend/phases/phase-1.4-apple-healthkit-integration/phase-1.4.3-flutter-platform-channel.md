# Phase 1.4.3: Flutter Platform Channel

**Parent Goal:** Phase 1.4 Apple HealthKit Integration
**Checklist:**
- [x] 1.4.1 HealthKit Entitlements & Permissions (iOS)
- [x] 1.4.2 Swift HealthKit Bridge
- [ ] 1.4.3 Flutter Platform Channel
- [ ] 1.4.4 HealthKit MCP Server (Cloud Brain)
- [ ] 1.4.5 Edge Agent Health Repository
- [ ] 1.4.6 Background Observation
- [ ] 1.4.7 Harness Test: HealthKit Integration
- [ ] 1.4.8 Apple Health Integration Document

---

## What
Create the communication bridge that allows Dart code to call the Swift `HealthKitBridge` methods. This involves defining a `MethodChannel` in both Dart and Swift and handling argument serialization.

## Why
This is the "glue" that exposes native iOS capabilities to our cross-platform business logic.

## How
We will use:
- **Flutter MethodChannel:** `com.zuralog/health`
- **Serialization:** Maps and Timestamps (millisecondsSinceEpoch) for data transfer.

## Features
- **Unified API:** Dart code calls `HealthBridge.getSteps()` without worrying about Swift.
- **Error Handling:** Native errors are caught and returned as defaults or re-thrown safely.

## Files
- Create: `zuralog/lib/core/health/health_bridge.dart`
- Modify: `zuralog/ios/Runner/AppDelegate.swift`

## Steps

1. **Create Dart platform channel wrapper (`zuralog/lib/core/health/health_bridge.dart`)**

```dart
import 'package:flutter/services.dart';

class HealthBridge {
  static const _channel = MethodChannel('com.zuralog/health');
  
  static Future<bool> isAvailable() async {
    try {
      return await _channel.invokeMethod('isAvailable');
    } catch (e) {
      return false;
    }
  }
  
  static Future<bool> requestAuthorization() async {
    try {
      return await _channel.invokeMethod('requestAuthorization');
    } catch (e) {
      return false;
    }
  }
  
  static Future<double> getSteps(DateTime date) async {
    try {
      final result = await _channel.invokeMethod('getSteps', {
        'date': date.millisecondsSinceEpoch,
      });
      return (result as num?)?.toDouble() ?? 0.0;
    } catch (e) {
      return 0.0;
    }
  }
  
  static Future<List<Map<String, dynamic>>> getWorkouts(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final result = await _channel.invokeMethod('getWorkouts', {
        'startDate': startDate.millisecondsSinceEpoch,
        'endDate': endDate.millisecondsSinceEpoch,
      });
      return List<Map<String, dynamic>>.from(result ?? []);
    } catch (e) {
      return [];
    }
  }
  // ... (Other write methods follow same pattern)
}
```

2. **Add method channel handler in iOS AppDelegate (`ios/Runner/AppDelegate.swift`)**

```swift
import Flutter
import UIKit

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        let controller = window?.rootViewController as! FlutterViewController
        let healthChannel = FlutterMethodChannel(
            name: "com.zuralog/health",
            binaryMessenger: controller.binaryMessenger
        )
        
        let healthKitBridge = HealthKitBridge()
        
        healthChannel.setMethodCallHandler { (call, result) in
            switch call.method {
            case "isAvailable":
                result(healthKitBridge.isAvailable())
                
            case "requestAuthorization":
                healthKitBridge.requestAuthorization { success, error in
                    result(success)
                }
                
            case "getSteps":
                if let args = call.arguments as? [String: Any],
                   let dateMs = args["date"] as? Int {
                    let date = Date(timeIntervalSince1970: Double(dateMs) / 1000)
                    healthKitBridge.fetchSteps(date: date) { steps, error in
                        result(steps ?? 0)
                    }
                }
            // ... (Handle other cases)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
```

## Exit Criteria
- Platform channel code compiles.
- Communication between Dart and Swift is established.
