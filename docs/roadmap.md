# Zuralog — Product Roadmap

**Format:** Living checklist. Agents and developers update `Status` as work completes.  
**Last Updated:** 2026-03-18 (Today Tab Redesign polish: metric picker full-screen, tile uniformity, tap-to-log, nav bar fix)

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
| P0 | Railway deployment + Dockerfile | ✅ Done | 2 services (web, Celery_Worker with integrated Beat) live |
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
| P1 | AI Insights Engine (signal detection, prioritization, LLM writing) | ✅ Done | 2026-03-18 — 8 signal categories, composite scoring, 3-level LLM fallback, daily fan-out scheduling |
| P2 | Pinecone vector store for long-term context | ✅ Done | PineconeMemoryStore with per-user namespace; graceful InMemoryStore fallback when unconfigured |

### Phase 1.12 — Health Score Calculation & Caching

| Priority | Task | Status | Notes |
|----------|------|--------|-------|
| P0 | Health Score calculation engine (weighted sub-scores) | ✅ Done | Combines sleep, HRV, resting HR, activity, consistency, step count; normalized to 0-100 via 30-day percentile |
| P0 | `GET /api/v1/health-score` endpoint | ✅ Done | Cache-first strategy; returns score, trend, AI commentary, data_days; rate limited 30/minute |
| P0 | Health Score caching table + Celery daily refresh | ✅ Done | `health_scores` table stores daily scores; Celery Beat task recalculates at 2 AM UTC daily |
| P0 | 7-day history query optimization | ✅ Done | Single cached query (was 28 N+1 queries); returns trend sparkline data |
| P0 | Consistency history query optimization | ✅ Done | Single cached query (was 30 N+1 queries); returns bedtime regularity data |
| P0 | Demo account seed data (30 days) | ✅ Done | Seeded with realistic health data; sub_score keys corrected to match backend schema |

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
| P0 | Today Feed (curated daily briefing) | ✅ Done | Phase 3 complete — Health Score hero, insight cards, quick actions, wellness check-in, streak, Quick Log FAB; feat/today-tab-settings-wiring: greeting personalization, data maturity banner persistence, wellness check-in gating; Polish pass (2026-03-18): metric picker full-screen route, tile uniformity (width/height/badge), tap-to-log, nav bar obstruction fix |
| P0 | Today — Insight Detail | ✅ Done | Phase 3 complete — bar chart, AI reasoning, source chips, Discuss with Coach CTA |
| P0 | Today — Notification History | ✅ Done | Phase 3 complete — grouped by day, unread indicators, deep-link routing |
| P0 | Today — Sleep Log Screen | ✅ Done | Part 3 complete — bedtime/wake time pickers, quality emoji, interruptions counter, factors chips, notes |
| P0 | Today — Run Log Screen | ✅ Done | Part 3 complete — mode picker (Strava/past/live), activity type, distance, duration, auto-pace, effort |
| P0 | Today — Meal Log Screen | ✅ Done | Part 3 complete — quick/full toggle (persisted), meal type, description, calorie presets, feel chips, tags |
| P0 | Today — Supplements Log Screen | ✅ Done | Part 3 complete — tap-to-check-off checklist, inline add form, optimistic updates |
| P0 | Today — Symptom Log Screen | ✅ Done | Part 3 complete — body area multi-select, symptom type, severity emoji, timing, notes |
| P0 | Today — Quick Log Real Data (Part 4) | ✅ Done | Water/Wellness/Weight/Steps endpoints + real data wiring + steps mode toggle; feat/today-tab-part4-real-data merged 2026-03-16 |
| P0 | Today — Inline Log Panels (Part 5) | ✅ Done | GET /quick-log/latest endpoint; latestLogValuesProvider; ZWaterLogPanel (oz/ml unit-aware, real logWater API); ZWellnessLogPanel (real logWellness API); ZWeightLogPanel (pre-fill, delta, unit persistence, real logWeight); ZStepsLogPanel (sync banner, goal display, Confirm Steps, real source); _PanelView snackbar fix; 2026-03-17 |
| P0 | Today — Metric grid tap-to-log | ✅ Done | Tap metric tile to open log sheet directly; energy/stress mapped to mood; water/weight/meal/supplement/symptom open inline or full-screen; heart_rate read-only; useRootNavigator: true for nav bar clearance; 2026-03-18 |
| P0 | Data — Health Dashboard (customizable) | ✅ Done | Phase 5 — feat/data-tab |
| P0 | Data — Category Detail (x10) | ✅ Done | Phase 5 — feat/data-tab |
| P0 | Data — Metric Detail | ✅ Done | Phase 5 — feat/data-tab |
| P0 | Coach — New Chat (Gemini-style) | ✅ Done | feat/coach-tab-gaps — integration context banner, auto-send quick actions, Quick Log tile, delete/archive conversations |
| P0 | Coach — Conversation Drawer | ✅ Done | feat/coach-tab-gaps — long-press delete + archive with confirmation dialogs |
| P0 | Coach — Chat Thread | ✅ Done | feat/coach-tab-gaps — MarkdownBody rendering for AI messages, attachment thumbnail rendering in bubbles |
| P0 | Coach — Quick Actions Sheet | ✅ Done | feat/coach-tab-gaps — 7th Quick Log tile opens QuickLogSheet; actions auto-send prompt |
| P1 | Progress — Progress Home | ✅ Done | feat/progress-tab-gaps — streak freeze tap-to-activate, milestone celebration card (7/14/30/60/90/180/365 days); fix/progress-tab-set-first-goal — "Set First Goal" button opens goal creation form directly; /progress/home endpoint wired to real database |
| P1 | Progress — Goals | ✅ Done | feat/progress-tab-gaps — water intake goal type added; auto-fills unit default on type selection; backend /api/v1/goals CRUD endpoints added (fix/goals-api-endpoints — resolves production 404) |
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
| P1 | Wire all mocks via `kDebugMode` guard in providers | ✅ Done | `if (kDebugMode)` swap in Today/Data/Progress/Trends providers; zero overhead in production; **removed in Phase 11** — mocks preserved for tests only, app always uses real APIs |
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

## Phase 10.5 — Coach Tab AI Features (`feat/coach-tab-full-ai`)

> **Branch:** `feat/coach-tab-full-ai` → merged to main (2026-03-09)

All 6 Coach tab AI conversation features implemented and reviewed.

| Priority | Task | Status | Notes |
|----------|------|--------|-------|
| P0 | Stop Generation Button | ✅ Done | Red stop button replaces spinner during streaming; `cancelStream()` commits partial content or shows `'_Generation stopped._'` placeholder; WebSocket cleanly closed on cancel |
| P0 | Regenerate / Retry Last Response | ✅ Done | "Regenerate" button below last AI message; re-sends last user message without duplicate DB insert; reads user's actual persona/proactivity settings |
| P0 | Copy Message (Long-press) | ✅ Done | Long-press any bubble → bottom sheet with "Copy" action; clipboard write awaited; correct `ScaffoldMessenger` handling |
| P0 | Message Editing | ✅ Done | Long-press user message → "Edit" in bottom sheet; truncates messages from that index; snapshot-and-restore on cancel; editing indicator bar above input |
| P0 | Better Empty State & Suggestions | ✅ Done | `_CoachEmptyState` with fade-in, pulsing logo, "What I can do" capability row, grouped suggestion cards with 4px left colored border and category headers |
| P0 | Search Conversations | ✅ Done | `_ConversationDrawer` gets `AnimatedSize` search field; client-side filtering by title and preview; empty-results state |

