# Zuralog — Implementation Status

**Last Updated:** 2026-03-05 (fix/mobile-sprint-1 — Mobile bug fix sprint 1 complete)  
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
- `WithingsServer` — 10 tools (body composition, blood pressure, temperature, SpO2, HRV, activity, workouts, sleep, sleep summary, ECG/heart)
- `AppleHealthServer` — ingest and read HealthKit data
- `HealthConnectServer` — ingest and read Health Connect data
- `DeepLinkServer` — URI scheme launch library for third-party apps

**Integrations**
- Strava: full OAuth 2.0, token auto-refresh, Celery sync (15min), webhooks, Redis sliding-window rate limiter
- Fitbit: OAuth 2.0 + PKCE, single-use refresh token handling, per-user Redis token-bucket rate limiter (150/hr), webhooks, Celery sync (15min) + token refresh (1hr)
- Oura Ring: OAuth 2.0 (no PKCE), long-lived tokens, app-level Redis sliding-window rate limiter (5,000/hr shared), per-app webhook subscriptions (90-day expiry with auto-renewal), sandbox mode, Celery sync
- Withings: OAuth 2.0 with HMAC-SHA256 request signing (unique), server-side callback, app-level rate limiter (120 req/min), 7 webhook `appli` codes, 10 MCP tools, `BloodPressureRecord` new model; credentials pending
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
- Deep link OAuth callback handler (`zuralog://oauth/strava`, `zuralog://oauth/fitbit`, `zuralog://oauth/oura`, `zuralog://oauth/withings`)

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

**Settings & Profile — Phase 8 (12 screens, fully built)**

- **Settings Hub** — iOS-style grouped list, icon badges, section labels, `SliverAppBar` large-title header; routes to all settings sub-screens
- **Account Settings** — name, email, password change rows; destructive Delete Account with confirmation dialog
- **Notification Settings** — granular per-category toggles (Coach insights, workout reminders, streak alerts, weekly reports, security); time-range picker for quiet hours
- **Appearance Settings** — Dark / Light / System theme selector with visual tile picker; language selector
- **Coach Settings** — AI coach persona toggle, coaching style selector (3 options), response detail level, proactive suggestions toggle, data sharing consent toggle
- **Integrations Management** — status tiles for all connected integrations (Strava, Apple Health, Health Connect, Fitbit, Oura Ring) with connect/disconnect actions; routes back to main Integrations screen
- **Privacy & Data** — data export request, analytics opt-out, delete all data with confirmation; links to Privacy Policy and Terms of Service screens
- **Subscription** — Free vs. Pro tier comparison; feature matrix; upgrade CTA (RevenueCat); restore purchases
- **About** — app version, build number, acknowledgements; links to Privacy Policy and Terms of Service screens
- **Profile Screen** — avatar with initials fallback, inline name edit, subscription tier badge, Emergency Health Card banner, account stats (joined date, workouts logged), sign-out
- **Emergency Health Card (view)** — high-contrast read-only view (blood type, allergies, conditions, medications, 3 emergency contacts); formatted for first-responder legibility
- **Emergency Health Card (edit)** — blood type picker, tag-style chip inputs for allergies/conditions/medications, 3 structured contact editors; persisted via `emergencyCardProvider`
- **Privacy Policy** — full GDPR/CCPA-compliant policy (11 sections); `SliverAppBar` + scrollable rich text
- **Terms of Service** — full ToS (13 sections, medical disclaimer); same layout

Legal routes added: `/settings/privacy-policy`, `/settings/terms` in `route_names.dart` + `app_router.dart`

**Subscription**
- RevenueCat paywall (Pro upgrade flow)
- Entitlement-aware feature gating

**Testing**
- 36 unit tests + integration tests

### Key Deviations from Original Plan

| Original Plan | Actual Implementation | Reason |
|--------------|----------------------|--------|
| `health` Flutter package for unified health API | Native Swift/Kotlin platform channels directly | Better reliability, deeper API access, and avoids third-party wrapper maintenance |
| Cloud Whisper STT for voice input | On-device STT via `speech_to_text` Flutter package | Free, offline, no API key required; audio never leaves the device |
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

## Design System v3.1 + App Shell Rebuild (2026-03-04)

### Phase 0: Design System Foundation

Full design system v3.1 established as the canonical token layer for all future Flutter work.

**Files created:**
- `zuralog/lib/core/theme/app_colors.dart` — All color tokens: `primary` (Sage Green `#CFE1B9`), OLED `scaffold` (`#000000`), `surface` (`#1C1C1E`), `cardBackground` (`#121212`), category colors (`categoryActivity`, `categorySleep`, `categoryHeart`, `categoryMindfulness`, `categoryNutrition`, `categoryBody`), semantic colors (`success`, `warning`, `error`, `info`), text hierarchy (`textPrimary`…`textQuaternary`)
- `zuralog/lib/core/theme/app_text_styles.dart` — Typography tokens: `h1`–`h3`, `body`, `caption`, `labelXs` (SF Pro Display / Inter)
- `zuralog/lib/core/theme/app_dimens.dart` — Spacing (`xs`=4…`xxl`=48), border radius (`cardRadius`=20, `buttonRadius`=14), icon sizes
- `zuralog/lib/core/theme/app_theme.dart` — `ThemeData` wired to all tokens; dark-first, OLED scaffold
- `zuralog/lib/core/haptics/haptic_service.dart` + `haptic_providers.dart` + `haptic.dart` barrel — `HapticService` with `selectionClick`, `lightImpact`, `mediumImpact`, `heavyImpact`, `success`, `error`, `warning`

**Key decisions:**
- Dark-first: `scaffoldBackgroundColor` is OLED true black (`#000000`); light mode tokens present but secondary priority
- No hardcoded hex in widget files — all widgets import `AppColors.*` and `AppTextStyles.*`
- Cards: `borderRadius: 20`, no border, no shadow — depth from background color contrast only
- Primary actions: `FilledButton` with `AppColors.primary`, `borderRadius: 14`

