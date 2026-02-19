# Phase 1.5.5: Background Sync (Android WorkManager)

**Parent Goal:** Phase 1.5 Google Health Connect Integration
**Checklist:**
- [x] 1.5.1 Health Connect Permissions (Android)
- [x] 1.5.2 Kotlin Health Connect Bridge
- [x] 1.5.3 Flutter Platform Channel (Android)
- [x] 1.5.4 Health Connect MCP Server
- [ ] 1.5.5 Background Sync (Android WorkManager)
- [ ] 1.5.6 Unified Health Store Abstraction
- [ ] 1.5.7 Health Connect Integration Document

---

## What
Implement background data synchronization using Android's `WorkManager`. This allows the app to wake up periodically (e.g., every 15 minutes) to sync health data to the Cloud Brain, even if the user hasn't opened the app.

## Why
Health Connect doesn't have a "real-time push" mechanism exactly like Apple's `HKObserverQuery` that wakes the app up instantly for every step. The standard pattern is periodic polling via `WorkManager`.

## How
Create a `HealthSyncWorker` Kotlin class that reads recent data and sends it to the Cloud API. Schedule this worker in `MainActivity`.

## Features
- **Reliable Sync:** Validates connectivity before attempting sync.
- **Battery Friendly:** Respects Android's doze mode and job scheduling optimization.

## Files
- Create: `life_logger/android/app/src/main/kotlin/com/lifelogger/HealthSyncWorker.kt`

## Steps

1. **Create WorkManager worker (`life_logger/android/app/src/main/kotlin/com/lifelogger/HealthSyncWorker.kt`)**

```kotlin
package com.lifelogger

import android.content.Context
import androidx.work.*
import java.util.concurrent.TimeUnit
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class HealthSyncWorker(
    context: Context,
    params: WorkerParameters
) : CoroutineWorker(context, params) {
    
    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        // 1. Check if Health Connect is installed/permitted
        // 2. Read last 24h of data via HealthConnectBridge logic
        // 3. Send to Cloud Brain API (using a simple HTTP client or calling into Flutter engine if headless is set up)
        
        // Note: Calling into Flutter from WorkManager requires "FlutterBackgroundExecutor" or similar.
        // For Phase 1.5, we might just log success to prove it runs.
        
        // System.out.println("HealthSyncWorker running...")
        
        return@withContext Result.success()
    }
    
    companion object {
        fun schedule(context: Context) {
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .setRequiresBatteryNotLow(true)
                .build()
            
            // Minimum interval is 15 minutes
            val request = PeriodicWorkRequestBuilder<HealthSyncWorker>(
                15, TimeUnit.MINUTES
            )
                .setConstraints(constraints)
                .build()
            
            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                "health_sync",
                ExistingPeriodicWorkPolicy.UPDATE,
                request
            )
        }
    }
}
```

2. **Schedule in `MainActivity.kt`**

```kotlin
// In onCreate() or a specific init method
HealthSyncWorker.schedule(this)
```

## Exit Criteria
- WorkManager worker compiles.
- Can be scheduled (verifiable via Android Studio "App Inspection" -> "Background Task Inspector").