---

## Phase 10.6 — Coach Tab WebSocket Production Fix (2026-03-10)

> **Branch:** `fix/websocket-connection` → merged to main (2026-03-10); subsequent fixes direct to main

End-to-end fix making the Coach tab's AI chat work against the production backend. All changes are live on `main`.

| Priority | Task | Status | Notes |
|----------|------|--------|-------|
| P0 | Fix WebSocket URI construction (`ws_client.dart`) | ✅ Done | `_deriveWsUrl()` now parses base URL as `https://` to get port 443, then rebuilds as `wss://` with explicit port |
| P0 | Fix WebSocket `accept()` ordering (`chat.py`) | ✅ Done | Moved `await websocket.accept()` to top of `websocket_chat` before auth; fixes HTTP 500 on auth failure |
| P0 | Wire `StorageService` into app state (`main.py`) | ✅ Done | `StorageService` imported and initialised in lifespan startup |
| P0 | Fix missing `archived`/`deleted_at` columns in production DB | ✅ Done | `ALTER TABLE conversations ADD COLUMN IF NOT EXISTS` run directly against production Supabase |
| P0 | Fix new-conversation stale history bug (`chat_thread_screen.dart`, `coach_providers.dart`) | ✅ Done | `seedFromPrior()` added to `CoachChatNotifier`; called before `replaceNamed()` to prevent redundant `loadHistory()` call |
| P1 | Fix backend tests for streaming protocol | ✅ Done | `test_ws_connect_and_echo` and `test_ws_empty_message_returns_error` updated to match `conversation_init` → `stream_token` → `stream_end` protocol; LLM mock updated to use `stream_chat` async generator |
| P1 | Add `make uninstall`, `make reinstall`, `make reinstall-prod` targets | ✅ Done | Ensures old APK is removed before reinstall; required because `flutter run --release` does not uninstall stale APKs |

---

## Phase 10.7 — Coach Chat UX Polish (`feat/coach-chat-ux-improvements`)

> **Branch:** `feat/coach-chat-ux-improvements` — in progress

| Priority | Task | Status | Notes |
|----------|------|--------|-------|
| P0 | Thinking state — "Thinking…" label between Send and first token | ✅ Done | Animated dots + italic "Thinking…" shown while `isSending=true` and no tokens/tool yet; disappears when tokens arrive |
| P0 | Inactivity timeout — surface error when connection goes silent | ✅ Done | 10-minute inactivity timer in `CoachChatNotifier`; resets on every server event (token/tool/complete/error); fires only if connection is completely silent; matches OpenAI SDK default |
| P0 | Smart auto-scroll — follow bottom, pause when scrolled up | ✅ Done | 80 px threshold; pauses on user scroll-up; floating scroll-to-bottom arrow button (sage green) fades in when user scrolls up; tapping it scrolls back down and clears the flag |
| P1 | Regenerate moved to long-press sheet | ✅ Done | Standalone button removed; long-press last AI message → Copy + Regenerate |

---

## Phase 10.8 — Flutter Layout Refactor (`feat/flutter-layout-refactor`)

> **Branch:** `feat/flutter-layout-refactor` — completed 2026-03-11

| Priority | Task | Status | Notes |
|----------|------|--------|-------|
| P0 | Phase 1: Foundation — color palette, typography, shared component library | ✅ Done | New dark #2D2D2D bg, light #FAFAF5 bg; 11 typography styles (was 7, 7 deprecated with forwarding); 12 new shared components |
| P0 | Phase 2: Layout shell — AppBar fix, AppShell update, tooltip boundary detection | ✅ Done | ZuralogScaffold created; ZuralogAppBar now theme-aware; frosted nav bar uses theme colors; tooltip auto-flip |
| P0 | Phase 3A–3H: Migrate all 33 screens to ZuralogScaffold | ✅ Done | Today, Data, Coach, Progress, Trends, Settings ×11, Profile, Auth/Onboarding — all migrated |
| P0 | Phase 4: Cleanup — remove private duplicates, verify zero regressions | ✅ Done | All private _categoryColor(String), _FadeSlideIn, _SkeletonBox copies confirmed removed; flutter analyze: zero issues; 267 tests passing |

---

## Phase 10.9 — Layout Bug Fixes Post-Refactor (`fix/tooltip-and-input-padding`)

> **Branch:** `fix/tooltip-and-input-padding` — completed 2026-03-11

| Priority | Task | Status | Notes |
|----------|------|--------|-------|
| P0 | Tooltip horizontal overflow clamping | ✅ Done | 240px bubble clamped to 16px margins on left/right edges; arrow offset refactored to CustomPainter canvas parameter; `_kHorizontalMargin` and `_kTooltipHeightEstimate` promoted to file-level constants |
| P0 | Coach input bar double bottom padding | ✅ Done | `_ChatInputBar` internal `Padding.bottom` changed from `AppDimens.bottomClearance()` (~184px) to `AppDimens.spaceSm` (8px); outer `ZuralogScaffold` padding now handles all bottom nav clearance |
| P0 | ~80px dead-space gap on all 5 tab screens (bottomClearance double-counting) | ✅ Done | `bottomClearance()` formula corrected: removed `bottomNavHeight` (was double-counted by `extendBody: true`); `addBottomNavPadding` parameter deprecated; non-scrollable screens use explicit `SizedBox(height: MediaQuery.padding.bottom)` |

---

## Phase 10.9.5 — Shared Component Library Consolidation (`chore/shared-component-library`)

> **Branch:** `chore/shared-component-library` — completed 2026-03-11

Established a centralized shared component library, eliminating duplicated UI code across 30+ screens and enforcing a single source of truth for all reusable widgets.

| Priority | Task | Status | Notes |
|----------|------|--------|-------|
| P0 | Create `ZIconBadge` widget (36–44px rounded icon container) | ✅ Done | Replaces ~30+ inline Container patterns across settings and detail screens |
| P0 | Create `ZSettingsTile` widget (settings row: icon + title + subtitle + trailing) | ✅ Done | Replaces 7 private `_SettingsTile`, `_TapRow`, `_AccountTile` classes across 7 screens |
| P0 | Create `ZSelectableTile` widget (animated selectable card frame) | ✅ Done | Replaces 4 onboarding selectable tile patterns across onboarding flow |
| P0 | Migrate all private `_EmptyState`/`_ErrorState` classes to shared components | ✅ Done | 4–6 screens migrated to `ZEmptyState` / `ZErrorState` |
| P0 | Migrate all `bool _pressed` manual animations to `ZuralogSpringButton` | ✅ Done | Eliminates manual press state management across multiple screens |
| P0 | Add Component Library enforcement rule to AGENTS.md | ✅ Done | New `## Component Library` section with library locations, barrel export pattern, and reusability guidelines |
| P1 | Create `docs/component-audit.md` with migration recommendations | ✅ Done | Audit of 26 FilledButton sites + 88 raw card Container sites with categorized recommendations for future phases |

**Net result:**
- ~1100+ lines of duplicated UI code removed
- 3 new reusable components added to library
- 7 private widget classes eliminated
- ~30+ inline icon badge patterns consolidated
- 4 onboarding tile patterns unified
- Single source of truth established for all reusable UI elements

