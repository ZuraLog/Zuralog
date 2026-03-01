# Zuralog — Technical Architecture

**Version:** 2.0  
**Last Updated:** 2026-03-01  
**Status:** Living Document

---

## 1. Architecture Overview: The Hybrid Hub

Zuralog uses a **Hybrid Hub Architecture** combining:
- **Cloud Brain** — Python/FastAPI backend running on Railway. Handles AI orchestration, MCP tool routing, data storage, and background sync.
- **Edge Agent** — Flutter mobile app running on iOS and Android. Handles the UI, native health platform access (HealthKit/Health Connect), and real-time user interaction.

The two communicate via a REST API with JWT-based authentication. The Cloud Brain is the intelligence center; the Edge Agent is the sensor and display layer.

```
┌─────────────────────────────────────────────────────────────────┐
│  EDGE AGENT (Flutter)                                           │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────────────┐    │
│  │  AI Chat UI  │  │  Dashboard   │  │  Integrations Hub  │    │
│  └──────┬───────┘  └──────┬───────┘  └────────┬───────────┘    │
│         │                 │                   │                 │
│  ┌──────┴─────────────────┴───────────────────┴────────────┐    │
│  │  Riverpod State   │   GoRouter   │   Dio HTTP Client    │    │
│  └──────┬────────────────────────────────────┬─────────────┘    │
│         │                                   │                   │
│  ┌──────┴──────────┐              ┌──────────┴─────────────┐    │
│  │  Native Bridges │              │  REST API ──────────── │────┼──→ Cloud Brain
│  │  HealthKit (iOS)│              │  JWT Auth (Supabase)   │    │
│  │  Health Connect │              └────────────────────────┘    │
│  │  (Android)      │                                            │
│  └─────────────────┘                                            │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  CLOUD BRAIN (FastAPI)                                          │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Agent Layer: Orchestrator → LLM (Kimi K2.5/OpenRouter)  │   │
│  │               └── MCP Client → MCP Server Registry       │   │
│  └──────────────────────────────────────────────────────────┘   │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌────────┐  │
│  │  Strava  │  │  Fitbit  │  │  Oura   │  │  Apple   │  │  Deep  │  │
│  │  MCP     │  │  MCP     │  │  MCP    │  │  Health  │  │  Link  │  │
│  │  Server  │  │  Server  │  │  Server │  │  MCP     │  │ Server │  │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘  └────────┘  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Services: Auth │ Cache │ Push │ Sync │ Rate Limiters    │   │
│  └──────────────────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Supabase (Postgres + Auth)  │  Upstash Redis            │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. Cloud Brain (FastAPI Backend)

**Location:** `cloud-brain/`  
**Runtime:** Python 3.12+, `uv` package manager  
**Framework:** FastAPI 0.115+ with async SQLAlchemy

### 2.1 Application Structure

```
cloud-brain/
├── app/
│   ├── main.py              # FastAPI app, lifespan, router mounting
│   ├── config.py            # Pydantic BaseSettings (all env vars)
│   ├── database.py          # Async SQLAlchemy session factory
│   ├── worker.py            # Celery app + beat schedule
│   │
│   ├── agent/               # AI orchestration layer
│   │   ├── orchestrator.py  # Main agent loop + MCP tool dispatch
│   │   ├── llm_client.py    # OpenRouter API client (Kimi K2.5)
│   │   ├── mcp_client.py    # MCP protocol client
│   │   ├── response.py      # Response streaming
│   │   └── prompts/         # System prompt templates
│   │
│   ├── mcp_servers/         # MCP tool implementations
│   │   ├── base_server.py          # Abstract BaseMCPServer
│   │   ├── health_data_server_base.py  # Health-specific base (~550 lines)
│   │   ├── strava_server.py        # Strava MCP tools
│   │   ├── fitbit_server.py        # Fitbit MCP tools (12 tools)
│   │   ├── oura_server.py          # Oura MCP tools (16 tools)
│   │   ├── apple_health_server.py  # HealthKit data ingest tools
│   │   ├── health_connect_server.py # Health Connect ingest tools
│   │   ├── deep_link_server.py     # App launch via URI schemes
│   │   ├── deep_link_registry.py   # URI scheme mapping library
│   │   └── registry.py             # MCP server registry
│   │
│   ├── api/v1/              # REST API routes
│   │   ├── auth.py          # Supabase auth integration
│   │   ├── chat.py          # Chat endpoint (SSE streaming)
│   │   ├── health_ingest.py # Push health data from Edge Agent
│   │   ├── integrations.py  # OAuth orchestration (all providers)
│   │   ├── strava_webhooks.py   # Strava webhook handler
│   │   ├── fitbit_routes.py     # Fitbit OAuth + status endpoints
│   │   ├── fitbit_webhooks.py   # Fitbit webhook handler
│   │   ├── oura_routes.py       # Oura OAuth + status endpoints
│   │   ├── oura_webhooks.py     # Oura webhook handler (per-app subscription, 90-day renewal)
│   │   ├── analytics.py     # Correlation engine endpoints
│   │   ├── users.py         # User profile management
│   │   ├── devices.py       # Device registration (FCM tokens)
│   │   ├── transcribe.py    # Voice input (Whisper)
│   │   └── dev.py           # Dev-only debug endpoints
│   │
│   ├── services/            # Business logic
│   │   ├── auth_service.py          # JWT validation, user creation
│   │   ├── cache_service.py         # Upstash Redis cache layer
│   │   ├── push_service.py          # FCM push notifications
│   │   ├── subscription_service.py  # RevenueCat webhook + entitlements
│   │   ├── sync_scheduler.py        # Celery sync orchestration
│   │   ├── strava_token_service.py  # Strava OAuth token management
│   │   ├── strava_rate_limiter.py   # App-level sliding window limiter
│   │   ├── fitbit_token_service.py  # Fitbit OAuth + PKCE token management
│   │   ├── fitbit_rate_limiter.py   # Per-user token bucket limiter
│   │   ├── oura_token_service.py    # Oura OAuth token management + sandbox mode
│   │   ├── oura_rate_limiter.py     # App-level sliding-window limiter (5,000/hr)
│   │   ├── rate_limiter.py          # Generic rate limiting primitives
│   │   ├── device_write_service.py  # Write commands to Edge Agent devices
│   │   ├── user_service.py          # User data helpers
│   │   └── usage_tracker.py         # API usage tracking per user tier
│   │
│   ├── models/              # SQLAlchemy ORM models
│   │   ├── user.py          # User (Supabase-linked)
│   │   ├── conversation.py  # Chat conversation + messages
│   │   ├── health_data.py   # UnifiedActivity, SleepRecord, HealthMetric
│   │   ├── integration.py   # OAuth integration per provider
│   │   ├── daily_metrics.py # Aggregated daily health summaries
│   │   ├── user_goal.py     # User fitness goals
│   │   ├── user_device.py   # FCM device tokens
│   │   └── usage_log.py     # API usage logs for billing
│   │
│   ├── analytics/           # AI reasoning engine
│   │   └── (correlation, trend detection, insight generation)
│   │
│   ├── middleware/          # Request middleware
│   └── tasks/               # Celery task definitions
│
├── alembic/                 # Database migrations
├── tests/                   # pytest test suite (61 files)
├── Dockerfile               # Production container
├── docker-compose.yml       # Local dev (Postgres + Redis)
├── pyproject.toml           # Dependencies + tool config
└── Makefile                 # Dev commands
```

### 2.2 Agent Layer: How the AI Works

The agent follows a **Reason → Tool → Act** loop:

1. User sends a message to `POST /api/v1/chat`
2. **Orchestrator** builds context (conversation history, user's connected integrations, active goals)
3. **LLM Client** calls Kimi K2.5 via OpenRouter with the constructed prompt
4. Kimi reasons and selects MCP tools to call (e.g., `strava_get_activities`, `fitbit_get_sleep`)
5. **MCP Client** routes tool calls to the correct MCP Server in the registry
6. Results are fed back to Kimi for final synthesis and response
7. Response is streamed back via SSE

### 2.3 MCP Architecture

All external integrations are implemented as **MCP Servers** that expose a standardized tool interface to the LLM. Adding a new integration means:
1. Subclass `HealthDataServerBase` (~70 new lines)
2. Register with the `MCPServerRegistry`
3. The LLM can immediately use it without orchestrator changes

**Currently registered MCP servers:**

| Server | Tools | Status |
|--------|-------|--------|
| `StravaServer` | `strava_get_activities`, `strava_create_activity`, `strava_get_athlete_stats` | ✅ Production |
| `FitbitServer` | 12 tools (activity, HR, HRV, sleep, SpO2, breathing, temp, VO2, weight, nutrition, intraday) | ✅ Production |
| `OuraServer` | 16 tools covering sleep, readiness, activity, heart rate, SpO2, stress, resilience, cardiovascular age, VO2 max, workouts, sessions, tags, rest mode, sleep time, and ring configuration | ✅ Production |
| `AppleHealthServer` | Read/write HealthKit data via ingest endpoint | ✅ Production |
| `HealthConnectServer` | Read/write Health Connect data via ingest endpoint | ✅ Production |
| `DeepLinkServer` | Launch third-party apps via URI schemes | ✅ Production |

---

## 3. Edge Agent (Flutter Mobile App)

**Location:** `zuralog/`  
**Framework:** Flutter 3+ / Dart  
**State Management:** Riverpod + code generation  
**Navigation:** GoRouter

### 3.1 Application Structure

```
zuralog/lib/
├── main.dart           # App entry, Riverpod + Sentry init
├── app.dart            # GoRouter + theme configuration
│
├── core/               # Platform-wide infrastructure
│   ├── di/             # Dependency injection (providers.dart)
│   ├── network/        # ApiClient (Dio + auth interceptor)
│   ├── storage/        # Drift DB, SecureStorage, SharedPreferences
│   ├── router/         # GoRouter config + route guards
│   ├── deeplink/       # App link interception (app_links)
│   ├── health/         # HealthRepository (HealthKit + Health Connect)
│   ├── theme/          # AppTheme, AppColors, AppTextStyles
│   ├── monitoring/     # Sentry integration
│   └── state/          # Global app state
│
├── features/           # Feature modules
│   ├── auth/           # Login, signup, onboarding, OAuth callback
│   ├── chat/           # AI chat UI, input bar, streaming messages
│   ├── dashboard/      # Health summary cards, insight widgets
│   ├── integrations/   # Integrations Hub, OAuth flows
│   ├── settings/       # Profile, preferences, data export
│   ├── subscription/   # RevenueCat paywall, subscription status
│   ├── analytics/      # Correlation charts, trend views
│   ├── health/         # Native health data sync service
│   ├── catalog/        # App deep link catalog
│   └── harness/        # Development test harness
│
└── shared/             # Shared widgets + utilities
```

### 3.2 Native Health Integration

**iOS — HealthKit (Swift via Platform Channel):**
- `HKHealthStore` for reading/writing health data
- `HKObserverQuery` for background change detection — triggers automatically when other apps (CalAI, MyFitnessPal) write new data
- `HKAnchoredObjectQuery` for incremental sync
- JWT + API URL persisted to iOS Keychain so native Swift code can sync in the background without the Flutter engine running

**Android — Health Connect (Kotlin via Platform Channel):**
- Android Health Connect API for reading/writing health records
- `WorkManager` periodic task for background sync
- JWT persisted to EncryptedSharedPreferences for background authentication
- Handles the Health Connect app availability check before requesting permissions

**Background Sync Flow:**
```
Other App (CalAI, Strava) writes data
  ↓
