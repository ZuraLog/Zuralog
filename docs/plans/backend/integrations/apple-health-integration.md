# Apple HealthKit Integration

> **Status:** Implemented in Phase 1.4  
> **Priority:** P0 (MVP)  
> **Phase:** 1.4 — Apple HealthKit Integration

---

## Overview

Zuralog integrates with Apple HealthKit on iOS to read and write health metrics. The architecture spans three layers:

```
Swift HealthKitBridge  ->  Flutter MethodChannel  ->  Dart HealthBridge  ->  HealthRepository  ->  MCP Server
     (iOS native)          (com.zuralog/health)      (platform channel)     (Riverpod DI)       (Cloud Brain)
```

- **Swift layer** (`HealthKitBridge.swift`): Direct `HKHealthStore` interactions — reads, writes, and background observers.
- **Platform channel** (`AppDelegate.swift`): Routes Flutter `MethodChannel` calls to the Swift bridge.
- **Dart layer** (`health_bridge.dart`): Marshals Dart arguments to/from the native layer via `MethodChannel`.
- **Repository** (`health_repository.dart`): Clean abstraction over the bridge, injected via Riverpod.
- **MCP Server** (`apple_health_server.py`): Exposes health capabilities as semantic tools for the LLM agent.

---

## Supported Data Types

| Data Type | HK Identifier | Read | Write | Notes |
|-----------|---------------|------|-------|-------|
| Steps | `HKQuantityType(.stepCount)` | Yes | No | Cumulative sum per day |
| Active Energy | `HKQuantityType(.activeEnergyBurned)` | Via workouts | No | Included in workout energy |
| Dietary Energy | `HKQuantityType(.dietaryEnergyConsumed)` | No | Yes | Write nutrition/calories |
| Body Mass | `HKQuantityType(.bodyMass)` | Yes | Yes | Most recent sample |
| Workouts | `HKWorkoutType.workoutType()` | Yes | Yes | With activity type + energy |
| Sleep | `HKCategoryType(.sleepAnalysis)` | Yes | No | Sleep segments with value |

---

## Permissions Configuration

### Entitlements (`Runner.entitlements`)

```xml
<key>com.apple.developer.healthkit</key>
<true/>
<key>com.apple.developer.healthkit.access</key>
<array/>
<key>com.apple.developer.healthkit.background-delivery</key>
<true/>
```

### Info.plist Keys

```xml
<key>NSHealthShareUsageDescription</key>
<string>Zuralog needs access to your health data (steps, workouts, nutrition, sleep) to provide personalized AI coaching and track your fitness goals.</string>
<key>NSHealthUpdateUsageDescription</key>
<string>Zuralog needs to write health data (like workouts and nutrition entries) to Apple Health based on your requests.</string>
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>processing</string>
</array>
```

### Xcode Setup

The Runner target must have:
- **HealthKit** capability enabled (with Background Delivery checked)
- **Background Modes** capability (Background fetch + Background processing)
- `Runner.entitlements` referenced in Code Signing Entitlements build setting

---

## Platform Channel Methods

Channel name: `com.zuralog/health`

| Method | Arguments | Returns | Description |
|--------|-----------|---------|-------------|
| `isAvailable` | None | `bool` | Check if HealthKit is available |
| `requestAuthorization` | None | `bool` | Request read/write permissions |
| `getSteps` | `{date: int}` (ms epoch) | `double` | Total steps for a day |
| `getWorkouts` | `{startDate: int, endDate: int}` | `List<Map>` | Workouts in date range |
| `getSleep` | `{startDate: int, endDate: int}` | `List<Map>` | Sleep segments in date range |
| `getWeight` | None | `double?` | Most recent body weight (kg) |
| `writeWorkout` | `{activityType, startDate, endDate, energyBurned}` | `bool` | Save a workout |
| `writeNutrition` | `{calories, date}` | `bool` | Save a nutrition entry |
| `writeWeight` | `{weightKg, date}` | `bool` | Save a weight entry |
| `startBackgroundObservers` | None | `bool` | Start HKObserverQuery watchers |