---

## Phase 10.10 — Empty State & Zero-Data UX (`feat/empty-state-improvements`)

> **Branch:** `feat/empty-state-improvements` — merged to main 2026-03-11

| Priority | Task | Status | Notes |
|----------|------|--------|-------|
| P0 | Today tab — Health Score zero state | ✅ Done | Muted ring + heart icon + "Your health score awaits" headline + two tappable action rows (Log mood/energy → QuickLogSheet; Connect app → Settings > Integrations) |
| P0 | Today tab — Insights empty state | ✅ Done | `_EmptyInsightsCard` with "Insights on the way" copy and same two action rows |
| P0 | Data tab — Score trend chart empty state | ✅ Done | `_ScoreChartEmptyState` with chart icon + friendly message inside sparkline area |
| P0 | Data tab — Categories empty state | ✅ Done | Ghost preview cards for 5 categories + sage-green "Connect your first app" CTA → Settings > Integrations |
| P0 | Trends tab — Correlations empty state | ✅ Done | 3-icon cluster + `_ProgressHintRow` ("7 days of data unlocks your first pattern") |
| P0 | Never-error provider pattern | ✅ Done | All 4 providers (`healthScoreProvider`, `todayFeedProvider`, `dashboardProvider`, `trendsHomeProvider`) catch all errors and return empty data objects — UI never sees an error branch |
| P0 | Shared `HealthScoreZeroState` widget | ✅ Done | Extracted to `lib/shared/widgets/health_score_zero_state.dart`; used by TodayFeedScreen card body |
| P0 | Layout fix — compact zero ring in ScoreTrendHero | ✅ Done | `_CompactScoreZeroState` (48×48 muted ring) replaces full `HealthScoreZeroState` in row slot; prevents row layout break |

---

## Today Tab Part 4 — Quick Log Real Data & Steps Mode Toggle (2026-03-16)

> **Branch:** `feat/today-tab-part4-real-data` → merged to main (2026-03-16)

Completed real data wiring for quick-log endpoints (water, wellness, weight, steps) and added steps log mode toggle (add vs. override).

### Backend (Cloud Brain)

| Priority | Task | Status | Notes |
|----------|------|--------|-------|
| P0 | `POST /api/v1/quick-log/water` endpoint | ✅ Done | Logs water intake (amount_ml, vessel_key). Rate limit 60/min. Validation: 1–5000ml. |
| P0 | `POST /api/v1/quick-log/wellness` endpoint | ✅ Done | Logs mood/energy/stress check-in. Stores one `quick_logs` row per metric type. Rate limit 30/min. Validation: values 1.0–10.0, at least one required. |
| P0 | `POST /api/v1/quick-log/weight` endpoint | ✅ Done | Logs body weight in kg. Rate limit 10/min. Validation: 20–500kg. |
| P0 | `POST /api/v1/quick-log/steps` endpoint | ✅ Done | Logs step count with add/override mode. Rate limit 10/min. Validation: 0–100,000 steps. |
| P0 | `GET /api/v1/quick-log/my-metric-types` endpoint | ✅ Done | Returns distinct metric types the user has ever logged. Rate limit 60/min. |
| P0 | `GET /api/v1/quick-log/summary/today` endpoint | ✅ Done | Returns aggregated summary of today's logs (water/meal/supplement summed; mood/energy/stress/weight/sleep/run latest value; steps with override-as-reset logic). Timezone-aware via `tz_offset` query param. Rate limit 60/min. |
| P0 | Add `weight` and `steps` to `VALID_METRIC_TYPES` frozenset | ✅ Done | Metric type validation updated. |

### Flutter (Mobile App)

| Priority | Task | Status | Notes |
|----------|------|--------|-------|
| P0 | `TodayRepository.getTodayLogSummary()` real implementation | ✅ Done | Replaces stub. Wired to `GET /api/v1/quick-log/summary/today`. |
| P0 | `TodayRepository.getUserLoggedTypes()` real implementation | ✅ Done | Replaces stub. Wired to `GET /api/v1/quick-log/my-metric-types`. |
| P0 | `todayLogSummaryProvider` real implementation | ✅ Done | Replaces stub. Log Ring, Snapshot Cards, and Water panel's "X ml today" now reflect real data. |
| P0 | `userLoggedTypesProvider` real implementation | ✅ Done | Replaces stub. |
| P0 | `stepsLogModeProvider` new AsyncNotifierProvider | ✅ Done | Backed by SharedPreferences key `'steps_log_mode'`. Default: add mode. |
| P0 | `ZStepsLogPanel` mode toggle added | ✅ Done | Switch widget. Default: "Add to today's total". Can be switched to "Set as new total" (override mode). Mode remembered across sessions. |
| P0 | `logSteps` method added to `TodayRepository` | ✅ Done | Wired to `POST /api/v1/quick-log/steps`. |

### Tests

| Priority | Task | Status | Notes |
|----------|------|--------|-------|
| P0 | Backend tests for new endpoints | ✅ Done | 48 tests in `cloud-brain/tests/api/v1/test_new_log_endpoints.py`. |
| P0 | Provider unit tests | ✅ Done | `zuralog/test/features/today/providers/today_providers_test.dart`. |
| P0 | Widget tests for steps panel | ✅ Done | `zuralog/test/shared/widgets/log_panels/z_steps_log_panel_test.dart`. |

---

## Today Tab Part 7 — Backend Hardening (2026-03-17)

> **Branch:** commits on `main` (2026-03-17)

Completed 5 backend hardening tasks: composite index verification, Redis storage for rate-limit counters, UTC normalization, empty supplement guard, and CORS production safety.

| Priority | Task | Status | Notes |
|----------|------|--------|-------|
| P0 | Composite index verification | ✅ Done | `ix_quick_logs_user_type_logged` on `(user_id, metric_type, logged_at DESC)` already existed in migration `o0p1q2r3s4t5` |
| P0 | slowapi Redis storage for rate-limit counters | ✅ Done | `cloud-brain/app/limiter.py` passes `storage_uri=os.getenv("REDIS_URL")` to Limiter; counters shared across all server instances |
| P0 | `logged_at` UTC normalization | ✅ Done | `_resolve_logged_at()` in `quick_log_routes.py` normalizes non-UTC offsets to UTC before returning string; tests added |
| P0 | Empty supplement IDs guard | ✅ Done | `POST /quick-log/supplements` returns 422 when `taken_supplement_ids` is empty; dead ownership-check wrapper removed; tests added |
| P0 | CORS production guard | ✅ Done | `_resolve_cors_origins()` helper in `main.py` raises `RuntimeError` in production when `ALLOWED_ORIGINS` unset or empty; falls back to `*` in dev with warning; 4 tests added |

---

## Today Tab Part 8 — Shared Components Audit (2026-03-17)

> **Branch:** commits on `main` (2026-03-17)

Completed 1 shared component rename: `ZEmptyInsightsState` → `ZEmptyInsightsCard` across definition, two call sites, and widget test.

| Priority | Task | Status | Notes |
|----------|------|--------|-------|
| P0 | Rename `ZEmptyInsightsState` to `ZEmptyInsightsCard` | ✅ Done | Updated definition file, two call sites in `today_feed_screen.dart`, widget test file; `widgets.dart` barrel export unchanged (exports by file path); `flutter analyze`: 0 issues; `flutter test`: 377 passing |