### Phase 1: App Shell & 5-Tab Navigation

Replaced the old 2-tab shell (Dashboard + Chat) with the full 5-tab architecture defined in `screens.md`.

**Files modified:**
- `zuralog/lib/shared/layout/app_shell.dart` — Rebuilt as 5-tab `NavigationBar` with `BackdropFilter` Gaussian blur (σ=20), frosted glass effect, 200ms curve animation, haptic selection tick via `hapticServiceProvider`, sage green active / `textTertiary` inactive, no indicator pill
- `zuralog/lib/core/router/app_router.dart` — Rebuilt with `StatefulShellRoute.indexedStack` (5 branches: Today / Data / Coach / Progress / Trends), all settings nested under `/settings`, profile sub-routes under `/profile`, auth guard preserved
- `zuralog/lib/core/router/route_names.dart` — All 37 route name + path constants

**Files created (placeholder screens):**
- Today: `today_feed_screen.dart`, `insight_detail_screen.dart`, `notification_history_screen.dart`
- Data: `health_dashboard_screen.dart`, `category_detail_screen.dart`, `metric_detail_screen.dart` (new `features/data/` directory)
- Coach: `new_chat_screen.dart`, `chat_thread_screen.dart`
- Progress: `progress_home_screen.dart`, `goals_screen.dart`, `goal_detail_screen.dart`, `achievements_screen.dart`, `weekly_report_screen.dart`, `journal_screen.dart`
- Trends: `trends_home_screen.dart`, `correlations_screen.dart`, `reports_screen.dart`, `data_sources_screen.dart`
- Settings (9 screens): hub, account, notifications, appearance, coach, integrations, privacy, subscription, about
- Profile: `profile_screen.dart`, `emergency_card_screen.dart`, `emergency_card_edit_screen.dart`

**Key decisions:**
- `StatefulShellRoute.indexedStack` preserves tab state across navigation (no re-renders on tab switch)
- Frosted glass nav bar keeps OLED background visible — no opaque bottom chrome
- All screens are placeholder scaffolds — real implementations follow in Phases 3–8

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

## Withings Direct Integration (2026-03-01) — Code Complete, Credentials Pending

> **Status:** All backend and Flutter code is implemented on `feat/withings-integration`. Deployment is blocked on setting `WITHINGS_CLIENT_ID` and `WITHINGS_CLIENT_SECRET` in Railway (credentials are in BitWarden). The `WITHINGS_REDIRECT_URI` is already set on the Zuralog Railway service. Once credentials are configured on all three Railway services (Zuralog, Celery_Worker, Celery_Beat), the branch can be deployed and E2E tested.

Full Withings integration providing body composition, sleep, blood pressure, temperature, SpO2, HRV, ECG, and activity data via the Withings Health API (HMAC-SHA256 request signing).

**Backend files created (8):**
- `cloud-brain/app/services/withings_signature_service.py` — HMAC-SHA256 nonce+signature service; every Withings API call gets a fresh nonce from `/v2/signature`, then signs `action,client_id,nonce` with HMAC-SHA256
- `cloud-brain/app/services/withings_token_service.py` — OAuth 2.0 token management (no PKCE); 3-hour access tokens with 30-minute proactive refresh buffer; stores `user_id` (not `"1"`) in Redis state for server-side callback resolution
- `cloud-brain/app/services/withings_rate_limiter.py` — App-level Redis Lua-atomic rate limiter (120 req/min shared; Withings enforces at app level)
- `cloud-brain/app/models/blood_pressure.py` — New `BloodPressureRecord` DB model; Supabase migration applied (`blood_pressure_records` table with uq constraint on `user_id+source+measured_at`)
- `cloud-brain/app/api/v1/withings_routes.py` — OAuth routes: `/authorize`, `/callback` (server-side; browser redirect then deep-link redirect to `zuralog://oauth/withings`), `/status`, `/disconnect`
- `cloud-brain/app/api/v1/withings_webhooks.py` — Webhook receiver (form-encoded POST, not JSON); dispatches Celery tasks per `appli` code
- `cloud-brain/app/mcp_servers/withings_server.py` — `WithingsServer` with 10 MCP tools covering all Withings data types
- `cloud-brain/app/tasks/withings_sync.py` — 5 Celery tasks: notification sync, 15-min periodic, 1-hr token refresh, 30-day backfill, webhook subscription creation

**Backend files modified (2):**
- `cloud-brain/app/main.py` — wired `WithingsSignatureService`, `WithingsTokenService`, `WithingsRateLimiter`, `WithingsServer`; mounted routes
- `cloud-brain/app/worker.py` — added Beat schedules: `sync-withings-users-15m` (900s), `refresh-withings-tokens-1h` (3600s)

**Flutter files modified (3):**
- `zuralog/lib/features/integrations/data/oauth_repository.dart` — added `getWithingsAuthUrl()` (GET `/api/v1/integrations/withings/authorize`)
- `zuralog/lib/features/integrations/domain/integrations_provider.dart` — added Withings to `_defaultIntegrations` and `connect()` switch case
- `zuralog/lib/core/deeplink/deeplink_handler.dart` — added `withings` provider case; reads `success` query param from `zuralog://oauth/withings?success=true`

**Test coverage (71 new tests):**

| File | Tests |
|------|-------|
| `tests/test_withings_signature_service.py` | 10 |
| `tests/test_withings_token_service.py` | 16 |
| `tests/test_withings_rate_limiter.py` | 12 |
| `tests/test_withings_routes.py` | 11 |
| `tests/test_withings_webhooks.py` | 7 |
| `tests/test_withings_server.py` | 15 |
| **Total** | **71** |

**Key implementation decisions:**

