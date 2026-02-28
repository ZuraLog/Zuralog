# Indirect Integrations (via Apple Health / Google Health Connect)

**Status:** ✅ Covered automatically  
**No additional implementation required**

---

## Overview

Many popular health apps do not have public APIs — or their APIs are too limited for direct integration. They write their data to the OS health store — Apple HealthKit (iOS) or Google Health Connect (Android). Since Zuralog has native integrations with both health stores, all data written by these apps is automatically read by Zuralog.

This is Zuralog's **Zero-Friction Connector** philosophy in action: we don't rebuild what CalAI, Cronometer, or Samsung Health does. We read the result.

**Source:** Top 30 globally used + top 30 US health apps, deduplicated into 45 apps. See `.opencode/plans/2026-02-27-compatible-apps-integrations-hub.md` for the full registry (used to populate the in-app Compatible Apps section).

---

## How This Works (Technical)

```
User logs food in CalAI / records workout in Nike Run Club / etc.
  → App writes data to Apple HealthKit or Google Health Connect
  → Zuralog's HKObserverQuery (iOS) or WorkManager (Android) fires
  → Zuralog reads new records from the health store
  → POST /api/v1/health/ingest → Cloud Brain stores data
  → Agent now knows about the activity without user doing anything in Zuralog
```

---

## Full Compatible Apps List (45 Apps)

Platform badges: **HK** = Apple HealthKit | **HC** = Google Health Connect

### 🏃 Running & Outdoor Activity

| App | HK | HC | Notes |
|-----|----|----|-------|
| **Strava** | ✅ | ✅ | Also has a direct integration (OAuth) for richer data |
| **Nike Run Club** | ✅ | ✅ | Guided runs, training plans |
| **Adidas Running** (Runtastic) | ✅ | ✅ | GPS run + cycling tracking |
| **Runkeeper** (ASICS) | ✅ | ✅ | GPS running and fitness |
| **MapMyRun** (Under Armour) | ✅ | ✅ | 700+ activity types |
| **AllTrails** | ✅ | ✅ | Hiking and trail activities |
| **Komoot** | ✅ | ✅ | Outdoor route planning and navigation |
| **Zwift** | ✅ | ❌ | Indoor cycling / virtual racing (iOS only) |

### ⌚ Wearables & Devices

| App | HK | HC | Notes |
|-----|----|----|-------|
| **Garmin Connect** | ✅ | ✅ | Steps, sleep, workouts, body metrics |
| **Fitbit** | ✅ | ✅ | Also has a direct integration for richer data |
| **Oura Ring** | ✅ | ✅ | Sleep, readiness, HRV |
| **WHOOP** | ✅ | ✅ | Recovery, strain, sleep |
| **Polar** | ✅ | ✅ | Training load, sleep, HR zones |
| **COROS** | ✅ | ✅ | GPS sport watch data |
| **Suunto** | ✅ | ✅ | Outdoor sports, diving |
| **Withings / Health Mate** | ✅ | ✅ | Scale, BP monitor, sleep mat |
| **Amazfit (Zepp)** | ✅ | ✅ | Smartwatch health data |
| **Samsung Health** | ❌ | ✅ | Android only via Health Connect |
| **Huawei Health** | ❌ | ✅ | Android only via Health Connect |
| **Xiaomi Health (Mi Fitness)** | ❌ | ✅ | Android only via Health Connect |
| **Apple Watch Workouts** | ✅ | ❌ | All Watch workouts auto-flow to HealthKit |
| **Wahoo Fitness** | ✅ | ❌ | Cycling computers and trainers (iOS only) |
| **Eight Sleep** | ✅ | ❌ | Smart mattress sleep data (iOS only) |

### 🥗 Nutrition & Diet

| App | HK | HC | Notes |
|-----|----|----|-------|
| **Cal AI** | ✅ | ✅ | AI food photo → calories and macros |
| **MyFitnessPal** | ✅ | ✅ | Calorie + macro logging |
| **Cronometer** | ✅ | ✅ | Detailed macro + micronutrient tracking |
| **Lose It!** | ✅ | ✅ | Calorie counting, weight loss |
| **Carb Manager** | ✅ | ✅ | Keto / low-carb diet tracker |
| **Noom** | ✅ | ✅ | Reads steps/weight from health stores |
| **WaterMinder** | ✅ | ❌ | Hydration tracking (iOS only) |

### 🏋️ Strength & Gym

| App | HK | HC | Notes |
|-----|----|----|-------|
| **Fitbod** | ✅ | ✅ | AI-powered strength training |
| **Strong Workout** | ✅ | ✅ | Gym logging, weight tracking |
| **JEFIT** | ✅ | ✅ | Workout planner and tracker |
| **Peloton** | ✅ | ✅ | Connected classes (cycling, running, strength) |
| **TrainingPeaks** | ✅ | ❌ | Endurance training plans (iOS only) |

### 😴 Sleep & Recovery

| App | HK | HC | Notes |
|-----|----|----|-------|
| **Sleep Cycle** | ✅ | ✅ | Smart alarm, sleep stages |
| **Calm** | ✅ | ❌ | Mindful minutes (iOS only) |
| **Headspace** | ✅ | ✅ | Meditation and mindfulness |

### ⏱️ Fasting & Metabolic

| App | HK | HC | Notes |
|-----|----|----|-------|
| **Zero Fasting** | ✅ | ✅ | Intermittent fasting tracker |
| **Life Fasting** | ✅ | ✅ | Fasting + weight sync |

### 🩺 Health Monitoring

| App | HK | HC | Notes |
|-----|----|----|-------|
| **Flo Period Tracker** | ✅ | ✅ | Period, fertility, pregnancy |
| **Clue Period Tracker** | ✅ | ✅ | Cycle tracking + symptoms |
| **Glucose Buddy** | ✅ | ❌ | Blood glucose logging (iOS only) |
| **Blood Pressure Companion** | ✅ | ❌ | BP readings (iOS only) |

---

## Apps That Cannot Be Integrated (No API, No Health Store)

Apps that have no public API **and** don't write to the OS health store — these cannot be integrated at all currently:

| App | Reason |
|-----|--------|
| **Noom** (coaching content) | Only reads health data; its proprietary coaching content is walled |
| **Future** | Walled garden coaching platform |
| **Eight Sleep** (software) | No official public API; only HealthKit sleep data is accessible |

---

## In-App Implementation

The full 45-app list is also displayed in the Integrations Hub screen as a searchable "Compatible Apps" section, powered by `CompatibleAppsRegistry` (`zuralog/lib/features/integrations/domain/compatible_apps_registry.dart`). Each app shows platform badges (HK/HC), category, and an info bottom sheet explaining the data flow.