---

## Today Tab Part 9 — Provider Gaps Closed (2026-03-17)

> **Branch:** `feat/today-tab-redesign` → merged to main (2026-03-17)

Converted three remaining FutureProviders to AsyncNotifierProviders for reactive state management, and added persistent meal log mode provider.

| Priority | Task | Status | Notes |
|----------|------|--------|-------|
| P0 | `logRingProvider` — FutureProvider → AsyncNotifierProvider | ✅ Done | `LogRingNotifier` watches `todayLogSummaryProvider` and `userLoggedTypesProvider` reactively. Eliminates stale data on upstream changes. |
| P0 | `snapshotProvider` — FutureProvider → AsyncNotifierProvider | ✅ Done | `SnapshotNotifier` watches both upstream providers reactively. Snapshot cards update in real-time when new data is logged. |
| P0 | `mealLogModeProvider` — new AsyncNotifierProvider | ✅ Done | Backed by SharedPreferences key `meal_log_quick_mode`, default `false`. `MealLogScreen` refactored to consume this provider instead of raw `setState` + `SharedPreferences`. |

---

## Today Tab Part 11 — Full Test Suite (2026-03-17)

> **Branch:** `feat/today-tab-redesign` → merged to main (2026-03-17)

Comprehensive test coverage across Flutter unit tests, integration tests, and backend security/rate-limit tests.

### Flutter Tests

| Priority | Task | Status | Notes |
|----------|------|--------|-------|
| P0 | Unit tests: `mealLogModeProvider` | ✅ Done | 4 tests covering persistence, default value, updates |
| P0 | Unit tests: `calculatePaceSecondsPerKm` | ✅ Done | 6 tests covering metric/imperial conversions, edge cases |
| P0 | Unit tests: `formatWeightDelta` | ✅ Done | 4 tests covering positive/negative deltas, unit display |
| P0 | Unit tests: logRing notifier AsyncData resolution | ✅ Done | 1 test verifying reactive updates on upstream changes |
| P0 | Unit tests: water panel vessel coverage | ✅ Done | 2 tests covering vessel selection and display |
| P0 | Function extractions for testability | ✅ Done | `calculatePaceSecondsPerKm` extracted in `run_log_screen.dart`; `formatWeightDelta` extracted in `z_weight_log_panel.dart` |
| P0 | Integration tests: water log end-to-end | ✅ Done | 1 test in `test/integration/today_log_flow_test.dart` |
| P0 | Integration tests: meal full-mode end-to-end | ✅ Done | 1 test in `test/integration/today_log_flow_test.dart` |
| P0 | Integration tests: network failure path | ✅ Done | 1 test in `test/integration/today_log_flow_test.dart` |

### Backend Tests

| Priority | Task | Status | Notes |
|----------|------|--------|-------|
| P0 | Security: `user_id`-from-body ignored on all 9 typed endpoints | ✅ Done | 7 new tests (run, water, meal, supplements, symptom, sleep, weight endpoints). Existing tests for wellness and steps already covered. |
| P0 | Rate limiting: `@limiter.limit()` decorator on all 9 typed endpoints | ✅ Done | 9 tests verifying rate limit headers and 429 responses |

### Test Results

| Metric | Result |
|--------|--------|
| Flutter unit + integration tests | 397/397 passing |
| Backend (api/v1) tests | 81/81 passing |
| `flutter analyze` | 0 issues |

---

## Today Tab Part 5 — Inline Log Panels (2026-03-17)

> **Branch:** commits on `main` (2026-03-17)

Completed full wiring of the four inline log panels — Water, Wellness, Weight, and Steps — with real API calls, pre-fill from backend latest values, unit awareness, and sync banners.

### Backend (Cloud Brain)

| Priority | Task | Status | Notes |
|----------|------|--------|-------|
| P0 | `GET /api/v1/quick-log/latest` endpoint | ✅ Done | Returns the most recent logged value per metric type across all time, deduplicated (one entry per type). Single ROW_NUMBER subquery. Rate limit 60/min. |

### Flutter (Mobile App)

| Priority | Task | Status | Notes |
|----------|------|--------|-------|
| P0 | `TodayRepository.getLatestLogValues()` | ✅ Done | Wired to `GET /api/v1/quick-log/latest`. Returns `Map<String, dynamic>` keyed by metric type. |
| P0 | `TodayRepository.logWater()` | ✅ Done | Wired to `POST /api/v1/quick-log/water`. |
| P0 | `TodayRepository.logWellness()` | ✅ Done | Wired to `POST /api/v1/quick-log/wellness`. |
| P0 | `TodayRepository.logWeight()` | ✅ Done | Wired to `POST /api/v1/quick-log/weight`. |
| P0 | `latestLogValuesProvider` | ✅ Done | `FutureProvider.family<Map<String, dynamic>, String>` keyed via `latestLogValuesKey(Set<String>)` helper. Caches per metric-type set. |
| P0 | `ZWaterLogPanel` — real API + unit awareness | ✅ Done | Calls `logWater` on save. oz/ml unit awareness (reads user prefs). Shows "X ml today" from `todayLogSummaryProvider`. Error handling via `parentMessenger`. |
| P0 | `ZWellnessLogPanel` — real API | ✅ Done | Calls `logWellness` on save. Error handling via `parentMessenger`. |
| P0 | `ZWeightLogPanel` — pre-fill, delta, unit persistence | ✅ Done | Pre-fills from `latestLogValuesProvider(weight)`. Shows delta indicator vs previous. Last-used unit (kg/lbs) persisted via SharedPreferences. Calls `logWeight` on save. |
| P0 | `ZStepsLogPanel` — sync banner + goal display | ✅ Done | Shows sync banner when Apple Health / Health Connect source detected (source stored as state). Displays goal progress from `dailyGoalsProvider`. "Confirm Steps" label when value matches synced total. Manual source omits banner. |
| P0 | `_PanelView` snackbar fix in `z_log_grid_sheet.dart` | ✅ Done | Single `todayLogSummaryProvider` invalidation on save. `parentMessenger` threaded through to all error handlers. |

### Tests

| Priority | Task | Status | Notes |
|----------|------|--------|-------|
| P0 | Backend tests for GET /quick-log/latest | ✅ Done | 11 tests in `cloud-brain/tests/api/v1/test_quick_log_routes.py`. |
| P0 | Widget tests for ZStepsLogPanel sync banner + goal display | ✅ Done | 7 tests in `zuralog/test/shared/widgets/log_panels/z_steps_log_panel_test.dart`. |

---

## Today Tab Part 3 — Full-Screen Log Screens (2026-03-16)

> **Branch:** `feat/today-tab-part-3` → merged to main (2026-03-16)

Completed 5 full-screen log screens for Sleep, Run, Meal, Supplements, and Symptom logging, plus all backend endpoints and route registration.

### Flutter (Mobile App)