| Decision | Rationale |
|----------|-----------|
| Standalone `WithingsSignatureService` | HMAC-SHA256 nonce+signature is unique to Withings among all integrations; isolating it into its own class makes testing clean and reuse straightforward |
| Server-side OAuth callback | Withings validates callback URL reachability at app registration — `zuralog://` custom schemes are rejected. Backend receives the code at `https://api.zuralog.com/api/v1/integrations/withings/callback`, exchanges it within the 30-second window, then redirects the browser to `zuralog://oauth/withings?success=true` |
| `store_state` stores `user_id` | Unlike Oura (which stores `"1"`), Withings' server-side callback has no JWT available — user identity is resolved from the `state` → `user_id` Redis lookup |
| Webhook subscribe uses Bearer auth (no signing) | Only data API calls require HMAC-SHA256 signatures; Withings' `notify/subscribe` endpoint uses standard Bearer token auth |
| 30-minute refresh buffer | Access tokens expire in 3 hours (most aggressive of all integrations); 30-minute buffer ensures proactive refresh before expiry during long-running tasks |
| `BloodPressureRecord` as new model | No existing BP model in codebase; designed to support future integrations (not Withings-specific); includes `source` field for multi-provider dedup |
| App-level rate limiter at 120/min | Withings enforces 120 req/min at the application level (not per-user); Redis Lua atomic INCR+EXPIRE, fail-open on Redis errors |

**Webhook `appli` codes handled:**
```
1=weight/body comp → getmeas (1,5,6,8,76,77,88,91)
2=temperature → getmeas (12,71,73)
4=blood pressure/SpO2 → getmeas (9,10,11,54)
16=activity → getactivity / getworkouts
44=sleep → sleep v2 getsummary
54=ECG → heart v2 list
62=HRV → getmeas (135)
```

**MCP tools (10):** `withings_get_measurements`, `withings_get_blood_pressure`, `withings_get_temperature`, `withings_get_spo2`, `withings_get_hrv`, `withings_get_activity`, `withings_get_workouts`, `withings_get_sleep`, `withings_get_sleep_summary`, `withings_get_heart_list`

---

## WHOOP Integration — Deferred (2026-03-01)

WHOOP was researched and planned as a P1 direct integration. Implementation was deferred after confirming that the WHOOP Developer Dashboard (`developer-dashboard.whoop.com`) requires an active WHOOP membership to create an account and register an OAuth application. This is a hardware dependency, not a policy gate — there is no workaround.

**Decision:** Moved to P2/Future. Will revisit when user demand from the WHOOP member segment justifies acquiring hardware. All technical research and the implementation plan are preserved in `.opencode/plans/2026-02-28-direct-integrations-top10-research.md`.

**Next integration:** Withings (P1).

---

## Dynamic Tool Injection (2026-03-02)

**Branch:** `feat/dynamic-tool-injection`  
**Status:** Complete — squash-merged to main

### What Was Built

A per-user MCP tool filtering layer that injects only the tools for integrations the user has actually connected, rather than all registered MCP tools.

**New file:**
- `app/services/user_tool_resolver.py` — `UserToolResolver` class with `ALWAYS_ON_SERVERS` frozenset and `PROVIDER_TO_SERVER` allowlist dict. Uses `select(Integration.provider)` (column-only projection — no token data loaded) with `WHERE user_id = ? AND is_active IS TRUE` on the indexed column. Maps provider strings → server names, unions with always-on servers, calls `MCPServerRegistry.get_tools_for_servers()`.

**Modified files:**
- `app/mcp_servers/registry.py` — Added `get_tools_for_servers(server_names: AbstractSet[str])` filtered aggregation method
- `app/agent/mcp_client.py` — Added optional `tool_resolver` param to `__init__`; added `get_tools_for_user(db, user_id)` async method
- `app/agent/orchestrator.py` — `_build_tools_for_llm()` accepts pre-resolved tool list; `process_message()` accepts optional `db: AsyncSession | None = None`
- `app/main.py` — Wires `UserToolResolver` into `MCPClient` at startup
- `app/api/v1/chat.py` — Passes `db` session to `orchestrator.process_message()`; removed dead `_get_orchestrator` dependency function

**Test coverage:** 40 new/updated tests across 5 files including an end-to-end integration test.

### Key Decisions

- **Column-only query:** `select(Integration.provider)` — does not load OAuth tokens or metadata into memory. Returns plain strings.
- **DB query per request (no cache):** ~1ms async Postgres query on indexed `user_id` column. Revisit with Redis only if profiling shows bottleneck.
- **Fail-open:** DB failure falls back to all tools — chat never breaks due to resolver error.
- **Backwards-compatible:** All parameters default to `None`; existing call sites unchanged.
- **Allowlist mapping:** `PROVIDER_TO_SERVER` dict means unknown provider values in DB are silently dropped — no injection risk.

---

## Polar AccessLink Direct Integration (2026-03-01) — Code Complete, Credentials Set

Full Polar AccessLink integration providing exercise data, daily activity, continuous heart rate, sleep, Nightly Recharge (ANS/HRV recovery), cardio load, SleepWise alertness/circadian bedtime, Elixir body temperature, and physical information from Polar watches and sensors.

