# Developer Testing Bugfix Sprint

**Date:** 2026-02-23
**Branch:** `fix/developer-testing-bugfixes`
**Agent:** Claude Code (claude-sonnet-4-6)
**Status:** Complete — 10 commits merged onto branch, pending PR to main

---

## Overview

After all 14 backend and frontend phases were implemented, a full developer testing session was conducted against the harness screen (`HarnessScreen`) — the single-screen developer test UI that exercises every subsystem. This document records everything that was discovered, fixed, and what still requires manual developer setup before testing.

---

## What the Harness Screen Is

`zuralog/lib/features/harness/harness_screen.dart` is a ~1,960-line developer-only test console that exposes every backend and device API as tappable buttons. It is the only screen rendered by the app at this stage (Phase 2 will replace it with the production UI). Each section corresponds to a phase of the backend implementation:

| Section | Tests |
|---|---|
| COMMANDS | Health check, Local DB, Secure Storage |
| AUTH | Register, Login, Logout |
| HEALTH DATA | HealthKit / Health Connect read |
| INTEGRATIONS | Strava OAuth, CalAI |
| AI BRAIN | Chat WebSocket, Voice upload, LLM test |
| BACKGROUND SYNC | FCM trigger-write, Sync status |
| ANALYTICS | Daily summary, Weekly trends, Dashboard insight |
| SUBSCRIPTION | RevenueCat paywall, entitlement check |
| DEEP LINKS | zuralog:// scheme testing |

All output is streamed to a scrollable log terminal at the bottom of the screen.

---

## Stage 1 Fixes (Commits e848625 → 2a21154)

### Issue 1 — RevenueCat Paywall Crash (`PlatformException: PAYWALLS_MISSING_WRONG_ACTIVITY`)

**Root cause:** `MainActivity` extended `FlutterActivity`. RevenueCat's paywall UI requires `FlutterFragmentActivity` to render its Fragment-based paywall screen.

**Fix:** Changed `android/app/src/main/kotlin/.../MainActivity.kt` to extend `FlutterFragmentActivity`.

**Commit:** `e848625`

---

### Issue 2 — All Backend Calls Returned 404

**Root cause:** A port conflict. `workspace-mcp` (an MCP tooling server) bound to `127.0.0.1:8000` and intercepted all localhost requests before the Zuralog Cloud Brain (which also bound to `0.0.0.0:8000`). Every `/health`, `/auth/*`, and `/analytics/*` call hit the wrong server.

**Fix:** Moved the Cloud Brain to port **8001**. Updated the default base URL in `api_client.dart`, `ws_client.dart`, and the `Makefile`.

**Commit:** `83de02d`

---

### Issue 3 — No Graceful Error Handling for Backend Offline

**Root cause:** Raw `DioException` stack traces were logged when the backend was unreachable, giving developers no actionable information.

**Fix:**
- Added `ApiClient.friendlyError()` static method that produces human-readable messages distinguishing between "backend unreachable" (connection error) and "backend returned an error" (HTTP error).
- Added a green/red "API" status dot in the AppBar that pings `/health` on startup.
- Updated all harness backend calls to catch `DioException` specifically.

**Commit:** `95a4b4b`

---

### Issue 4 — Sync Status Button Said "Not Implemented"

**Root cause:** The background sync status button was a stub that logged "not yet implemented".

**Fix:**
- Created `lib/core/storage/sync_status_store.dart` — a `SharedPreferences`-backed store for the last successful sync timestamp.
- Added `syncStatusStoreProvider` to `providers.dart`.
- Updated `HealthSyncWorker.kt` to write the sync timestamp to `FlutterSharedPreferences` (with the `flutter.` key prefix that the Flutter plugin expects).
- Updated the harness button to display last sync time or "Never synced".

**Commit:** `c224c03`

---

### Issue 5 — Strava OAuth Flow Was Undocumented

**Root cause:** Developer didn't know the OAuth flow (browser opens, deep link intercepts, backend exchanges code). The button silently failed with "Bad Request" because credentials weren't set up yet.

**Fix:** Added a "Strava Guide" button that logs step-by-step OAuth testing instructions to the output panel.

**Commit:** `8fbd57f`

---

## Stage 2 Fixes (Commits dbbcd98 → e4e3b6f)

### Issue 6 — Local DB Crash: `libsqlite3.so` Not Found

**Root cause:** `pubspec.yaml` had `sqlite3_flutter_libs: any`, which resolved to `0.6.0+eol` — a deliberately empty tombstone package published by the sqlite3.dart maintainer to signal migration to sqlite3 v3.x. This package ships **zero native code**. At runtime, Drift's `NativeDatabase` called `dlopen("libsqlite3.so")` and crashed because the `.so` was never bundled into the APK.