| Priority | Task | Status | Notes |
|----------|------|--------|-------|
| P0 | SleepLogScreen — bedtime/wake time pickers, quality emoji, interruptions counter, factors chips, notes | ✅ Done | Full-screen route outside tab shell; floating submit button |
| P0 | RunLogScreen — mode picker (Open Strava / Log a past run / Record live), activity type, distance, duration, auto-pace, effort | ✅ Done | Full-screen route; Strava deep link support |
| P0 | MealLogScreen — quick/full toggle (persisted via SharedPreferences), meal type, description, calorie presets, feel chips, tags | ✅ Done | Full-screen route; toggle state persisted across sessions |
| P0 | SupplementsLogScreen — tap-to-check-off checklist, inline add form, optimistic updates | ✅ Done | Full-screen route; real-time checklist UI |
| P0 | SymptomLogScreen — body area multi-select, symptom type, severity emoji, timing, notes | ✅ Done | Full-screen route; multi-select body area picker |
| P0 | Register 5 routes outside tab shell in `app_router.dart` | ✅ Done | Routes: `/sleep-log`, `/run-log`, `/meal-log`, `/supplements-log`, `/symptom-log` |
| P0 | Add `logSheetCallbackProvider` in `log_sheet_provider.dart` | ✅ Done | Enables log grid sheet to launch from AppShell, floating above nav bar |
| P0 | Add `ZSectionLabel` shared widget | ✅ Done | Section title label for log screens; added to `lib/shared/widgets/layout/z_section_label.dart` |
| P0 | Add `DailyGoal` and `SupplementEntry` models to `today_models.dart` | ✅ Done | ORM models for goals and supplements |
| P0 | Add `dailyGoalsProvider` and `supplementsListProvider` to `today_providers.dart` | ✅ Done | Riverpod providers for goals and supplements data |
| P0 | Add repository methods: `logSleep`, `logRun`, `logMeal`, `logSupplements`, `logSymptom`, `getSupplementsList`, `updateSupplementsList`, `getDailyGoals` | ✅ Done | All methods wired to backend endpoints |

### Backend (Cloud Brain)

| Priority | Task | Status | Notes |
|----------|------|--------|-------|
| P0 | Add database migration: `data` JSONB column to `quick_logs` | ✅ Done | Stores structured log data (sleep, run, meal, supplements, symptom) |
| P0 | Add composite indexes replacing single-column indexes | ✅ Done | Performance optimization for queries |
| P0 | Create `user_supplements` table | ✅ Done | Stores user's supplement list with timestamps |
| P0 | Add RLS policies on `quick_logs` and `user_supplements` | ✅ Done | Critical security fix — RLS was never enabled on `quick_logs` |
| P0 | Add `UserSupplement` ORM model | ✅ Done | SQLAlchemy model for supplements |
| P0 | Extend `VALID_METRIC_TYPES` to include sleep, run, meal, supplement, symptom, workout | ✅ Done | Metric type validation |
| P0 | Add 7 new endpoints to `quick_log_routes.py` | ✅ Done | `/sleep`, `/run`, `/meal`, `/supplements`, `/symptom`, `/user/supplements-list` (GET + POST) |
| P0 | Rate limit all endpoints via slowapi | ✅ Done | Per-user rate limiting |

---

## Phase 11.5 — Pre-Tester Stability & Bug Audit (fix/pre-tester-cleanup, 2026-03-13)

> **Branch:** `fix/pre-tester-cleanup` → merged to main (2026-03-13)

Comprehensive bug audit and fix pass across backend and Flutter. All tabs now query correctly, no crashes on network failures, zero `flutter analyze` issues. App is stable and ready for pre-tester onboarding.

### Backend Fixes

| Priority | Task | Status | Notes |
|----------|------|--------|-------|
| P0 | Add `GET /api/v1/trends/metrics` endpoint | ✅ Done | Returns available metrics for trend analysis |
| P0 | Add `GET /api/v1/trends/correlations` endpoint | ✅ Done | Returns correlation data for Trends tab |
| P0 | Add `GET /api/v1/progress/weekly-report` endpoint | ✅ Done | Returns weekly report data for Progress tab |
| P0 | Create `GET /api/v1/data-sources` endpoint (new route file) | ✅ Done | New route file + registered in main.py |

### Flutter Fixes

| Priority | Task | Status | Notes |
|----------|------|--------|-------|
| P0 | Fix Today tab quick actions JSON key (`items` → `actions`) | ✅ Done | Quick actions now appear correctly on Today screen |
| P0 | Add error-safe fallback to 6 providers | ✅ Done | `notificationsProvider`, `coachPromptSuggestionsProvider`, `coachQuickActionsProvider`, `availableMetricsProvider`, `reportsProvider`, `dataSourcesProvider` |
| P0 | Fix 8 crash sites in pull-to-refresh handlers | ✅ Done | Dart `catchError` signature corrected; app no longer crashes on network failures |
| P0 | Fix raw error message in journal screen error state | ✅ Done | Users no longer see raw error text |
| P0 | Fix explicit `dataDays: 0` in health score fallback | ✅ Done | Prevents incorrect banner appearing after failed refresh |

**Result:** All tabs query correctly, zero crashes on network failures, `flutter analyze` reports zero issues. App is stable and ready for pre-tester onboarding.

---

## Phase 11 — Real Data Wiring (fix/remove-mock-data-wire-real-apis, 2026-03-11)

> **Branch:** `fix/remove-mock-data-wire-real-apis` → merged to main (2026-03-11, fast-forward)

Removed all debug-mode mock gates and wired the entire Flutter app to real backend APIs. The app now always fetches live data in both debug and release builds.

| Priority | Task | Status | Notes |
|----------|------|--------|-------|
| P0 | Remove `kDebugMode` mock gates from all 5 feature tab providers | ✅ Done | Today, Data, Coach, Trends, Progress tabs now always use real API repositories. Mock repositories preserved in codebase for test use only. |
| P0 | Remove hardcoded 'mock-user' ID from Analytics Repository | ✅ Done | Removed misleading `const String _mockUserId = 'mock-user'` query parameter. Backend reads user from JWT. Added `invalidateAll()` method for logout cleanup. |
| P0 | Wire Integrations Hub to real backend status endpoints | ✅ Done | `loadIntegrations()` fetches real connection status from `/status` endpoints for all 5 OAuth providers (Strava, Fitbit, Oura, Polar, Withings) in parallel. `disconnect()` calls backend `DELETE /disconnect` endpoints. Added `getProviderStatus()` and `disconnectProvider()` to OAuthRepository. |
| P0 | Rewrite Settings > Integrations screen to use live server data | ✅ Done | Removed 100% hardcoded duplicate model classes. Screen now reads from `integrationsProvider` (live server data). Connect/disconnect buttons trigger real OAuth flows. |
| P0 | Comprehensive logout cleanup | ✅ Done | New `_clearUserState()` method clears: (a) user-specific SharedPreferences keys, (b) all repository in-memory caches via `invalidateAll()`, (c) all Riverpod providers across every tab. Prevents User A's data from leaking to User B on the same device. |
| P0 | Code review fixes | ✅ Done | Fixed OAuth `connect()` prematurely marking integrations as "connected" (now stays in "syncing" until deep-link callback confirms). Fixed parallel fetch, UTC time comparison, added notificationsProvider to cleanup, added mounted guard on navigator pop. |

**Key decisions:**
- Device-local integrations (Apple Health, Health Connect) correctly use SharedPreferences. Server-side OAuth integrations (Strava, Fitbit, Oura, Polar, Withings) query the backend.
- Mock repositories preserved in the codebase for test use, but no longer used at runtime.
- The "never-error" provider pattern (established in Phase 10.10) was preserved — providers still catch errors and return empty data.

---

## Architectural Debt Cleanup — Batch 3 (2026-03-14)

