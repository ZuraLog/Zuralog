# Executed: Sentry Integration

**Date:** 2026-03-01
**Branch:** feat/sentry-integration
**Plan:** `.opencode/plans/2026-02-28-integration-sentry.md`
**Status:** Complete — all three subprojects integrated

---

## What Was Built

### Sentry Projects Created (via MCP)

Three projects provisioned in the `zuralog` Sentry organization (slug: `zuralog`, region: `https://us.sentry.io`):

- `cloud-brain` — Python/FastAPI backend (DSN stored in Railway env)
- `website` — Next.js marketing site (DSN stored in Vercel env)
- `zuralog-flutter` — Flutter mobile app (DSN passed via `--dart-define`)

---

### Cloud Brain (FastAPI) — Commits 66b3354, a6ed4d0

- Added `sentry-sdk[fastapi,celery,sqlalchemy,httpx]>=2.19.0` to `pyproject.toml`
- Added `sentry_dsn`, `sentry_traces_sample_rate`, `sentry_profiles_sample_rate` to `app/config.py` Settings class
- Initialized Sentry in `app/main.py` before `FastAPI()` with `FastApiIntegration(transaction_style="endpoint")` and dynamic release string via `git rev-parse --short HEAD`
- Initialized Sentry separately in `app/worker.py` for Celery processes (separate OS process, needs own init)
- Created `app/middleware/sentry_context.py` — `SentryUserContextMiddleware` reads `request.state.user_id` (populated by auth handlers) and calls `sentry_sdk.set_user()`
- Created `app/middleware/__init__.py`
- All 14 route modules converted to router-level `dependencies=[Depends(_set_sentry_module)]` for `api.module` tagging on every request (not just first endpoint)
- Added `sentry_sdk.capture_exception()` to catch blocks in: `chat.py`, `transcribe.py`, `fitbit_webhooks.py`, `services/sync_scheduler.py`, `tasks/fitbit_sync.py`, `agent/llm_client.py`, `agent/mcp_client.py`
- Added `sentry_sdk.set_context("health_ingest", {...})` in `health_ingest.py` for structured health data context
- Added auth handlers (`health_ingest.py`, `users.py`, `devices.py`) to populate `request.state.user_id` for user attribution
- Added `SENTRY_DSN`, `SENTRY_TRACES_SAMPLE_RATE`, `SENTRY_PROFILES_SAMPLE_RATE` to `.env.example`

---

### Website (Next.js) — Commit 55f4af6

- Installed `@sentry/nextjs@^9` (used `--legacy-peer-deps` due to Next.js 16.1.6 being beyond SDK's `^15` peer range declaration — runtime compatible)
- Created `sentry.client.config.ts` — client-side init with Replay integration (session: 0%, on-error: 100%), ignoreErrors filter for noisy browser errors
- Created `sentry.server.config.ts` — server-side init
- Created `sentry.edge.config.ts` — edge runtime init
- Created `src/instrumentation.ts` — `register()` + `onRequestError = Sentry.captureRequestError`
- Wrapped `next.config.ts` with `withSentryConfig()` — sourcemaps with auto-delete, tunnel route `/monitoring`, tree-shaken logger
- Updated `src/app/error.tsx` — replaced `console.error` with `Sentry.captureException(error)`
- Created `src/app/global-error.tsx` — root layout error boundary
- Wrapped all 7 API route handlers with `Sentry.withServerActionInstrumentation()`: `waitlist/join`, `waitlist/stats`, `waitlist/status`, `waitlist/leaderboard`, `contact`, `support/stats`, `support/admin`
- Created `.env.sentry-build-plugin` (gitignored placeholder)
- Added `.env.sentry-build-plugin` to `website/.gitignore`

---

### Flutter (zuralog) — Commit 701c374

- Added `sentry_flutter: ^8.13.0` and `sentry_dio: ^8.13.0` to `pubspec.yaml` (resolved to 8.14.2 minor patch — compatible)
- Wrapped `runApp` in `main.dart` with `SentryFlutter.init()` guarded by `_kSentryDsn.isNotEmpty` dart-define constant
- Enabled: ANR detection (5s timeout), screenshot attachment, view hierarchy, auto native breadcrumbs, auto performance tracing
- Created `lib/core/monitoring/sentry_riverpod_observer.dart` — `SentryRiverpodObserver extends ProviderObserver` to capture all provider failures
- Registered `SentryRiverpodObserver` in `ProviderScope.observers` in both Sentry-wrapped and plain `runApp` paths
- Added `SentryNavigatorObserver()` to GoRouter `observers` list in `app_router.dart` for automatic screen navigation tracing
- Added `dio.addSentry()` to `api_client.dart` for HTTP span tracing and breadcrumbs on all API calls
- Added `Sentry.captureException` to catch blocks across 11 files: `main.dart`, `paywall_screen.dart`, `subscription_providers.dart`, `subscription_repository.dart`, `compatible_app_info_sheet.dart`, `integrations_provider.dart`, `health_sync_service.dart`, `profile_questionnaire_screen.dart`, `auth_providers.dart`, `social_auth_service.dart`, `fcm_service.dart`
- `dart analyze lib/` — 2 warnings only (experimental API notices from Sentry's own `profilesSampleRate` and `attachViewHierarchy` options)

---

## Deviations from Plan

- **Middleware user context ordering**: Plan suggested setting user context before `call_next`, but `request.state.user_id` is populated by auth handlers which run inside `call_next`. Resolution: middleware reads state after `call_next`; auth handlers that validate JWTs now also call `sentry_sdk.set_user()` directly for immediate attribution during request processing.
- **Router-level tagging vs first-endpoint**: Plan specified adding `sentry_sdk.set_tag()` to the first endpoint of each router. Improved to router-level `dependencies=[Depends(_set_sentry_module)]` so all routes in each module are tagged, not just the first one.
- **Dynamic release string**: Plan specified `cloud-brain@{app_version}` from pyproject.toml. Implemented as `git rev-parse --short HEAD` for per-commit release tracking, which is more useful for Sentry regression tracking.
- **Next.js peer dep**: `--legacy-peer-deps` needed for `@sentry/nextjs@9` with Next.js 16.1.6 (SDK declares `^15` peer range). Runtime behavior is unaffected.
- **`support/admin` route**: Actual file is at `api/support/admin/contribute/route.ts` (not `api/support/admin/route.ts` as in plan). Wrapped the actual file.

---

## Next Steps

- Set `SENTRY_DSN`, `SENTRY_TRACES_SAMPLE_RATE`, `SENTRY_PROFILES_SAMPLE_RATE` in Railway (production) for Cloud Brain
- Set `NEXT_PUBLIC_SENTRY_DSN`, `SENTRY_DSN`, `SENTRY_ORG`, `SENTRY_PROJECT`, `SENTRY_AUTH_TOKEN` in Vercel for Website
- Populate `SENTRY_AUTH_TOKEN` in `website/.env.sentry-build-plugin` for source map uploads
- Pass `--dart-define=SENTRY_DSN=...` in Flutter build commands for release builds
- Configure Sentry alert rules per plan section 6.1
- For production: lower `SENTRY_TRACES_SAMPLE_RATE` to `0.2` (currently `1.0` for dev)
- Phase 2: integrate Upstash (plan execution order 2 of 3)
- Phase 3: integrate PostHog (plan execution order 3 of 3)
