# Google Health Connect Integration

> **Status:** Reference document for Phase 1.5 implementation  
> **Priority:** P0 (MVP)

---

## Overview

This document provides deep-dive technical details for integrating Google Health Connect into Life Logger for Android.

---

## API Overview

Health Connect is Android's equivalent to Apple HealthKit, providing a unified API for reading and writing health data across multiple apps.

### Available Data Types

#### Read Permissions
- Steps: `StepsRecord`
- Calories: `ActiveCaloriesBurnedRecord`, `TotalCaloriesBurnedRecord`
- Sleep: `SleepRecord`
- Weight: `BodyWeightRecord`
- Exercise: `ExerciseSessionRecord`

#### Write Permissions
- Nutrition: `NutritionRecord`
- Weight: `BodyWeightRecord`
- Exercise: `ExerciseSessionRecord`

---

## Permission Requirements

### AndroidManifest.xml
```xml
<uses-permission android:name="android.permission.health.READ_STEPS"/>
<uses-permission android:name="android.permission.health.WRITE_STEPS"/>
<uses-permission android:name="android.permission.health.READ_ACTIVE_CALORIES_BURNED"/>
<uses-permission android:name="android.permission.health.WRITE_ACTIVE_CALORIES_BURNED"/>
<uses-permission android:name="android.permission.health.READ_SLEEP"/>
<uses-permission android:name="android.permission.health.READ_WEIGHT"/>
<uses-permission android:name="android.permission.health.WRITE_WEIGHT"/>
<uses-permission android:name="android.permission.health.READ_EXERCISE"/>
<uses-permission android:name="android.permission.health.WRITE_EXERCISE"/>
```

### Health Permissions XML
```xml
<health-permissions>
    <permission android:name="android.permission.health.READ_STEPS"/>
    <permission android:name="android.permission.health.WRITE_STEPS"/>
    <!-- Additional permissions -->
</health-permissions>
```

---

## Platform Channels

### Kotlin Bridge Implementation

```kotlin
class HealthConnectBridge(private val context: Context) {
    
    private val healthConnectClient: HealthConnectClient? by lazy {
        HealthConnectClient.getOrCreate(context)
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
}
```

---

## Background Sync

### WorkManager Implementation

```kotlin
class HealthSyncWorker(
    context: Context,
    params: WorkerParameters
) : CoroutineWorker(context, params) {
    
    override suspend fun doWork(): Result {
        // 1. Read data from Health Connect
        // 2. Send to Cloud Brain
        // 3. Return result
        return Result.success()
    }
    
    companion object {
        fun schedule(context: Context) {
            val request = PeriodicWorkRequestBuilder<HealthSyncWorker>(
                15, TimeUnit.MINUTES
            ).build()
            
            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                "health_sync",
                ExistingPeriodicWorkPolicy.KEEP,
                request
            )
        }
    }
}
```

---

## Testing Checklist

- [ ] Health Connect availability check
- [ ] Permission request flow
- [ ] Read steps for date range
- [ ] Read workouts
- [ ] Write nutrition entry
- [ ] Write weight entry
- [ ] Background sync via WorkManager
- [ ] Data syncs to Cloud Brain

---

## Rate Limits

No explicit rate limits. Health Connect is local to the device.

---

## References

- [Health Connect Documentation](https://developer.android.com/health-connect)
- [Health Connect API Reference](https://developer.android.com/reference/androidx/health/platform/client)