---

## Background Updates

### HKObserverQuery

Three observer queries run for:
- `stepCount` — fires when new step data arrives (e.g., from Apple Watch)
- `workoutType` — fires when a new workout is recorded
- `sleepAnalysis` — fires when new sleep data is detected

### Background Delivery

Enabled with `.immediate` frequency for all three types. iOS may batch notifications for battery efficiency.

### Current Behavior

In Phase 1.4, observers log the event via `print()`. In Phase 1.10 (Background Services), they will:
1. Start a headless `FlutterEngine`
2. Send the change type via method channel
3. Trigger Dart code to sync data to Cloud Brain via REST

---

## MCP Server Tools

The `AppleHealthServer` exposes two tools to the LLM agent:

### `apple_health_read_metrics`
- **Inputs:** `data_type` (enum: steps/calories/workouts/sleep/weight), `start_date`, `end_date`
- **Current behavior:** Returns `pending_device_sync` status (queued for Edge Agent)
- **Future behavior:** Triggers FCM push to device, device reads HealthKit, returns via callback

### `apple_health_write_entry`
- **Inputs:** `data_type` (enum: nutrition/workout/weight), `value`, `date`, optional `metadata`
- **Current behavior:** Returns `pending_device_sync` status
- **Future behavior:** Triggers FCM push to device, device writes to HealthKit

---

## Riverpod Providers

```dart
// In lib/core/di/providers.dart
final healthBridgeProvider = Provider<HealthBridge>((ref) => HealthBridge());
final healthRepositoryProvider = Provider<HealthRepository>((ref) {
  return HealthRepository(bridge: ref.watch(healthBridgeProvider));
});
```

---

## Testing

### Harness Screen Buttons

The developer test harness includes HealthKit buttons:
- **Check Available** — calls `isAvailable`
- **Request Auth** — calls `requestAuthorization`
- **Read Steps** — reads today's step count
- **Read Workouts** — reads last 7 days of workouts
- **Read Sleep** — reads last 7 days of sleep data
- **Read Weight** — reads most recent weight

### MCP Server Tests

10 tests in `cloud-brain/tests/mcp/test_apple_health_server.py`:
- Server identity properties (name, description)
- Tool definitions (returns ToolDefinition list, has both tools, correct required fields)
- Tool execution (read returns ToolResult, write returns ToolResult, unknown tool returns error)
- Resource listing (returns empty list)

### On-Device Testing (iOS Simulator)

1. Run on iOS Simulator: `flutter run --debug`
2. Tap "Check Available" — should show available
3. Tap "Request Auth" — iOS permission dialog appears
4. Tap "Read Steps" — returns step count (add fake data via Health app on simulator)

### On-Device Testing (Physical Device)

1. Connect iPhone, run `flutter run --debug`
2. Grant HealthKit permissions when prompted
3. Verify real data from Apple Watch or Health app appears

---

## Troubleshooting

| Issue | Cause | Fix |
|-------|-------|-----|
| `isAvailable` returns false | Not on iOS, or HealthKit not supported | Check platform, ensure running on iPhone |
| Authorization dialog doesn't appear | Already shown once | Reset via Settings > Privacy > Health |
| Steps return 0 | No data for today | Add sample data via Health app or Apple Watch |
| Write fails | Missing write permission | User denied write access; re-request |
| Background observer doesn't fire | Background delivery not enabled | Verify entitlements and UIBackgroundModes |
| `PlatformException` in logs | Native bridge error | Check Xcode console for Swift-side errors |

---

## References

- [Apple HealthKit Documentation](https://developer.apple.com/documentation/healthkit)
- [HealthKit Entitlements](https://developer.apple.com/documentation/healthkit/supported_healthkit_entitlements)
- [HKObserverQuery](https://developer.apple.com/documentation/healthkit/hkobserverquery)
- [Background Delivery](https://developer.apple.com/documentation/healthkit/hkhealthstore/1614175-enablebackgrounddelivery)
