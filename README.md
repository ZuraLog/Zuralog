<p align="center">
  <img src="https://img.shields.io/badge/Status-In%20Development-blueviolet?style=for-the-badge" />
  <img src="https://img.shields.io/badge/Backend-FastAPI-009688?style=for-the-badge&logo=fastapi&logoColor=white" />
  <img src="https://img.shields.io/badge/Mobile-Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" />
  <img src="https://img.shields.io/badge/Website-Next.js-000000?style=for-the-badge&logo=nextdotjs&logoColor=white" />
  <img src="https://img.shields.io/badge/AI-MCP%20Agents-FF6F00?style=for-the-badge" />
  <img src="https://img.shields.io/badge/License-Proprietary-red?style=for-the-badge" />
</p>

# ZuraLog

**Your AI health assistant that connects the apps you already use.**

ZuraLog is a mobile AI agent that turns the fragmented landscape of fitness apps — CalAI, Strava, Fitbit, Oura, Apple Health, Google Health Connect — into a single, intelligent system. It doesn't rebuild features. It **connects** them and adds a brain.

---

## The Problem

The average fitness-conscious person juggles 3–5 apps. Calories in CalAI, runs in Strava, sleep in Oura, steps on their watch. None of these talk to each other. Apple Health and Google Health Connect collect the data, but they're **dumb databases** — they store numbers without intelligence, reasoning, or automation.

**ZuraLog fixes this.**

## What It Does

```
You:    "Why am I not losing weight?"

ZuraLog: "Over the last 4 weeks: CalAI shows avg 2,180 cal/day, but your
         Strava-based maintenance is ~1,950. You're in a 230 cal surplus.
         Your runs dropped from 8 sessions last month to 3 this month.
         Want me to set a daily calorie target?"
```

| Capability | Example |
|---|---|
| **Cross-App Reasoning** | Correlate nutrition + exercise + sleep + weight across all connected apps |
| **Autonomous Actions** | "Start a run" → opens Strava recording. "Log yesterday's 5K" → creates a Strava activity via API |
| **Real-Time Chat** | WebSocket streaming with an opinionated AI coach persona |
| **Zero-Friction Logging** | Take a photo in CalAI → ZuraLog reads it from Apple Health and analyzes it |
| **Push Intelligence** | "I noticed you haven't logged food today. Forgetting something?" |

---

## Architecture

ZuraLog uses a **Hybrid Hub** architecture — a cloud-hosted AI brain paired with native mobile agents.

```
┌─────────────────────────────────────────────────────────┐
│                     CLOUD BRAIN                         │
│                                                         │
│  FastAPI ─── LLM Agent ─── MCP Client (Orchestrator)   │
│     │           │              │                        │
│  PostgreSQL   Pinecone     ┌──┴──────────────────┐     │
│  (Supabase)   (context)    │  MCP Servers         │     │
│                            │  ├─ Strava           │     │
│                            │  ├─ Apple HealthKit  │     │
│                            │  ├─ Health Connect   │     │
│                            │  ├─ Fitbit (planned) │     │
│                            │  └─ Oura (planned)   │     │
│                            └─────────────────────┘     │
└────────────────────┬───────────────────────────────────┘
                     │  REST / WebSocket / FCM Push
┌────────────────────┴───────────────────────────────────┐
│               EDGE AGENT (Flutter)                      │
│                                                         │
│  Dart Layer (~95%): Chat UI, State (Riverpod), Network  │
│  Native Bridge (~5%): HealthKit (Swift), HC (Kotlin)    │
└─────────────────────────────────────────────────────────┘
```

### MCP-First Integrations

Every external service is an **MCP (Model Context Protocol) Server** that the AI agent can call as tools:

