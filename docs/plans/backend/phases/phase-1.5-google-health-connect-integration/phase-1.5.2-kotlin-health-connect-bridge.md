# Phase 1.5.2: Kotlin Health Connect Bridge

**Parent Goal:** Phase 1.5 Google Health Connect Integration
**Checklist:**
- [x] 1.5.1 Health Connect Permissions (Android)
- [ ] 1.5.2 Kotlin Health Connect Bridge
- [ ] 1.5.3 Flutter Platform Channel (Android)
- [ ] 1.5.4 Health Connect MCP Server
- [ ] 1.5.5 Background Sync (Android WorkManager)
- [ ] 1.5.6 Unified Health Store Abstraction
- [ ] 1.5.7 Health Connect Integration Document

---

## What
Implement the native Kotlin code to interact with the Android Health Connect SDK. This mirrors the Swift `HealthKitBridge`.

## Why
Flutter does not have native access to Health Connect. We must implement a bridge.

## How
Use `androidx.health.connect:connect-client` library. Create a `HealthConnectBridge` class in Kotlin.

## Features
- **Read Records:** Steps, Workouts (ExerciseSession), Weight.
- **Write Records:** Nutrition, Weight, Workouts.
- **Aggregates:** Summing steps per day.

## Files
- Create: `life_logger/android/app/src/main/kotlin/com/lifelogger/HealthConnectBridge.kt`

## Steps

1. **Add dependencies to `android/app/build.gradle`**

```gradle
dependencies {
    implementation "androidx.health.connect:connect-client:1.1.0-alpha07" // Check for latest stable
}
```

2. **Create Health Connect bridge (`life_logger/android/app/src/main/kotlin/com/lifelogger/HealthConnectBridge.kt`)**

```kotlin
package com.lifelogger

import android.content.Context
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.*
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import kotlinx.coroutines.runBlocking
import java.time.Instant

class HealthConnectBridge(private val context: Context) {
    
    private val healthConnectClient: HealthConnectClient? by lazy {
        HealthConnectClient.getOrCreate(context)
    }
    
    // Define exact permissions needed
    val permissions = setOf(
        HealthPermission.getReadPermission(StepsRecord::class),
        HealthPermission.getWritePermission(StepsRecord::class),
        HealthPermission.getReadPermission(ActiveCaloriesBurnedRecord::class),
        HealthPermission.getWritePermission(ActiveCaloriesBurnedRecord::class),
        HealthPermission.getReadPermission(SleepSessionRecord::class), // Updated class name if needed
        HealthPermission.getReadPermission(WeightRecord::class),       // Updated class name
        HealthPermission.getWritePermission(WeightRecord::class),
        HealthPermission.getReadPermission(ExerciseSessionRecord::class),
        HealthPermission.getWritePermission(ExerciseSessionRecord::class),
    )
    
    fun isAvailable(): Boolean {
        return HealthConnectClient.getSdkStatus(context) == HealthConnectClient.SDK_AVAILABLE
    }
    
    fun requestPermissions(): Boolean {
        // Logic handled in MainActivity usually via ActivityResultContract
        // This helper just confirms intent triggers
        return true 
    }
    
    fun readSteps(startTime: Long, endTime: Long): Int {
        val client = healthConnectClient ?: return 0
        
        return runBlocking {
            val response = client.readRecords(
                ReadRecordsRequest(
                    recordType = StepsRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(
                        Instant.ofEpochMilli(startTime),
                        Instant.ofEpochMilli(endTime)
                    )
                )
            )
            response.records.sumOf { it.count.toInt() }
        }
    }
    
    fun readWorkouts(startTime: Long, endTime: Long): List<Map<String, Any>> {
        val client = healthConnectClient ?: return emptyList()
        
        return runBlocking {
            val response = client.readRecords(
                ReadRecordsRequest(
                    recordType = ExerciseSessionRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(
                        Instant.ofEpochMilli(startTime),
                        Instant.ofEpochMilli(endTime)
                    )
                )
            )
            response.records.map { workout ->
                mapOf(
                    "title" to (workout.title ?: "Workout"),
                    "startTime" to workout.startTime.toEpochMilli(),
                    "endTime" to workout.endTime.toEpochMilli(),
                    "duration" to (workout.endTime.toEpochMilli() - workout.startTime.toEpochMilli()),
                )
            }
        }
    }
    
    // ... write methods similar to Swift logic ...
}
```

## Exit Criteria
- Kotlin bridge class compiles.
- Dependencies resolved.
- Basic read methods implemented.
