# Zuralog — Product Roadmap

**Format:** Living checklist. Agents and developers update `Status` as work completes.  
**Last Updated:** 2026-03-08 (Coach tab settings wiring: suggestedPromptsEnabled, voiceInputEnabled, sendMessage contract, backend user_preferences columns, chat message timestamps; Today tab settings wiring: greeting personalization, data maturity banner persistence, wellness check-in gating, units-aware water label; Data tab settings wiring: units_system to metric/category detail, category color overrides propagation; Progress tab settings wiring: units_system to goal default unit pre-fill and all goal/WoW metric display labels; Trends tab: persist dismissed correlation suggestion IDs with stale-ID pruning and multi-account safety)

**Status Key:** ✅ Done | 🔄 In Progress | 🔜 Planned | 📋 Future | ❌ Blocked

---

## Backend (Cloud Brain)

### Phase 1.1 — Foundation & Infrastructure

| Priority | Task | Status | Notes |
|----------|------|--------|-------|
| P0 | Repository structure, monorepo setup | ✅ Done | |
| P0 | FastAPI app scaffold with lifespan, CORS, error handlers | ✅ Done | |
| P0 | Supabase Postgres connection (async SQLAlchemy) | ✅ Done | |
| P0 | Alembic migrations setup | ✅ Done | |
| P0 | Docker Compose (local Postgres + Redis) | ✅ Done | |
| P0 | uv + pyproject.toml project setup | ✅ Done | |
| P0 | Railway deployment + Dockerfile | ✅ Done | All 3 services (web, Celery_Worker, Celery_Beat) live |
| P0 | Sentry integration (FastAPI + Celery + SQLAlchemy) | ✅ Done | |
| P0 | `.env.example` + RAILWAY_ENV_VARS.md | ✅ Done | |

### Phase 1.2 — Auth & User Management

| Priority | Task | Status | Notes |
|----------|------|--------|-------|
| P0 | Supabase JWT validation middleware | ✅ Done | |
| P0 | User creation on first login | ✅ Done | |
| P0 | Row Level Security (RLS) setup in Supabase | ✅ Done | |
| P0 | Auth API routes (`/api/v1/auth/`) | ✅ Done | |

### Phase 1.3 — Agent & LLM

| Priority | Task | Status | Notes |
|----------|------|--------|-------|
| P0 | Orchestrator (Reason → Tool → Act loop) | ✅ Done | |
| P0 | OpenRouter LLM client (Kimi K2.5) | ✅ Done | Via `moonshotai/kimi-k2.5` |
| P0 | MCP client + server registry | ✅ Done | |
| P0 | Chat SSE streaming endpoint | ✅ Done | |
| P0 | Conversation persistence | ✅ Done | |
| P1 | System prompt tuning (Tough Love Coach persona) | ✅ Done | 3 personas (tough_love/balanced/gentle) + 3 proactivity levels; persona selected per user preferences |

### Phase 1.4 — Apple Health Integration

| Priority | Task | Status | Notes |
|----------|------|--------|-------|
| P0 | HealthKit native bridge (Swift platform channel) | ✅ Done | |
| P0 | `HKObserverQuery` background observers | ✅ Done | |
| P0 | `HKAnchoredObjectQuery` incremental sync | ✅ Done | |
| P0 | 30-day initial backfill on connect | ✅ Done | |
| P0 | iOS Keychain JWT persistence for background sync | ✅ Done | |
| P0 | `AppleHealthServer` MCP tools | ✅ Done | |
| P0 | `/api/v1/health/ingest` endpoint | ✅ Done | |

### Phase 1.5 — Google Health Connect Integration

| Priority | Task | Status | Notes |
|----------|------|--------|-------|
| P0 | Health Connect native bridge (Kotlin platform channel) | ✅ Done | |
| P0 | WorkManager periodic background sync | ✅ Done | |
| P0 | EncryptedSharedPreferences JWT persistence | ✅ Done | |
| P0 | 30-day initial backfill on connect | ✅ Done | |
| P0 | `HealthConnectServer` MCP tools | ✅ Done | |

### Phase 1.6 — Strava Integration

