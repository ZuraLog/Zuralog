# Executed: Fix Health Connect Connection Status

**Date:** 2026-02-24
**Scope:** Frontend (Flutter) + Native (Android Kotlin, iOS Swift)
**Branch:** `fix/health-connect-connection-status`

## Summary

Fixed a race condition in `IntegrationsNotifier` that caused the Integrations Hub
to show "Connect" instead of "Connected" for Google Health Connect and Apple Health
after permissions were granted, even across app restarts.

## Root Cause

The `IntegrationsNotifier` constructor fired `_loadPersistedStates()` via `unawaited()`
which mapped over `state.integrations` — but the integration list was still empty because
`loadIntegrations()` (which populates the list) ran via `Future.microtask()` after the
constructor completed. The persisted connected flags were applied to an empty list and
silently discarded.

## Changes

### Core Fix (`integrations_provider.dart`)
- Removed `_loadPersistedStates()` from the constructor
- Merged SharedPreferences restoration into `loadIntegrations()` — persisted states
  are now always restored AFTER the integration list is populated
- Made `loadIntegrations()` `Future<void>` to support SharedPreferences read + permission verification
- Deleted the standalone `_loadPersistedStates()` method

### Permission Verification (New)
- Added passive `checkPermissions()` method to `HealthBridge` (Dart), `HealthRepository`,
  `MainActivity.kt` (Android), and `HealthKitBridge.swift`/`AppDelegate.swift` (iOS)
- On each `loadIntegrations()` call, verifies actual permission state with the native platform
- If permissions were revoked in system settings, reverts integration to "Available" and
  clears the stale SharedPreferences entry

### Tests (New & Updated)
- Added `integrations_notifier_test.dart` with 8 tests covering:
  - Persisted state restoration for Health Connect and Apple Health
  - Pull-to-refresh preservation of persisted states
  - Permission revocation detection and status reversion
  - SharedPreferences cleanup on revocation
  - Default integration loading
  - Non-health integration isolation
  - isLoading false after load
- Updated existing stub notifiers in 3 test files (`integrations_hub_screen_test.dart`,
  `integration_tile_test.dart`, `dashboard_screen_test.dart`) for `Future<void>` signature

## Deviations from Plan

- **Task 6 scope expanded**: The plan only mentioned updating `integrations_hub_screen_test.dart`. Code review revealed two additional files (`integration_tile_test.dart`, `dashboard_screen_test.dart`) also had the broken `void loadIntegrations()` stub. All three were fixed.
- **Unused import**: An unused `health_bridge.dart` import in `integrations_notifier_test.dart` (introduced during Task 4) was removed in Task 6 to keep `flutter analyze` clean.
- **iOS permission strategy**: The plan's Task 2 originally used `HKQuantityType(.stepCount)` as the proxy write type. Execution used `HKQuantityType(.bodyMass)` instead (confirmed in the previous session notes) — write authorization status for `bodyMass` is more reliably reported by HealthKit for the permissions this app requests.

## Affected Files

- `lib/features/integrations/domain/integrations_provider.dart` — core fix
- `lib/features/integrations/presentation/integrations_hub_screen.dart` — async refresh
- `lib/core/health/health_bridge.dart` — new `checkPermissions()` method
- `lib/features/health/data/health_repository.dart` — new `checkPermissions()` method
- `android/app/src/main/kotlin/com/zuralog/zuralog/MainActivity.kt` — new handler
- `ios/Runner/HealthKitBridge.swift` — new method
- `ios/Runner/AppDelegate.swift` — new handler
- `test/features/integrations/domain/integrations_notifier_test.dart` — new tests (8 tests)
- `test/features/integrations/presentation/integrations_hub_screen_test.dart` — stub updated
- `test/features/integrations/presentation/widgets/integration_tile_test.dart` — stub updated
- `test/features/dashboard/presentation/dashboard_screen_test.dart` — stub updated

## Final State

- **226/226 tests pass**
- **`flutter analyze`: No issues found**
- **Branch:** `fix/health-connect-connection-status` — ready for review and merge

## Next Steps

- Manual QA on physical Android device with Health Connect: connect, force-close, reopen — verify status persists
- Manual QA on iOS device with HealthKit: same flow
- Consider adding an integration test for the full connect → restart → verify flow
- Follow-up: extract `_healthIntegrationIds` as a `static const` to eliminate magic string duplication between `loadIntegrations()` and `connect()`
