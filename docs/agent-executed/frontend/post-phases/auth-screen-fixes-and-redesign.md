# Auth Screen Fixes, Redesign, and Smoke-Test Bugfix Sprint

**Date:** 2026-02-23
**Branch:** `fix/onboarding-questionnaire-null-profile`
**Initial Commit SHA:** `14029de`
**Latest Commit SHA:** `aa7af17`
**Agent:** Claude Code (claude-sonnet-4-6)
**Status:** Complete — merged to `main`

> **This document covers three sessions on the same branch:**
> - **Session 1** (commits `14029de` → `93306dd`): Auth screen fixes and WelcomeScreen redesign
> - **Session 2** (commits `84bd693` → `6a4e09c`): User profile system, integration tile redesign, and smoke-test bugfixes
> - **Session 3** (commits `cdca216` → `aa7af17`): Questionnaire save failures and expired-token force-logout

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

---

# Session 2: User Profile System, Integration Redesign, and Smoke-Test Bugfixes

## Overview

After Session 1 was committed, a manual smoke test revealed 6 issues plus 4 additional runtime bugs. Session 2 addressed all of them across both the Flutter frontend and the FastAPI backend.

---

## What Was Built — Tasks 3–9

### Task 3 — Backend: User Profile API Endpoints

Added `GET /me/profile` and `PATCH /me/profile` to `cloud-brain/app/api/v1/users.py`. Both endpoints require the authenticated current user. `PATCH` uses `model_dump(exclude_none=True)` for partial updates and guards against empty payloads (400) and missing `user_id` (401). Added `UserProfileResponse` and `UpdateProfileRequest` Pydantic schemas to `schemas.py`.

**Commits:** `fd2868b`, `4fcaebe`

---

### Task 4 — Flutter: UserProfile Model + Provider + ApiClient.patch()

Created `zuralog/lib/features/auth/domain/user_profile.dart` — an immutable Dart model with `aiName` getter (nickname → displayName → email prefix), `fromJson`, `copyWith` (sentinel pattern for nullable fields), `==`/`hashCode`, and a `createdAt` field (added in Session 2 smoke-test fix).

Added `ApiClient.patch()` (was missing). Added `fetchProfile()` and `updateProfile()` to `AuthRepository`. Added `UserProfileNotifier` + `userProfileProvider` (manual Riverpod, `NotifierProvider<UserProfileNotifier, UserProfile?>`). Wired fire-and-forget `load()` calls in `login()`, `register()`, and `checkAuthStatus()` success paths. Added `clear()` on logout.

**Commits:** `7c09b4b`, `cec9aa9`

---

### Task 5 — Flutter: Post-Registration Profile Questionnaire

Created `profile_questionnaire_screen.dart` — a 3-step `ConsumerStatefulWidget`:
- Step 1: Display name + nickname text fields
- Step 2: Birthday date picker (Material `showDatePicker`)
- Step 3: Gender selection (radio-style tiles — Male, Female, Non-binary, Prefer not to say)

Progress indicator shows "Step X of 3". Final step calls `update(onboardingComplete: true)` and navigates to dashboard.

Registered route at `/auth/profile-questionnaire`. Added to `publicPaths`. Added router guard (Step 3 in `app_router.dart`): authenticated + `onboardingComplete == false` → redirect. Added `userProfileProvider` to `_RouterRefreshListenable`.

**Deviation from original plan:** The `register_screen.dart` was initially given an explicit `context.go()` to the questionnaire on `AuthSuccess`, but this created a double-navigation race with the router guard. The explicit call was removed — the guard handles it entirely.

**Additional fix:** Auth guard Rule 3 (redirect authenticated users on public paths to dashboard) was updated to exclude `profileQuestionnairePath`, preventing a redirect ping-pong loop.

**Commits:** `3cb7280`, `d53e194`

---

### Task 6 — Flutter: Wire Display Name into Dashboard Header

`DashboardScreen` (already a `ConsumerWidget`) now watches `userProfileProvider` and passes `profile?.aiName ?? '...'` to `_buildHeader`. The hardcoded `'Alex'` is gone.

**Commit:** `387e0d9`

---

### Task 7 — Flutter: Integration Tile Redesign

Replaced `CupertinoSwitch` in `integration_tile.dart` with:
- `OutlinedButton('Connect')` when not connected
- Green `_ConnectedBadge` + `IconButton(Icons.link_off_rounded)` when connected

Removed `_handleToggle`. Uses `AppColors.statusConnected` and `AppDimens` tokens — no raw color or magic number values.

**Commits:** `2a5e3e1`, `a1e473d`

---

### Task 8 — Flutter: Platform-Aware Integration Compatibility