Note: Drift 2.28.2 (the version in use) is **not yet compatible** with sqlite3 v3.x — the migration was in progress as of late 2025. Upgrading was not an option without breaking Drift.

**Fix:**
- Pinned `sqlite3_flutter_libs: ^0.5.0` in `pubspec.yaml` (resolved to `0.5.41`, the last real version with native binaries).
- Added `jniLibs { useLegacyPackaging = true }` to `android/app/build.gradle.kts` — required on AGP 8.x where the default changed to storing `.so` files compressed.
- Added `android:extractNativeLibs="true"` to `AndroidManifest.xml`.
- Deleted `pubspec.lock` and re-resolved.

**Commit:** `dbbcd98`

---

### Issue 7 — Chat Returns 401 ("No cookie auth credentials found")

**Root cause:** `OPENROUTER_API_KEY` was not present in `cloud-brain/.env`. The `LLMClient` defaulted to an empty string, causing the OpenAI SDK to send `Authorization: Bearer ` (empty). OpenRouter fell back to cookie auth, found none, and returned 401.

Secondary issue: The model name in `config.py` was `"moonshotai/kimi-k2.5"` but everywhere else (`.env.example`, tests, docstrings) said `"moonshot/kimi-k2.5"`. The correct OpenRouter model ID is `moonshotai/kimi-k2.5` (confirmed on openrouter.ai/models).

**Fix:**
- Added `OPENROUTER_API_KEY`, `OPENROUTER_REFERER`, `OPENROUTER_TITLE`, and `OPENROUTER_MODEL` to `.env`.
- Corrected `"moonshot/kimi-k2.5"` → `"moonshotai/kimi-k2.5"` in `.env.example`, all tests, and docstrings.
- Added a startup `logger.warning` in `LLMClient.__init__` when `OPENROUTER_API_KEY` is empty.

**Commit:** `27fb6ca`

---

### Issue 8 — Voice Transcription Returns 500

**Root cause:** `OPENAI_API_KEY` was not in `.env`. The transcription endpoint explicitly checks `if not settings.openai_api_key` and raises HTTP 500 if missing.

Secondary issues found: stale docstrings still said "mock transcription", and `from openai import AsyncOpenAI` was imported lazily inside the request handler body rather than at module level.

**Fix:**
- Added `OPENAI_API_KEY` to `.env`.
- Updated docstrings in `transcribe.py` to accurately describe the real Whisper integration.
- Moved `AsyncOpenAI` and `settings` imports to module level.

**Commit:** `27fb6ca` (combined with Issue 7)

---

### Issue 9 — Keyboard Jank During Text Field Focus

**Root cause:** The `_log()` method wrapped `_outputController.text +=` in `setState()`, triggering a full rebuild of the ~1,960-line monolithic widget tree on every log message. This competed with the Android `IME_INSETS_SHOW_ANIMATION` during keyboard appearance, dropping ~1–3 compositor frames.

Secondary cause: `_pulseController` (the connecting-status animation) ran perpetually from `initState()` even when nothing was connecting, keeping the GPU compositor continuously active.

**Fix:**
- Removed `setState` from `_log()`. `TextEditingController` notifies its own listeners; `setState` was redundant.
- Made the pulse animation conditional: only `repeat()` while `_chatStatus == ConnectionStatus.connecting`; `stop()` otherwise.

**Commit:** `dbbecc9`

---

### Issue 10 — Background Sync Buttons: "No device registered (FCM not initialized)"

**Root cause:** Firebase was completely unconfigured:
- No `google-services.json` in `android/app/`
- Google Services Gradle plugin not applied
- `FCMService.initialize()` was never called anywhere
- No device token registration with the backend after init

**Fix (code side — complete):**
- Added `com.google.gms.google-services` version `4.4.2` to `settings.gradle.kts` and `build.gradle.kts`.
- Added `fcmServiceProvider` to `providers.dart`.
- Added `FCMService.registerWithBackend(ApiClient)` method that POSTs the FCM token to `POST /api/v1/devices/register`.
- Added **"Init FCM"** button in the Background Sync section: initializes FCM, retrieves the device token, and registers it with the backend.
- Added **"Firebase Setup"** help button that logs step-by-step setup instructions to the output panel.
- Improved 404 error message on AI Write buttons to guide the user to tap "Init FCM" first.

**Fix (Firebase project — requires manual setup, see below).**

**Commit:** `e4e3b6f`

---

## Commit Log (All 10 Commits)

