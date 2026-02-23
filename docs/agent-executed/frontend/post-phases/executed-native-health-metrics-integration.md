# Executed: Native Health Metrics Integration (Smoke Test 3 + Dashboard Data)

**Branch:** `feat/native-health-metrics` (merged to `main`)
**Date:** 2026-02-23
**Preceded by:** `feat/smoke-test-3-fixes` (push-reveal panel, hero dedup, Health Connect status, RHR/HRV/Cardio chips)

---

## Summary

Two sessions of work were completed before this merge:

### Session A — Smoke Test 3 Fixes (`feat/smoke-test-3-fixes`)
Addressed all four Smoke Test 3 issues plus a chip-content swap:
1. **Push-reveal side panel** — `AppShell` rewritten as `ConsumerStatefulWidget` with `AnimationController`; full app shell slides left 80% of screen width; no scrim overlay; `sidePanelOpenProvider` (`StateProvider<bool>`) is the single source of truth.
2. **Hero row deduplication** — `ActivityRings` gained `showPillRow` param; dashboard `_HeroRow` passes `showPillRow: false`.
3. **Google Health Connect status** — changed `comingSoon` → `available`; Android-only badge shown on iOS.
4. **Quick-stat chips** — `_QuickStatChips` strip added between hero row and metrics grid.
5. **Chip content swap** — Chips changed from Workouts/Nutrition/Sleep Quality → **Resting HR / HRV / Cardio Fitness Level**.
6. **`DailySummary` model extended** — Added `restingHeartRate` (int?), `hrv` (double?), `cardioFitnessLevel` (double?) with JSON deserialization.
7. **Native RHR / HRV / VO2 max reads** — Full platform stack added on both iOS (HealthKitBridge) and Android (HealthConnectBridge); `dailySummaryProvider` uses Cloud Brain API as primary source and falls back to native reads for any null cardio field.

### Session B — Full Native Metrics Integration (`feat/native-health-metrics`)
Audit revealed steps, sleep hours, calories burned, and calories consumed had NO native fallback — they were API-only with zero offline resilience. Fixed:

---

## What Was Actually Built (Session B)

### iOS — `HealthKitBridge.swift`
- Added `fetchActiveCaloriesBurned(date:)` — `HKStatisticsQuery` `.cumulativeSum` on `activeEnergyBurned` for midnight-to-midnight window; returns kcal as `Double?`.
- Added `fetchNutritionCalories(date:)` — same pattern on `dietaryEnergyConsumed`; returns kcal as `Double?`.

### iOS — `AppDelegate.swift`
- Added `"getCaloriesBurned"` and `"getNutrition"` channel cases (both take a single `date` ms argument).

### Android — `HealthConnectBridge.kt`
- Added `readActiveCaloriesBurned(dateMillis)` — sums `ActiveCaloriesBurnedRecord` for day window; returns `Double?`.
- Added `readNutritionCalories(dateMillis)` — sums `NutritionRecord.energy?.inKilocalories` for day window; returns `Double?`.

### Android — `MainActivity.kt`
- Added `"getCaloriesBurned"` and `"getNutrition"` channel cases (both take a single `date` ms argument).

### Dart — `HealthBridge` (`health_bridge.dart`)
- Replaced broken list-based `getNutrition(startDate, endDate)` (which always hit `notImplemented` on both platforms) with:
  - `getCaloriesBurned(date)` → `double?`
  - `getNutritionCalories(date)` → `double?`

### Dart — `HealthRepository` (`health_repository.dart`)
- Replaced `getNutrition(startDate, endDate)` with `getCaloriesBurned(date)` and `getNutritionCalories(date)`.

### Dart — `DailySummary` (`daily_summary.dart`)
- Added `copyWith({...})` method — enables clean merging of native fallback values into an API-sourced summary without full reconstruction.

### Dart — `dailySummaryProvider` (`analytics_providers.dart`)
Complete rewrite. Now implements a **two-source merge strategy** for all six primary metrics:

**Merge priority:** Cloud Brain API (non-zero/non-null) > native bridge > original zero/null

**Per-metric fallback logic:**
| Metric | API zero/null condition | Native call |
|---|---|---|
| Steps | `summary.steps == 0` | `healthRepo.getSteps(today)` |
| Sleep Hours | `summary.sleepHours == 0.0` | `healthRepo.getSleep(sleepStart, sleepEnd)` → `_sumSleepHours()` |
| Calories Burned | `summary.caloriesBurned == 0` | `healthRepo.getCaloriesBurned(today)` |
| Calories Consumed | `summary.caloriesConsumed == 0` | `healthRepo.getNutritionCalories(today)` |
| Resting HR | `summary.restingHeartRate == null` | `healthRepo.getRestingHeartRate()` |
| HRV | `summary.hrv == null` | `healthRepo.getHRV()` |
| Cardio Fitness | `summary.cardioFitnessLevel == null` | `healthRepo.getCardioFitness()` |

**Sleep window:** yesterday 6 pm → today 12 noon (captures cross-midnight sessions).
**All native reads fire in parallel** via `Future.wait`.
**`_sumSleepHours()`** handles both iOS key names (`startDate`/`endDate`) and Android key names (`startTime`/`endTime`).

### Dart — `HarnessScreen` (`harness_screen.dart`)
- Updated `_readNutrition()` to use the new `getNutritionCalories(today)` scalar API.

---

## Deviations from Original Plan

1. **`getNutrition` was completely broken** — the old list-based Dart method called `invokeMethod('getNutrition')` with `startDate`/`endDate` args, but neither `AppDelegate.swift` nor `MainActivity.kt` had a handler for it. It silently returned `[]` on every call. Rather than patching the broken path, the entire API surface was replaced with two scalar methods (`getCaloriesBurned` + `getNutritionCalories`) that match what the native implementations actually return.

2. **`DailySummary.copyWith` added** — the original model had no `copyWith`. Rather than reconstructing the full model in the provider (error-prone, verbose), `copyWith` was added to the domain model itself — the cleaner pattern.

3. **Sleep window is heuristic** — native sleep segments don't map cleanly to "last night's hours." The chosen window (yesterday 6 pm → today 12 noon) captures cross-midnight sessions reliably. The Cloud Brain API value (when available) is always preferred and computed with full context.

---

## Activity Rings — Data Flow (Confirmed Functional)

The `ActivityRings` widget in `_HeroRow` (`dashboard_screen.dart`) consumes:
- **Outer ring (Steps):** `summary.steps` from `dailySummaryProvider` — now backed by native `getSteps` fallback.
- **Middle ring (Sleep):** `summary.sleepHours` — now backed by native `getSleep` + `_sumSleepHours` fallback.
- **Inner ring (Calories):** `summary.caloriesBurned` — now backed by native `getCaloriesBurned` fallback.

Ring goals are still hardcoded (10 000 steps / 8 hrs / 600 kcal) — user-configurable goals are deferred to a future phase.

---

## Next Steps

- User-configurable ring goals (steps/sleep/calories targets per user profile)
- Background sync of native health data to Cloud Brain (Phase 1.10 `TODO` already noted in `HealthKitBridge.swift`)
- `writeNutrition` / `getNutrition` list-based reads for food logging UI (separate from the scalar daily-total used here)
- WorkManager (Android) periodic sync of steps/calories to Cloud Brain to reduce API zero-values