Added `PlatformCompatibility` enum (`all`, `iosOnly`, `androidOnly`) to `integration_model.dart`. Added `isCompatibleWithCurrentPlatform` (with `kIsWeb` guard) and `incompatibilityNote` computed properties. Marked `apple_health` → `iosOnly`, `google_health_connect` → `androidOnly`. Incompatible tiles render at 45% opacity with a `_IncompatibleBadge` instead of the Connect button.

**Commits:** `af3dd61`, `4981ec5`

---

### Task 9 — Flutter: Fix Dashboard Integrations Rail

`IntegrationsRail` converted from `StatelessWidget` to `ConsumerWidget`. Removed hardcoded `_kPills` list. Now watches `integrationsProvider`, filters to connected integrations, and renders live pill tiles. Added `_EmptyState` widget ("No apps connected") for the zero-connected case. Extracted `_RailShell` helper for the section chrome. Added `Future.microtask(loadIntegrations)` to `IntegrationsNotifier.build()` for auto-load on first watch. Added `AppDimens.integrationPillHeight`, `AppDimens.integrationRailHeight`, and `AppTextStyles.labelXs` to the design system.

**Commits:** `4a2e25d`, `f41e087`

---

## What Was Fixed — Smoke-Test Bugs

### Bug 1 — Onboarding questionnaire never appeared after signup

**Root cause:** Router guard required `profile != null` before redirecting to the questionnaire. After registration, `authState` became `authenticated` immediately while `load()` was still in-flight, causing the guard to skip. Changed guard condition from `profile != null && !profile.onboardingComplete` to `profile == null || !profile.onboardingComplete` — redirects to the questionnaire during loading too, giving the user the form to fill while the profile resolves.

Also fixed `sync_user_to_db` in `user_service.py` to explicitly include `onboarding_complete = false` in the INSERT and `RETURNING` clause rather than relying solely on `server_default`.

**Commit:** `6dca090`

---

### Bug 2 — "Disconnected — pull to reconnect" did nothing

**Root cause 1:** `RefreshIndicator.onRefresh` in `chat_screen.dart` called `loadHistory()` (a REST history fetch), not a WebSocket reconnect.

**Root cause 2:** `ChatNotifier` had no `reconnect()` method and no access to `Ref` for token retrieval.

**Fix:** Added `Ref _ref` to `ChatNotifier`. Added `reconnect()` method that reads the auth token from `secureStorageProvider` and calls `connect(token)`. Changed `onRefresh` to call `reconnect()`. The `WsClient.connect()` already correctly reset `_shouldReconnect = true` and `_retryCount = 0` on explicit calls — no change needed there.

**Commit:** `34cabf3`

---

### Bug 3 — Apps View was completely blank

**Root cause:** The empty-state condition in `integrations_hub_screen.dart` was inverted — it showed a `CircularProgressIndicator` when `isEmpty && !isLoading`, which was always true because `loadIntegrations()` never set `isLoading = true`. The spinner blocked the list from ever rendering.

**Fix:** Made `loadIntegrations()` set `isLoading: true` at the start and `isLoading: false` at the end. Split the empty-state into two correct branches: spinner when `isLoading == true`, genuine "No integrations available" message when `isEmpty && !isLoading`.

**Commit:** `c8203ba`

---

### Bug 4 — "Member since January 2025" was hardcoded

**Root cause:** `created_at` existed on the `User` ORM model and in the DB but was never exposed in `UserProfileResponse`, never added to the `UserProfile` Dart model, and never read in the widget.

**Fix (3 layers):**
- `cloud-brain/app/api/v1/schemas.py`: Added `created_at: Optional[datetime] = None` to `UserProfileResponse`
- `zuralog/lib/features/auth/domain/user_profile.dart`: Added `createdAt` field, `fromJson` parsing, `copyWith`, `==`/`hashCode`
- `zuralog/lib/features/settings/presentation/widgets/user_header.dart`: Watch `userProfileProvider`, format `profile?.createdAt` with a local `_formatDate` helper (`MMMM yyyy`), replace hardcoded string

**Commit:** `6a4e09c`

---

## Full Files Changed (Session 2)

### Backend (`cloud-brain/`)

| File | Change |
|------|--------|
| `app/api/v1/users.py` | Added `GET /me/profile`, `PATCH /me/profile` |
| `app/api/v1/schemas.py` | Added `UserProfileResponse`, `UpdateProfileRequest`, `created_at` field |
| `app/services/user_service.py` | Explicit `onboarding_complete = false` in INSERT + RETURNING |
| `alembic/versions/050d7af3bdcf_add_user_profile_fields.py` | Migration: 5 new user columns |
| `app/models/user.py` | 5 new columns: `display_name`, `nickname`, `birthday`, `gender`, `onboarding_complete` |

### Flutter Frontend (`zuralog/`)

