# Zuralog — Implementation Status

**Last Updated:** 2026-03-01  
**Purpose:** Historical record of what has been built, per major area. Synthesized from agent execution logs.

> This document covers *what was built*, including notable decisions made during implementation and deviations from the original plan. For *what's next*, see [roadmap.md](./roadmap.md).

---

## Cloud Brain (Backend)

### Built

The Cloud Brain is a fully functional FastAPI backend deployed on Railway with the following components:

**Authentication & Users**
- Supabase JWT validation on all protected endpoints via `deps.py`
- User creation on first login, linked to Supabase Auth identity
- Row Level Security (RLS) enforced at the Postgres level
- Google OAuth 2.0 (web + mobile)

**Agent Layer**
- Orchestrator with Reason → Tool → Act loop
- OpenRouter client calling `moonshotai/kimi-k2.5` (Kimi K2.5)
- MCP Client + Server Registry — plug-and-play tool routing
- Chat endpoint with Server-Sent Events (SSE) streaming
- Conversation history persistence

**MCP Servers (all production-registered)**
- `StravaServer` — activities, stats, create activity
- `FitbitServer` — 12 tools (activity, HR/HRV/intraday, sleep, SpO2, breathing rate, skin temp, VO2 max, weight, nutrition)
- `OuraServer` — 16 tools (sleep, readiness, activity, HR, SpO2, stress, resilience, cardiovascular age, VO2 max, workouts, sessions, tags, rest mode, sleep time, ring config)
- `AppleHealthServer` — ingest and read HealthKit data
- `HealthConnectServer` — ingest and read Health Connect data
- `DeepLinkServer` — URI scheme launch library for third-party apps

**Integrations**
- Strava: full OAuth 2.0, token auto-refresh, Celery sync (15min), webhooks, Redis sliding-window rate limiter
- Fitbit: OAuth 2.0 + PKCE, single-use refresh token handling, per-user Redis token-bucket rate limiter (150/hr), webhooks, Celery sync (15min) + token refresh (1hr)
- Oura Ring: OAuth 2.0 (no PKCE), long-lived tokens, app-level Redis sliding-window rate limiter (5,000/hr shared), per-app webhook subscriptions (90-day expiry with auto-renewal), sandbox mode, Celery sync
- Apple Health: ingest-only (native bridge handles reading; backend receives via platform channel)
- Google Health Connect: same pattern as Apple Health

**Infrastructure Services**
- Celery + Redis (Upstash) for background task queuing
- Sync scheduler orchestrating all provider syncs
- Firebase FCM push notification service
- RevenueCat webhook handler + subscription entitlement service
- Upstash cache layer (short/medium/long TTL patterns)
- SlowAPI rate limiter middleware
- Sentry error tracking (FastAPI + Celery + SQLAlchemy + httpx)

**Analytics**
- Correlation analysis engine
- Daily metrics aggregation
- Analytics API endpoints

**Database Models**
`User`, `Conversation`, `HealthData` (UnifiedActivity, SleepRecord, HealthMetric), `Integration`, `DailyMetrics`, `UserGoal`, `UserDevice`, `UsageLog`

### Key Deviations from Original Plan

| Original Plan | Actual Implementation | Reason |
|--------------|----------------------|--------|
| Direct Kimi K2.5 API | OpenRouter (`moonshotai/kimi-k2.5`) | OpenRouter provides routing flexibility and a single API surface for future model swaps |
| Fitbit marked as "Phase 5.1" | Fitbit fully implemented | Moved up due to high user value and available API |
| Pinecone vector store in Phase 1.8 | Not yet active | `PINECONE_API_KEY` env var exists; integration code not written yet |

---

## Flutter Edge Agent (Mobile)

### Built

**Core Infrastructure**
- Riverpod state management with code generation
- GoRouter navigation with authenticated route guards
- Dio HTTP client with auth interceptor (auto-attaches JWT)
- Drift local database for offline caching
- SecureStorage for JWT persistence
- `app_links` deep link interception
- Sentry + Sentry-Dio integration

**Auth**
- Email/password signup and login
- Google Sign In (native, iOS + Android)
- Onboarding screens
- Deep link OAuth callback handler (`zuralog://oauth/strava`, `zuralog://oauth/fitbit`, `zuralog://oauth/oura`)