| Priority | Task | Status | Notes |
|----------|------|--------|-------|
| P0 | Strava OAuth 2.0 flow | ✅ Done | |
| P0 | Deep link callback (`zuralog://oauth/strava`) | ✅ Done | |
| P0 | `StravaSyncService` + Celery periodic sync | ✅ Done | |
| P0 | `StravaServer` MCP tools | ✅ Done | `get_activities`, `create_activity`, `get_athlete_stats` |
| P0 | Strava webhook handler + real-time sync | ✅ Done | |
| P0 | Redis sliding window rate limiter (100/15min, 1K/day) | ✅ Done | |

### Phase 1.7 — Oura Ring Integration

| Priority | Task | Status | Notes |
|----------|------|--------|-------|
| P1 | Oura OAuth 2.0 flow (no PKCE) | ✅ Done | |
| P1 | `OuraTokenService` (long-lived tokens, refresh on 401) | ✅ Done | |
| P1 | App-level Redis sliding-window rate limiter (5,000/hr) | ✅ Done | Shared across all users; no response headers to track |
| P1 | `OuraServer` MCP tools (16 tools) | ✅ Done | Sleep, readiness, activity, HR, SpO2, stress, resilience, cardiovascular age, VO2 max, workouts, sessions, tags, rest mode, sleep time, ring config |
| P1 | Oura webhook handler + per-app subscription management | ✅ Done | 90-day expiry; auto-renewal Celery task |
| P1 | Celery periodic sync + webhook auto-renewal | ✅ Done | |
| P1 | Sandbox mode (`OURA_USE_SANDBOX=true`) | ✅ Done | Mock token for dev testing without real ring |
| P1 | Oura developer app registered + credentials configured | ❌ Blocked | Requires an Oura Ring to create an account; hardware not yet acquired |
| P1 | Submit Oura production app review (lift 10-user limit) | ❌ Blocked | Depends on credentials above |

### Phase 1.8 — Fitbit Integration

| Priority | Task | Status | Notes |
|----------|------|--------|-------|
| P1 | Fitbit OAuth 2.0 + PKCE flow | ✅ Done | |
| P1 | `FitbitTokenService` (single-use refresh handling) | ✅ Done | |
| P1 | Per-user Redis token bucket rate limiter (150/hr) | ✅ Done | |
| P1 | `FitbitServer` MCP tools (12 tools) | ✅ Done | Activity, HR, HRV, sleep, SpO2, breathing, temp, VO2, weight, nutrition |
| P1 | Fitbit webhook handler + subscription management | ✅ Done | |
| P1 | Celery periodic sync (15min) + token refresh (1hr) | ✅ Done | |
| P1 | Fitbit developer app registered + credentials configured | ✅ Done | Server type; `developer@zuralog.com`; credentials in Bitwarden + Railway + local `.env` |
| P1 | Fitbit webhook subscription registration | 🔜 Planned | Requires deployed endpoint; generate `FITBIT_WEBHOOK_VERIFY_CODE` first |

### Phase 1.9 — Push Notifications

| Priority | Task | Status | Notes |
|----------|------|--------|-------|
| P1 | Firebase FCM integration | ✅ Done | |
| P1 | Device token registration (`/api/v1/devices/`) | ✅ Done | |
| P1 | Push notification service | ✅ Done | |
| P1 | Background insight alerts | ✅ Done | Triggers: anomaly detected, goal reached, streak milestone, integration stale |

### Phase 1.10 — Subscriptions

| Priority | Task | Status | Notes |
|----------|------|--------|-------|
| P1 | RevenueCat webhook receiver | ✅ Done | |
| P1 | Subscription entitlement service | ✅ Done | |
| P1 | Usage tracking per tier | ✅ Done | |

### Phase 1.11 — Analytics & Reasoning

| Priority | Task | Status | Notes |
|----------|------|--------|-------|
| P1 | Correlation analysis engine | ✅ Done | |
| P1 | Analytics API endpoints | ✅ Done | |
| P2 | Pinecone vector store for long-term context | ✅ Done | PineconeMemoryStore with per-user namespace; graceful InMemoryStore fallback when unconfigured |