OS Health Store (HealthKit / Health Connect)
  ↓
Native Observer fires (HKObserverQuery / WorkManager)
  ↓
Native bridge reads new records
  ↓
POST /api/v1/health/ingest (with JWT)
  ↓
Cloud Brain processes and stores data
  ↓
FCM push notification to user (optional insight)
```

### 3.3 Deep Link Architecture

Zuralog uses the `zuralog://` URI scheme for two purposes:
1. **OAuth callbacks** — `zuralog://oauth/strava`, `zuralog://oauth/fitbit`, `zuralog://oauth/oura`
2. **External app launching** — `strava://`, `calai://`, etc. (Deep Link Registry)

The `DeepLinkHandler` intercepts incoming links and routes them to the correct feature handler.

---

## 4. Website

**Location:** `website/`  
**Framework:** Next.js 16 (App Router) + TypeScript  
**Styling:** Tailwind CSS v4

### 4.1 Stack

| Layer | Technology |
|-------|-----------|
| Framework | Next.js 16 with React 19 |
| Styling | Tailwind CSS v4 |
| 3D / Animation | Three.js + React Three Fiber + GSAP + Framer Motion |
| Smooth Scroll | Lenis |
| Database | Supabase (waitlist) |
| Auth | Supabase SSR |
| Email | Resend (transactional) |
| Analytics | Vercel Analytics |
| Error Tracking | Sentry (Next.js) |
| Rate Limiting | Upstash Ratelimit |
| Deployment | Vercel |

