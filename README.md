<p align="center">
  <img src="https://img.shields.io/badge/Status-In%20Development-blueviolet?style=for-the-badge" />
  <img src="https://img.shields.io/badge/Backend-FastAPI-009688?style=for-the-badge&logo=fastapi&logoColor=white" />
  <img src="https://img.shields.io/badge/Mobile-Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" />
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
| **CalAI** | Zero-friction deep link integration | ✅ Built |
| **Fitbit** | Read steps, sleep, HR, weight, HRV | 📋 Planned |
| **Oura** | Read sleep, readiness, HRV | 📋 Planned |

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
| Testing | **pytest** (93 tests passing) |

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
| Health Data | **health** package (HealthKit + Health Connect) |

---

## Project Structure

```
ZuraLog/
├── cloud-brain/                 # Python backend
│   ├── app/
│   │   ├── api/v1/              # REST + WebSocket endpoints
│   │   │   ├── auth.py          # Login, register, refresh
│   │   │   ├── chat.py          # WebSocket chat + history
│   │   │   └── integrations.py  # OAuth flows (Strava, etc.)
│   │   ├── agent/               # AI orchestration layer
│   │   │   ├── orchestrator.py  # LLM agent loop
│   │   │   └── mcp_client.py   # MCP tool routing
│   │   ├── mcp_servers/         # Integration modules
│   │   │   ├── base_server.py
│   │   │   ├── strava_server.py
│   │   │   ├── apple_health_server.py
│   │   │   └── health_connect_server.py
│   │   ├── models/              # SQLAlchemy ORM models
│   │   ├── services/            # Auth, push notifications
│   │   └── config.py
│   ├── tests/                   # pytest suite
│   ├── alembic/                 # DB migrations
│   ├── Dockerfile
│   └── docker-compose.yml       # PostgreSQL + Redis
│
├── life_logger/                 # Flutter mobile app
│   └── lib/
│       ├── core/
│       │   ├── network/         # API client, WebSocket, FCM
│       │   ├── health/          # HealthKit/HC bridge
│       │   ├── storage/         # Drift DB, secure storage
│       │   ├── deeplink/        # App launcher (Strava, CalAI)
│       │   └── di/              # Riverpod providers
│       └── features/
│           ├── chat/            # Chat repository + domain model
│           ├── auth/            # Auth state management
│           ├── harness/         # Dev test harness
│           └── health/          # Health data repository
│
└── docs/                        # Architecture, PRD, phase plans
    ├── plans/
    │   ├── product-requirements-document.md
    │   ├── architecture-design.md
    │   └── backend/phases/      # 14 phase plans (1.1 → 1.14)
    └── agent-executed/          # Completed phase docs
```

---

## Development Progress

Phase-based execution plan with 14 phases for MVP:

| Phase | Name | Status |
|---|---|---|
| 1.1 | Foundation & Infrastructure | ✅ Complete |
| 1.2 | Authentication & User Management | ✅ Complete |
| 1.3 | MCP Base Framework | ✅ Complete |
| 1.4 | Apple HealthKit Integration | ✅ Complete |
| 1.5 | Google Health Connect Integration | ✅ Complete |
| 1.6 | Strava Integration | ✅ Complete |
| 1.7 | CalAI Integration | ✅ Complete |
| 1.8 | AI Brain (LLM Orchestrator) | 🔲 Planned |
| 1.9 | Chat & Communication | ✅ Complete |
| 1.10 | Background Services | 🔲 Planned |
| 1.11 | Analytics & Reasoning | 🔲 Planned |
| 1.12 | Autonomous Actions | 🔲 Planned |
| 1.13 | Subscription & Billing | 🔲 Planned |
| 1.14 | End-to-End Testing | 🔲 Planned |

---

## Getting Started

> **Full setup instructions → [SETUP.md](./SETUP.md)**

### Quick Start

```bash
# Clone
git clone https://github.com/hyowonbernabe/Life-Logger.git
cd Life-Logger

# Backend
cd cloud-brain
cp .env.example .env          # Configure Supabase credentials
docker compose up -d           # Start PostgreSQL + Redis
uv sync --all-extras           # Install Python deps
uv run alembic upgrade head    # Run migrations
make dev                       # Start dev server → http://localhost:8000

# Mobile
cd ../life_logger
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run                    # Launch on emulator/device
```

### Verify

```bash
# Backend health check
curl http://localhost:8000/health
# → {"status": "healthy"}

# Run tests (93 passing)
cd cloud-brain && uv run pytest tests/ -v

# API docs
open http://localhost:8000/docs
```

---

## User Scenarios

**"Why am I not losing weight?"** → Cross-references CalAI nutrition, Strava runs, and weight trends to explain the calorie surplus.

**"Start a run for me"** → Deep-links to Strava's recording screen. One tap to go.

**"I forgot to log yesterday"** → "I had a burrito and ran 3 miles" → Logs both to the right apps via API.

**"What should I eat?"** → Checks remaining calorie budget and protein intake, suggests meals based on your patterns.

---

## Core Philosophy

1. **Connect, don't rebuild.** We don't build a food logger or a run tracker. We connect CalAI, Strava, Fitbit — the best-in-class apps users already love.
2. **AI-first interface.** Chat is the primary interaction model. No complex dashboards to learn.
3. **Zero-friction.** Background sync, deep links, push notifications — the user does minimal manual work.
4. **Privacy by design.** Raw health data stays on-device. The cloud receives only processed summaries for AI reasoning.

---

## AI Agent & Tool Rules

> [!IMPORTANT]
> **Local Artifacts:** AI tools (OpenCode, AntiGravity, Cursor, etc.) must write rules, plans, and temporary artifacts in their **local tool directories**, NOT in the project repository.

*   **OpenCode:** Do not create implementation plans in `docs/plans/`. If you do, you will encounter a `no-write-permission` error and be forced to rewrite the plan in `.opencode/plans/`, wasting 2x the tokens. Always write plans directly to your local `.opencode/plans/` directory.
*   **AntiGravity:** Continue utilizing your isolated artifact system. Do not write plans or temporary guidelines into the project repository.
*   **Other Tools (Cursor, etc.):** Do not place any implementation plans or temporary context files in `docs/plans/` or the project repository. Keep them in your respective localized tool directories to prevent repository clutter.

---

## License

Copyright © 2026 Hyo Won Bernabe and Fernando Leano. All Rights Reserved.

This is proprietary software. See [LICENSE](./LICENSE) for details.