---

## Mobile App (Flutter Edge Agent)

### Core Infrastructure

| Priority | Task | Status | Notes |
|----------|------|--------|-------|
| P0 | Flutter project setup + Riverpod | ✅ Done | |
| P0 | GoRouter navigation | ✅ Done | |
| P0 | Dio HTTP client + auth interceptor | ✅ Done | |
| P0 | Drift local DB | ✅ Done | |
| P0 | SecureStorage (JWT persistence) | ✅ Done | |
| P0 | Sentry integration (Flutter + Dio) | ✅ Done | |
| P0 | Deep link handler (`app_links`) | ✅ Done | |

### Features (Current — Pre-Rebuild)

| Priority | Task | Status | Notes |
|----------|------|--------|-------|
| P0 | Auth flow (signup, login, Google Sign In) | ✅ Done | |
| P0 | Apple Sign In (iOS native) | 🔜 Planned | Pending Apple Developer subscription |
| P0 | Onboarding screens | ✅ Done | |
| P0 | AI Chat UI (streaming) | ✅ Done | |
| P0 | Voice input (mic button) | ✅ Done | On-device STT via `speech_to_text` Flutter package (free, offline, no API key) — wired to mic button in Coach tab |
| P0 | File attachments in chat | ✅ Done | `attachment_picker_sheet.dart` + `attachment_preview_bar.dart`; image/file picker with inline preview strip |
| P0 | Dashboard (health summary cards) | ✅ Done | |
| P0 | Integrations Hub screen | ✅ Done | Connected / Available / Coming Soon sections |
| P0 | Settings screen | ✅ Done | |
| P0 | Data export | 📋 Future | |
| P0 | Profile photo upload | 📋 Future | |
| P1 | RevenueCat paywall (Pro upgrade) | ✅ Done | |
| P1 | Analytics / correlation views | ✅ Done | |
| P1 | Deep link catalog (third-party app launch) | ✅ Done | |
| P1 | Push notification handling | ✅ Done | |

### Full UI Rebuild — Screen Inventory

> **Directive:** All existing screens are to be rebuilt from scratch. Functionality is preserved; presentation layer is fully replaced. See [`docs/screens.md`](./screens.md) for the complete screen inventory, user intent model, and navigation structure.

**Navigation:** 5-tab bottom bar (Today, Data, Coach, Progress, Trends). Settings/Profile/Integrations pushed from headers, not tabs.

| Priority | Task | Status | Notes |
|----------|------|--------|-------|
| P0 | Today Feed (curated daily briefing) | ✅ Done | Phase 3 complete — Health Score hero, insight cards, quick actions, wellness check-in, streak, Quick Log FAB; feat/today-tab-settings-wiring: greeting personalization, data maturity banner persistence, wellness check-in gating |
| P0 | Today — Insight Detail | ✅ Done | Phase 3 complete — bar chart, AI reasoning, source chips, Discuss with Coach CTA |
| P0 | Today — Notification History | ✅ Done | Phase 3 complete — grouped by day, unread indicators, deep-link routing |
| P0 | Data — Health Dashboard (customizable) | ✅ Done | Phase 5 — feat/data-tab |
| P0 | Data — Category Detail (x10) | ✅ Done | Phase 5 — feat/data-tab |
| P0 | Data — Metric Detail | ✅ Done | Phase 5 — feat/data-tab |
| P0 | Coach — New Chat (Gemini-style) | ✅ Done | feat/coach-tab-gaps — integration context banner, auto-send quick actions, Quick Log tile, delete/archive conversations |
| P0 | Coach — Conversation Drawer | ✅ Done | feat/coach-tab-gaps — long-press delete + archive with confirmation dialogs |
| P0 | Coach — Chat Thread | ✅ Done | feat/coach-tab-gaps — MarkdownBody rendering for AI messages, attachment thumbnail rendering in bubbles |
| P0 | Coach — Quick Actions Sheet | ✅ Done | feat/coach-tab-gaps — 7th Quick Log tile opens QuickLogSheet; actions auto-send prompt |
| P1 | Progress — Progress Home | ✅ Done | feat/progress-tab-gaps — streak freeze tap-to-activate, milestone celebration card (7/14/30/60/90/180/365 days) |
| P1 | Progress — Goals | ✅ Done | feat/progress-tab-gaps — water intake goal type added; auto-fills unit default on type selection |
| P1 | Progress — Goal Detail | ✅ Done | feat/progress-tab-gaps — projected completion date from trend line; AI card extended with projection |
| P1 | Progress — Achievements | ✅ Done | feat/progress-tab-gaps — progress-toward-unlock bars on locked badges |
| P1 | Progress — Weekly Report | ✅ Done | feat/progress-tab-gaps — enforced 5-card story sequence; share-as-image via screenshot + share_plus |
| P1 | Progress — Journal / Daily Log | ✅ Done | Phase 10 — complete (from Phase 6 rebuild) |
 | P1 | Trends — Trends Home | ✅ Complete | Phase 7 |
 | P1 | Trends — Correlations | ✅ Complete | Phase 7 |
 | P1 | Trends — Reports | ✅ Complete | Phase 7 |
 | P1 | Trends — Data Sources | ✅ Complete | Phase 7 |
