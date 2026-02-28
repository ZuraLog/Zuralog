# Integration: Apple Health (HealthKit)

**Status:** ✅ Production (iOS only)  
**Priority:** P0  
**Type:** Native SDK (Swift platform channel)  
**Auth:** OS-level permission grant (`HKHealthStore.requestAuthorization`)

---

## Overview

Apple HealthKit is accessed natively via a Swift platform channel — **not** via a REST API. The Flutter app communicates with a native Swift module through platform channels, which then reads/writes to the `HKHealthStore`.

This integration is iOS-only. Android users are covered by [Google Health Connect](./google-health-connect.md).

---

## Permissions Flow

1. User taps "Connect" on Apple Health tile
2. Flutter calls `HealthRepository.requestAuthorization()`
3. Platform channel invokes Swift `HKHealthStore.requestAuthorization()`
4. iOS shows native permission dialog (Zuralog cannot bypass this)
5. On grant: JWT + API URL persisted to iOS Keychain for background sync
6. `startBackgroundObservers()` activates `HKObserverQuery`
7. 30-day initial backfill triggered (fire-and-forget Celery task)

## Background Sync Architecture

**How background sync works without the Flutter engine:**

```
Other app (CalAI, MyFitnessPal) writes to HealthKit
  ↓
HKObserverQuery fires (native iOS, app may be in background)
  ↓
Native Swift code reads JWT from iOS Keychain
  ↓
POST /api/v1/health/ingest (without Flutter engine)
  ↓
Cloud Brain stores new health records
```

The native Swift code reads the JWT **directly from the iOS Keychain** so the background observer can sync data even when the Flutter engine is not running. This is critical for real-time CalAI meal detection.

## Data Types Read

| Category | HealthKit Type |
|----------|---------------|
| Steps | `HKQuantityTypeIdentifierStepCount` |
| Calories burned | `HKQuantityTypeIdentifierActiveEnergyBurned` |
| Distance | `HKQuantityTypeIdentifierDistanceWalkingRunning` |
| Heart rate | `HKQuantityTypeIdentifierHeartRate` |
| Resting HR | `HKQuantityTypeIdentifierRestingHeartRate` |
| HRV | `HKQuantityTypeIdentifierHeartRateVariabilitySDNN` |
| Sleep | `HKCategoryTypeIdentifierSleepAnalysis` |
| Weight | `HKQuantityTypeIdentifierBodyMass` |
| Body fat | `HKQuantityTypeIdentifierBodyFatPercentage` |
| Nutrition (calories) | `HKQuantityTypeIdentifierDietaryEnergyConsumed` — written by CalAI, MyFitnessPal, etc. |
| Nutrition (protein) | `HKQuantityTypeIdentifierDietaryProtein` |
| Workouts | `HKWorkout` |

## Data Types Written

| Action | HealthKit Type |
|--------|---------------|
| Log a meal (by description) | `HKQuantityTypeIdentifierDietaryEnergyConsumed` + macros |
| Log a manual workout | `HKWorkout` |

## Implementation Files

```
cloud-brain/
  app/
    mcp_servers/apple_health_server.py   # MCP tools for reading/writing
    api/v1/health_ingest.py              # POST endpoint receiving data from native bridge

zuralog/
  lib/
    core/health/                         # HealthRepository (Dart interface)
    features/health/data/                # HealthSyncService — pushes to Cloud Brain
    features/integrations/domain/
      integrations_provider.dart         # Apple Health connect flow
```

## Indirect Integrations via HealthKit

Apps that write to HealthKit are automatically read by Zuralog:
- **CalAI** — food photos → nutrition data
- **MyFitnessPal** — food logs → nutrition data
- **Cronometer** — detailed macro tracking
- **Sleep Cycle** — sleep stages
- **Renpho** — body composition from smart scales
- **Nike Run Club** — workouts (limited)