```
e4e3b6f feat: integrate Firebase/FCM for push notifications and device registration
dbbecc9 perf: reduce unnecessary widget rebuilds in harness screen
27fb6ca fix: correct OpenRouter model name to moonshotai/kimi-k2.5 and clean up transcribe
dbbcd98 fix: pin sqlite3_flutter_libs ^0.5.0 and enable legacy JNI packaging
2a21154 docs: add Windows PowerShell equivalents to Makefile
83de02d fix: change default backend port from 8000 to 8001
8fbd57f docs: add Strava OAuth testing guide to harness screen
c224c03 feat: implement simple sync status with last-synced timestamp
95a4b4b feat: add graceful backend connectivity handling and status indicator
e848625 fix: change MainActivity to FlutterFragmentActivity for RevenueCat paywall support
```

---

## Files Changed (Summary)

### Flutter Frontend (`zuralog/`)

| File | Change |
|---|---|
| `android/app/src/main/kotlin/.../MainActivity.kt` | `FlutterActivity` → `FlutterFragmentActivity` |
| `android/app/build.gradle.kts` | Added `jniLibs.useLegacyPackaging = true`, Google Services plugin |
| `android/app/src/main/AndroidManifest.xml` | Added `android:extractNativeLibs="true"` |
| `android/settings.gradle.kts` | Added `com.google.gms.google-services` plugin declaration |
| `pubspec.yaml` | Pinned `sqlite3_flutter_libs: ^0.5.0` (was `any`) |
| `pubspec.lock` | Re-resolved; `sqlite3_flutter_libs` now `0.5.41` |
| `lib/core/network/api_client.dart` | Added `friendlyError()` + `_extractDetail()` static methods |
| `lib/core/network/ws_client.dart` | Updated default base URL to port 8001 |
| `lib/core/network/fcm_service.dart` | Added `registerWithBackend(ApiClient)` method |
| `lib/core/storage/sync_status_store.dart` | **New file** — SharedPreferences sync timestamp store |
| `lib/core/di/providers.dart` | Added `syncStatusStoreProvider`, `fcmServiceProvider` |
| `lib/features/harness/harness_screen.dart` | Friendly error handling, AppBar status dot, sync status button, Strava guide, Init FCM button, Firebase Setup guide, removed setState from `_log()`, conditional pulse animation |

### Python Backend (`cloud-brain/`)

| File | Change |
|---|---|
| `.env` | Added `OPENAI_API_KEY`, `OPENROUTER_API_KEY`, `OPENROUTER_*`, `STRAVA_*` entries (**not committed — gitignored**) |
| `.env.example` | Fixed model name `moonshot/kimi-k2.5` → `moonshotai/kimi-k2.5` |
| `app/agent/llm_client.py` | Fixed docstring model name, added empty key startup warning |
| `app/api/v1/transcribe.py` | Updated stale "mock" docstrings, moved imports to module level |
| `tests/test_llm_client.py` | Fixed model name in test fixtures and assertions |
| `tests/test_usage_tracker.py` | Fixed model name in test fixtures |
| `Makefile` | Added Windows PowerShell equivalents as comments |

---

## Current Working State (After All Fixes)

With the Cloud Brain running (`uv run uvicorn app.main:app --reload --host 0.0.0.0 --port 8001`) and the app rebuilt (`flutter clean && flutter run`):

| Feature | Status | Notes |
|---|---|---|
| Health check | **Working** | Green dot in AppBar |
| Local DB (SQLite) | **Working** | `sqlite3_flutter_libs 0.5.41` bundled |
| Secure Storage | **Working** | |
| Register / Login / Logout | **Working** | Supabase Auth |
| Chat (WebSocket) | **Working** | OpenRouter `moonshotai/kimi-k2.5` |
| Voice Transcription | **Working** | OpenAI Whisper |
| Analytics | **Working** | Daily summary, weekly trends |
| RevenueCat Paywall | **Working** | FlutterFragmentActivity fix |
| Background Sync Status | **Working** | Shows last sync time or "Never synced" |
| Strava OAuth | **Requires setup** | See below |
| Background Sync (FCM trigger-write) | **Requires setup** | See below |

---

## Pending Developer Setup (Deferred)

The following features are **fully wired in code** but require external service configuration before they can be tested. They are intentionally deferred and documented here for when you are ready.

---

### Strava OAuth

**What it does:** Allows users to connect their Strava account. The app opens a browser to Strava's login page, the user authorizes "Zuralog", and Strava redirects back to `zuralog://oauth/strava?code=XXX`. The backend exchanges the code for an access token and stores it.

**How OAuth works (important):** You register **one** Strava API application as the developer/app owner. Your users never need their own Strava API keys — they simply log into their personal Strava accounts via the standard OAuth consent screen, exactly like "Sign in with Google". The `STRAVA_CLIENT_ID` and `STRAVA_CLIENT_SECRET` are *your app's* server-side credentials, never sent to the Flutter client.

**Setup steps:**