**New files:**
- `cloud-brain/app/services/polar_token_service.py` — OAuth 2.0 token lifecycle (auth URL, code exchange with Basic auth, mandatory user registration, save/retrieve/disconnect); no refresh tokens (~1 year access tokens)
- `cloud-brain/app/services/polar_rate_limiter.py` — Dynamic dual-window app-level rate limiter (short: `500 + N×20` per 15 min; long: `5000 + N×100` per 24 hr); limits updated from Polar response headers (`RateLimit-Usage`, `RateLimit-Limit`, `RateLimit-Reset`), fail-open
- `cloud-brain/app/api/v1/polar_routes.py` — OAuth endpoints: `GET /authorize`, `POST /exchange`, `GET /status`, `DELETE /disconnect`; IDOR prevention via state→user_id lookup; mandatory user registration step after token exchange
- `cloud-brain/app/api/v1/polar_webhooks.py` — Webhook handler with HMAC-SHA256 signature verification (`Polar-Webhook-Signature` header); handles PING event (sent on webhook creation); always returns 200 to prevent 7-day auto-deactivation
- `cloud-brain/app/mcp_servers/polar_server.py` — `PolarServer` with 14 MCP tools covering all Polar data types
- `cloud-brain/app/tasks/polar_sync.py` — 6 Celery tasks: webhook-triggered sync, 15-min periodic sync, daily token expiry monitor (push notification 30 days before expiry), 28-day backfill, webhook creation (client-level Basic auth), daily webhook status check + re-activation

**Modified files:**
- `cloud-brain/app/config.py` — added `polar_client_id`, `polar_client_secret`, `polar_redirect_uri`, `polar_webhook_signature_key`
- `cloud-brain/app/main.py` — wired `PolarTokenService`, `PolarRateLimiter`, `PolarServer`; mounted routes and webhook router
- `cloud-brain/app/worker.py` — added 3 Beat schedules: `sync-polar-users-15m`, `monitor-polar-token-expiry-daily`, `check-polar-webhook-status-daily`
- `zuralog/lib/features/integrations/data/oauth_repository.dart` — added `getPolarAuthUrl()` and `handlePolarCallback()`
- `zuralog/lib/features/integrations/domain/integrations_provider.dart` — added Polar to `_defaultIntegrations` (Available) and `connect()` switch case
- `zuralog/lib/core/deeplink/deeplink_handler.dart` — added `case 'polar':` and `_handlePolarCallback()`

**Tests:** 137 tests total across 5 test files (token service 42, rate limiter 20, webhooks 13, MCP server 33, sync tasks 29)

**Key decisions:**

| Decision | Rationale |
|----------|-----------|
| Basic auth on token exchange | Polar requires `Authorization: Basic base64(client_id:client_secret)` — unlike most providers that accept credentials in the POST body. `redirect_uri` must also be echoed per RFC 6749 §4.1.3 |
| Mandatory user registration | Polar AccessLink requires `POST /v3/users {"member-id": user_id}` after every first OAuth before any data can be fetched. 409 (already registered) is handled gracefully |
| No refresh tokens | Polar issues ~1-year access tokens with no refresh mechanism. Expired tokens require full re-auth; `monitor_polar_token_expiry_task` sends push notification 30 days before expiry |
| Single client-level webhook | Polar issues one webhook per client covering all users (unlike Fitbit/Withings which are per-user). Webhook auto-deactivates after 7 days of failures → `check_polar_webhook_status_task` checks daily and re-activates if needed |
| Dynamic dual-window rate limits | Polar's limits scale with registered user count: `500 + (N×20)` per 15 min, `5000 + (N×100)` per 24 hr. Headers are authoritative; formula is fallback. Block at 90% safety margin |
| Two auth modes | Bearer token for user data endpoints; Basic auth for client-level endpoints (webhook CRUD, pull notifications). `_basic_auth_header()` helper in sync tasks |
| Data window | Polar only exposes last 30 days and only data uploaded after user registration. Backfill uses 28-day window to be safe |

**MCP tools (14):** `polar_get_exercises`, `polar_get_exercise`, `polar_get_daily_activity`, `polar_get_activity_range`, `polar_get_continuous_hr`, `polar_get_continuous_hr_range`, `polar_get_sleep`, `polar_get_nightly_recharge`, `polar_get_cardio_load`, `polar_get_cardio_load_range`, `polar_get_sleepwise_alertness`, `polar_get_sleepwise_bedtime`, `polar_get_body_temperature`, `polar_get_physical_info`

---

## Waitlist Bug Fix (2026-02-24)

A critical bug in the waitlist signup flow was identified and fixed:

**Root cause:** Schema mismatch between the API payload and the Supabase database table. The API was sending fields that didn't exist or had wrong types in the `waitlist_signups` table.

**Fix applied:**
- Corrected Supabase table schema to match API expectations
- Updated API routes to use correct field names
- Fixed TypeScript types in the frontend
- Enhanced UI with animated counter and dark-only theme

---

## Voice Input — On-Device STT (2026-03-02)

**Branch:** `feat/voice-input-stt`
**Status:** Complete

On-device speech-to-text using the `speech_to_text` Flutter package (v7.3.0). Audio never leaves the device. No API key or network required (uses Apple Speech framework on iOS, Google Speech Services on Android).

**New files:**
- `zuralog/lib/core/speech/speech_state.dart` — Immutable state model (`SpeechStatus` enum, `SpeechState` class with `copyWith`, equality, `toString`)
- `zuralog/lib/core/speech/speech_service.dart` — Service wrapper around `SpeechToText` plugin (init, listen, stop, cancel, sound level normalization dBFS → 0–1)
- `zuralog/lib/core/speech/speech_providers.dart` — `SpeechNotifier` (StateNotifier) + `speechNotifierProvider` (Riverpod autoDispose)
- `zuralog/lib/core/speech/speech.dart` — Barrel export
- `zuralog/test/core/speech/speech_service_test.dart` — 29 unit tests using `_FakeSpeechToText extends SpeechToText` (hand-rolled fake using `withMethodChannel()` ctor)
- `zuralog/test/core/speech/speech_providers_test.dart` — 6 unit tests using `_FakeSpeechService extends SpeechService`

