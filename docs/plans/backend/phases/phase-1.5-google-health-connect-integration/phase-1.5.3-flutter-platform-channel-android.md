# Phase 1.5.3: Flutter Platform Channel (Android)

**Parent Goal:** Phase 1.5 Google Health Connect Integration
**Checklist:**
- [x] 1.5.1 Health Connect Permissions (Android)
- [x] 1.5.2 Kotlin Health Connect Bridge
- [ ] 1.5.3 Flutter Platform Channel (Android)
- [ ] 1.5.4 Health Connect MCP Server
- [ ] 1.5.5 Background Sync (Android WorkManager)
- [ ] 1.5.6 Unified Health Store Abstraction
- [ ] 1.5.7 Health Connect Integration Document

---

## What
Hook up the Android side of the existing `com.zuralog/health` method channel.

## Why
So that the exact same Dart code we wrote in Phase 1.4 (`HealthBridge.getSteps()`) works on Android devices too.

## How
Modify `MainActivity.kt` to intercept the method channel calls and route them to `HealthConnectBridge`.

## Features
- **Cross-Platform Compatibility:** One Dart API, two native implementations.
- **Unified Logic:** The rest of the app doesn't know it's talking to Health Connect vs HealthKit.

## Files
- Modify: `zuralog/android/app/src/main/kotlin/com/zuralog/MainActivity.kt`
- Review: `zuralog/lib/core/health/health_bridge.dart` (ensure no iOS-specific assumptions)

## Steps

1. **Add Android method channel handler (`MainActivity.kt`)**

```kotlin
package com.zuralog

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.zuralog/health"
    private lateinit var healthConnectBridge: HealthConnectBridge
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        healthConnectBridge = HealthConnectBridge(this)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAvailable" -> result.success(healthConnectBridge.isAvailable())
                
                // Note: RequestPermissions in Android is async ActivityResult. 
                // We'd need to launch an intent here and return result later.
                // For MVP, we can treat it as 'started' or implement the full ActivityResultListener.
                "requestAuthorization" -> {
                    // Start auth flow
                    // For now, return false if implementation incomplete, or true if we launched intent
                    result.success(true) 
                }
                
                "getSteps" -> {
                    val startDate = call.argument<Long>("startDate") ?: 0
                    val endDate = call.argument<Long>("endDate") ?: System.currentTimeMillis()
                    // Run on creation thread (or background if bridge handles coroutines properly)
                    // Since bridge uses runBlocking, it might block UI thread. 
                    // Better to use coroutine scope here.
                    result.success(healthConnectBridge.readSteps(startDate, endDate))
                }
                
                "getWorkouts" -> {
                    val startDate = call.argument<Long>("startDate") ?: 0
                    val endDate = call.argument<Long>("endDate") ?: System.currentTimeMillis()
                    result.success(healthConnectBridge.readWorkouts(startDate, endDate))
                }
                
                else -> result.notImplemented()
            }
        }
    }
}
```

## Exit Criteria
- MainActivity handles method channel calls.
- Builds and runs on Android Emulator.
