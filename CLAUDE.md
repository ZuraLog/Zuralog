# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Zuralog is a health AI assistant with a **monorepo structure**:
- `zuralog/` — Flutter mobile app (Edge Agent)
- `cloud-brain/` — Python FastAPI backend (Cloud Brain)

## Commands

### Backend (`cloud-brain/`)

```bash
# Setup
docker compose up -d                      # Start Postgres + Redis
uv sync --all-extras                      # Install deps into .venv

# Development
uv run uvicorn app.main:app --reload      # Start server (port 8000)
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

### Frontend (`zuralog/`)

```bash
flutter pub get                           # Install dependencies
dart run build_runner build --delete-conflicting-outputs  # Codegen (Drift, Riverpod)
flutter analyze                           # Lint (must report "No issues found")
flutter run                               # Launch on emulator
flutter run --dart-define=BASE_URL=http://localhost:8000  # iOS Simulator
flutter test                              # Run tests
flutter test test/path/to/test.dart       # Run single test
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

Health data **never persists on Cloud Brain** — it stays on-device. The Cloud Brain orchestrates LLM tool calls via MCP servers, generates write payloads, and delivers them to the device via FCM push notifications.

### MCP Pattern (Critical to Understand)

Every integration (Apple Health, Health Connect, Strava, etc.) implements a MCP server in `cloud-brain/app/mcp_servers/`. Each server must expose:
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

State management is exclusively **Riverpod** (with Riverpod Generator for codegen). Navigation uses **GoRouter**. HTTP uses **Dio** (with auth token refresh interceptors on 401). Local storage uses **Drift** (SQLite) for chat history/offline cache and **flutter_secure_storage** for tokens.

### Platform Channels (iOS/Android Health Bridges)

The `health` Flutter package handles standard reads/writes. Custom Swift (`ios/`) and Kotlin (`android/`) platform channels are used for background observation (HKObserverQuery / WorkManager) — these fire when third-party apps write health data, allowing Cloud Brain to generate follow-up questions.

## Engineering Standards (from AGENTS.md)

- **Git**: Never commit directly to `master`. Use feature branches (e.g., `feat/phase-X.Y`).
- **Zero Warnings**: `flutter analyze` must report "No issues found" before any commit.
- **No `dynamic`**: Always use concrete types in Dart. No `dynamic` keyword.
- **Const constructors**: Required on all immutable Flutter widgets.
- **Phase docs**: After completing a phase, create `docs/agent-executed/executed-phase-[X.Y.Z].[name].md`.
- **Public APIs**: Every public Dart/Python function must have a docstring explaining *why*, not just what.

## Key Files

| File | Purpose |
|------|---------|
| `cloud-brain/app/main.py` | FastAPI app entry + lifespan |
| `cloud-brain/app/agent/orchestrator.py` | LLM agent loop |
| `cloud-brain/app/mcp_servers/registry.py` | MCP server registry |
| `cloud-brain/app/api/v1/chat.py` | Chat + WebSocket streaming endpoint |
| `zuralog/lib/main.dart` | Flutter entry point |
| `zuralog/lib/core/di/providers.dart` | Global Riverpod DI providers |
| `zuralog/lib/core/network/api_client.dart` | Dio HTTP client with auth interceptors |
| `zuralog/lib/core/health/health_bridge.dart` | Unified platform channel API |
| `docs/plans/architecture-design.md` | Full architecture specification |
| `AGENTS.md` | AI agent role definitions and standards |
| `SETUP.md` | Step-by-step local dev setup |

## Environment Setup

Backend `.env` (copy from `cloud-brain/.env.example`): requires `DATABASE_URL`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_KEY`. Pinecone and OpenAI keys needed for full LLM features.

Verify backend is running: `curl http://localhost:8000/health` → `{"status": "healthy"}`

Verify frontend: The test harness screen (dev only) has buttons for Health Check, Secure Storage, and Local DB.

## Completed Phases

Phases 1.1–1.5 are complete (Foundation, Auth, MCP Base, HealthKit, Health Connect). See `docs/agent-executed/` for summaries of what was built.