**Modified files:**
- `zuralog/lib/features/chat/presentation/widgets/chat_input_bar.dart` — Hold-to-talk `GestureDetector` on mic button; animated pulsing circle feedback; `didUpdateWidget` inserts recognized text into field on listen stop
- `zuralog/lib/features/chat/presentation/chat_screen.dart` — Wires `SpeechNotifier` to `ChatInputBar`; listening overlay banner with `_PulsingDot`; speech error SnackBars; PostHog analytics (`voice_input_started`, `voice_input_completed` with `text_length` / `has_text` properties)
- `zuralog/pubspec.yaml` — Added `speech_to_text: ^7.3.0`
- `zuralog/ios/Runner/Info.plist` — Added `NSSpeechRecognitionUsageDescription` + `NSMicrophoneUsageDescription`
- `zuralog/android/app/src/main/AndroidManifest.xml` — Added `RECORD_AUDIO` permission + speech `RecognitionService` query (BLUETOOTH/BLUETOOTH_CONNECT intentionally omitted — not required for on-device mic STT and would trigger Play Store dangerous-permission review)
- `zuralog/test/features/chat/presentation/widgets/chat_input_bar_test.dart` — Updated for new widget structure; 4 new voice input tests (11 total)

**UX:** Hold-to-talk. User long-presses mic button → listening starts → partial text shown in overlay banner → release → final text fills input field → user reviews/edits → taps send. Cancel by dragging away.

**Key decisions:**

| Decision | Rationale |
|----------|-----------|
| On-device STT (not Cloud Whisper) | Free, offline, no API key; audio never leaves device; existing `/api/v1/transcribe/` endpoint remains as future option |
| Hold-to-talk (not tap-to-toggle) | More intuitive for short phrases; matches iMessage/WhatsApp voice note UX; natural start/stop boundary |
| Fill text field (not auto-send) | Users review and edit transcription before sending; prevents embarrassing mis-transcriptions |
| Lazy initialization | Speech engine initialized on first mic tap, not app startup; avoids permission prompt on first launch |
| Hand-rolled fakes (not Mockito) | `SpeechToText` and `SpeechService` are concrete classes with platform channels — cannot be mocked with `@GenerateMocks`; `SpeechToText.withMethodChannel()` is the plugin's `@visibleForTesting` extension point |
| 30-second listen limit | Apple recommends max 1 minute; 30s is sufficient for chat commands and reduces battery impact |
| Analytics captured in `ref.listen` (not `onVoiceStop`) | `stopListening()` fires before the plugin's async final result arrives; reading `recognizedText` in the callback gives 0/partial text. `ref.listen` fires on the `isFinal` transition which has the full final text |
| Error-state early return in `onVoiceStart` | Prevents a permission-denied error from looping silently on every long-press. The `ref.listen` SnackBar already surfaces the error; `onVoiceStart` returns early to avoid re-triggering |
| `SpeechNotifier` seeded from `currentState` | `autoDispose` notifier re-creates on re-navigation; seeding from the persistent service's `currentState` prevents the notifier from advertising `uninitialized` when the engine is already `ready` |

---

## Phase 7 — Trends Tab (2026-03-04)

**Branch:** `feat/trends-tab`
**Status:** Complete

Full Trends tab UI — 4 screens built with Riverpod state management, design system tokens, and dark-first layout.

**New files:**
- `zuralog/lib/features/trends/domain/trends_models.dart` — Domain models: `CorrelationHighlight`, `TimePeriodSummary`, `MetricHighlight`, `TrendsHomeData`, `AvailableMetric`, `ScatterPoint`, `CorrelationAnalysis`, `CorrelationTimeRange`, `GeneratedReport`, `ReportCategorySummary`, `TrendDirection`, `ReportList`, `DataFreshness`, `DataSource`, `DataSourceList`
- `zuralog/lib/features/trends/data/trends_repository.dart` — Data layer with 5-min TTL cache; endpoints: trends home, available metrics, correlation analysis (uncached family keyed by metric pair + time range + lag), reports, data sources
- `zuralog/lib/features/trends/providers/trends_providers.dart` — Riverpod providers: `trendsRepositoryProvider`, `trendsHomeProvider`, `availableMetricsProvider`, `selectedMetricAProvider`, `selectedMetricBProvider`, `selectedLagDaysProvider`, `selectedTimeRangeProvider`, `CorrelationKey` + `correlationAnalysisProvider` family, `reportsProvider`, `dataSourcesProvider`
- `zuralog/lib/features/trends/presentation/trends_home_screen.dart` — AI correlation cards, horizontal time-machine strip, quick-nav row (Explorer/Reports/Sources), loading skeleton, error state, onboarding empty state, pull-to-refresh
- `zuralog/lib/features/trends/presentation/correlations_screen.dart` — Two-metric picker (bottom sheet grouped by health category), time-range chips (7D/30D/90D), lag-day selector (same day/+1/+2/+3), scatter plot (`fl_chart` `ScatterChart`), Pearson coefficient card, AI annotation card, picker-prompt empty state
- `zuralog/lib/features/trends/presentation/reports_screen.dart` — Report list with category avatar dots, `_ReportDetailSheet` modal (category summaries, trend direction chips, top correlations, AI recommendations), export PDF + share placeholders with "coming soon" snackbar
- `zuralog/lib/features/trends/presentation/data_sources_screen.dart` — Connected/Not Connected grouped sections, per-source freshness dot (green/yellow/red based on `DataFreshness`), last sync timestamp, data type chips, Reconnect/Connect → `settingsIntegrationsPath`

**Key decisions:**

| Decision | Rationale |
|----------|-----------|
| Uncached `correlationAnalysisProvider` family | Correlation queries are keyed by 3 independent state variables; caching at repository layer would require LRU eviction logic; provider-level invalidation is simpler and sufficient |
| `CorrelationKey` value class for family key | Riverpod family requires a single key; `CorrelationKey` bundles metricA + metricB + timeRange + lagDays with `==`/`hashCode` to deduplicate in-flight requests |
| Scatter plot via `fl_chart` `ScatterChart` | Already a project dependency (used in Progress tab); avoids adding `syncfusion_flutter_charts` which requires a license key |
| "Coming soon" snackbar for PDF export | PDF generation requires a native plugin (`pdf`, `printing`) not yet in pubspec; surface the intent without a broken flow |
| `DataFreshness` color thresholds: green ≤1h, yellow ≤24h, red >24h | Matches Apple Health's own staleness UX; users expect sub-hour freshness for wearable data |