| File | Change |
|------|--------|
| `lib/features/auth/domain/user_profile.dart` | **New** — `UserProfile` model with `aiName`, `createdAt`, sentinel `copyWith`, equality |
| `lib/core/network/api_client.dart` | Added `patch()` method |
| `lib/features/auth/data/auth_repository.dart` | Added `fetchProfile()`, `updateProfile()` |
| `lib/features/auth/domain/auth_providers.dart` | Added `UserProfileNotifier`, `userProfileProvider`, wired `load()`/`clear()` |
| `lib/core/router/app_router.dart` | Questionnaire guard (Step 3), `userProfileProvider` in listenable, auth Rule 3 exclusion |
| `lib/core/router/route_names.dart` | Added `profileQuestionnaire` route + path + `publicPaths` |
| `lib/features/auth/presentation/onboarding/profile_questionnaire_screen.dart` | **New** — 3-step questionnaire |
| `lib/features/auth/presentation/auth/register_screen.dart` | Removed redundant `context.go()` on `AuthSuccess` |
| `lib/features/dashboard/presentation/dashboard_screen.dart` | Replaced `'Alex'` with `profile?.aiName ?? '...'` |
| `lib/features/integrations/domain/integration_model.dart` | Added `PlatformCompatibility`, `isCompatibleWithCurrentPlatform`, `incompatibilityNote`, full equality |
| `lib/features/integrations/domain/integrations_provider.dart` | Platform tags, `isLoading` state fix, `Future.microtask` auto-load |
| `lib/features/integrations/presentation/widgets/integration_tile.dart` | Connect/Connected button UI, `_IncompatibleBadge`, `_ConnectedBadge`, platform opacity |
| `lib/features/dashboard/presentation/widgets/integrations_rail.dart` | Wired to `integrationsProvider`, removed `_kPills`, `_RailShell`, `_EmptyState` |
| `lib/features/chat/domain/chat_providers.dart` | Added `Ref` to `ChatNotifier`, added `reconnect()` |
| `lib/features/chat/presentation/chat_screen.dart` | `onRefresh` → `reconnect()` |
| `lib/features/settings/presentation/widgets/user_header.dart` | Dynamic `Member since` from `profile.createdAt` |
| `lib/core/theme/app_dimens.dart` | Added `integrationPillHeight`, `integrationRailHeight` |
| `lib/core/theme/app_text_styles.dart` | Added `labelXs` (10pt Medium) |

---

## Architecture Notes for Future Reference

### Router Guard Ordering
The `app_router.dart` redirect function has three steps in strict order:
1. **Auth guard** — unauthenticated users → `/welcome`; authenticated on public paths (except `/auth/profile-questionnaire`) → `/dashboard`
2. **First-launch guard** — `hasSeenOnboarding == false` → `/onboarding`
3. **Profile/onboarding guard** — authenticated + (`profile == null` OR `onboardingComplete == false`) → `/auth/profile-questionnaire`

The questionnaire path must be in `publicPaths` (so Step 1 doesn't redirect away from it) AND excluded from the Step 1 "authenticated on public path → dashboard" sub-rule (so the loop doesn't form).

### `UserProfile.copyWith` Sentinel Pattern
`copyWith` uses a file-scope `const Object _copyWithSentinel = Object()` as the default for nullable fields (`displayName`, `nickname`, `birthday`). This allows callers to explicitly pass `null` to clear a field, which the standard `??` pattern cannot do.

### `intl` Package Not Added
Date formatting in `profile_questionnaire_screen.dart` and `user_header.dart` uses manual helpers rather than `DateFormat`. If `intl` is added in the future, these helpers should be replaced with `DateFormat('MMMM yyyy')` etc.

### Backend Port
Cloud Brain runs on port **8001**. See the developer-testing-bugfix-sprint doc for why (port conflict with `workspace-mcp` on 8000).

---

## Next Steps

- **Apple Sign-In** — implement when Apple Developer Program credentials are available
- **Google Sign-In** — implement using the `google_sign_in` package
- **Profile edit screen** — allow users to update their display name/nickname/birthday/gender post-onboarding

---

---

# Session 3: Questionnaire Save Failures and Expired-Token Force-Logout

## Overview

After Session 2, manual smoke testing uncovered three chained bugs that collectively prevented the profile questionnaire from saving for any user. All three were diagnosed from live backend/Flutter logs and fixed in the same session before merging to `main`.

---

## What Was Fixed

### Bug 5 — Questionnaire redirect fired before profile loaded (race condition)

**Root cause:** The router Step-3 guard checked `profile == null` and immediately redirected to the questionnaire. On every login, `authStateProvider` flips to `authenticated` before the fire-and-forget `load()` call completes. In that window, `profile` is transiently `null` — so every returning user (including those with `onboardingComplete = true`) was sent to the questionnaire on every app launch.