| MCP Server | Capabilities | Status |
|---|---|---|
| **Apple HealthKit** | Read/write steps, sleep, weight, nutrition, workouts | ✅ Built |
| **Google Health Connect** | Read/write (Android equivalent) | ✅ Built |
| **Strava** | Read activities, create/update workouts, OAuth flow | ✅ Built |
| **Fitbit** | Read steps, sleep, HR, HRV, SpO2, temperature (12 tools + webhooks) | ✅ Built |
| **CalAI** | Zero-friction deep link integration | ✅ Built |
| **Oura** | Read sleep, readiness, HRV | 🔜 Coming Soon |
| **WHOOP** | Read recovery, strain, sleep | 🔜 Coming Soon |

---

## Tech Stack

### Cloud Brain (Backend)

| Component | Technology |
|---|---|
| Framework | **Python 3.12+ / FastAPI** |
| Database | **PostgreSQL** (Supabase for Auth) |
| ORM | **SQLAlchemy 2.0** (async, Mapped pattern) |
| Migrations | **Alembic** |
| AI Agent | **MCP Client + LLM Orchestrator** |
| Real-Time | **WebSocket** streaming |
| Push | **Firebase Cloud Messaging** |
| Task Queue | Celery + **Redis** |
| Package Manager | **uv** |
| Linting | **Ruff** |
| Testing | **pytest** (309 tests passing) |

### Edge Agent (Mobile)

| Component | Technology |
|---|---|
| Framework | **Flutter 3.32+ / Dart** |
| State | **Riverpod** |
| HTTP | **Dio** (interceptors, auth refresh) |
| WebSocket | **web_socket_channel** |
| Local DB | **Drift** (SQLite, type-safe) |
| Secure Storage | **flutter_secure_storage** |
| Navigation | **GoRouter** (deep link support) |
| Push | **Firebase Messaging** |
| Health Data | **Native platform channels** — Swift (HealthKit) + Kotlin (Health Connect). The `health` package is **not used**. |

### Website (`web/`)

