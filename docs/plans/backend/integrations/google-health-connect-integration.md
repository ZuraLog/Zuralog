# Google Health Connect Integration Reference

## Overview

Zuralog uses Google Health Connect (built-in on Android 14+, available via APK on Android 9–13) to read and write health data on Android devices. This mirrors the Apple HealthKit integration (Phase 1.4) and shares the same Flutter platform channel (`com.zuralog/health`).

## Architecture

```
┌───────────────────────────────────────────────────────────────┐
│  Flutter (Dart)                                               │
│  HealthBridge → MethodChannel("com.zuralog/health")        │
│  HealthRepository (Riverpod)                                  │
└──────────────────────────┬────────────────────────────────────┘
                           │ Platform Channel
┌──────────────────────────▼────────────────────────────────────┐
│  Android Native (Kotlin)                                      │
│  MainActivity.kt → HealthConnectBridge.kt                     │
│  HealthSyncWorker.kt (WorkManager, 15min periodic)            │
└──────────────────────────┬────────────────────────────────────┘
                           │ SDK
┌──────────────────────────▼────────────────────────────────────┐
│  androidx.health.connect:connect-client                       │
│  Google Health Connect (system app)                            │
└───────────────────────────────────────────────────────────────┘
```

### Key Components

| Component | File | Role |
|-----------|------|------|
| Kotlin Bridge | `HealthConnectBridge.kt` | Suspend functions for Health Connect SDK |
| Platform Channel | `MainActivity.kt` | Routes Dart calls to Kotlin bridge |
| Background Sync | `HealthSyncWorker.kt` | WorkManager periodic polling |
| MCP Server | `health_connect_server.py` | Exposes tools to LLM agent |

## Data Types

| Metric | Health Connect Record | Read | Write |
|--------|----------------------|------|-------|
| Steps | `StepsRecord` | ✅ | ✅ |
| Active Calories | `ActiveCaloriesBurnedRecord` | ✅ | ✅ |
| Total Calories | `TotalCaloriesBurnedRecord` | ✅ | ✅ |
| Sleep | `SleepSessionRecord` | ✅ | ✅ |
| Body Weight | `WeightRecord` | ✅ | ✅ |
| Exercise | `ExerciseSessionRecord` | ✅ | ✅ |
| Nutrition | `NutritionRecord` | ✅ | ✅ |

## Permission Handling

### Build-time
All permissions are declared in `AndroidManifest.xml` as `<uses-permission>` tags:
```xml
<uses-permission android:name="android.permission.health.READ_STEPS"/>
<uses-permission android:name="android.permission.health.WRITE_STEPS"/>
<!-- ... etc -->
```

### Runtime
At runtime, the app must request permissions via an `ActivityResultContract`. Health Connect shows a system sheet prompting the user to toggle access for each data category.

### ViewPermissionUsageActivity
A mandatory `<activity-alias>` in the manifest allows Health Connect settings to link back to the app when users review "Apps with access."

## Background Sync

Android does not provide a push-based observer like iOS's `HKObserverQuery`. Instead, we use `WorkManager` for periodic polling:

- **Interval:** 15 minutes (WorkManager minimum)
- **Constraints:** Network connected + battery not low
- **Current scope (MVP):** Reads today's steps and logs to logcat
- **Phase 1.10:** Will add HTTP sync to Cloud Brain API

## Testing on Emulator

1. Use an API 34+ (Android 14) system image **with Google Play Store**.
2. Health Connect is built into Android 14+. On older images, install the "Health Connect" app from Play Store.
3. Launch Zuralog → it will request Health Connect permissions.
4. To pre-populate test data: Open Health Connect app → Data and Access → Add test data.
5. Verify WorkManager scheduling: Android Studio → App Inspection → Background Task Inspector.

## Differences from Apple HealthKit

| Aspect | HealthKit (iOS) | Health Connect (Android) |
|--------|----------------|------------------------|
| API style | Callback/completion handler | Suspend (coroutine) |
| Background | `HKObserverQuery` (push) | `WorkManager` (poll) |
| Availability | Built-in on all iPhones | Built-in on Android 14+, APK on 9-13 |
| Permission model | System dialog, hides denials | System sheet, explicit toggles |
| Min SDK | iOS 11+ | API 28 (Android 9+) |