| P1 | Trends — Persist dismissed correlation suggestion IDs (Step 3.8) | ✅ Done | feat/trends-persist-dismissals — SharedPreferences persistence with stale-ID pruning and multi-account safety |
| P1 | Settings Hub | ✅ Complete | Phase 8 |
| P1 | Settings — Account | ✅ Complete | Phase 8 |
| P1 | Settings — Notifications | ✅ Complete | Phase 8; re-wired to API + SharedPrefs persistence in feat/settings-providers |
| P1 | Settings — Appearance | ✅ Complete | Phase 8; fixed tooltips/haptics/theme wiring in feat/settings-providers |
| P1 | Settings — Coach Settings | ✅ Complete | feat/coach-tab-gaps + feat/settings-providers + feat/coach-settings-wiring — private StateProviders replaced with global UserPreferencesNotifier; all 5 coach preferences wired to chat screens |
| P1 | Settings — Integrations | ✅ Complete | Phase 8 |
| P1 | Settings — Privacy & Data | ✅ Complete | Phase 8; re-wired to global providers in feat/settings-providers |
| P1 | Settings — Units (metric/imperial) | ✅ Complete | feat/settings-providers — segmented toggle in Account screen, persisted via UserPreferencesNotifier |
| P1 | UserPreferencesNotifier (global settings layer) | ✅ Complete | feat/settings-providers — AsyncNotifier with API load, SharedPrefs fallback, optimistic PATCH writes |
| P1 | Settings — Subscription | ✅ Complete | Phase 8 |
| P1 | Settings — About | ✅ Complete | Phase 8 |
| P2 | Profile (side panel or pushed) | ✅ Complete | Phase 8 |
| P2 | Privacy Policy | ✅ Complete | Phase 8 |
| P2 | Terms of Service | ✅ Complete | Phase 8 |
| P0 | Onboarding Flow (6-step rebuild) | ✅ Complete | feat/onboarding-rebuild — replaces ProfileQuestionnaire; Welcome, Goals, Persona, Connect Apps, Notifications, Discovery steps |
| P0 | Emergency Health Card | 🔜 Planned | Spec complete in screens.md — awaiting implementation phase |
| P0 | Emergency Health Card Edit | 🔜 Planned | Spec complete in screens.md — awaiting implementation phase |
| P1 | Quick Log Bottom Sheet | ✅ Done | Phase 10 — OnboardingTooltip, haptics (submit, water, chips), ConsumerStatefulWidget |

### Phase 9 — Mock Data Layer (`--dart-define=USE_MOCK=true`)

> **Prerequisite:** Every screen in Phases 3–8 must be fully built before this phase starts. Mock seed data must cover the complete app.

