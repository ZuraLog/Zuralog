# Phase 2.3.3: Loading States & Haptics

**Parent Goal:** Phase 2.3 Navigation & Polish
**Checklist:**
- [x] 2.3.1 Router Setup
- [x] 2.3.2 Animations & Transitions
- [x] 2.3.3 Loading States & Haptics

---

## What
Replace generic circular spinners with "Skeleton/Shimmer" loaders and add tactile feedback.

## Why
Shimmer loaders make the app feel faster (perceived performance). Haptics verify actions without looking.

## How
Use `shimmer` package and `HapticFeedback` class.

## Features
- **Skeleton Loader:** Grey boxes pulsing while data fetches on Dashboard.
- **Haptics:**
    - `Light`: Tab change.
    - `Medium`: Button press.
    - `Heavy`: Error or Success.

## Files
- Create: `zuralog/lib/shared/widgets/loaders/skeleton_loader.dart`
- Modify: `zuralog/lib/features/dashboard/presentation/dashboard_screen.dart`

## Steps

1. **Create Skeleton Loader**
   - Widget that accepts `width` and `height` and animates a gradient overlay.

2. **Add Haptics**
   - `onPressed: () { HapticFeedback.mediumImpact(); ... }`

## Exit Criteria
- No "Is it working?" moments for the user.
