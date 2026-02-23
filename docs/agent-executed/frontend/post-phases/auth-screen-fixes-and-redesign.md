# Auth Screen Fixes and Redesign

**Date:** 2026-02-23
**Branch:** `feat/fix-auth-screens-and-navigation`
**Commit SHA:** `14029de`
**Agent:** Claude Code (claude-sonnet-4-6)
**Status:** Complete — committed, pending PR to main

---

## Overview

A focused bugfix and redesign sprint targeting the auth flow. The `RegisterScreen` and `LoginScreen` were rendering as completely blank white screens on all devices. Additionally, back buttons were broken across the auth flow, the `WelcomeScreen` needed a full redesign to match the approved reference design, and the Zuralog SVG logo needed to be integrated (previously the app only supported the PNG variant).

---

## Root Cause: Blank White Screens

The `textButtonTheme` in `app_theme.dart` applied `minimumSize: Size(double.infinity, 48)` globally to **all** `TextButton` widgets. The "Don't have an account? Sign up" and "Already have an account? Log in" links were `TextButton` widgets placed inside a `Row(mainAxisSize: MainAxisSize.min)`. When Flutter tried to lay out an `infinity`-width widget inside a `min`-sized Row that was itself inside a Column, the constraint system generated a layout overflow that collapsed the entire `Column`, producing a blank white screen.

The fix was to change the global `textButtonTheme` to `minimumSize: Size.zero` with `tapTargetSize: MaterialTapTargetSize.shrinkWrap`. The `SecondaryButton` widget (which genuinely needs full-width fill behaviour) was updated to own its style explicitly rather than inheriting from the global theme.

---

## What Was Built

### 1. TextButton Theme Fix (`app_theme.dart`, `secondary_button.dart`)

Changed the global `textButtonTheme` to shrink-wrap, eliminating the layout conflict. `SecondaryButton` was rewritten to apply its full-width filled style explicitly via `TextButton.styleFrom()` so it is no longer dependent on the global theme.

### 2. SVG Logo Integration

Added `flutter_svg: ^2.0.17` to `pubspec.yaml`. Copied the SVG logo from `assets/brand/logo/Zuralog.svg` into `zuralog/assets/images/zuralog_logo.svg` for use in the Flutter asset bundle.

Note: The SVG file is actually a base64-encoded PNG bitmap wrapped in an SVG container — `flutter_svg` renders it correctly, and the `<filter/>` element warnings that appear in tests are harmless (test renderer skips unsupported SVG filters).

### 3. WelcomeScreen — "Clean Gate" Redesign (`welcome_screen.dart`)

Completely rewrote the screen to match the reference design at `docs/stitch/zuralog_welcome_and_authentication/screen.png`:

- White background
- Zuralog SVG logo in a sage green rounded card with a soft shadow
- App name and tagline below the card
- "Continue with Apple" — black filled pill button
- "Continue with Google" — outlined pill button
- `—— or ——` divider
- "Log in with Email" — shrink-wrapped `TextButton`
- `RichText` legal footer with tappable Terms of Service and Privacy Policy links
- Apple and Google buttons show a "Coming soon" floating `SnackBar` (OAuth not yet implemented)

### 4. First-Launch Onboarding Gate (`auth_providers.dart`, `app_router.dart`, `onboarding_page_view.dart`)

Added `hasSeenOnboardingProvider` — a `FutureProvider<bool>` backed by `SharedPreferences` — so first-launch users see the onboarding slides and returning users go directly to the `WelcomeScreen`.

- `markOnboardingComplete()` writes the flag to `SharedPreferences`
- Onboarding "Skip" and "Get Started" buttons call `markOnboardingComplete()` then `context.go(RouteNames.welcomePath)`
- `app_router.dart` uses a `_RouterRefreshListenable` that listens to both `authStateProvider` and `hasSeenOnboardingProvider`, and adds a redirect rule: if navigating to `/welcome` and `hasSeenOnboarding == false`, redirect to `/onboarding`

### 5. Login and Register Screen Fixes (`login_screen.dart`, `register_screen.dart`)

Both screens received:
- An explicit `leading: IconButton(Icons.arrow_back_ios_new_rounded)` back button using `context.canPop() ? context.pop() : context.go(welcomePath)`, fixing the broken back navigation
- The Zuralog SVG logo in the `AppBar` via `SvgPicture.asset` with a `colorFilter` for theme adaptation
- Explicit `color: colorScheme.onSurface` on heading text (was invisible against the white background without this)
- Floating `SnackBarBehavior.floating` on all snack bars

Additionally, the `LoginScreen` "Sign up" link was changed from `context.push()` to `context.pushReplacement()` to prevent stack accumulation (navigating Login → Register → back → Login → Register would stack indefinitely).

### 6. Orphaned Screen Removed (`auth_selection_screen.dart`)

`AuthSelectionScreen` was fully orphaned — not registered in the router, not imported anywhere. Its intended functionality (Apple / Google / Email auth options) was already covered by the redesigned `WelcomeScreen`. The file was deleted.