### 4.2 Pages & Routes

| Route | Purpose |
|-------|---------|
| `/` | Landing page (hero, 3D phone mockup, waitlist CTA) |
| `/about` | Company / mission page |
| `/support` | Customer support |
| `/contact` | Contact form |
| `/privacy-policy` | GDPR / CCPA privacy policy |
| `/terms-of-service` | ToS |
| `/cookie-policy` | Cookie policy |
| `/community-guidelines` | Community guidelines |
| `/api/waitlist` | Waitlist signup endpoint |
| `/api/quiz` | Onboarding quiz handler |

### 4.3 Key Components

- **3D Phone Mockup** — Three.js + React Three Fiber, shows the app UI on a rotating phone model
- **Waitlist System** — Supabase-backed signup with animated counter, leaderboard, and confetti
- **Quiz Flow** — Multi-step onboarding quiz to personalize the waitlist experience
- **Stats Bar** — Live waitlist statistics
- **OpenGraph Image** — Server-rendered OG image for social sharing

---

## 5. Key Data Flows

### 5.1 Cloud-to-Device Write
When the AI decides to write data (e.g., log a workout):
```
LLM selects tool → HealthConnectServer/AppleHealthServer
  ↓
POST /api/v1/devices/{device_id}/write (with payload)
  ↓
FCM push to device with write command
  ↓
Edge Agent receives push, performs native health write
  ↓
Background observer fires, new data synced back up
```