> **Branch:** `fix/security-rate-limiting-webhooks` → merged to main (2026-03-14)

Completed all security and rate-limiting fixes for unprotected endpoints and webhook verification vulnerabilities.

| Priority | Task | Status | Notes |
|----------|------|--------|-------|
| P0 | DEBT-016: Add rate limits to 12 unprotected endpoints | ✅ Done | Health ingest, chat history/conversations, analytics dashboard, trends home/metrics/correlations, RevenueCat webhook. Rate limiter upgraded from IP-based to per-user (JWT sub claim) for authenticated endpoints, with IP fallback for webhook endpoints. |
| P0 | DEBT-037: Add Strava webhook subscription_id verification | ✅ Done | Events with mismatched subscription ID rejected (returns 200 to prevent Strava retries). Backward compatible — check skipped when `STRAVA_WEBHOOK_SUBSCRIPTION_ID` env var not set. |
| P0 | DEBT-038: Fix Fitbit webhook verification timing vulnerability | ✅ Done | Replaced `==` string comparison with `hmac.compare_digest` to prevent timing side-channel attacks. |
| P0 | DEBT-040: Add CORS wildcard production warning | ✅ Done | App logs `WARNING` at startup if `ALLOWED_ORIGINS=*` is set in production. |
| P0 | Bonus: Remove secret token from logs | ✅ Done | Removed `strava_webhook_verify_token` that was being printed to logs on validation mismatch. |

---

## Architectural Debt Cleanup — Batch 5 (2026-03-14)

> **Branch:** `fix/data-integrity-insights-ingest` → merged to main (2026-03-14)

Completed all data integrity and deprecation fixes for the insights feature and health ingest pipeline.

| Priority | Task | Status | Notes |
|----------|------|--------|-------|
| P0 | DEBT-049: Duplicate insight rows fixed | ✅ Done | Added unique constraint on `insights(user_id, type, created_at::date)`. Updated `generate_insights_for_user` Celery task to use `INSERT ... ON CONFLICT DO UPDATE` (upsert) instead of bare `db.add()`. Added missing Row Level Security to insights table. |
| P0 | DEBT-018: `datetime.utcnow()` deprecation fixed | ✅ Done | Replaced `datetime.utcnow()` with `datetime.now(timezone.utc)` in `health_ingest.py`. Confirmed zero remaining `utcnow()` calls across entire backend. |

---

## Architectural Debt Cleanup — Batch 8 (2026-03-15)

> **Branch:** `fix/backend-performance-cleanup` → merged to main (2026-03-15)

Completed performance optimization, security hardening, and dependency cleanup across the backend. Parallelized slow analytics queries, consolidated auth dependencies, and removed unused code.

| Priority | Task | Status | Notes |
|----------|------|--------|-------|
| P0 | DEBT-008: Sentry traces sampling reduced | ✅ Done | Changed `sentry_traces_sample_rate` default from 1.0 to 0.1 in `cloud-brain/app/config.py`. Reduces Sentry quota usage by 90% while maintaining visibility into errors. |
| P0 | DEBT-007: Integration API base URL validation | ✅ Done | Changed `withings_api_base_url` and `polar_api_base_url` defaults from `"https://api.zuralog.com"` to `""`. Added `_validate_integration_config` Pydantic validator that fails fast at startup if client IDs are set without corresponding URLs. Prevents silent failures in production. |
| P0 | DEBT-020 + DEBT-048: Dashboard analytics parallelized | ✅ Done | Replaced 8 sequential database queries in `dashboard_summary` with `asyncio.gather()` + generic `_fetch_category_data` helper. Added SQL injection allowlist. Decorated with `@cached` for response caching. Implemented `return_exceptions=True` for graceful category-level degradation. |
| P0 | DEBT-013 + DEBT-014: Auth dependencies consolidated | ✅ Done | Consolidated `_get_auth_service` and `get_authenticated_user_id` into `cloud-brain/app/api/deps.py` as single source of truth. Deleted `cloud-brain/app/api/v1/deps.py`. Updated all 25+ route files and 14 test files to import from canonical location. |
| P0 | DEBT-006: Removed permanent sync stub | ✅ Done | Deleted `sync_all_users_task` permanent stub from `cloud-brain/app/services/sync_scheduler.py`. Cleans up dead code. |
| P0 | DEBT-033: Dependency cleanup | ✅ Done | Moved `psycopg2-binary` from production to dev dependencies in `cloud-brain/pyproject.toml`. Removed `[dependency-groups]` block (consolidated into `[project.optional-dependencies]`). Reduces production image size. |
| P0 | Security: Replaced assert guards with HTTPException | ✅ Done | Replaced `assert` statements with explicit `HTTPException` in `analytics.py`. Prevents assertion failures from crashing the server in production. |
| P0 | Security: Added metric field pattern constraint | ✅ Done | Added `metric` field pattern constraint (`^[a-z_]{1,64}$`) in `analytics_schemas.py`. Prevents injection attacks via metric names. |

---

## Architectural Debt Cleanup — Batch 9 (fix/flutter-medium-priority, 2026-03-15)

> **Branch:** `fix/flutter-medium-priority` → merged to main (2026-03-15)

Completed Flutter package management, SharedPreferences centralization, and fire-and-forget async cleanup.

| Priority | Task | Status | Notes |
|----------|------|--------|-------|
| P0 | DEBT-034: Pin all Flutter package versions in pubspec.yaml | ✅ Done | 19 packages: `any` → `^<version>` caret constraints for reproducible builds |
| P0 | DEBT-017: Create central `prefsProvider` (SharedPreferences) | ✅ Done | `zuralog/lib/core/storage/prefs_service.dart` — Riverpod provider wired in `main.dart`; all widgets access SharedPreferences synchronously |
| P0 | DEBT-041: Fix fire-and-forget in `today_feed_screen.dart` | ✅ Done | Replaced `SharedPreferences.getInstance().then(...)` with synchronous `ref.read(prefsProvider)` |
| P0 | DEBT-042: Fix fire-and-forget in `trends_home_screen.dart` | ✅ Done | Replaced `SharedPreferences.getInstance().then(...)` in `_persistDismissals` with `ref.read(prefsProvider)` + `unawaited()` |
| P0 | DEBT-019: Remove hardcoded goals from `account_settings_screen.dart` | ✅ Done | Deleted local-only `_selectedGoalsProvider` with hardcoded `{0, 2}`. Added `_GoalsTile` that reads real `goalsProvider` and navigates to `GoalsScreen` for full CRUD |

---

## Architectural Debt Cleanup — Batch 10 (fix/low-priority-cleanup, 2026-03-15)

> **Branch:** `fix/low-priority-cleanup` → merged to main (2026-03-15)

Completed magic number extraction, ORM migration, smoke test rewrite, and documentation fixes.