### 7. Dashboard Tab Switching Fix (`dashboard_screen.dart`)

Two CTAs in the dashboard were using `context.go(RouteNames.chatPath)` and `context.go(RouteNames.integrationsPath)` to switch between `StatefulShellRoute` branches. Using `context.go()` for intra-shell navigation discards the shell's tab state. Replaced with `StatefulNavigationShell.of(context).goBranch(1)` and `.goBranch(2)` respectively.

### 8. Test Suite Update (`welcome_screen_test.dart`)

Completely rewrote `welcome_screen_test.dart` for the new "Clean Gate" design. Tests cover:
- SVG logo widget is present
- App name and tagline text
- Apple, Google, and Email CTA buttons
- Legal footer `RichText`
- Sage green container colour
- Navigation to `/auth/login` on "Log in with Email"
- "Coming soon" `SnackBar` on Apple and Google buttons
- Uses `hasSeenOnboardingProvider.overrideWith(() => AsyncValue.data(true))` to bypass the async SharedPreferences redirect in the router

---

## Deviations from Any Prior Plan

This was an unplanned bugfix sprint with no prior specification. The session was driven entirely by discovered issues. No spec existed to deviate from.

The one significant design decision made during execution was to **delete** `AuthSelectionScreen` rather than wire it into the router, because the redesigned `WelcomeScreen` already subsumes its role entirely.

---

## Files Changed

### Modified

| File | Change |
|------|--------|
| `pubspec.yaml` / `pubspec.lock` | Added `flutter_svg: ^2.0.17` |
| `lib/core/theme/app_theme.dart` | `textButtonTheme` changed to `Size.zero` + `shrinkWrap` |
| `lib/shared/widgets/buttons/secondary_button.dart` | Explicit full-width filled style, no longer inherits from global theme |
| `lib/features/auth/presentation/onboarding/welcome_screen.dart` | Complete rewrite — "Clean Gate" auth home design |
| `lib/features/auth/presentation/onboarding/onboarding_page_view.dart` | Fixed navigation targets + `markOnboardingComplete()` calls |
| `lib/features/auth/presentation/auth/login_screen.dart` | Back button, SVG logo, explicit text color, `pushReplacement` for Sign up link |
| `lib/features/auth/presentation/auth/register_screen.dart` | Back button, SVG logo, explicit text color |
| `lib/features/auth/domain/auth_providers.dart` | Added `hasSeenOnboardingProvider`, `markOnboardingComplete()`, `_kHasSeenOnboarding` |
| `lib/core/router/app_router.dart` | `_RouterRefreshListenable` dual-listener, first-launch redirect rule |
| `lib/features/dashboard/presentation/dashboard_screen.dart` | `context.go()` → `goBranch()` for intra-shell tab switching |
| `test/features/auth/presentation/welcome_screen_test.dart` | Complete rewrite for new design |

### Deleted

| File | Reason |
|------|--------|
| `lib/features/auth/presentation/auth/auth_selection_screen.dart` | Orphaned — functionality merged into redesigned `WelcomeScreen` |

### Added

| File | Purpose |
|------|---------|
| `assets/images/zuralog_logo.svg` | SVG logo asset for Flutter bundle |

---

## Test Results

- **Tests passing:** 205 / 205
- **`flutter analyze`:** 0 issues
- **SVG `<filter/>` warnings in test output:** Harmless — `flutter_svg` test renderer skips unsupported SVG filter elements; no tests fail because of this

---

## Navigation Flow After This Sprint

```
[First Launch]              [Returning Launch]
/onboarding  ──────────→   /welcome  (Clean Gate)
  (sets flag)                   │
                          Apple / Google → "Coming soon" SnackBar
                          Log in with Email → context.push(/auth/login)
                                                  │  back → context.pop()
                                                  Sign up → context.pushReplacement(/auth/register)
                                                                │  back → context.pop()
                                                                Log in → context.pushReplacement(/auth/login)
```

---

## Architecture Notes for Future Reference

### Why `pushReplacement` Between Login and Register
Login and Register are peer screens — neither is a child of the other. Using `context.push()` both ways would stack indefinitely. Using `pushReplacement` means there is always exactly one auth screen on the stack above `WelcomeScreen`.

### Why `goBranch()` Instead of `context.go()` for Dashboard Tabs
`context.go()` navigates the full router tree, which discards the `StatefulShellRoute`'s preserved tab state (scroll position, loaded data). `StatefulNavigationShell.of(context).goBranch()` switches branches inside the shell without destroying any of them.

### SharedPreferences Key
`hasSeenOnboarding` — stored under the constant `_kHasSeenOnboarding` in `auth_providers.dart`. The key uses the same `SharedPreferences` instance that sync status timestamps already use.

---

## Next Steps

- **Manual smoke test** — visually verify the redesigned screens on a simulator/device
- **Apple Sign-In** — implement when Apple Developer Program credentials are available
- **Google Sign-In** — implement using the `google_sign_in` package
- **Merge to `main`** — create PR from `feat/fix-auth-screens-and-navigation`
