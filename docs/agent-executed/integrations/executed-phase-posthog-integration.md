# PostHog Integration — Execution Record

**Executed:** 2026-02-28 → 2026-03-01  
**Branch:** `feat/posthog-integration`  
**Plan:** `.opencode/plans/2026-02-28-integration-posthog.md`  
**Status:** Complete — pending squash merge to `main`

---

## What Was Built

Full PostHog product analytics integration across all three Zuralog subprojects.

### Cloud Brain (FastAPI)

**New files:**
- `app/services/analytics.py` — `AnalyticsService` singleton wrapping `posthog-python`. Fire-and-forget capture, identify, group_identify, feature flag evaluation, shutdown. Disabled when `POSTHOG_API_KEY` is empty (graceful no-op).
- `app/middleware/posthog_analytics.py` — `PostHogAnalyticsMiddleware` ASGI middleware capturing one `api_request` event per HTTP request with method, path, status code, duration (ms), user agent. Skips `/health`, `/docs`, `/openapi.json`, `/redoc`, `OPTIONS`.

**Modified files:**
- `pyproject.toml` — `posthog>=3.7.0` dependency
- `app/config.py` — `posthog_api_key`, `posthog_host` settings
- `app/main.py` — AnalyticsService init in lifespan, PostHogAnalyticsMiddleware registered after CORS + SentryUserContextMiddleware
- `app/worker.py` — PostHog init for Celery worker process + `worker_shutdown` signal handler to flush on exit
- `app/api/v1/auth.py` — `user_signed_up` + `identify` on register; `user_logged_in` on login
- `app/api/v1/health_ingest.py` — `health_data_ingested` (platform, record_count, data_types, source)
- `app/api/v1/chat.py` — `chat_message_sent`, `chat_response_received` (model, token_count, latency_ms)
- `app/api/v1/integrations.py` — `strava_connected`, `strava_disconnected`, `fitbit_connected`, `fitbit_disconnected` + identify updates
- `app/api/v1/fitbit_routes.py` — `fitbit_connected`, `fitbit_disconnected`
- `app/api/v1/analytics.py` — `analytics_viewed`, `goals_updated`
- `app/api/v1/devices.py` — `device_registered`
- `app/api/v1/strava_webhooks.py` — `webhook_received` (provider: strava)
- `app/api/v1/fitbit_webhooks.py` — `webhook_received` (provider: fitbit)
- `app/api/v1/webhooks.py` — `subscription_changed` (RevenueCat)
- `app/tasks/fitbit_sync.py` — `health_data_ingested` in 3 Celery background sync tasks
- `.env.example` — `POSTHOG_API_KEY`, `POSTHOG_HOST` documented

**Railway env vars set:** `POSTHOG_API_KEY`, `POSTHOG_HOST` on all 3 services (Zuralog, Celery Worker, Celery Beat).

---

### Website (Next.js)

**New files:**
- `src/components/providers/PostHogProvider.tsx` — Client-side PostHog init + `PostHogPageView` component for App Router navigation tracking. `sanitize_properties` strips accidental email captures. Session recording configured with `maskAllInputs: true`.
- `src/lib/posthog-server.ts` — Server-side `PostHog` singleton (posthog-node) with `globalThis` cache pattern. Returns `null` when `POSTHOG_API_KEY` is unset.
- `src/hooks/useScrollDepth.ts` — Tracks scroll depth milestones (25/50/75/100%) per page, firing `page_scrolled` events. Resets on route change.

**Modified files:**
- `package.json` — `posthog-js`, `posthog-node` dependencies
- `src/app/layout.tsx` — `PostHogProvider` wrapping children (outermost provider)
- `src/app/api/waitlist/join/route.ts` — `waitlist_signup_server` (referral_code, position, source)
- `src/app/api/contact/route.ts` — `contact_form_server` (subject, message_length)
- `src/app/api/support/stats/route.ts` — `support_stats_viewed` (cached)
- Waitlist form component — `waitlist_joined` client-side event
- BentoSection — `useScrollDepth()` hook added

**Vercel env vars required:** `NEXT_PUBLIC_POSTHOG_KEY`, `NEXT_PUBLIC_POSTHOG_HOST`, `POSTHOG_API_KEY` (set manually in Vercel dashboard).

---

### Flutter App (Zuralog)

**New files:**
- `lib/core/analytics/analytics_service.dart` — Riverpod `Provider<AnalyticsService>`. Wraps `posthog_flutter` SDK. Methods: `capture`, `screen`, `identify`, `reset`, `registerSuperProperties`, `isFeatureEnabled`, `getFeatureFlagPayload`, `reloadFeatureFlags`, `group`, `flush`. Disabled in debug mode unless `--dart-define=ENABLE_ANALYTICS=true`.
- `lib/core/analytics/posthog_navigator_observer.dart` — `NavigatorObserver` subclass tracking `didPush`, `didPop`, `didReplace` routes. Skips unnamed routes (GoRouter shell routes without `name:` set).
- `lib/core/analytics/analytics_initializer.dart` — `ConsumerStatefulWidget` that registers super properties (`platform`, `app_version`, `build_number`) at startup and tracks `app_opened`/`app_backgrounded` lifecycle events.

