# Phase 2.3.2: Animations & Transitions

**Parent Goal:** Phase 2.3 Navigation & Polish
**Checklist:**
- [x] 2.3.1 Router Setup
- [x] 2.3.2 Animations & Transitions
- [ ] 2.3.3 Loading States & Haptics

---

## What
Add "Delight" to the UI with smooth page transitions and micro-interactions.

## Why
A static app feels cheap. Motion guides the user's attention.

## How
Use `PageTransitionsTheme` and `flutter_animate`.

## Features
- **Page Transitions:** Slide Right (iOS style) or Fade Up (Android 14 style).
- **Hero Animations:** Shared elements between screens (e.g., Profile Avatar).
- **Micro-interactions:** Buttons scale down slightly when pressed.

## Files
- Modify: `life_logger/lib/core/theme/app_theme.dart`
- Create: `life_logger/lib/shared/animations/scale_button.dart`

## Steps

1. **Configure Theme Transitions**
   - In `AppTheme`, set `pageTransitionsTheme` to `ZoomPageTransitionsBuilder` or `CupertinoPageTransitionsBuilder`.

2. **Add Micro-interactions**
   - Wrap `PrimaryButton` in a `ScaleButton` widget that handles the press animation.

## Exit Criteria
- Navigation feels smooth.
- Buttons respond to touch.