---

## Phase 9 — Onboarding Rebuild (2026-03-05)

**Branch:** `feat/onboarding-rebuild`
**Status:** Complete

Replaced the old 3-field `ProfileQuestionnaireScreen` with a new 6-step paginated `OnboardingFlowScreen`. Updated `docs/screens.md` to v1.2 with all MVP feature additions from `mvp-features.md` Section 8.

**New files:**
- `zuralog/lib/features/onboarding/presentation/onboarding_flow_screen.dart` — `PageView` container with animated dot indicator, Back/Next bottom nav (hidden on step 0), completion handler writes to `/api/v1/preferences`
- `zuralog/lib/features/onboarding/presentation/steps/welcome_step.dart` — Animated logo fade/slide, brand headline, "Get Started" CTA
- `zuralog/lib/features/onboarding/presentation/steps/goals_step.dart` — 2-col multi-select grid of 8 health goals; requires ≥1 selection to advance
- `zuralog/lib/features/onboarding/presentation/steps/persona_step.dart` — 3 AI persona cards (Tough Love / Balanced / Gentle) + Proactivity slider (Low / Medium / High)
- `zuralog/lib/features/onboarding/presentation/steps/connect_apps_step.dart` — Informational grid of 6 featured integrations with "Later" badge; no OAuth during onboarding
- `zuralog/lib/features/onboarding/presentation/steps/notifications_step.dart` — Morning Briefing toggle + time picker, Smart Reminders toggle, Wellness Check-in toggle + time picker
- `zuralog/lib/features/onboarding/presentation/steps/discovery_step.dart` — "Where did you hear about us?" picker; fires `onboarding_discovery` PostHog event on selection

**Modified files:**
- `zuralog/lib/core/router/app_router.dart` — Route `profileQuestionnairePath` now imports and instantiates `OnboardingFlowScreen` instead of `ProfileQuestionnaireScreen`

**Documentation updates:**
- `docs/screens.md` → v1.2: Auth & Onboarding section replaced with 6-step flow spec; Quick Log Bottom Sheet added to Today Tab; Emergency Health Card + Edit added to Settings; all existing screen descriptions updated with MVP feature additions (Health Score hero, Data Maturity banner, Wellness Check-in, streak badges, file attachments, memory management, story-style Weekly Report, personalized AI starters, expanded Notifications settings, Appearance theme/haptics, Coach proactivity selector, Integrations sync badges, Emergency Health Card link in Profile)
- `docs/roadmap.md` → Onboarding Flow marked ✅ Complete; Emergency Health Card, Emergency Health Card Edit, and Quick Log Bottom Sheet added as 🔜 Planned

**Key decisions:**

| Decision | Rationale |
|----------|-----------|
| Keep `ProfileQuestionnaireScreen` on disk (unused) | Low risk to leave; avoids git history churn; router no longer references it so it's dead code harmlessly |
| `ConnectAppsStep` is informational only (no OAuth) | OAuth during onboarding creates drop-off; users who haven't decided which apps to connect are forced to skip anyway; Settings → Integrations is the right context for OAuth |
| `WelcomeStep` manages its own CTA (Back/Next hidden) | Step 0 has no "Back" destination and a custom "Get Started" CTA — the shared bottom nav would be redundant and visually wrong |
| `activeThumbColor` instead of deprecated `activeColor` on Switch | `activeColor` was deprecated in Flutter v3.31; `activeThumbColor` is the correct API going forward |
| PostHog event fired in `DiscoveryStep` on selection (not on complete) | The discovery question is the last step; firing on selection ensures the event is captured even if the user backgrounds the app before tapping "Finish" |

---

## Phase 10 — Engagement & Polish

**Branch:** `feat/engagement-polish`
**Status:** Complete (Tasks 10.1–10.4; Task 10.5 Apple Sign In blocked on Apple Developer subscription)

Completed the engagement and polish layer across the entire app. Coach screens were Phase 4 placeholders — fully rebuilt from scratch with production-grade implementations.

**New files:**
- `zuralog/lib/features/coach/domain/coach_models.dart` — Domain models: `Conversation`, `ChatMessage`, `MessageRole`, `PromptSuggestion`, `QuickAction`, `IntegrationContext`
- `zuralog/lib/features/coach/data/coach_repository.dart` — Abstract `CoachRepository` interface + `MockCoachRepository` with realistic seed data
- `zuralog/lib/features/coach/providers/coach_providers.dart` — Riverpod providers: conversations, messages (family), suggestions, quick actions, active conversation ID

**Modified files:**
- `new_chat_screen.dart` — Full rebuild: `OnboardingTooltip` on brand icon, animated shimmer `_CoachLoadingSkeleton` (1200ms), `_ConversationDrawer` bottom sheet, `_QuickActionsSheet` (2-col grid), `_ChatInputBar`, `_SuggestionChip` grid, haptics throughout
- `chat_thread_screen.dart` — Full rebuild: `_MessageBubble` (user sage-green / AI surface-dark), `_TypingIndicator` (3-dot animated), `_MessagesLoadingSkeleton`, `_ChatInputBar`, haptics throughout
- `progress_home_screen.dart` — Added `OnboardingTooltip` on title, replaced `_LoadingState` plain spinner with animated shimmer skeleton (goal cards + streaks shapes), haptics on refresh/nav/section headers
- `trends_home_screen.dart` — Added `OnboardingTooltip` on title, haptic on pull-to-refresh trigger, haptics on correlation cards + quick-nav buttons
- `correlations_screen.dart` — Haptics on range chips (`selectionTick`) + metric picker button (`light`)
- `reports_screen.dart` — Haptic on card tap (`light`) + refresh trigger (`light`); `_ReportCard` → `ConsumerWidget`
- `data_sources_screen.dart` — Haptic on connect/reconnect button (`medium`) + refresh trigger (`light`); `_DataSourceCard` → `ConsumerWidget`
- `quick_log_sheet.dart` — `ConsumerStatefulWidget`; haptic on submit (`success`), water buttons (`light`), symptom chips (`selectionTick`); `OnboardingTooltip` on title
- `health_dashboard_screen.dart` — `OnboardingTooltip` on AppBar title (existing haptics + skeletons preserved)

