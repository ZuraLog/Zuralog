# Executed Phase: Social OAuth Sign-In (Google + Apple)

**Date:** 2026-02-23  
**Branch:** `feat/social-oauth-signin`  
**Status:** Code-complete, pending user credential setup in Google Cloud Console + Supabase Dashboard

---

## Summary

Implemented native OAuth Sign-In with Google (fully functional flow) and Apple (stubbed with informative dialog) following the Hybrid Hub architecture:

> Flutter Edge Agent → collects native ID token → POST `/api/v1/auth/social` on Cloud Brain → Cloud Brain calls Supabase GoTrue `POST /auth/v1/token?grant_type=id_token` → returns session

### Backend (Cloud Brain — Python/FastAPI)
- **`schemas.py`**: Added `SocialAuthRequest(provider, id_token, access_token?, nonce?)` Pydantic model.
- **`auth_service.py`**: Added `sign_in_with_id_token()` calling Supabase GoTrue `id_token` grant endpoint.
- **`auth.py`**: Added `POST /api/v1/auth/social` endpoint with Apple "Hide My Email" fallback email handling.
- **`test_social_auth.py`**: 9 new unit tests; all pass. Existing 7 auth tests unaffected.

### Flutter (Edge Agent — Dart)
- **`pubspec.yaml`**: Added `google_sign_in: ^6.2.2`, `sign_in_with_apple: ^6.1.4`, `crypto: ^3.0.6`.
- **`social_auth_credentials.dart`**: `SocialProvider` enum (`google`, `apple`) + `SocialAuthCredentials` value model.
- **`social_auth_service.dart`**: `SocialAuthService` with real `signInWithGoogle()` and stubbed `signInWithApple()`. Custom exceptions: `SocialAuthException`, `SocialAuthCancelledException`.
- **`auth_repository.dart`**: Added `socialLogin(SocialAuthCredentials)` calling backend `/api/v1/auth/social`.
- **`auth_providers.dart`**: Added `socialLogin()` action on `AuthStateNotifier`.
- **`providers.dart`**: Added `socialAuthServiceProvider` reading `GOOGLE_WEB_CLIENT_ID` from `--dart-define`.
- **`welcome_screen.dart`**: Google button wired to real OAuth flow (loading overlay + error SnackBar). Apple button shows informative dialog about needing Apple Developer Program enrollment.

### Platform Config
- **`ios/Runner/Info.plist`**: Added placeholder URL scheme entry for Google reversed client ID (`REPLACE_WITH_REVERSED_GOOGLE_CLIENT_ID`).
- **`ios/Runner/Runner.entitlements`**: Added `com.apple.developer.applesignin` stub (commented — do not activate until Apple Developer Portal is configured).

---

## Deviations from Original Plan

| Deviation | Reason |
|---|---|
| Apple Sign In is **stubbed**, not implemented | Requires $99/year Apple Developer Program enrollment and a real device. Stub shows an informative dialog rather than silently failing. |
| `GOOGLE_WEB_CLIENT_ID` injected via `--dart-define` (not `.env`) | Follows existing project pattern for build-time config; avoids hardcoding secrets. |
| Firebase `GoogleService-Info.plist` is **not** the OAuth source | Discovered Firebase project `zuralog-8311a` was FCM-only — no OAuth clients existed. A separate Web + iOS OAuth 2.0 client must be created in Google Cloud Console. |

---

## Key Discovery: Firebase ≠ Google Sign-In OAuth

The existing Firebase setup (for push notifications) does **not** provide the OAuth 2.0 credentials needed for `google_sign_in`. Without a **Web Application OAuth 2.0 Client ID** set as `serverClientId`, the SDK returns `null` for `idToken`, which is required by Supabase's `id_token` grant.

---

## Remaining User Actions (Cannot Be Automated)

1. **Google Cloud Console** ([console.cloud.google.com](https://console.cloud.google.com) → project `zuralog-8311a`):
   - Create **Web Application** OAuth 2.0 client → redirect URI: `https://enccjffwpnwkxfkhargr.supabase.co/auth/v1/callback` → note `GOOGLE_WEB_CLIENT_ID` + secret
   - Create **iOS** OAuth 2.0 client → Bundle ID `com.zuralog.zuralog` → copy `REVERSED_CLIENT_ID` into `ios/Runner/Info.plist` (replace `REPLACE_WITH_REVERSED_GOOGLE_CLIENT_ID`)
   - Create **Android** OAuth 2.0 client → package `com.zuralog.zuralog` + debug SHA-1 fingerprint
   - Download updated `GoogleService-Info.plist` and `google-services.json`

2. **Supabase Dashboard** → Auth → Providers → Google:
   - Enable Google provider
   - Paste Web Client ID + Web Client Secret

3. **Flutter build**: Add `--dart-define=GOOGLE_WEB_CLIENT_ID=<your-web-client-id>` to all `flutter run` / `flutter build` commands (or add to VS Code launch config / `Makefile`).

4. **Apple Sign In** (when ready):
   - Enroll in Apple Developer Program
   - Enable "Sign in with Apple" capability on App ID in Apple Developer Portal
   - Uncomment `Runner.entitlements` Apple entry
   - Replace stub in `social_auth_service.dart` `signInWithApple()` with real implementation

---

## Ready for Next Phase

- All code is merged-ready (zero `flutter analyze` warnings).
- Once user completes Google Cloud Console + Supabase Dashboard steps, Google Sign-In will work end-to-end.
- Apple Sign-In architecture is fully in place — only needs the stub replaced with real SDK calls when credentials are available.