| Component | Technology |
|---|---|
| Framework | **Next.js 16.x** (App Router, TypeScript) |
| Styling | **Tailwind v4** (CSS-first, `@theme inline` tokens) |
| Components | **shadcn/ui** |
| 3D / Animation | **Three.js + React Three Fiber, GSAP, Framer Motion, Lenis** |
| Backend | **Supabase** (shared project with Cloud Brain) |
| Analytics | **PostHog + Vercel Analytics** |
| Deployment | **Vercel** (auto-deploy from `main`, root dir: `web`) |
| Live URL | [https://www.zuralog.com](https://www.zuralog.com) |

---

## Project Structure

```
ZuraLog/
├── cloud-brain/                 # Python backend (Cloud Brain)
│   ├── app/
│   │   ├── api/v1/              # REST + WebSocket endpoints
│   │   │   ├── auth.py          # Login, register, refresh
│   │   │   ├── chat.py          # WebSocket chat + history
│   │   │   ├── strava_routes.py # Strava OAuth + webhooks
│   │   │   └── fitbit_routes.py # Fitbit OAuth + webhooks
│   │   ├── agent/               # AI orchestration layer
│   │   │   ├── orchestrator.py  # LLM agent loop (OpenRouter → kimi-k2.5)
│   │   │   └── mcp_client.py    # MCP tool routing
│   │   ├── mcp_servers/         # Integration modules
│   │   │   ├── strava_server.py
│   │   │   ├── fitbit_server.py
│   │   │   ├── apple_health_server.py
│   │   │   └── health_connect_server.py
│   │   ├── models/              # SQLAlchemy ORM models
│   │   ├── services/            # Auth, push, rate limiting
│   │   └── config.py
│   ├── tests/                   # pytest suite
│   ├── alembic/                 # DB migrations
│   ├── Dockerfile
│   └── docker-compose.yml       # PostgreSQL + Redis
│
├── zuralog/                     # Flutter mobile app (Edge Agent)
│   └── lib/
│       ├── core/
│       │   ├── network/         # API client, WebSocket, FCM
│       │   ├── health/          # Native HealthKit/HC bridge (platform channels)
│       │   ├── storage/         # Drift DB, secure storage
│       │   ├── deeplink/        # App launcher (Strava, CalAI)
│       │   └── di/              # Riverpod providers
│       └── features/
│           ├── chat/            # Chat repository + domain model
│           ├── auth/            # Auth state management
│           ├── integrations/    # Direct + compatible app integrations
│           └── health/          # Health data repository
│
├── website/                     # Next.js marketing website
│   ├── src/
│   │   ├── app/                 # App Router pages + layouts
│   │   ├── components/          # React components (3d/, sections/, ui/)
│   │   ├── hooks/               # Custom React hooks
│   │   └── lib/                 # Supabase client, GSAP, utilities
│   ├── public/                  # Static assets, fonts, favicons
│   └── package.json
│
└── docs/                        # Project documentation (13 files)
    ├── PRD.md                   # Product vision and decisions
    ├── architecture.md          # Technical architecture + ADRs
    ├── infrastructure.md        # Services, costs, env vars
    ├── roadmap.md               # Living checklist with priorities
    ├── implementation-status.md # What was built and how
    ├── design.md                # Brand + design philosophy
    └── integrations/            # Per-integration reference docs
```

---

## Development Progress

### Cloud Brain + Edge Agent

| Phase | Name | Status |
|---|---|---|
| 1.1–1.5 | Foundation, Auth, MCP Base, HealthKit, Health Connect | ✅ Complete |
| 1.6 | Strava Integration | ✅ Complete |
| 1.7 | CalAI Integration | ✅ Complete |
| 1.8 | AI Brain (LLM Orchestrator — OpenRouter → kimi-k2.5) | ✅ Complete |
| 1.9 | Chat & Communication | ✅ Complete |
| 1.10–1.14 | Background Services, Analytics, Autonomous Actions, Billing, Testing | ✅ Complete |
| Direct: Fitbit | OAuth+PKCE, 12 MCP tools, webhooks, per-user rate limiting | ✅ Complete |
| Direct: Oura | Read sleep, readiness, HRV | 🔜 Planned |
| Direct: WHOOP | Read recovery, strain, sleep | 🔜 Planned |

### Website

| Feature | Status |
|---|---|
| Marketing site — live at [zuralog.com](https://www.zuralog.com) | ✅ Complete |
| 3D hero (Three.js + React Three Fiber), GSAP animations, Lenis scroll | ✅ Complete |
| Waitlist with quiz, email confirmation (Resend + Supabase) | ✅ Complete |
| Legal pages (Privacy Policy, Terms of Service) | ✅ Complete |

---

## Getting Started

> **Full setup instructions → [SETUP.md](./SETUP.md)**

### Quick Start

```bash
# Clone
git clone https://github.com/hyowonbernabe/Life-Logger.git
cd Life-Logger

# Backend (Cloud Brain)
cd cloud-brain
cp .env.example .env          # Configure Supabase + API credentials
docker compose up -d           # Start PostgreSQL + Redis
uv sync --all-extras           # Install Python deps
uv run alembic upgrade head    # Run migrations
make dev                       # Start dev server → http://localhost:8001

# Mobile (Edge Agent)
cd ../zuralog
flutter pub get
dart run build_runner build --delete-conflicting-outputs
make run                       # Launch on Android emulator (injects GOOGLE_WEB_CLIENT_ID)

# Website
cd ../website
cp .env.example .env.local    # Configure Supabase + PostHog credentials
npm install
npm run dev                    # Start dev server → http://localhost:3000
```

### Verify

```bash
# Backend health check
curl http://localhost:8001/health
# → {"status": "healthy"}

# Run tests
cd cloud-brain && uv run pytest tests/ -v

# API docs
open http://localhost:8001/docs

# Website
open http://localhost:3000
```

---

## Testing

### Backend (Python/pytest)

```bash
cd cloud-brain

# Run all unit tests
python -m pytest tests/ -v

# Run integration tests only
python -m pytest tests/integration/ -v

# Collect test count without running
python -m pytest tests/ --co -q
```

### Flutter

```bash
cd zuralog

# Run all unit/widget tests
flutter test

# Run integration tests (requires emulator/device)
flutter test integration_test/
```

---

## Exporting OpenAPI Schema

Generate the full OpenAPI 3.1 JSON schema from the running FastAPI app definition:

```bash
cd cloud-brain
python -m scripts.export_openapi
# → Writes openapi.json with endpoint count
```

The exported `openapi.json` can be used for client codegen, documentation hosting, or CI contract testing.

---

## User Scenarios

**"Why am I not losing weight?"** → Cross-references CalAI nutrition, Strava runs, and weight trends to explain the calorie surplus.

**"Start a run for me"** → Deep-links to Strava's recording screen. One tap to go.

**"I forgot to log yesterday"** → "I had a burrito and ran 3 miles" → Logs both to the right apps via API.

**"What should I eat?"** → Checks remaining calorie budget and protein intake, suggests meals based on your patterns.

## Documentation

| Document | Purpose |
|----------|---------|
| [`docs/PRD.md`](./docs/PRD.md) | Product vision, decisions, business model |
| [`docs/architecture.md`](./docs/architecture.md) | Full system architecture, ADRs, data flows |
| [`docs/infrastructure.md`](./docs/infrastructure.md) | All services, costs, environment variables |
| [`docs/roadmap.md`](./docs/roadmap.md) | Living checklist with priorities and statuses |
| [`docs/design.md`](./docs/design.md) | Brand palette, typography, design philosophy |
| [`docs/integrations/`](./docs/integrations/) | Per-integration reference docs |
| [`SETUP.md`](./SETUP.md) | Step-by-step local dev setup |
| [`AGENTS.md`](./AGENTS.md) / [`CLAUDE.md`](./CLAUDE.md) | Agent rules and standards |
| [`DEBUG-FLUTTER.md`](./DEBUG-FLUTTER.md) | ADB screenshot + interaction guide for agents |

---

## Core Philosophy

1. **Connect, don't rebuild.** We don't build a food logger or a run tracker. We connect CalAI, Strava, Fitbit — the best-in-class apps users already love.
2. **AI-first interface.** Chat is the primary interaction model. No complex dashboards to learn.
3. **Zero-friction.** Background sync, deep links, push notifications — the user does minimal manual work.
4. **Privacy by design.** Raw health data stays on-device. The cloud receives only processed summaries for AI reasoning.

---

## AI Agent & Tool Rules

> [!IMPORTANT]
> **Local Artifacts:** AI tools (OpenCode, AntiGravity, Cursor, etc.) must write rules, plans, and temporary artifacts in their **local tool directories within the project**, BUT these directories MUST be added to `.gitignore`. Never push them to the remote GitHub repository.

*   **Plan Persistence:** "If using 'Plan' mode, it is recommended to direct the agent to save the plan to a file in the working directory before initiating code changes to avoid losing the plan due to context compaction."
*   **OpenCode:** Create implementation plans in `.opencode/plans/`. Ensure `.opencode/` is in `.gitignore` so it is not tracked by Git. Do NOT use `docs/plans/` for tool-specific working plans.
*   **AntiGravity:** Continue utilizing your isolated artifact system. Do not leak scratchpads or implementation plans into the tracked project repository files.
*   **Other Tools (Cursor, etc.):** Keep your implementation plans and state tracking in your respective localized tool directories (e.g., `.cursor/`) inside the project, and ensure those directories are gitignored.

---

## License

Copyright © 2026 Hyo Won Bernabe and Fernando Leano. All Rights Reserved.

This is proprietary software. See [LICENSE](./LICENSE.md) for details.