**Key decisions:**

| Decision | Rationale |
|----------|-----------|
| Coach screens rebuilt from scratch (not patched) | Phase 4 stubs were center-column text with zero functionality — patching would require rewriting anyway |
| `MockCoachRepository` rather than live API calls | Coach AI is a backend feature (Gemini); mock enables full UI testing without API keys |
| `ConsumerStatefulWidget` for `QuickLogSheet` | Sheet needed Riverpod for haptics; no clean way to thread haptic service through props |
| `_LoadingState` → animated shimmer (not `shimmer` package) | Zero additional dependency; `AnimationController` + `Color.lerp` achieves identical visual result |
| `OnboardingTooltip` on AppBar titles (not mid-screen) | Titles are the natural tap target on first encounter; tooltip fires once (SharedPreferences key) and never again |

---

## Task 11.2 — Sentry Error Boundaries & Performance Monitoring

**Branch:** `feat/sentry-boundaries`
**Status:** Complete

Added comprehensive Sentry instrumentation across the full Zuralog stack — Flutter Edge Agent and Python/FastAPI Cloud Brain.

**New files (Flutter):**
- `zuralog/lib/core/monitoring/sentry_error_boundary.dart` — `SentryErrorBoundary` StatefulWidget; wraps any child with a Sentry-reported error capture and a themed fallback UI (safe black screen with primary-color retry)
- `zuralog/lib/core/monitoring/sentry_breadcrumbs.dart` — `SentryBreadcrumbs` abstract class with static typed helpers: `apiRequest`, `aiMessageSent`, `healthSync`, `authEvent`, `userAction`, `navigation`, `aiResponseReceived`
- `zuralog/lib/core/monitoring/sentry_router_observer.dart` — `SentryRouterObserver` extending `NavigatorObserver`; emits structured `navigation` breadcrumbs on every route push/pop

**Modified files (Flutter):**
- `app_router.dart` — All GoRouter routes (25+) wrapped in `SentryErrorBoundary` with `module` tags; `SentryRouterObserver` added to observers
- `auth_providers.dart` — `authEvent` breadcrumbs for login/register/social/logout (attempt + success/failure)
- `chat_repository.dart` — `apiRequest` breadcrumbs on `connect` and `fetchHistory`; `aiMessageSent` breadcrumb on `sendMessage`
- `health_sync_service.dart` — `healthSync` breadcrumbs for `started`/`completed` (with `recordCount`)/`failed`; properly structured try/catch
- `chat_thread_screen.dart` — `Sentry.startTransaction('ai.chat_response', 'ai')` started on send with `conversation_id` tag; finished on post-frame callback (placeholder for streaming completion hook)

**Modified files (Backend):**
- `main.py` — Added `StarletteIntegration(transaction_style="endpoint")` + `CeleryIntegration()` to Sentry init integrations list
- `orchestrator.py` — Full `process_message` wrapped in `sentry_sdk.start_transaction(op="ai.process_message")`; child `ai.llm_call` span per LLM turn; child `ai.tool_call` span per tool execution with `tool.name` tag; custom fingerprints `["llm_failure", "{{ default }}"]` and `["tool_call_failure", func_name]` for AI error groups
- `llm_client.py` — `ai.error_type=llm_failure` + `ai.model` tags set before `capture_exception` in both `chat()` and `stream_chat()` except blocks
- `health_ingest.py` — `db.health_ingest` span wrapping `db.commit()` with record count in description
- `report_tasks.py` — `task.type=weekly/monthly` tag at task start; `task.report_generation` span wrapping `generator.generate_weekly/monthly()`
- `pinecone_memory_store.py` — `memory_store_failure` fingerprint + `ai.error_type=memory_store_error` + `memory.operation=save/query` tags in `save_memory` and `query_memory` except blocks

**Key decisions:**

| Decision | Rationale |
|----------|-----------|
| `SentryErrorBoundary` as a Flutter widget (not a global handler) | Per-screen isolation: one crashed screen doesn't crash the app; module tags route issues to the right team/alert |
| `start_transaction` in `_sendMessage` finishes on post-frame (not stream end) | Chat streaming is not yet wired in production; the stub is correct — replace finish call with stream completion callback when streaming lands |
| `push_scope` for tool call / memory store fingerprints | Scope is ephemeral per-exception; prevents fingerprint bleed across concurrent requests |
| `StarletteIntegration` added alongside `FastApiIntegration` | FastAPI is built on Starlette; both needed for full request lifecycle tracing including middleware spans |

---

## Phase 11.3 — PostHog Feature Flags / A/B Testing Readiness

Added a typed feature flag layer on top of the existing `AnalyticsService`, enabling PostHog-driven A/B test variants to be gated in future without code changes.

**New files (Flutter):**
- `zuralog/lib/core/analytics/feature_flag_service.dart` — `FeatureFlags` abstract class (3 flag key constants) + `FeatureFlagService` typed wrapper (`onboardingStepOrder()`, `notificationFrequencyDefault()`, `aiPersonaDefault()`) + `featureFlagServiceProvider` Riverpod provider. All methods return safe defaults on PostHog failure.