1. Go to https://www.strava.com/settings/api
2. Create a new API application:
   - **Application Name:** Zuralog (or any name)
   - **Category:** Training (or appropriate)
   - **Website:** `https://zuralog.app`
   - **Authorization Callback Domain:** `localhost`
3. Note your **Client ID** (numeric) and **Client Secret** (40-char hex string)
4. Add to `cloud-brain/.env`:
   ```
   STRAVA_CLIENT_ID=<your_numeric_client_id>
   STRAVA_CLIENT_SECRET=<your_40_char_secret>
   STRAVA_REDIRECT_URI=zuralog://oauth/strava
   ```
5. Restart the Cloud Brain
6. In the harness: log in via AUTH first, then tap **"Connect Strava"**

**What the "Strava Guide" button in the harness does:** Logs these steps directly to the output panel.

---

### Firebase Cloud Messaging (FCM) — Background Sync

**What it does:** The "AI Write (Steps)" and "AI Write (Nutrition)" buttons test the full cloud-to-device write pipeline:
1. Flutter app POSTs to `/api/v1/dev/trigger-write`
2. Cloud Brain looks up the device's FCM token
3. Cloud Brain sends a silent FCM data message to the device
4. Android receives the FCM push in the background
5. `firebaseMessagingBackgroundHandler` runs in a headless isolate
6. It calls the `com.zuralog/health` MethodChannel → `backgroundWrite`
7. Native Health Connect writes the data

**Setup steps (client side — required for "Init FCM" to work):**

1. Go to https://console.firebase.google.com
2. Create a new Firebase project (or use existing)
3. Add an **Android app** with package name: `com.zuralog.zuralog`
4. Download `google-services.json`
5. Place it at: `zuralog/android/app/google-services.json`
6. Rebuild the app: `flutter clean && flutter run`
7. In the harness: tap **"Init FCM"** — this requests notification permission, retrieves the FCM device token, and registers it with the backend

**Setup steps (backend side — required for Cloud Brain to send FCM pushes):**

1. Firebase Console → your project → Project Settings → **Service Accounts** tab
2. Click **"Generate new private key"** → download the JSON file
3. Save it somewhere safe (e.g., `cloud-brain/firebase-service-account.json`)
4. Add to `cloud-brain/.env`:
   ```
   FCM_CREDENTIALS_PATH=path/to/firebase-service-account.json
   ```
5. Restart the Cloud Brain

**After both client and backend are set up:**
- Tap "Init FCM" → device token is registered with the backend
- Tap "AI Write (Steps)" → the full FCM push pipeline fires
- Health Connect receives the write in the background

**What the "Firebase Setup" button in the harness does:** Logs all these steps directly to the output panel.

---

## Architecture Notes for Future Reference

### Port Configuration
The Cloud Brain runs on port **8001** (not 8000). The `workspace-mcp` tool binds to `127.0.0.1:8000` and would intercept requests if the same port were used.

- Flutter base URL: `http://10.0.2.2:8001` (Android emulator alias for host `localhost:8001`)
- Start command: `cd cloud-brain && uv run uvicorn app.main:app --reload --host 0.0.0.0 --port 8001`

### SQLite Version Constraint
`sqlite3_flutter_libs` is pinned to `^0.5.0` and **must stay pinned**. Do not change it to `any` or `^0.6.0`. Version `0.6.0+eol` is an empty tombstone package. When Drift officially supports sqlite3 v3.x (expected in 2026), the migration path is:

1. Remove `sqlite3_flutter_libs` from `pubspec.yaml` entirely
2. Upgrade `drift` to the version that declares sqlite3 v3.x compatibility
3. Remove `jniLibs.useLegacyPackaging` and `extractNativeLibs` from Gradle/manifest

### OpenRouter Model ID
The correct model identifier is `moonshotai/kimi-k2.5` (with the `moonshotai/` prefix). The `moonshot/` prefix is incorrect and will cause a model-not-found error once authentication is fixed.

### FCM Token Lifecycle
The token is stored in-memory on the backend (`app.state.device_tokens`) — it is lost on Cloud Brain restart. After restarting the backend, tap "Init FCM" again in the harness to re-register. Phase 2 will persist device tokens to the database.

---

## Next Steps (Phase 2)

This sprint was a pre-production hardening pass. The next major work is:

1. **Production UI** — Replace `HarnessScreen` with the real application UI (home dashboard, chat interface, activity log, settings)
2. **Strava integration** — Register the Strava API app and test the full OAuth + data sync flow
3. **Firebase setup** — Create Firebase project, configure FCM end-to-end
4. **Persist device tokens** — Move FCM token storage from `app.state` (in-memory) to the `user_devices` database table
5. **sqlite3 v3.x migration** — Monitor Drift for official sqlite3 v3.x support and upgrade when available
