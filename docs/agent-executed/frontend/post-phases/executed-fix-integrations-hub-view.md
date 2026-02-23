# Executed: Fix Integrations Hub View (Blank Screen)

**Branch:** `fix/integrations-hub-view`
**Date:** 2026-02-23
**Status:** Complete — 0 analyze issues, 208/209 tests pass (1 pre-existing failure in dashboard unrelated to this work)

---

## Summary

Fixed the Integrations Hub (third tab, route `/integrations`) which rendered as a completely blank white screen. The screen now correctly displays all six health app integrations grouped into Connected, Available, and Coming Soon sections with proper connect/disconnect UI and platform-aware greying.

---

## Root Cause

**`outlinedButtonTheme` `minimumSize: Size(double.infinity, ...)` layout crash.**

`app_theme.dart` configured `OutlinedButton` with `minimumSize: const Size(double.infinity, AppDimens.touchTargetMin)`. The `OutlinedButton('Connect')` inside `IntegrationTile` lives in a `Row` where an `Expanded` child gives it unbounded width constraints, triggering `BoxConstraints forces an infinite width`, which collapses the entire screen to blank. The same pattern was previously fixed for `TextButton` in the auth sprint but `OutlinedButton` was missed.

---

## Changes Made

### 1. `lib/core/theme/app_theme.dart`
- `outlinedButtonTheme.minimumSize` changed from `Size(double.infinity, ...)` to `Size.zero`
- Added `tapTargetSize: MaterialTapTargetSize.shrinkWrap` so touch targets remain accessible without forcing infinite width

### 2. `lib/features/integrations/domain/integration_model.dart`
- `logoAsset` field made nullable (`String?`)
- Constructor updated (no longer `required`)
- `copyWith` updated with `clearLogoAsset` bool flag to explicitly null the field

### 3. `lib/features/integrations/domain/integrations_provider.dart`
- Removed `.autoDispose` modifier — provider was re-creating on every tab switch causing blank flash
- Initial `IntegrationsState` default changed to `isLoading: true` (prevents "No integrations" flash)
- All 6 seed `IntegrationModel` entries have `logoAsset` removed (non-existent asset paths eliminated)
- Fitbit and Health Connect changed from `available` to `comingSoon` (they fell through to a "Coming soon!" snackbar anyway)

### 4. `lib/features/integrations/presentation/integrations_hub_screen.dart`
- Removed redundant `loadIntegrations()` call from `initState` (provider factory already calls it via `Future.microtask`)

### 5. `lib/features/integrations/presentation/widgets/integration_logo.dart`
- Accepts nullable `logoAsset`; skips `Image.asset` entirely when null and renders `_InitialsFallback` directly
- Eliminates all asset-not-found crashes without needing placeholder files

### 6. `lib/features/dashboard/presentation/widgets/integrations_rail.dart`
- Local `_IntegrationLogo` widget `logoAsset` field made nullable (`String?`)
- `build()` short-circuits to initials fallback when `logoAsset == null`

### 7. `test/features/integrations/presentation/integrations_hub_screen_test.dart`
- `IntegrationModel` fixtures updated: removed now-invalid `logoAsset` arguments
- `findsOneWidget` for `'Connected'` changed to `findsWidgets` — both the section header and the `_ConnectedBadge` on each connected tile render that text, so exact-one would always fail with real data

### 8. `test/features/integrations/presentation/widgets/integration_tile_test.dart`
- Complete rewrite of stale `CupertinoSwitch`-era tests
- Now covers: `OutlinedButton('Connect')` for available, `'Connected'` badge + `Icons.link_off_rounded` for connected, `'Soon'` badge for comingSoon, `0.5` opacity for comingSoon, disconnect sheet tap flow, initials fallback for null logoAsset
- Removed unused `_iosOnlyModel` fixture (caused `unused_element` analyzer warning)

---

## Deviations from Original Plan

- **No `assets/integrations/` directory created.** Instead `logoAsset` was made nullable. This is simpler and avoids needing placeholder images that would later be replaced anyway.
- **`_IntegrationLogo` in `integrations_rail.dart` patched in-place** rather than switching to the shared `IntegrationLogo` widget from the integrations feature, to minimise diff surface.

---

## Test Results

```
flutter analyze  →  No issues found
flutter test     →  208 passed, 1 failed (pre-existing: DashboardScreen "Alex" name test — unrelated)
```

All 23 integrations-specific tests pass (hub screen: 7, tile: 12, disconnect sheet: 4).

---

## Next Steps

- The `DashboardScreen shows user name "Alex"` test is a pre-existing failure; the stub user provider no longer surfaces `displayName` to that widget. That should be fixed in the dashboard sprint.
- Real brand assets (`assets/integrations/strava.png`, etc.) can be added at any time. Setting `logoAsset` on the `IntegrationModel` seeds will immediately render them without any other code change.
- OAuth `connect()` flows for Strava and Apple Health / Health Connect need real implementation (currently they show a "Coming soon!" snackbar or open a URL stub).
