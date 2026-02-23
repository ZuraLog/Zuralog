# Executed: Side Panel Fixes & Profile Avatar Unification

**Branch:** `fix/side-panel-and-profile-button` (merged to `main`)
**Date:** 2026-02-23
**Status:** Complete — 0 analyze issues, 209/209 tests pass

---

## Summary

Three distinct issues were resolved in this session:

1. **Side panel black void gap** — The `ClipRRect` rounded left-edge on `ProfileSidePanelWidget` caused a visible black gap between the translated scaffold and the panel edge.
2. **No scrim on panel open** — The 20 % exposed content strip had no dimming, making the panel fail to visually dominate the screen.
3. **Inconsistent profile avatar** — The dashboard header used a generic `Icons.person_rounded` icon that did not match the initial-letter avatar in the side panel. The profile avatar button was also absent from the Coach and Apps tabs.

---

## Changes Made

### 1. `lib/shared/widgets/profile_side_panel.dart`
- Removed the `ClipRRect` wrapper with `borderRadius: BorderRadius.only(topLeft: 24, bottomLeft: 24)`.
- The panel is now a flat `Material` — square-edged and flush with both the screen boundary and the translated scaffold, eliminating the black void.
- Removed the now-unused `_kPanelRadius` constant.

### 2. `lib/shared/layout/app_shell.dart`
- Added a `_kScrimMaxOpacity = 0.60` constant.
- Added a third `AnimatedBuilder` layer in the `Stack` (between scaffold and panel) that renders a `Colors.black` `ColoredBox` animated from 0 → 60 % opacity as the panel opens.
- The scrim covers the full screen and its `GestureDetector` handles tap-to-close, replacing the old detector that sat on the scaffold.
- Updated doc comments and the widget-tree diagram to reflect the new three-layer stack structure.

### 3. `lib/shared/widgets/profile_avatar_button.dart` *(new file)*
- New shared `ConsumerWidget` that reads `userProfileProvider` (same source as the side panel header) to derive the user's display name initial.
- Renders a `CircleAvatar` with `AppColors.primary` at 85 % opacity and the initial letter — visually identical to the side panel avatar.
- Tapping sets `sidePanelOpenProvider = true`, opening the panel.

### 4. `lib/features/dashboard/presentation/dashboard_screen.dart`
- Replaced the inline `GestureDetector → CircleAvatar(Icons.person_rounded)` in `_buildHeader` with `const ProfileAvatarButton()`.
- Removed the now-unused `sidePanelOpenProvider` import.

### 5. `lib/features/chat/presentation/chat_screen.dart`
- Added `ProfileAvatarButton` as the rightmost action in the Coach screen's `AppBar` (after the existing `_ConnectionDot`).

### 6. `lib/features/integrations/presentation/integrations_hub_screen.dart`
- Added `ProfileAvatarButton` to the `SliverAppBar` `actions` in the Integrations (Apps) screen.

---

## Deviations from Original Request

- **No rounded corner retained on panel.** The request was to "remove the curve." Rather than just reducing the radius, the `ClipRRect` was removed entirely — a complete removal is cleaner and eliminates the root cause (any non-zero radius would still produce a visible gap at the seam).
- **Scrim covers full screen, not just the 20 % strip.** Positioning the scrim over exactly the 20 % strip would require computing the translated offset each frame and coordinating with the scaffold animation. A full-screen `Positioned.fill` is simpler, produces identical visual results (the panel itself occludes the 80 % right portion), and keeps the tap-to-close gesture unified.

---

## Test Results

```
flutter analyze  →  No issues found
flutter test     →  209/209 passed (0 failures)
```

---

## Next Steps

- The `ProfileAvatarButton` currently falls back to `'?'` when no profile is loaded. A skeleton/shimmer state could be added once profile loading latency is measurable on real devices.
- Tap target on `ProfileAvatarButton` inside `SliverAppBar` should be verified on small-screen devices (the `CircleAvatar` radius matches `AppDimens.avatarMd / 2`; if that is below 44 px the hit area may need an `InkWell` wrapper with explicit padding).
