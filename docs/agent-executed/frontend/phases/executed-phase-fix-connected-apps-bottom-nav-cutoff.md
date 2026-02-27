# Executed Phase: Fix Connected Apps Cut Off by Bottom Nav Bar

**Branch:** `fix/connected-apps-bottom-nav-cutoff`  
**Merged to:** `main` (`bf3a91b`)  
**Date:** 2026-02-27

---

## Summary

Fixed the "Connected Apps" (`IntegrationsRail`) section on the Dashboard being hidden behind the floating bottom navigation bar when the user scrolled to the bottom of the screen.

**File changed:** `zuralog/lib/features/dashboard/presentation/dashboard_screen.dart`

---

## Root Cause

The last sliver in the dashboard `CustomScrollView` had a static `SizedBox(height: AppDimens.spaceXxl)` (48 px) as its bottom clearance. The bottom navigation bar is 80 px tall (`AppDimens.bottomNavHeight`), so the rail was partially obscured on all devices, and fully obscured on devices with a non-zero safe-area bottom inset.

---

## What Was Built

Replaced the static spacer with dynamic `SliverPadding` bottom padding:

```dart
// BEFORE
SliverPadding(
  padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
  sliver: SliverToBoxAdapter(
    child: Column(children: [
      const SizedBox(height: AppDimens.spaceSm),
      IntegrationsRail(...),
      const SizedBox(height: AppDimens.spaceXxl), // 48 px — too short
    ]),
  ),
),

// AFTER
SliverPadding(
  padding: EdgeInsets.fromLTRB(
    AppDimens.spaceMd,
    0,
    AppDimens.spaceMd,
    AppDimens.bottomNavHeight +          // 80 px nav bar
        MediaQuery.of(context).padding.bottom + // device safe-area
        AppDimens.spaceMd,               // 16 px breathing room
  ),
  sliver: SliverToBoxAdapter(
    child: Column(children: [
      const SizedBox(height: AppDimens.spaceSm),
      IntegrationsRail(...),
      // SizedBox removed — clearance handled by sliver padding
    ]),
  ),
),
```

---

## Deviations from Original Plan

None — this was a straightforward, isolated fix with no architectural changes.

---

## Verification

- Visually confirmed on `emulator-5554` in dark mode: the Google Health Connect card in the Connected Apps section is fully visible with comfortable clearance above the bottom nav bar.
- `flutter analyze` reported **No issues found**.

---

## Next Steps

All known dashboard UI bugs are now resolved and merged to `main`. The dashboard is in a stable, production-quality state. Future work should refer to the PRD for the next planned phase.