**Chat**
- AI chat UI with streaming message display
- Markdown rendering (`flutter_markdown_plus`)
- Voice input button (UI present; backend endpoint exists; integration pending)
- File attachment button (UI present; feature pending)

**Dashboard**
- Health summary cards (steps, calories, sleep, activities)
- Charts (`fl_chart` — sparklines, trend charts)
- AI insight card

**Integrations Hub**
- Three sections: Connected / Available / Coming Soon
- Connected integrations: Strava, Apple Health (iOS), Google Health Connect (Android), Fitbit, Oura Ring
- Coming soon: Garmin, WHOOP
- Platform compatibility badges (iOS-only, Android-only)
- Persisted connection state via SharedPreferences

**Health Native Bridges**
- iOS: HealthKit native bridge with `HKObserverQuery` background observers, `HKAnchoredObjectQuery` incremental sync, 30-day initial backfill, iOS Keychain JWT persistence for background-only sync
- Android: Health Connect WorkManager periodic task, EncryptedSharedPreferences JWT persistence, 30-day initial backfill

**Settings**
- User profile display
- Preferences management
- Data export placeholder ("Coming soon")

**Subscription**
- RevenueCat paywall (Pro upgrade flow)
- Entitlement-aware feature gating

**Testing**
- 36 unit tests + integration tests

### Key Deviations from Original Plan

| Original Plan | Actual Implementation | Reason |
|--------------|----------------------|--------|
| `health` Flutter package for unified health API | Native Swift/Kotlin platform channels directly | Better reliability, deeper API access, and avoids third-party wrapper maintenance |
| `record` package for voice input | Not in pubspec.yaml | Voice input routes through Cloud Brain Whisper endpoint; no local recording library needed |
| Apple Sign In (live) | Coming soon (UI shows dialog) | Pending Apple Developer subscription |

---

## Website

### Built

A full marketing and waitlist site built on Next.js 16:

**Core Pages**
- Landing page with hero section, animated text
- 3D phone mockup (Three.js + React Three Fiber) rotates in hero
- GSAP + Framer Motion animations throughout
- Lenis smooth scroll

**Waitlist System**
- Supabase-backed signup
- Animated waitlist counter
- Support leaderboard
- Waitlist statistics bar
- Confetti burst on signup
- Upstash rate limiting on API endpoints

**User Experience**
- Multi-step onboarding quiz flow to personalize waitlist experience
- iPhone mockup component for app preview

**Legal & Company Pages**
- Privacy Policy (GDPR / CCPA compliant)
- Terms of Service
- Cookie Policy
- Community Guidelines
- About page
- Contact form
- Support page

**Technical**
- OpenGraph image (server-rendered)
- Sitemap + robots.txt
- Sentry error tracking
- Vercel Analytics
- Resend transactional email
- React Hook Form + Zod validation

### Key Deviations from Original Plan

| Original Plan | Actual Implementation | Reason |
|--------------|----------------------|--------|
| Simple landing page | Full marketing site with legal pages, About, Contact, Support | Required for App Store review + GDPR |
| Basic animations | Three.js, GSAP, Framer Motion, Lenis | Higher-quality brand impression |

---

## Oura Ring Direct Integration (2026-03-01) — Code Complete, Credentials Blocked

> **Status:** All backend and Flutter code is implemented and merged on `feat/oura-direct-integration`. Deployment is blocked because registering an Oura OAuth application requires an active Oura account, which in turn requires owning an Oura Ring. Once the hardware is acquired, the remaining steps are: create account → register app at cloud.ouraring.com/oauth/applications → add credentials to Bitwarden + `.env` + Railway → flip the Flutter tile from "Coming Soon" to live.

## Oura Ring Direct Integration (2026-03-01)

Full Oura Ring integration implemented as a direct REST API connection, providing 16 data types unavailable via HealthKit/Health Connect alone.

**Backend files created (6):**
- `cloud-brain/app/services/oura_token_service.py` — OAuth 2.0 token management (no PKCE), refresh on 401, sandbox mode via `OURA_USE_SANDBOX=true`
- `cloud-brain/app/services/oura_rate_limiter.py` — App-level Redis sliding-window rate limiter (5,000 req/hr shared across all users; no response headers to track)
- `cloud-brain/app/mcp_servers/oura_server.py` — 16 MCP tools covering all Oura data types
- `cloud-brain/app/api/v1/oura_routes.py` — OAuth routes: `/authorize`, `/exchange`, `/status`, `/disconnect`
- `cloud-brain/app/api/v1/oura_webhooks.py` — Webhook receiver with HMAC verification; per-app subscription (90-day expiry)
- `cloud-brain/app/tasks/oura_sync_tasks.py` — Celery tasks: data sync, token refresh, webhook auto-renewal (runs daily; renews if < 7 days to expiry)