**Modified files:**
- `pubspec.yaml` — `posthog_flutter: ^4.11.0` (resolved), `package_info_plus`
- `android/app/src/main/AndroidManifest.xml` — 4 PostHog meta-data entries (API_KEY, HOST, lifecycle tracking, debug)
- `ios/Runner/Info.plist` — 3 PostHog config keys
- `lib/app.dart` — `AnalyticsInitializer` wraps `MaterialApp.router`
- `lib/core/router/app_router.dart` — `PostHogNavigatorObserver` added to GoRouter observers alongside `SentryNavigatorObserver`
- `lib/core/di/providers.dart` — `analyticsServiceProvider` injected into `healthSyncServiceProvider` and `integrationsProvider`
- `lib/features/auth/domain/auth_providers.dart` — `identify` (before `capture`) + login/signup events; `reset()` on logout + forceLogout
- `lib/features/chat/domain/chat_providers.dart` — `chat_opened` (once per session) + `chat_message_sent`
- `lib/features/health/data/health_sync_service.dart` — `health_sync_started`, `health_sync_completed`, `health_sync_failed`
- `lib/features/integrations/domain/integrations_provider.dart` — `integration_connected`, `integration_disconnected`
- `lib/features/subscription/domain/subscription_providers.dart` — `identify` with tier in `initialize()`; `subscription_started` after purchase
- `lib/features/dashboard/presentation/dashboard_screen.dart` — `dashboard_viewed` on init (converted to `ConsumerStatefulWidget`)
- `lib/features/settings/presentation/widgets/theme_selector.dart` — `settings_changed` on theme pill tap

---

### PostHog Configuration

**Feature flags created (10 total, all at 0% rollout):**

| Flag Key | Purpose |
|---|---|
| `new-hero-design` | A/B test hero section on marketing website |
| `show-testimonials` | Toggle testimonials section |
| `enable-dark-mode` | Dark mode toggle on website |
| `new-dashboard-layout` | A/B test dashboard layout in mobile app |
| `enable-ai-insights` | AI-powered health insights |
| `show-streak-badges` | Gamification streak badges |
| `enable-workout-recommendations` | AI workout recommendations |
| `beta-social-features` | Social/community features |
| `enhanced-analytics-api` | Enhanced analytics computation backend |
| `enable-mcp-v2` | MCP v2 protocol |

**Dashboards created (8 total):**

| Dashboard | ID | Key Insights |
|---|---|---|
| User Acquisition | 1319279 | Waitlist signups trend, signup funnel |
| Mobile App Engagement | 1319280 | DAU, WAU |
| Health Data Pipeline | 1319281 | Ingest by platform, sync success rate |
| AI Chat Usage | 1319282 | Chat messages per day |
| Integration Health | 1319283 | Connections + disconnections by provider |
| Subscription Funnel | 1319284 | Signup → subscription funnel, starts over time |
| Website Performance | 1319285 | Page views by path, scroll depth |
| API Performance | 1319286 | Request volume by endpoint |

---

## Key Design Decisions

### Identity Strategy
- **Cloud Brain (authenticated):** Supabase UID as `distinct_id`
- **Cloud Brain (unauthenticated):** `anon_{ip}` in middleware
- **Website (pre-signup):** PostHog anonymous ID (auto-managed)
- **Website (waitlist):** Email address as `distinct_id`
- **Flutter (pre-login):** PostHog anonymous ID
- **Flutter (post-login):** Supabase UID via `posthog.identify()`

### Identity Order (Critical)
`identify()` is called **before** `capture()` in all auth paths so login/signup events are attributed to the identified user in PostHog, not the anonymous session.

### `registerSuperProperties` API
`posthog_flutter` v4+ changed `register()` to take `(String key, Object value)` not a `Map`. The implementation iterates the map and calls `register()` per entry.

### Analytics Disabled in Debug
`AnalyticsService.enabled` returns `false` in `kDebugMode` unless `--dart-define=ENABLE_ANALYTICS=true` is passed. This prevents test events polluting production PostHog data during development.

### posthog_flutter Limitations
- No `Map`-based `register()` — must iterate entries
- No `flush()` method — auto-flushes on lifecycle changes via native SDK
- `goRouter` routes without `name:` parameter have `settings.name == null` — observer skips them silently; shell/tab routes are not tracked via observer (PostHog autocapture may partially compensate)

---

## Commits

```
aa09f2b fix(flutter): fix analytics identity attribution order and subscription tier race
fc2a57f feat: wire PostHog analytics into router, entry point, and feature modules
97541ac fix(flutter): remove unused import and add safety guards in analytics initializer
a620fd9 fix(flutter): fix posthog_flutter API type mismatches in analytics_service
fb72f63 feat(flutter): add PostHog analytics service, navigator observer, and initializer
a6b9ec9 feat(flutter): add posthog_flutter dependency and platform configuration
39be261 fix(website): make PostHog server events fire-and-forget to avoid response latency
6b42ee9 feat(website): integrate PostHog provider + instrument API routes and client events
7a9b003 fix(website): improve PostHog server flush, sanitize_properties, and scroll depth
4c79822 feat(website): add PostHog provider, server client, and scroll depth hook
f332980 chore(cloud-brain): add PostHog env vars to .env.example + set Railway vars
cfabb10 fix(cloud-brain): fix PostHog analytics edge cases in webhooks, auth, and chat
5a213fe feat(cloud-brain): instrument route handlers with PostHog analytics events
598fb1c fix(cloud-brain): improve PostHog analytics reliability and security
0665282 feat(cloud-brain): add PostHog analytics service + middleware infrastructure
```

---

## Rollback

All PostHog integration is **additive** — removing any piece returns to baseline behavior.

- **Cloud Brain:** Set `POSTHOG_API_KEY=""` in Railway → all methods become no-ops
- **Website:** Remove `NEXT_PUBLIC_POSTHOG_KEY` from Vercel → client SDK never initializes
- **Flutter:** Remove API key from `AndroidManifest.xml` and `Info.plist` → SDK never activates

No application logic depends on PostHog being available. Every call is wrapped in null/enabled checks and try/catch.
