# Executed Phase 1.6 — Strava Integration

**Date:** 2026-02-21
**Branch:** `feat/phase-1.6-strava-integration`
**Status:** Complete

---

## Summary

Implemented end-to-end Strava OAuth 2.0 integration across the full Hybrid Hub stack. The LLM agent can now call `strava_get_activities` and `strava_create_activity` via MCP; the mobile Edge Agent exposes "Connect Strava" and "Check Strava Status" buttons in the developer harness.

---

## What Was Built

### Backend (Cloud Brain)

- **`app/config.py`** — Added `strava_client_id`, `strava_client_secret`, `strava_redirect_uri` fields using the existing Pydantic v2 `SettingsConfigDict` pattern.
- **`.env.example`** — Documented the three new Strava env vars with setup instructions.
- **`app/api/v1/integrations.py`** — New router with two endpoints:
  - `GET /api/v1/integrations/strava/authorize` — Returns the Strava OAuth URL for the app to open.
  - `POST /api/v1/integrations/strava/exchange?code=&user_id=` — Exchanges the authorization code for tokens; stores the access token on the `StravaServer` instance.
- **`app/mcp_servers/strava_server.py`** — Full `StravaServer` implementation inheriting `BaseMCPServer`. Exposes two tools (`strava_get_activities`, `strava_create_activity`). MVP returns mock data; live `httpx` calls are written and commented in for easy activation once real credentials are supplied. Token management via `store_token(user_id, access_token)`.
- **`app/main.py`** — Registered `StravaServer()` in the MCP registry and mounted the integrations router at `/api/v1`.

### Flutter (Edge Agent)

- **`pubspec.yaml`** — Added `app_links` for custom URL scheme interception.
- **`lib/features/integrations/data/oauth_repository.dart`** — `OAuthRepository` wraps the two backend OAuth endpoints. Provider lives in `core/di/providers.dart` (consistent with existing pattern).
- **`lib/core/di/providers.dart`** — Added `oauthRepositoryProvider`.
- **`lib/core/network/api_client.dart`** — Extended `post()` with optional `queryParameters` parameter.
- **`lib/features/auth/data/auth_repository.dart`** — `_saveTokens()` now also persists `user_id` to `SecureStorage` (needed by `DeeplinkHandler`); `_clearTokens()` deletes it on logout.
- **`lib/core/deeplink/deeplink_handler.dart`** — Static `DeeplinkHandler` class subscribes to `AppLinks().uriLinkStream`, routes `lifelogger://oauth/strava?code=XXX` to `OAuthRepository.handleStravaCallback()`.
- **`ios/Runner/Info.plist`** — Registered `CFBundleURLSchemes: [lifelogger]`.
- **`android/app/src/main/AndroidManifest.xml`** — Added `intent-filter` for `scheme=lifelogger host=oauth`.
- **`lib/features/harness/harness_screen.dart`** — New STRAVA section with "Connect Strava" and "Check Strava Status" buttons; `DeeplinkHandler.init()` called in `initState`, `dispose()` in `dispose()`.

---

## Deviations from Original Plan

| Item | Plan Said | What Was Built | Reason |
| --- | --- | --- | --- |
| Import paths | `cloudbrain.app.*` | `app.*` | Matches existing codebase convention |
| `StravaServer` return types | Plain `dict` | `ToolResult` / `list[Resource]` | Required by `BaseMCPServer` abstract contract |
| Token storage | Vague ("DB or local") | In-memory `dict` on `StravaServer` | No DB migration needed for MVP harness; Phase 1.7 adds persistence |
| User identification | Implicit | `user_id` query param on exchange | No JWT decode middleware exists yet |
| OAuthRepository provider location | In `oauth_repository.dart` | In `core/di/providers.dart` | Consistent with `healthRepositoryProvider` pattern |
| Deep link package | `uni_links` (deprecated) | `app_links` v6 | `app_links` is the maintained successor |
| `ApiClient.post()` | No `queryParameters` | Added optional `queryParameters` | Required by `handleStravaCallback` |
| `user_id` persistence | Not mentioned | Added to `AuthRepository._saveTokens()` | `DeeplinkHandler` needs it to identify user without a server round-trip |

---

## Next Steps (Phase 1.7)

- Add `user_integrations` database table (Alembic migration) with columns: `user_id`, `provider`, `access_token`, `refresh_token`, `expires_at`.
- Migrate `StravaServer._tokens` to DB-backed storage so tokens survive server restarts.
- Implement automatic token refresh when `expires_at` is approaching.
- Add `GET /api/v1/integrations/strava/status` endpoint for the harness "Check Strava Status" button.
- Activate live Strava API calls in `StravaServer` (uncomment `httpx` blocks).