| Priority | Task | Status | Notes |
|----------|------|--------|-------|
| P1 | Extract abstract interface for `TodayRepository` | ✅ Done | `TodayRepositoryInterface` in `today_repository.dart`; `kDebugMode` guard in provider |
| P1 | Extract abstract interface for `DataRepository` | ✅ Done | `DataRepositoryInterface` in `data_repository.dart`; `kDebugMode` guard in provider |
| P1 | Extract abstract interface for `CoachRepository` | ✅ Done | Abstract `CoachRepository` interface in `coach_repository.dart`; `kDebugMode` guard in `coachRepositoryProvider` |
| P1 | Extract abstract interface for `ProgressRepository` | ✅ Done | `ProgressRepositoryInterface` in `progress_repository.dart`; `kDebugMode` guard in provider |
| P1 | Extract abstract interface for `TrendsRepository` | ✅ Done | `TrendsRepositoryInterface` in `trends_repository.dart`; `kDebugMode` guard in provider |
| P1 | `MockTodayRepository` — seed insights, quick actions, streak, notifications | ✅ Done | `mock_today_repository.dart`; covers Today Feed, Insight Detail, Notification History |
| P1 | `MockDataRepository` — seed data (all 10 categories, sparklines, charts) | ✅ Done | `mock_data_repository.dart`; all 10 categories with realistic metrics (Activity, Sleep, Heart, Body, Vitals, Nutrition, Wellness, Mobility, Cycle, Environment) |
| P1 | `MockCoachRepository` — seed conversations, quick action prompts | ✅ Done | `coach_repository.dart` — 4 conversations, 4-message thread, 6 suggestions, 6+1 quick actions |
| P1 | `MockProgressRepository` — seed goals, achievements, journal, weekly report | ✅ Done | `mock_progress_repository.dart`; covers all Progress tab screens |
| P1 | `MockTrendsRepository` — seed correlations, reports, data source list | ✅ Done | `mock_trends_repository.dart`; covers all Trends tab screens |
| P1 | Wire all mocks via `kDebugMode` guard in providers | ✅ Done | `if (kDebugMode)` swap in Today/Data/Progress/Trends providers; zero overhead in production |
| P1 | `Makefile` `run-mock` target + `.vscode/launch.json` config | 🔜 Planned | One-click mock launch in VS Code and terminal |

---

## Phase 9.5 — Settings Mapping Audit & Today Tab Wiring (`feat/today-tab-settings-wiring`)

> **Branch:** `feat/today-tab-settings-wiring` → merged to main (2026-03-08)

Completed 4 tasks from the Settings Mapping Audit plan, wiring persisted user preferences to the Today tab and Quick Log.

| Priority | Task | Status | Notes |
|----------|------|--------|-------|
| P0 | Task 3.1: Greeting personalization (Bug fix) | ✅ Done | `_timeOfDayGreeting()` now shows "Good morning, Alex" using `profile?.aiName`; falls back gracefully to "Good morning" if no name available |
| P0 | Task 3.2: Data Maturity Banner dismiss persistence | ✅ Done | Banner dismiss writes to persisted `userPreferencesProvider` via `mutate()`; progress mode `onDismiss` and stillBuilding `onPermanentDismiss` both persist; session X-dismiss on stillBuilding remains session-only (intentional); dead session-scoped `dataMaturityBannerDismissed` StateProvider removed; `showBanner` logic gates on both `!bannerDismissed` AND `!prefsAsync.isLoading` (prevents race condition) |
| P0 | Task 3.3: Wellness Check-in card gated on Privacy toggle | ✅ Done | `_WellnessCheckinCard` wrapped in `if (wellnessCardVisible)`; reads `wellnessCheckinCardVisibleProvider` (persisted via `userPreferencesProvider`); Privacy & Data screen's "Wellness Check-in" toggle now controls Today tab card visibility |
| P0 | Task 3.4: Units-aware water label in Quick Log | ✅ Done | Added `UnitsSystemWaterLabel` extension to `user_preferences_model.dart` — `waterUnitLabel` getter returns `'glasses (250 ml)'` for metric, `'glasses (8 oz)'` for imperial; `_WaterCounter` now has `required String label`; receives `unitsSystem.waterUnitLabel`; backend `waterGlasses` payload unchanged |

---

## Phase 9.6 — Settings Mapping Audit: Data Tab Wiring (`feat/data-tab-settings-wiring`)

