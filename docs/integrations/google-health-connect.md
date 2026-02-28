# Integration: Google Health Connect

**Status:** ✅ Production (Android only)  
**Priority:** P0  
**Type:** Native SDK (Kotlin platform channel)  
**Auth:** OS-level permission grant (`PermissionController.createRequestPermissionResultContract`)

---

## Overview

Google Health Connect is accessed natively via a Kotlin platform channel — **not** via a REST API. The Flutter app communicates with a native Kotlin module through platform channels, which reads/writes to the Android Health Connect data store.

This integration is Android-only. iOS users are covered by [Apple Health](./apple-health.md).

> **Note:** Google Fit API was deprecated. Health Connect is the replacement and the correct path going forward.

---

## Permissions Flow

1. User taps "Connect" on Google Health Connect tile
2. Flutter calls `HealthRepository.isAvailable()` — checks if Health Connect app is installed
3. If not installed: shows SnackBar directing user to Play Store
4. If installed: `HealthRepository.requestAuthorization()` via platform channel
5. On grant: JWT + API URL persisted to EncryptedSharedPreferences for background sync
6. `startBackgroundObservers()` schedules WorkManager periodic task
7. 30-day initial backfill triggered (fire-and-forget)

## Background Sync Architecture

**How background sync works without the Flutter engine:**

```
Other app (CalAI, MyFitnessPal) writes to Health Connect
  ↓
WorkManager periodic task fires (on schedule or data change)
  ↓
Native Kotlin code reads JWT from EncryptedSharedPreferences
  ↓
POST /api/v1/health/ingest (without Flutter engine)
  ↓
Cloud Brain stores new health records
```

WorkManager is the Android equivalent of iOS's `HKObserverQuery` but is schedule-based rather than event-driven; Health Connect doesn't have real-time change callbacks.

## Data Types Read

| Category | Health Connect Type |
|----------|-------------------|
| Steps | `Steps` |
| Calories | `TotalCaloriesBurned` / `ActiveCaloriesBurned` |
| Distance | `Distance` |
| Heart rate | `HeartRate` |
| Resting HR | `RestingHeartRate` |
| HRV | `HeartRateVariabilityRmssd` |
| Sleep | `SleepSession` / `SleepStage` |
| Weight | `Weight` |
| Body fat | `BodyFat` |
| Nutrition (calories) | `Nutrition` — written by CalAI, MyFitnessPal |
| Workouts | `ExerciseSession` |

## Data Types Written

| Action | Health Connect Type |
|--------|-------------------|
| Log a meal | `Nutrition` record |
| Log a manual workout | `ExerciseSession` |

## Implementation Files

```
cloud-brain/
  app/
    mcp_servers/health_connect_server.py  # MCP tools for reading/writing
    api/v1/health_ingest.py               # POST endpoint receiving data

zuralog/
  lib/
    core/health/                          # HealthRepository (Dart interface)
    features/health/data/                 # HealthSyncService
    features/integrations/domain/
      integrations_provider.dart          # Health Connect connect flow
```

## Indirect Integrations via Health Connect

Apps that write to Health Connect are automatically read by Zuralog:
- **CalAI** — food photos → nutrition data
- **MyFitnessPal** — food logs → nutrition data
- **Cronometer** — macro tracking
- **Samsung Health** — workouts, sleep, HR
- Any app using the `WRITE_*` Health Connect permissions
