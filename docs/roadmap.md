# Zuralog — Product Roadmap

**Format:** Living checklist. Agents and developers update `Status` as work completes.  
**Last Updated:** 2026-03-04 (feat/data-tab merged — Data tab fully built; mock data layer planned for Phase 5.1)

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
| P1 | System prompt tuning (Tough Love Coach persona) | 🔜 Planned | |

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
| P1 | Background insight alerts | 🔜 Planned | Trigger on health data events |

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
| P2 | Pinecone vector store for long-term context | 🔜 Planned | Env var exists; code not yet written |

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
| P0 | Voice input (mic button) | ✅ Done | On-device STT via `speech_to_text` Flutter package (free, offline, no API key) |
| P0 | File attachments in chat | 📋 Future | |
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
| P0 | Today Feed (curated daily briefing) | ✅ Done | Phase 3 complete — Health Score hero, insight cards, quick actions, wellness check-in, streak, Quick Log FAB |
| P0 | Today — Insight Detail | ✅ Done | Phase 3 complete — bar chart, AI reasoning, source chips, Discuss with Coach CTA |
| P0 | Today — Notification History | ✅ Done | Phase 3 complete — grouped by day, unread indicators, deep-link routing |
| P0 | Data — Health Dashboard (customizable) | ✅ Done | Phase 5 — feat/data-tab |
| P0 | Data — Category Detail (x10) | ✅ Done | Phase 5 — feat/data-tab |
| P0 | Data — Metric Detail | ✅ Done | Phase 5 — feat/data-tab |
| P0 | Coach — New Chat (Gemini-style) | 🔄 Route+placeholder done | Phase 4 |
| P0 | Coach — Conversation Drawer | 🔜 Planned | Phase 4 |
| P0 | Coach — Chat Thread | 🔄 Route+placeholder done | Phase 4 |
| P0 | Coach — Quick Actions Sheet | 🔜 Planned | Phase 4 |
| P1 | Progress — Progress Home | 🔄 Route+placeholder done | Phase 6 |
| P1 | Progress — Goals | 🔄 Route+placeholder done | Phase 6 |
| P1 | Progress — Goal Detail | 🔄 Route+placeholder done | Phase 6 |
| P1 | Progress — Achievements | 🔄 Route+placeholder done | Phase 6 |
| P1 | Progress — Weekly Report | 🔄 Route+placeholder done | Phase 6 |
| P1 | Progress — Journal / Daily Log | 🔄 Route+placeholder done | Phase 6 |
| P1 | Trends — Trends Home | 🔄 Route+placeholder done | Phase 7 |
| P1 | Trends — Correlations | 🔄 Route+placeholder done | Phase 7 |
| P1 | Trends — Reports | 🔄 Route+placeholder done | Phase 7 |
| P1 | Trends — Data Sources | 🔄 Route+placeholder done | Phase 7 |
| P1 | Settings Hub | 🔄 Route+placeholder done | Phase 8 |
| P1 | Settings — Account | 🔄 Route+placeholder done | Phase 8 |
| P1 | Settings — Notifications | 🔄 Route+placeholder done | Phase 8 |
| P1 | Settings — Appearance | 🔄 Route+placeholder done | Phase 8 |
| P1 | Settings — Coach Settings | 🔄 Route+placeholder done | Phase 8 |
| P1 | Settings — Integrations | 🔄 Route+placeholder done | Phase 8 |
| P1 | Settings — Privacy & Data | 🔄 Route+placeholder done | Phase 8 |
| P1 | Settings — Subscription | 🔄 Route+placeholder done | Phase 8 |
| P1 | Settings — About | 🔄 Route+placeholder done | Phase 8 |
| P2 | Profile (side panel or pushed) | 🔄 Route+placeholder done | Phase 8 |
| P2 | Privacy Policy | 🔜 Planned | Phase 8 |
| P2 | Terms of Service | 🔜 Planned | Phase 8 |

### Phase 5.1 — Mock Data Layer (`--dart-define=USE_MOCK=true`)

| Priority | Task | Status | Notes |
|----------|------|--------|-------|
| P1 | Extract abstract interface for `DataRepository` | 🔜 Planned | Prerequisite for Riverpod `overrideWith` swap |
| P1 | Extract abstract interface for `TodayRepository` | 🔜 Planned | Prerequisite for Riverpod `overrideWith` swap |
| P1 | `MockDataRepository` — rich seed data (all 10 categories, sparklines, charts) | 🔜 Planned | Covers Health Dashboard, Category Detail, Metric Detail |
| P1 | `MockTodayRepository` — seed insights, quick actions, streak, notifications | 🔜 Planned | Covers Today Feed, Insight Detail, Notification History |
| P1 | Wire via Riverpod `overrideWith` in `main.dart` (`USE_MOCK=true`) | 🔜 Planned | `--dart-define=USE_MOCK=true` at build/run time; zero overhead in production |
| P1 | `Makefile` `run-mock` target + `.vscode/launch.json` config | 🔜 Planned | One-click mock launch in VS Code and terminal |

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
| Voice input (on-device STT) | P1 | ✅ Done | `speech_to_text` Flutter package — on-device, free, no API key; hold-to-talk fills input field for user review before sending |
| File attachments in chat | P2 | 📋 Future | UI placeholder exists |
| Apple Sign In | P1 | 🔜 Planned | Pending Apple Developer subscription |
| Profile photo upload | P2 | 📋 Future | |
| Data export | P2 | 📋 Future | |
| Pinecone vector store (AI memory) | P2 | 🔜 Planned | Config env var exists; code not written |
| Dynamic tool injection | P1 | ✅ Done | Only inject MCP tools for integrations the user has connected; prevents context bloat as integration catalog grows; prerequisite for semantic retrieval |
| Semantic tool retrieval | P2 | 🔜 Planned | Embed user message + tool descriptions at request time; inject top-K relevant tools only; scales to unlimited integrations without MCP bloat; requires Pinecone |
| AI-powered morning briefing | P2 | 📋 Future | Daily summary push |
| Smart reminders | P2 | 📋 Future | "You haven't run in 5 days" |
| Bi-directional triggers | P3 | 📋 Future | "If sleep < 30%, reschedule workout" |
| Notion / YNAB / Todoist integration | P3 | 📋 Future | Life OS phase |