> **Branch:** `feat/data-tab-settings-wiring` → merged to main (2026-03-08)

Completed all 3 Data tab actions from the Settings Mapping Audit plan.

| Priority | Task | Status | Notes |
|----------|------|--------|-------|
| P0 | Task 4.1: Appearance Settings category color section | ✅ Done | Pre-existing — section was already removed. `appearance_settings_screen.dart` has no disconnected local provider; category colors are managed canonically via Data tab edit mode. |
| P1 | Task 4.2: Wire `units_system` to Metric Detail value display | ✅ Done | Created `unit_converter.dart` shared domain utility; `metric_detail_screen.dart` now reads `unitsSystemProvider` and passes display unit to all value-rendering widgets; named constants for raw table row cap and coach prefill cap |
| P2 | Task 4.3: Propagate category color overrides to Category Detail screen | ✅ Done | Both `category_detail_screen.dart` and `metric_detail_screen.dart` now read `dashboardLayoutProvider.categoryColorOverrides` via `.select()` and apply user-defined color overrides with `!= 0` guard; `_MetricChartCard` in category detail also receives display unit |

---

## Phase 9.7 — Settings Mapping Audit: Progress Tab Wiring (`feat/progress-tab-units-wiring`)

> **Branch:** `feat/progress-tab-units-wiring` → merged to main (2026-03-08)

Completed both P1 Progress tab actions from the Settings Mapping Audit plan, wiring `units_system` to the Progress tab's goal display and goal creation form.

| Priority | Task | Status | Notes |
|----------|------|--------|-------|
| P1 | Wire `units_system` to goal default unit pre-fill | ✅ Done | `goal_create_edit_sheet.dart`: `_defaultUnitFor(GoalType.weightTarget)` returns `'lbs'` for imperial, `'kg'` for metric via `ref.read(unitsSystemProvider)`. All other goal types are unit-system-agnostic and unchanged. |
| P1 | Wire `units_system` to goal display formatting | ✅ Done | `goals_screen.dart`, `goal_detail_screen.dart`, `progress_home_screen.dart`: all goal unit labels and WoW metric unit labels now go through `displayUnit(x.unit, unitsSystem)` from the shared `unit_converter.dart` utility. `_GoalCard` and `_WoWMetricRow` converted to `ConsumerWidget`. |

---

## Phase 10 — Engagement & Polish (`feat/engagement-polish`)

> **Branch:** `feat/engagement-polish` → squash merged to `main`

| Priority | Task | Status | Notes |
|----------|------|--------|-------|
| P0 | Haptics across all screens | ✅ Done | All tab roots, Coach screens, Quick Log, Reports, Data Sources |
| P0 | OnboardingTooltip on all major screens | ✅ Done | Health Dashboard, Progress, Trends, Coach New Chat, Quick Log |
| P0 | Shimmer skeleton loading | ✅ Done | Coach (both screens), Progress Home (replaces spinner), Trends Home |
| P0 | Pull-to-refresh (sage-green) + haptic | ✅ Done | All tab roots — Today, Data, Progress, Trends |
| P1 | Apple Sign In | ⛔ Blocked | Requires Apple Developer subscription |

---

## Website

| Priority | Task | Status | Notes |
|----------|------|--------|-------|
| P0 | Next.js 16 project setup | ✅ Done | |
| P0 | Landing page (hero section) | ✅ Done | |
| P0 | 3D phone mockup (Three.js) | ✅ Done | |
| P0 | Waitlist signup system | ✅ Done | Supabase-backed |
| P0 | Waitlist counter + leaderboard | ✅ Done | |
| P0 | Onboarding quiz flow | ✅ Done | |
| P0 | Legal pages (privacy, terms, cookies, community guidelines) | ✅ Done | |
| P0 | About + Contact + Support pages | ✅ Done | |
| P0 | SEO + OG image | ✅ Done | |
| P0 | Sentry integration (Next.js) | ✅ Done | |
| P0 | Vercel Analytics | ✅ Done | |
| P1 | Email confirmation (Resend) | ✅ Done | |
| P1 | Upstash Redis removal (Website + Cloud-Brain) | ✅ Done | Replaced with HTTP Cache-Control headers + in-memory TTL cache; Railway Redis for Celery/rate limiters |
| P1 | Google reCAPTCHA v2 on waitlist form | ✅ Done | `react-google-recaptcha`; server-side token verification in `POST /api/waitlist/join` |

