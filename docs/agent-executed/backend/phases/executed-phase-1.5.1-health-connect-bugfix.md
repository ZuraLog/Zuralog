# Executed Phase 1.5.1: Google Health Connect — Connection Bug Fix

> **Branch:** `feat/fix-health-connect`
> **Merged to main:** `09884ab`
> **Date:** 2026-02-23
> **Status:** Complete — merged to main

---

## Summary

Phase 1.5 delivered the full Health Connect native implementation but left three critical bugs that prevented users from ever successfully connecting: the permission dialog was never shown, the connect button dispatched to "Coming soon!", and several data-type permissions were missing from the manifest. This phase fixed all root causes through 9 atomic commits across 9 files.

---

## Root Causes Fixed

| # | Root Cause | Severity | File(s) |
|---|-----------|----------|---------|
| 1 | `AndroidManifest.xml` missing `READ_RESTING_HEART_RATE`, `READ_HEART_RATE_VARIABILITY`, `READ_VO2_MAX` — Health Connect silently rejects ungrouped permissions | Critical | `AndroidManifest.xml` |
| 2 | `requestAuthorization` handler only called `hasAllPermissions()` — never launched the system permission dialog | Critical | `MainActivity.kt` |
| 3 | `IntegrationsNotifier.connect()` had no `'google_health_connect'` case — fell through to "Coming soon!" | Critical | `integrations_provider.dart` |
| 4 | Health Connect SDK pinned to `alpha07` — unstable for production | High | `build.gradle.kts` |
| 5 | Integration connected-state was in-memory only — reset on every app restart | Medium | `integrations_provider.dart` |
| 6 | `TotalCaloriesBurnedRecord` was in the manifest but not in `REQUIRED_PERMISSIONS` — never requested at runtime | Medium | `HealthConnectBridge.kt` |
| 7 | HRV chip displayed same label for RMSSD (Android) and SDNN (iOS) — different metrics | Low | `dashboard_screen.dart` |

---

## What Was Actually Built

### Android Layer

**`AndroidManifest.xml`**
- Added `READ_RESTING_HEART_RATE`, `READ_HEART_RATE_VARIABILITY`, `READ_VO2_MAX`
- Removed dead `WRITE` permissions for read-only cardiac metrics (`WRITE_RESTING_HEART_RATE`, etc.)
- Removed unused `READ_HEART_RATE` / `WRITE_HEART_RATE` (no corresponding bridge method)
- Added grouping comments for readability
- Final state: 10 READ + 7 WRITE permissions, in exact 1-to-1 alignment with `REQUIRED_PERMISSIONS`

**`HealthConnectBridge.kt`**
- Moved `requiredPermissions` instance field to a `companion object` as `REQUIRED_PERMISSIONS: Set<String>` — accessible statically by `MainActivity` without an instance
- Added `TotalCaloriesBurnedRecord` to `REQUIRED_PERMISSIONS` (was missing despite being queried and manifest-declared)
- Updated `hasAllPermissions()` to reference the companion constant

**`MainActivity.kt`**
- Added `ActivityResultLauncher<Set<String>>` field registered in `onCreate()` before `super.onCreate()` — the only valid lifecycle point
- Added `pendingPermissionResult: MethodChannel.Result?` field for the async bridge-back pattern
- Replaced the `"requestAuthorization"` handler: now checks permissions first (fast path returns `true`), otherwise stores the `MethodChannel.Result` and launches the Health Connect dialog; the launcher callback resolves the stored result
- Added a double-call guard (`if (pendingPermissionResult != null) → result.error("ALREADY_PENDING", ...)`) to prevent result leaking on rapid re-invocations
- Added KDoc docstrings to `onCreate`, the launcher callback, and the handler body

**`build.gradle.kts`**
- Upgraded `androidx.health.connect:connect-client` from `1.1.0-alpha07` to `1.1.0` (stable)

### Dart Layer

**`integrations_provider.dart`**
- Added `case 'google_health_connect':` to `IntegrationsNotifier.connect()` switch
- Guard: calls `_healthRepository.isAvailable()` before `requestAuthorization()`; shows snackbar directing to Play Store if Health Connect is not installed
- On success: sets status to `connected` and persists via `SharedPreferences`
- Added `_saveConnectedState()` and `_loadPersistedStates()` private methods with full KDoc docstrings
- Added `_connectedPrefix` static const (`'integration_connected_'`)
- Constructor now calls `unawaited(_loadPersistedStates())` with `.catchError` logging — restores connected status on cold launch
- `disconnect()` now clears persisted state via `unawaited(_saveConnectedState(..., connected: false))` with `.catchError` logging
- Updated `catch (_)` in `connect()` to `catch (e, st)` with `debugPrint` logging
- Updated `'apple_health'` case to also persist connected state

**`health_repository.dart`**
- Changed `isAvailable` from a Dart getter to a proper `Future<bool> isAvailable()` method for consistent async call-site usage

**`daily_summary.dart`**
- Added full platform-aware docstring to `hrv` field documenting the Android=RMSSD / iOS=SDNN distinction

**`dashboard_screen.dart`**
- Added optional `String? subtitle` parameter to `_StatChip` widget (non-breaking — existing call sites unchanged)
- HRV chip now passes `subtitle: Platform.isAndroid ? 'RMSSD' : 'SDNN'`
- HRV chip null value now renders `'—'` instead of the previous `'null ms'`
- Added `import 'dart:io' show Platform;`

---

## Deviations from Plan

| # | Original Plan | Actual |
|---|---------------|--------|
| 1 | Plan specified `1.1.0-rc01` for the SDK upgrade | Used `1.1.0` (full stable, released 2025-10-08) — strictly better |
| 2 | Plan listed Tasks 1–9 as separate phases | Tasks 4–6 (connect case, persistence, availability guard) were merged into a single commit `3e6c28f` for cohesion — all three touch `integrations_provider.dart` |
| 3 | Plan suggested `isAvailable` as a check via a separate method | `isAvailable` already existed as a getter in `health_repository.dart`; it was converted to a method to match the `()` call pattern consistently used elsewhere |

---

## Next Steps

- **Play Store Console:** The account owner must declare the Health Connect data types in Play Console → App content → Health Connect before any production release.
- **Background Sync Worker (`HealthSyncWorker.kt`):** Still a stub (`TODO(Phase 1.10)`). Full Cloud Brain push deferred — tracked in Phase 1.10.
- **HRV Normalization:** RMSSD and SDNN are documented as different but are not normalized. A future phase may apply a conversion factor or show platform-specific labels in more places (e.g., the weekly trend view).
- **`writeWorkout` energy discarded:** Pre-existing issue in `HealthConnectBridge.kt` — `energyBurned` parameter is accepted but never passed to `ExerciseSessionRecord`. Tracked as a minor follow-up.