### 5.2 Cross-App Reasoning
```
User: "Why am I not losing weight?"
  ↓
Orchestrator builds context: user has Strava + Fitbit + Apple Health
  ↓
LLM calls: fitbit_get_daily_activity (7 days), strava_get_activities (30 days)
  ↓
LLM synthesizes: calorie surplus + reduced run frequency
  ↓
Returns insight with specific numbers, suggests action
```

### 5.3 Real-Time Webhook Sync
```
User records Strava activity
  ↓
Strava fires webhook → POST /api/v1/webhooks/strava
  ↓
Celery task: sync_strava_activity_task
  ↓
Data stored in UnifiedActivity table
  ↓
FCM push: "Great run! 5.2K in 28 min. You've hit your weekly goal."
```

---

## 6. Technology Decisions (ADRs)

### ADR 002: Flutter vs. React Native vs. KMP

**Decision:** Flutter

| Option | Reason Rejected |
|--------|----------------|
| React Native | Lower native performance; Bridge overhead for health APIs; `react-native-health` is unreliable |
| Kotlin Multiplatform | Immature UI layer; no production-proven health integration story |
| **Flutter** ✅ | Single codebase for iOS + Android; Dart platform channels for HealthKit/Health Connect; Riverpod for state; strong community |

### ADR 003: Hybrid Dev Environment

**Decision:** Python code runs natively; services (Postgres, Redis) run in Docker Compose.

Rationale: Full Docker creates 10–50× file I/O overhead on Windows (WSL2 mount penalty) and makes hot-reload painful. The hybrid approach gives the clean isolation of containers for stateful services while preserving fast iteration for application code.

### ADR 004: Asset Strategy (Multi-Platform Monorepo)

**Decision:** Root-level source of truth at `assets/brand/`, with intentional copies to platform-specific directories.

- `assets/brand/` — Single source of truth for all brand assets (logo, icons, fonts)
- `zuralog/assets/` — Flutter **copy** (required — Flutter cannot reference files outside the project directory, a hard constraint of the Dart toolchain)
- `website/public/` — Next.js copy for static serving
- Run `scripts/sync-assets.sh` after any change to `assets/brand/`

**Never modify only the platform copy.** Always update `assets/brand/` first.

### ADR 005: Supabase for Auth

**Decision:** Use Supabase Auth + JWT for user identity across Cloud Brain and Edge Agent.

- Supabase handles registration, login, OAuth social providers
- JWT tokens validated server-side in `auth_service.py`
- Row Level Security (RLS) in Postgres enforces data isolation per user
- Supabase token refreshed client-side by Flutter

---

## 7. Security Model

- **Auth:** Supabase JWT on all protected endpoints; `deps.py` extracts and validates user identity
- **RLS:** Postgres Row Level Security ensures users can only access their own data
- **Token storage:** OAuth tokens for integrations stored server-side in the `integrations` table (never on device)
- **Device credentials:** JWT + API URL stored in iOS Keychain (native) and Android EncryptedSharedPreferences
- **Secrets:** All API keys in environment variables; never committed to source control
- **Rate limiting:** Per-endpoint limits via SlowAPI (Stubs in `limiter.py`); per-user token buckets for integration APIs
- **CORS:** `allowed_origins` env var (locked down in production)
- **HTTPS:** All production traffic via Cloudflare → Railway with TLS termination
