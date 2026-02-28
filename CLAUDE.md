# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Zuralog is a health AI assistant with a **monorepo structure**:
- `zuralog/` — Flutter mobile app (Edge Agent)
- `cloud-brain/` — Python FastAPI backend (Cloud Brain)
- `website/` — Next.js marketing website

**PRD:** [docs/PRD.md](./docs/PRD.md)

## Documentation

All project documentation lives in `docs/`. Read the relevant doc before starting any task.

| Document | Purpose |
|----------|---------|
| [`docs/PRD.md`](./docs/PRD.md) | Product vision, user scenarios, AI decisions, business model |
| [`docs/architecture.md`](./docs/architecture.md) | Technical architecture, all ADRs, data flows, security model |
| [`docs/infrastructure.md`](./docs/infrastructure.md) | All services, deployment, costs, environment variables |
| [`docs/roadmap.md`](./docs/roadmap.md) | Living checklist — update status as work completes |
| [`docs/implementation-status.md`](./docs/implementation-status.md) | Historical record of what was built and how |
| [`docs/design.md`](./docs/design.md) | Brand colors, typography, design philosophy (exploration-first) |
| [`docs/integrations/`](./docs/integrations/) | Per-integration reference (Strava, Fitbit, Apple Health, Health Connect, planned) |

## Commands

### Backend (`cloud-brain/`)

```bash
# Setup
docker compose up -d                      # Start Postgres + Redis
uv sync --all-extras                      # Install deps into .venv

# Development
uv run uvicorn app.main:app --reload --host 0.0.0.0 --port 8001
# OR: make dev

# Testing
uv run pytest tests/ -v                   # Run all tests
uv run pytest tests/path/to/test.py -v   # Run single test file
# OR: make test

# Linting & Formatting
uv run ruff check app/ tests/             # Lint
uv run ruff format app/ tests/            # Format
# OR: make lint / make format

# Database
uv run alembic upgrade head               # Apply migrations
uv run alembic revision --autogenerate -m "description"  # New migration
# OR: make migrate / make migration
```

### Flutter (`zuralog/`)

```bash
flutter pub get                           # Install dependencies
dart run build_runner build --delete-conflicting-outputs  # Codegen (Drift, Riverpod)
flutter analyze                           # Lint (must report "No issues found")
make run                                  # Launch on Android emulator (injects env vars)
make run-ios                              # iOS Simulator
flutter test                              # Run tests
flutter test test/path/to/test.dart       # Run single test
```

> **Never use bare `flutter run`** — always use `make run` / `make run-ios`. The Makefile injects `GOOGLE_WEB_CLIENT_ID` and `SENTRY_DSN` from `cloud-brain/.env`. Without them, Google Sign-In silently fails.

### Website (`website/`)

```bash
cd website
npm install
npm run dev      # http://localhost:3000
npm run lint
npm run build    # verify production build
```

## Architecture

### High-Level: Hybrid Hub

```
CLOUD BRAIN (Python FastAPI + LLM + MCP Client)
        │ REST / WebSocket / FCM
EDGE AGENT (Flutter + Platform Channels)
        │ Platform Channels
NATIVE BRIDGES (Swift HealthKit / Kotlin Health Connect)
```

Health data flows **from device to Cloud Brain** via `POST /api/v1/health/ingest`. The Cloud Brain orchestrates LLM tool calls via MCP servers and delivers results to the device via FCM push notifications or WebSocket.

### MCP Pattern (Critical to Understand)

Every integration implements an MCP server in `cloud-brain/app/mcp_servers/`. Each server exposes:
- `name`, `description` — for LLM context
- `get_tools()` — tool schemas the LLM can call
- `execute_tool(name, params)` — runs a named tool
- `get_resources()` — provides context data
- `health_check()` — connectivity check

The `orchestrator.py` runs the LLM agent loop, calling `mcp_client.py` to route tool calls to the correct MCP server based on the registry.

### Flutter Feature Structure

Each feature under `lib/features/` follows a three-layer pattern:
- `data/` — repositories, models, API clients
- `domain/` — business logic, services
- `presentation/` — widgets, controllers, Riverpod state

State management: **Riverpod** (with Riverpod Generator for codegen). Navigation: **GoRouter**. HTTP: **Dio** (with 401 refresh interceptors). Local storage: **Drift** (SQLite) + **flutter_secure_storage**.

### Platform Channels (iOS/Android Health Bridges)

> ⚠️ The `health` Flutter package is **NOT used**. Health data is accessed via custom Swift (iOS) and Kotlin (Android) native platform channels.

- **iOS:** Swift `HKHealthStore` + `HKObserverQuery` — fires when any third-party app writes to HealthKit (background, even when Flutter engine is not running). JWT stored in iOS Keychain.
- **Android:** Kotlin Health Connect SDK + WorkManager — periodic sync and data change notifications. JWT stored in EncryptedSharedPreferences.