**Flutter files created (4):**
- `zuralog/lib/features/integrations/oura_oauth_page.dart` — OAuth flow + deep link callback (`zuralog://oauth/oura`)
- `zuralog/lib/features/integrations/providers/oura_provider.dart` — Riverpod provider for connection state
- `zuralog/lib/features/integrations/services/oura_integration_service.dart` — API calls: connect, disconnect, status
- `zuralog/lib/features/integrations/widgets/oura_tile.dart` — Integrations Hub tile

**Test coverage (171 tests total):**

| File | Tests |
|------|-------|
| `tests/services/test_oura_token_service.py` | 48 |
| `tests/services/test_oura_rate_limiter.py` | 12 |
| `tests/api/test_oura_routes.py` | 14 |
| `tests/mcp_servers/test_oura_server.py` | 49 |
| `tests/api/test_oura_webhooks.py` | 12 |
| `tests/tasks/test_oura_sync_tasks.py` | 36 |
| **Total** | **171** |

**Key implementation decisions:**

| Decision | Rationale |
|----------|-----------|
| No PKCE | Oura's OAuth spec does not use PKCE (unlike Fitbit); standard Authorization Code flow with Basic auth header on token exchange |
| App-level rate limiter | Oura enforces 5,000 req/hr per app (not per user); sliding-window counter in Redis is the only mechanism since Oura returns no rate-limit headers |
| Sandbox mode | `OURA_USE_SANDBOX=true` + `OURA_SANDBOX_TOKEN` allows full MCP tool testing without a real ring or OAuth credentials |
| Per-app webhook subscription | Unlike Fitbit (per-user subscriptions), Oura uses one subscription covering all users; stored in `oura_webhook_subscriptions` table; auto-renewed via Celery Beat 7 days before expiry |
| Webhook-only for 5 types | Only `daily_sleep`, `daily_activity`, `daily_readiness`, `daily_spo2`, `sleep` receive webhooks; stress, resilience, cardiovascular age, and ring data require periodic Celery poll |

---

## Celery / Railway Production Fix (2026-03-01)

All three Railway services (**Zuralog** web, **Celery_Worker**, **Celery_Beat**) are now fully deployed and running.

**Root causes fixed:**

1. **Missing `posthog` in lockfile** — `posthog>=3.7.0` was added to `pyproject.toml` but `uv.lock` was never regenerated. The Dockerfile uses `uv sync --frozen`, so `posthog` was absent at runtime, causing `ModuleNotFoundError` on uvicorn startup and failing every `/health` healthcheck.

2. **No Railway config for Celery services** — Worker and Beat had no `railway.*.toml` files, so Railway had no start command. Created `cloud-brain/railway.celery-worker.toml` and `cloud-brain/railway.celery-beat.toml` with Dockerfile builder, correct `celery` start commands, and no `healthcheckPath` (Celery is not an HTTP server).

3. **Celery SSL config for Upstash `rediss://`** — Celery 5.x requires explicit `broker_use_ssl` / `redis_backend_use_ssl` with `ssl_cert_reqs` when using TLS. Added to `worker.py` using `ssl.CERT_REQUIRED` (Upstash uses CA-signed DigiCert certs).

**Security hardening applied:**

- `ssl.CERT_REQUIRED` (not `CERT_NONE`) — full TLS certificate verification against system CA bundle.
- Dockerfile runtime stage now creates a non-root `appuser` (uid=1000); Celery and uvicorn both run as non-root, eliminating Celery's SecurityWarning.

---

## Waitlist Bug Fix (2026-02-24)

A critical bug in the waitlist signup flow was identified and fixed:

**Root cause:** Schema mismatch between the API payload and the Supabase database table. The API was sending fields that didn't exist or had wrong types in the `waitlist_signups` table.

**Fix applied:**
- Corrected Supabase table schema to match API expectations
- Updated API routes to use correct field names
- Fixed TypeScript types in the frontend
- Enhanced UI with animated counter and dark-only theme