---

## Direct Integrations Roadmap

| # | Integration | Tier | Priority | Status | Backend | Mobile | Notes |
|---|-------------|------|----------|--------|---------|--------|-------|
| 1 | Strava | 1 | P0 | ✅ Done | OAuth, MCP, webhooks, sync | Connected | |
| 2 | Apple Health | 1 | P0 | ✅ Done | Ingest endpoint, MCP | Connected (iOS only) | HealthKit native bridge |
| 3 | Google Health Connect | 1 | P0 | ✅ Done | Ingest endpoint, MCP | Connected (Android only) | WorkManager |
| 4 | Fitbit | 1 | P1 | ✅ Done | OAuth+PKCE, 12 MCP tools, webhooks | Connected | |
| 5 | Oura Ring | 1 | P1 | ❌ Blocked | Code complete: OAuth, 16 MCP tools, webhooks, sync | Coming Soon | All code merged; credentials blocked on Oura Ring hardware (needed to register OAuth app) |
| 6 | Withings | 1 | P1 | ✅ Done | HMAC-SHA256 signing, server-side OAuth, 10 MCP tools, webhooks (?token= secret), Celery sync, BloodPressureRecord model | Connected (Available) | Credentials set in Railway; webhook secret set on all 3 services |
| 7 | WHOOP | 1 | P2 | 📋 Future | Deferred | Coming Soon | Deferred: developer dashboard registration requires an active WHOOP membership (hardware); revisit when user demand justifies acquisition |
| 8 | Polar | 1 | P2 | ✅ Done | OAuth, 14 MCP tools, webhooks (HMAC-SHA256), Celery sync, dynamic dual-window rate limiter | Connected (Available) | AccessLink API v3; tokens ~1 year, no refresh; mandatory user registration after OAuth |
| 9 | MapMyFitness | 1 | P2 | 📋 Future | Not started | Planned | 40M users, 700+ activity types |
| 10 | Garmin | 2 | P2 | 📋 Future | Not started | Coming Soon | Requires business application |
| — | Lose It! | 2 | P2 | 📋 Future | Not started | Planned | Nutrition gap; partner application needed |
| — | Suunto | 2 | P3 | 📋 Future | Not started | Planned | Outdoor/adventure niche |

**Indirect coverage (via Apple Health / Health Connect):** CalAI, MyFitnessPal, Cronometer, Yazio, Sleep Cycle, Renpho, Peloton, Nike Run Club, COROS — all write to the OS health store, so Zuralog reads them automatically.

---

## Coming Soon Features

| Feature | Priority | Status | Notes |
|---------|----------|--------|-------|
| Voice input (on-device STT) | P1 | ✅ Done | `speech_to_text` Flutter package — on-device, free, no API key; hold-to-talk fills input field for user review before sending; wired to Coach mic button |
| File attachments in chat | P2 | ✅ Done | `attachment_picker_sheet.dart` + `attachment_preview_bar.dart`; backend pipeline: upload, validate, extract health facts, inject into LLM context; food photo detection |
| Apple Sign In | P1 | 🔜 Planned | Pending Apple Developer subscription |
| Profile photo upload | P2 | 📋 Future | |
| Data export | P2 | 📋 Future | |
| Pinecone vector store (AI memory) | P2 | ✅ Done | PineconeMemoryStore implemented; per-user namespace; graceful fallback to InMemoryStore |
| Dynamic tool injection | P1 | ✅ Done | Only inject MCP tools for integrations the user has connected; prevents context bloat as integration catalog grows; prerequisite for semantic retrieval |
| Semantic tool retrieval | P2 | 🔜 Planned | Embed user message + tool descriptions at request time; inject top-K relevant tools only; scales to unlimited integrations without MCP bloat; requires Pinecone |
| AI-powered morning briefing | P2 | ✅ Done | Celery Beat task (15-min schedule); per-user time window; data-driven briefing; FCM + Insight card |
| Smart reminders | P2 | ✅ Done | Pattern/gap/goal/celebration reminder types; dedup 48h; quiet hours; frequency cap; hourly Beat task |
| Bi-directional triggers | P3 | 📋 Future | "If sleep < 30%, reschedule workout" |
| Notion / YNAB / Todoist integration | P3 | 📋 Future | Life OS phase |