## Rules

### 1. Git Discipline
- Create a new branch (e.g., `feat/task-name`) before executing any plan. **Never work on `main`.**
- Commit and push at every logical checkpoint. Do not wait for perfection.
- Merge only when the entire phase is complete with zero errors/warnings. **Squash merge** to keep `main` history clean.

### 2. Context Awareness
Before starting work, read the relevant docs in `docs/` for context — `architecture.md` for backend tasks, `design.md` for UI tasks, the relevant file in `docs/integrations/` for integration work. Do not assume — verify against the actual codebase.

### 3. Post-Execution Documentation
After completing a significant phase or feature:
- Update the relevant status column in [`docs/roadmap.md`](./docs/roadmap.md)
- Add a brief summary to [`docs/implementation-status.md`](./docs/implementation-status.md) if the work is substantial
- Do not create one-off plan files or task-specific markdown files in `docs/`

### 4. Final Review Only
Do not perform visual QA or detailed review after every sub-task. Perform a single comprehensive review (including Playwright/ADB screenshots for UI work) at the end of the last task in a sequence.

### 5. Cleanup Before Push
At final review, delete all temporary artifacts (screenshots, scratch files, test outputs) from the working tree. Nothing generated during the session should be pushed to the remote repository.

### 6. AI Working Directories
Each tool writes plans to its own **gitignored** directory. Never use another tool's directory.
- OpenCode → `.opencode/plans/` | Cursor → `.cursor/` | Claude → `.claude/` | AntiGravity → its artifact directory

### 7. Design System Tokens (Flutter)
Use the **Frontend Design skill** for all UI/UX decisions — aim for bold, premium designs. No hardcoded hex in widget files.
- **Brand color:** Sage Green `#CFE1B9` (`AppColors.primary`)
- Design philosophy is **exploration-first** — always seek the best UI/UX, see [`docs/design.md`](./docs/design.md)

| Token | Dark (primary theme) |
|-------|---------------------|
| `scaffoldBackgroundColor` | `#000000` (OLED) |
| `colorScheme.surface` | `#1C1C1E` |

- Typography: `AppTextStyles` only — no ad-hoc `TextStyle(...)`.
- Primary actions: pill `FilledButton` with `AppColors.primary` (Sage Green).
- Cards: `borderRadius: 24`, 1px border (dark theme).

### 8. Code Quality
- **Zero Warnings:** `flutter analyze` must report "No issues found" before any commit.
- **No `dynamic`:** Always use concrete types in Dart.
- **Const constructors:** Required on all immutable Flutter widgets.
- **Public APIs:** Every public Dart/Python function must have a docstring explaining *why*, not just what.

### 9. Security First
- Never expose API keys. Implement strict rate limits. Proactively prevent abuse.
- OAuth tokens stored server-side only. Device credentials in iOS Keychain / Android EncryptedSharedPreferences.

### 10. Scalability & Longevity
- Think about scale from day one. We are building a production-grade system that lasts, not a demo or MVP.

## Key Files

| File | Purpose |
|------|---------|
| `cloud-brain/app/main.py` | FastAPI app entry + lifespan |
| `cloud-brain/app/agent/orchestrator.py` | LLM agent loop (uses OpenRouter → `moonshotai/kimi-k2.5`) |
| `cloud-brain/app/mcp_servers/registry.py` | MCP server registry |
| `cloud-brain/app/api/v1/chat.py` | Chat + WebSocket streaming endpoint |
| `zuralog/lib/main.dart` | Flutter entry point |
| `zuralog/lib/core/di/providers.dart` | Global Riverpod DI providers |
| `zuralog/lib/core/network/api_client.dart` | Dio HTTP client with auth interceptors |
| `zuralog/lib/core/health/health_bridge.dart` | Unified platform channel API |
| `AGENTS.md` | Full agent rules and documentation index |
| `SETUP.md` | Step-by-step local dev setup |
| `DEBUG-FLUTTER.md` | ADB screenshot + interaction guide for agents |

## Environment Setup

Backend `.env` (copy from `cloud-brain/.env.example`):
- **Required:** `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_KEY`, `OPENROUTER_API_KEY`, `GOOGLE_WEB_CLIENT_ID`, `GOOGLE_WEB_CLIENT_SECRET`
- **Optional:** `OPENAI_API_KEY` (embeddings), `PINECONE_API_KEY` (vector memory — not yet wired)
- **Pre-filled:** `SENTRY_DSN`, `DATABASE_URL`, `REDIS_URL`

Verify backend: `curl http://localhost:8001/health` → `{"status": "healthy"}`