**Modified files (Flutter):**
- `onboarding_flow_screen.dart` — Converted `late final _pages` to a computed getter; `_stepOrder` field loaded async from `onboarding_step_order` flag in `initState`; analytics step index checks are now flag-aware (Goals/Persona indices swapped when `persona_first`)
- `notification_settings_screen.dart` — Converted `ConsumerWidget` → `ConsumerStatefulWidget`; `initState` loads `notification_frequency_default` flag and seeds `reminderFrequency` initial state if still at default
- `coach_settings_screen.dart` — Converted `ConsumerWidget` → `ConsumerStatefulWidget`; `initState` loads `ai_persona_default` flag and seeds `_personaProvider` if still at default
- `sentry_error_boundary.dart` — Removed unused `_handleError` / `_DefaultErrorFallback` (dead code from pre-existing `Sentry.withScope` API removal); `SentryWidget` handles automatic capture
- `sentry_router_observer.dart` — Removed invalid `const` from constructor (`NavigatorObserver` super is non-const)
- `app_router.dart` — Removed `showBackButton` parameter (no longer on `SentryErrorBoundary`)

**Key decisions:**

| Decision | Rationale |
|----------|-----------|
| Flag loaded in `initState` with safe default already set | UI renders immediately with the default; flag value is applied in the same frame once resolved, with no visible flicker |
| Guard `reminderFrequency == 2` / `_personaProvider == 'balanced'` before seeding | Prevents overwriting a value the user already changed in the same session |
| Analytics goal/persona indices computed from `_stepOrder` | Events must reflect *content* at each step, not raw page index, so PostHog funnels remain accurate under both variants |

---

## Mobile Bug Fix Sprint 1 (2026-03-05)

**Branch:** `fix/mobile-sprint-1`
**Status:** Complete — 11 commits

Bug fixes and feature completions addressing polish and usability issues surfaced after Phase 10.

### Fixes

**Android app name capitalisation** — `AndroidManifest.xml` `android:label` corrected from `zuralog` to `ZuraLog` (commit `2934720`).

**OnboardingTooltip overflow rewrite** — `onboarding_tooltip.dart` rewritten with Flutter `Overlay` instead of `Stack`-positioned absolute coordinates. The old implementation positioned tooltips relative to the widget's local coordinate space, causing overflow when the widget was near screen edges. The `Overlay` approach measures the global position of the target widget and places the tooltip layer above everything else in the widget tree, eliminating all overflow. (commit `2f8de31`)

**iOS app icons alpha channel removed** — All iOS `AppIcon.appiconset` PNGs regenerated without alpha channel. Apple App Store rejects icon submissions that contain transparency. (commit `57acaf9`)

### Features

**App launcher icons from brand logo** — Android mipmap icons and iOS AppIcon assets regenerated from `ZuraLog-Logo-Main.png` via `flutter_launcher_icons`. Replaces placeholder Flutter blue icons with the ZuraLog brand mark. `assets/images/icon_source.png` added as canonical source. (commit `cfacd03`)

**In-app brand SVG in Coach tab** — Coach New Chat screen and Chat Thread screen now render the `ZuraLog.svg` brand mark as the coach avatar / icon instead of a generic `Icons.auto_awesome` Material icon. `assets/images/ZuraLog.svg` asset registered in `pubspec.yaml`. (commit `3a87cff`)

**Mock data layer — Today, Data, Progress, Trends tabs** — Four mock repositories implemented with realistic seed data, all guarded by `kDebugMode`:

| Repository | File | Screens covered |
|-----------|------|----------------|
| `MockTodayRepository` | `mock_today_repository.dart` | Today Feed, Insight Detail, Notification History |
| `MockDataRepository` | `mock_data_repository.dart` | Health Dashboard, Category Detail, Metric Detail |
| `MockProgressRepository` | `mock_progress_repository.dart` | Progress Home, Goals, Achievements, Weekly Report, Journal |
| `MockTrendsRepository` | `mock_trends_repository.dart` | Trends Home, Correlations, Reports, Data Sources |

Each repository's provider file uses `if (kDebugMode) return MockXRepository()` — zero overhead in release builds. Abstract interfaces (`XRepositoryInterface`) extracted in each repository file as the contract. (commits `0a3c7eb`, `0ba667d`, `38d2e8e`)

**STT wired to Coach mic button** — `speech_providers.dart` updated so `SpeechNotifier` works with the rebuilt Coach screens (`new_chat_screen.dart`, `chat_thread_screen.dart`). The mic button in `_ChatInputBar` on both Coach screens now triggers hold-to-talk STT; recognized text fills the input field for user review before sending. (commit `81f0f61`)

**File attachment picker + preview in Coach chat** — Two new widgets:
- `attachment_picker_sheet.dart` — Bottom sheet with camera, photo library, and file picker options (using `image_picker` + `file_picker`)
- `attachment_preview_bar.dart` — Horizontal scrolling preview strip above the input bar; each attachment chip has a remove button

Both widgets are wired into `chat_thread_screen.dart` and `new_chat_screen.dart`. Attachment state is held locally in the screen's `StatefulWidget`. (commits `2dc677a`, `ad4b367`)

### Code Review Fixes (commit `ad4b367`)

Post-implementation code review pass:
- Removed redundant null checks in attachment state handlers
- Corrected `mounted` guard placement in async callbacks
- Consistent error handling pattern across both chat screens
- No new `print()`/`debugPrint()` statements introduced in any sprint commit

### Analyze Status

`flutter analyze` reports 23 issues (all pre-existing, none introduced by this sprint):
- 2 `warning` — `dead_code` + `dead_null_aware_expression` in `analytics_service.dart` (pre-existing)
- 2 `warning` — `experimental_member_use` in `main.dart` (Sentry experimental APIs; pre-existing)
- 19 `info` — `use_null_aware_elements` across `sentry_breadcrumbs.dart` + `progress_repository.dart` (pre-existing); `dangling_library_doc_comments` + `unintended_html_in_doc_comment` in analytics files (pre-existing)