---

## Observability & Monitoring

### Task 11.1 — PostHog Analytics

| Priority | Task | Status | Notes |
|----------|------|--------|-------|
| P1 | PostHog backend (FastAPI middleware) | ✅ Done | `PostHogAnalyticsMiddleware` capturing all API events |
| P1 | PostHog Flutter SDK integration | ✅ Done | Screen views, user actions, health sync events |
| P1 | PostHog website (Next.js) | ✅ Done | Pageviews, waitlist signups |

### Task 11.2 — Sentry Error Boundaries & Performance Monitoring

| Priority | Task | Status | Notes |
|----------|------|--------|-------|
| P1 | Flutter `SentryErrorBoundary` widget (all routes) | ✅ Done | All GoRouter routes wrapped; graceful fallback UI |
| P1 | Flutter `SentryBreadcrumbs` static helpers | ✅ Done | `apiRequest`, `aiMessageSent`, `healthSync`, `authEvent`, `userAction`, `navigation`, `aiResponseReceived` |
| P1 | Flutter `SentryRouterObserver` navigation breadcrumbs | ✅ Done | Registered in GoRouter observers |
| P1 | Flutter auth breadcrumbs (`auth_providers.dart`) | ✅ Done | Login/register/social/logout all instrumented |
| P1 | Flutter chat breadcrumbs (`chat_repository.dart`) | ✅ Done | `connect`, `fetchHistory`, `sendMessage` |
| P1 | Flutter health sync breadcrumbs (`health_sync_service.dart`) | ✅ Done | `started`, `completed`, `failed` states with `recordCount` |
| P1 | Flutter AI chat performance transaction (`chat_thread_screen.dart`) | ✅ Done | `Sentry.startTransaction('ai.chat_response', 'ai')` on send |
| P1 | Backend `StarletteIntegration` + `CeleryIntegration` | ✅ Done | Added alongside existing `FastApiIntegration` in `main.py` |
| P1 | Backend orchestrator spans + error groups | ✅ Done | `ai.process_message` transaction; `ai.llm_call` + `ai.tool_call` child spans; custom fingerprints for LLM/tool failures |
| P1 | Backend LLM failure tagging (`llm_client.py`) | ✅ Done | `ai.error_type=llm_failure` + `ai.model` tags on both `chat` and `stream_chat` |
| P1 | Backend health ingest span (`health_ingest.py`) | ✅ Done | `db.health_ingest` span wraps `db.commit()` |
| P1 | Backend Celery task spans (`report_tasks.py`) | ✅ Done | `task.report_generation` span + `task.type` tag for weekly/monthly |
| P1 | Backend memory store error groups (`pinecone_memory_store.py`) | ✅ Done | `memory_store_failure` fingerprint + `ai.error_type=memory_store_error` tag on save/query |

### Task 11.3 — PostHog Feature Flags / A/B Testing Readiness

| Priority | Task | Status | Notes |
|----------|------|--------|-------|
| P1 | `FeatureFlagService` + `FeatureFlags` constants | ✅ Done | `core/analytics/feature_flag_service.dart`; typed wrappers around `AnalyticsService.getFeatureFlagPayload` with safe defaults |
| P1 | `onboarding_step_order` flag wired into `OnboardingFlowScreen` | ✅ Done | Step 2/3 order (Goals/Persona) is flag-controlled; analytics indices are flag-aware |
| P1 | `notification_frequency_default` flag wired into `NotificationSettingsScreen` | ✅ Done | Seeds `reminderFrequency` initial state from PostHog on first open |
| P1 | `ai_persona_default` flag wired into `CoachSettingsScreen` | ✅ Done | Seeds `_personaProvider` initial value from PostHog on first open |