| Priority | Task | Status | Notes |
|----------|------|--------|-------|
| P0 | DEBT-012: Extract magic number `7` (data maturity threshold) to named constants | ✅ Done | `MIN_DATA_DAYS_FOR_MATURITY` in `cloud-brain/app/constants.py` and `kMinDataDaysForMaturity` in `zuralog/lib/core/constants/app_constants.dart`; all raw `7` comparisons replaced |
| P0 | DEBT-022: Replace raw SQL with ORM query in `users.py` | ✅ Done | `get_preferences` handler: raw `text("SELECT coach_persona, subscription_tier FROM users WHERE id = :uid")` → `select(User.coach_persona, User.subscription_tier).where(User.id == user_id)` |
| P0 | DEBT-027: Rewrite `widget_test.dart` smoke test | ✅ Done | Now verifies auth gate (welcome screen buttons) or main shell nav labels on cold start, not just Scaffold existence |
| P0 | DEBT-030: Fix `docs/architecture.md` — path correction | ✅ Done | `features/dashboard/` → `features/data/` |
| P0 | DEBT-031: Fix `docs/architecture.md` — test file count | ✅ Done | Updated from `61` to `109` |
| P0 | DEBT-032: Fix `docs/screens.md` — Conversation Drawer type | ✅ Done | Corrected from "Drawer overlay" to "Modal bottom sheet (`DraggableScrollableSheet` via `showModalBottomSheet`)" |
| P0 | DEBT-043: Verify `_MilestoneCelebrationCardState.dispose()` | ✅ Done | Confirmed `_pulseCtrl.dispose()` already called — no change needed |

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

## Infrastructure Optimization (2026-03-10)

| Priority | Task | Status | Notes |
|----------|------|--------|-------|
| P0 | Remove Upstash Redis, migrate to Railway Redis | ✅ Done | All 3 services use `redis.railway.internal:6379`; new `Redis` service provisioned |
| P0 | Consolidate Celery_Beat into Celery_Worker | ✅ Done | Worker runs `celery -A app.worker worker --beat --concurrency=2`; single-replica constraint documented |
| P0 | Optimize observability sampling rates | ✅ Done | Zuralog: 5% traces, 0% profiles; Celery_Worker: 0% traces; PostHog disabled |
| P0 | Fix Beat schedule (task names, intervals, crontab) | ✅ Done | Removed stub tasks, extended 4 syncs to 60min, added `celery-redbeat` for crash-safe persistence |
| P0 | Reduce Docker image size | ✅ Done | Removed `numpy` (−50MB), removed `psycopg2-binary` (−10MB), fixed git call to env var |
| P0 | Optimize database connection pools | ✅ Done | FastAPI: 2+3 (was 10+20); Celery: NullPool for all tasks |
| P0 | Cost reduction: ~$3.48 → ~$0.95/mo | ✅ Done | 73% savings via Redis consolidation + observability tuning + 1 fewer service |

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

---

## Architectural Debt Cleanup — All 10 Batches Complete (2026-03-15)

> **Status:** ✅ **COMPLETE** — All 50 architectural debt items from the March 2026 audit have been fixed and deployed to production.

**Batches completed:**

| Batch | Branch | Focus | Status | Date |
|-------|--------|-------|--------|------|
| 1 | `fix/chat-n-plus-1-queries` | N+1 query fixes in chat endpoints | ✅ Done | 2026-03-14 |
| 2 | `fix/dead-code-conversation-routes` | Delete dead backend router + test | ✅ Done | 2026-03-14 |
| 3 | `fix/security-rate-limiting-webhooks` | Rate limiting + webhook verification | ✅ Done | 2026-03-14 |
| 4 | `fix/security-dev-withings` | Withings webhook cleanup + dev endpoint clarity | ✅ Done | 2026-03-14 |
| 5 | `fix/data-integrity-insights-ingest` | Duplicate insights fix + datetime deprecation | ✅ Done | 2026-03-14 |
| 6 | `fix/flutter-hardcoded-values` | Remove hardcoded email, profile fields, prices | ✅ Done | 2026-03-14 |
| 7 | `fix/flutter-dead-code-cleanup` | Delete dead Flutter screens + providers | ✅ Done | 2026-03-14 |
| 8 | `fix/backend-performance-cleanup` | Parallelise analytics, consolidate auth, reduce sampling | ✅ Done | 2026-03-15 |
| 9 | `fix/flutter-medium-priority` | Pin packages, centralise SharedPreferences, remove fire-and-forget | ✅ Done | 2026-03-15 |
| 10 | `fix/low-priority-cleanup` | Extract magic numbers, ORM migration, smoke test rewrite, doc fixes | ✅ Done | 2026-03-15 |

**Key fixes deployed:**
- 10 broken test files fixed (Batches 1, 2, 7)
- Railway deployment fix (Batch 8: auth deps consolidation)
- Supabase migration idempotency fix (Batch 5: insights upsert)
- `WITHINGS_API_BASE_URL` env var validation (Batch 8: integration config)
- All 50 debt items resolved; zero regressions

---

## Today Tab Redesign — Multi-Part Implementation

> **Status:** Part 2 complete and merged to main (2026-03-16)

The Today Feed is being rebuilt in phases to add new shared components, refactor the screen layout, and wire real data from the backend.

### Part 1 — Shared Components & Layout Refactor (2026-03-16)

> **Branch:** `feat/today-tab-redesign-part-1` → merged to main

Extracted 5 new reusable components from the Today screen and refactored the layout to support new features.

| Priority | Task | Status | Notes |
|----------|------|--------|-------|
| P0 | Create `SectionHeader` with trailing widget slot and left accent bar | ✅ Done | Extended existing component; used across Today screen |
| P0 | Create `ZInsightCard` (reusable AI insight card) | ✅ Done | Extracted from Today screen; `cards/z_insight_card.dart` |
| P0 | Create `ZEmptyInsightsState` (empty state with two CTAs) | ✅ Done | `states/z_empty_insights_state.dart`; replaces private `_EmptyInsightsCard` |
| P0 | Create `ZLogRingWidget` (circular log completion ring) | ✅ Done | `health/z_log_ring_widget.dart`; watches `logRingProvider` |
| P0 | Create `ZSnapshotCard` (compact metric snapshot) | ✅ Done | `cards/z_snapshot_card.dart`; displays today's value for one metric |
| P0 | Create `ZDailyGoalsCard` (daily goals progress) | ✅ Done | `cards/z_daily_goals_card.dart`; shows setup prompt until goals configured |
| P0 | Create domain models: `TodayLogSummary`, `LogRingState`, `SnapshotCardData` | ✅ Done | `features/today/domain/log_summary_models.dart` |
| P0 | Add stub providers: `todayLogSummaryProvider`, `userLoggedTypesProvider`, `logRingProvider`, `snapshotProvider` | ✅ Done | Providers in `today_providers.dart`; will be wired to real data in Part 4 |
| P0 | Refactor Today screen layout: Health Score + Log Ring side-by-side | ✅ Done | Score left, Ring right; 120pt each |
| P0 | Add Snapshot Cards row (horizontally scrollable, hidden until user logs) | ✅ Done | Appears below Health Score + Log Ring |
| P0 | Add Daily Goals card | ✅ Done | Shows "Set a daily goal →" until goals configured |
| P0 | Remove Quick Actions section (superseded by FAB in Part 2) | ✅ Done | Deleted from layout |
| P0 | Remove Wellness Check-in card (superseded by FAB in Part 2) | ✅ Done | Deleted from layout |
| P0 | Replace private `_InsightCard`, `_SectionHeader`, `_EmptyInsightsCard` with shared components | ✅ Done | Screen reduced from 985 lines to 447 lines |
| P0 | Remove `QuickAction` model from `today_models.dart` | ✅ Done | Deleted |
| P0 | Remove `quickLogLoadingProvider` from `today_providers.dart` | ✅ Done | Deleted |

**Result:** Today screen refactored with 5 new shared components, cleaner layout, and foundation for Parts 2–4. Screen code reduced by 55%.