**Fix:**
- Added `isLoadingProfileProvider` (`StateProvider<bool>`) to `auth_providers.dart`.
- `UserProfileNotifier.load()` sets it `true` at the start and `false` in a `finally` block.
- Router Step-3 guard now returns `null` (stay put) while `isLoadingProfileProvider == true`; only redirects after the load settles and `onboardingComplete` is confirmed `false`.
- Added `isLoadingProfileProvider` to `_RouterRefreshListenable` so the guard re-evaluates when the flag clears.
- `ProfileQuestionnaireScreen.initState()` now pre-populates all fields from any existing profile, so returning users see their data rather than blank inputs.
- Added `debugPrint` of the actual exception in `_handleSubmit`'s catch block for future diagnostics.

**Commit:** `eeb8a62`

---

### Bug 6 — PATCH call returned 404 (wrong API path)

**Root cause:** `AuthRepository.fetchProfile()` and `updateProfile()` were calling `/api/v1/me/profile`. The FastAPI users router has `prefix="/users"`, making the real paths `/api/v1/users/me/profile`. The mismatch was masked in early development because the 404 was caught by the generic `catch(e)` and shown only as "Failed to save profile."

**Fix:** Updated both path strings in `auth_repository.dart` to `/api/v1/users/me/profile`.

**Commit:** `cb53ae0`

---

### Bug 7 — PATCH call returned 401 after app restart (expired JWT, no recovery path)

**Root cause:** `isLoggedIn()` only checks whether the token *string* exists in secure storage — it does not validate the JWT with the server. After an extended session gap (Supabase access tokens expire in ~1 hour; refresh tokens rotate and expire after inactivity), the user was auto-authenticated locally on restart but every real API call returned 401. The token-refresh interceptor attempted to exchange the refresh token, which was also expired — it cleared both tokens and passed the 401 error through. The `DioException` propagated to `_handleSubmit`'s `catch(e)`, showing a SnackBar with no recovery path. The user was permanently stuck: authenticated in app state, but every API call rejected.

**Fix:**
- Added `onUnauthenticated` callback parameter to `ApiClient`. Called after refresh failure, alongside token cleanup.
- Added `forceLogout()` to `AuthStateNotifier`: sets state to `unauthenticated`, clears profile and email providers — no backend call needed since tokens are already invalid.
- DI provider `apiClientProvider` wires `onUnauthenticated` → `forceLogout()` via a lazy `ref.read` callback (not `ref.watch`, to avoid a circular dependency).

**Result:** On unrecoverable 401, `forceLogout()` fires, `authStateProvider` flips to `unauthenticated`, the router guard redirects to `/welcome`, and the user can log in again normally.

**Commit:** `aa7af17`

---

## Full Files Changed (Session 3)

| File | Change |
|------|--------|
| `lib/features/auth/domain/auth_providers.dart` | Added `isLoadingProfileProvider`; `load()` sets/clears it; added `forceLogout()` to `AuthStateNotifier`; `clear()` also resets loading flag |
| `lib/core/router/app_router.dart` | Step-3 guard holds while `isLoadingProfileProvider == true`; added `isLoadingProfileProvider` to `_RouterRefreshListenable` |
| `lib/features/auth/presentation/onboarding/profile_questionnaire_screen.dart` | `initState()` pre-populates fields from existing profile; `debugPrint` in catch block |
| `lib/features/auth/data/auth_repository.dart` | Fixed both API paths: `/api/v1/me/profile` → `/api/v1/users/me/profile` |
| `lib/core/network/api_client.dart` | Added `onUnauthenticated` callback; called after refresh failure |
| `lib/core/di/providers.dart` | Wired `onUnauthenticated` → `AuthStateNotifier.forceLogout()` in `apiClientProvider` |
| `docs/agent-executed/frontend/post-phases/auth-screen-fixes-and-redesign.md` | This document |

---

## Architecture Notes Added in Session 3

### `isLoadingProfileProvider` — why a separate provider and not `AsyncNotifier`

Switching `UserProfileNotifier` to `AsyncNotifier<UserProfile?>` would expose the loading state natively but would require updating every consumer (`userProfileProvider` watcher) across the codebase. The `isLoadingProfileProvider` approach is an additive change — existing consumers are untouched and the router is the only reader of the flag.

### `forceLogout()` vs `logout()`

`logout()` calls `POST /api/v1/auth/logout` to invalidate the Supabase session server-side. `forceLogout()` skips the network call because the tokens are already invalid (the interceptor cleared them). Calling `logout()` in this scenario would itself get a 401, potentially triggering another `onUnauthenticated` call and a recursive loop.

### `onUnauthenticated` uses `ref.read`, not `ref.watch`

`apiClientProvider` is a `Provider` (synchronous, runs once). `ref.watch` inside a non-reactive provider would throw. The `ref.read` inside the closure is lazily evaluated at call-time, which is correct — `authStateProvider` is always initialized by the time a 401 can occur.