### Part 2 — FAB & Log Grid Sheet (2026-03-16)

> **Branch:** `feat/today-tab-redesign` → merged to main

Added floating action button (FAB) for quick log entry and a modal bottom sheet with 10-tile log type selection grid. Inline log panels for Water, Wellness, Weight, and Steps. Full-screen log screens (Sleep, Run, Meal, Supplements, Symptom) deferred to Part 3.

| Priority | Task | Status | Notes |
|----------|------|--------|-------|
| P0 | Create `ZLogFab` floating action button | ✅ Done | `buttons/z_log_fab.dart`; circular FAB with 500ms debounce |
| P0 | Create `ZLogGridSheet` modal bottom sheet | ✅ Done | `sheets/z_log_grid_sheet.dart`; 10-tile 4-column grid with animated panel swap |
| P0 | Create `ZLogGridCell` tile component | ✅ Done | `sheets/z_log_grid_cell.dart`; single tile in log grid |
| P0 | Create `ZWaterLogPanel` inline panel | ✅ Done | `log_panels/z_water_log_panel.dart`; vessel picker, custom input, today's total |
| P0 | Create `ZWellnessLogPanel` inline panel | ✅ Done | `log_panels/z_wellness_log_panel.dart`; mood/energy/stress sliders + notes |
| P0 | Create `ZWeightLogPanel` inline panel | ✅ Done | `log_panels/z_weight_log_panel.dart`; kg/lbs toggle |
| P0 | Create `ZStepsLogPanel` inline panel | ✅ Done | `log_panels/z_steps_log_panel.dart`; step count entry |
| P0 | Wire FAB to open log grid sheet | ✅ Done | `today_feed_screen.dart` converted to `ConsumerStatefulWidget` |
| P0 | Wire inline tiles to log panels | ✅ Done | Wellness, Water, Weight, Steps animate to their panel inside sheet |
| P0 | Wire full-screen tiles (no-op in Part 2) | ✅ Done | Sleep, Run, Meal, Supplements, Symptom are stubs; Part 3 will build screens |
| P0 | Wire Workout tile to "coming soon" snackbar | ✅ Done | Placeholder for future integration |
| P0 | Invalidate `todayLogSummaryProvider` after log submission | ✅ Done | Ensures UI updates with new data |
| P0 | Delete `quick_log_sheet.dart` | ✅ Done | Replaced by new FAB system |
| P0 | Update `new_chat_screen.dart` redirect | ✅ Done | Redirects to Today tab instead of old sheet |
| P0 | Add haptic feedback on log submission | ✅ Done | Medium impact haptic on successful log |

**Result:** 345 tests passing, zero analyzer issues. FAB + log grid sheet + 4 inline log panels fully functional. Full-screen log screens (Sleep, Run, Meal, Supplements, Symptom) ready for Part 3.

### Part 3 — Full-Screen Log Screens (Complete)

| Priority | Task | Status | Notes |
|----------|------|--------|-------|
| P0 | Create full-screen log screens: Sleep, Run, Meal, Supplements, Symptom | ✅ Done | See "Today Tab Part 3" section above |
| P0 | Wire log grid sheet to open full-screen screens | ✅ Done | Routes registered in `app_router.dart` |

### Part 4 — Backend Data Wiring (Complete)

| Priority | Task | Status | Notes |
|----------|------|--------|-------|
| P0 | Extend `quick_log_routes.py` with new log endpoints | ✅ Done | Water, wellness, weight, steps endpoints added |
| P0 | Wire `todayLogSummaryProvider` to real backend data | ✅ Done | Wired to `GET /api/v1/quick-log/summary/today` |
| P0 | Wire `userLoggedTypesProvider` to real backend data | ✅ Done | Wired to `GET /api/v1/quick-log/my-metric-types` |
| P0 | Wire `logRingProvider` to compute ring fill from real data | ✅ Done | Derived from `todayLogSummaryProvider` |
| P0 | Wire `snapshotProvider` to build ordered snapshot list | ✅ Done | Derived from `todayLogSummaryProvider` |
| P0 | Wire Daily Goals card to real goals data | ✅ Done | `dailyGoalsProvider` wired to `GET /api/v1/goals` |

### Part 5 — Inline Panels (Complete)

See "Today Tab Part 5" section above.

---

## Today Tab Redesign — Complete (2026-03-18)

> **Branch:** `feat/today-tab-redesign` → merged to main (2026-03-18)

Completed the Today tab visual redesign with three major UI changes: Health Score zero state, Streak Hero Card, and Adaptive Metric Grid.

| Priority | Task | Status | Notes |
|----------|------|--------|-------|
| P0 | Health Score zero state redesign | ✅ Done | Replaced muted ring + heart icon with 😔 sad face emoji, "Health Score" label, and "Log to unlock" subtitle |
| P0 | Create `StreakHeroCard` component | ✅ Done | `zuralog/lib/shared/widgets/streak_hero_card.dart`; zero streak shows ghost flame with "Start your streak today", active streak shows big orange number and flame |
| P0 | Remove `ZLogRingWidget` from Today screen | ✅ Done | Deleted `zuralog/lib/shared/widgets/health/z_log_ring_widget.dart`; removed `logRingProvider` and `LogRingNotifier` from `today_providers.dart` |
| P0 | Create Adaptive Metric Grid component | ✅ Done | `zuralog/lib/shared/widgets/metric_grid/metric_grid.dart`; user-configurable grid with long-press edit mode |
| P0 | Create Metric Tile component | ✅ Done | `zuralog/lib/shared/widgets/metric_grid/metric_tile.dart`; greyscale when not logged, colored when logged or synced |
| P0 | Create Metric Picker Sheet | ✅ Done | `zuralog/lib/shared/widgets/metric_grid/metric_picker_sheet.dart`; add/remove metrics in edit mode |
| P0 | Create metric grid domain models | ✅ Done | `zuralog/lib/features/today/domain/metric_grid_models.dart`; metric configuration and state |
| P0 | Create metric format utilities | ✅ Done | `zuralog/lib/features/today/domain/metric_format_utils.dart`; value formatting and display logic |
| P0 | Wire metric grid to user preferences | ✅ Done | Grid configuration persisted via `userPreferencesProvider` |
| P0 | Update Today Feed layout | ✅ Done | Health Score zero state, Streak Hero Card, Adaptive Metric Grid in new layout |
| P0 | Full test suite | ✅ Done | 397 Flutter tests + 81 backend tests, all passing; zero `flutter analyze` issues |

**New files created:**
- `zuralog/lib/shared/widgets/streak_hero_card.dart`
- `zuralog/lib/shared/widgets/metric_grid/metric_tile.dart`
- `zuralog/lib/shared/widgets/metric_grid/metric_grid.dart`
- `zuralog/lib/shared/widgets/metric_grid/metric_picker_sheet.dart`
- `zuralog/lib/features/today/domain/metric_grid_models.dart`
- `zuralog/lib/features/today/domain/metric_format_utils.dart`

**Retired:**
- `zuralog/lib/shared/widgets/health/z_log_ring_widget.dart` — deleted
- `logRingProvider` / `LogRingNotifier` — removed from `today_providers.dart`

**Result:** Today tab redesigned with new visual hierarchy, user-configurable metric grid, and improved zero-state UX. All tests passing, ready for production.
