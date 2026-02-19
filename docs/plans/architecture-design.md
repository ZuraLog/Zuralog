# Life Logger — Architecture Design Document

**Version:** 2.1
**Date:** February 18, 2026
**Status:** Draft — Under Revision

---

## 1. Design Decision: Cross-Platform Framework

### Decision: Flutter (Dart) with Platform Channels

### Options Evaluated

**Option A — React Native (Expo):** JS/TS UI with native modules. Largest ecosystem, best web-skill transfer. **Rejected** because the JS bridge introduces unreliability in background task execution — the Edge Agent's most critical function. `react-native-background-fetch` is fragile on iOS, and HealthKit observer queries need to fire reliably when the app is suspended.

**Option B — Flutter (Selected):** Dart UI with platform channels into native Swift/Kotlin for OS-level APIs. ~90-95% code sharing. Impeller rendering engine delivers smoother chat UI performance. The `health` package provides a single unified API across HealthKit and Health Connect, reducing platform-specific code.

**Option C — Kotlin Multiplatform + Native UI:** Shared Kotlin business logic with SwiftUI + Jetpack Compose UIs. Best raw native API access. **Rejected** because it requires two separate UI codebases, adding 40-60% more UI work. Incompatible with a 3-4 month MVP timeline for both platforms.

### Deciding Factor

The Edge Agent is the product's moat — not the UI. The app must sit in the background, observe health store writes from third-party apps, receive push payloads from the Cloud Brain, and write to HealthKit/Health Connect silently. Flutter's platform channels provide a clean boundary: Dart handles UI and business logic, native Swift/Kotlin code handles OS-level health operations in background isolates without fighting a JS thread scheduler.

### Trade-Off Accepted

Flutter Web is not suitable for a production website. The future website will be a **separate frontend** (likely Next.js) talking to the same Cloud Brain backend. This is acceptable because neither React Native Web nor Flutter Web would deliver a quality web experience for this product.

---

## 2. System Architecture: The Hybrid Hub

### 2.1 High-Level Overview

```
┌──────────────────────────────────────────────────────────────┐
│                        CLOUD BRAIN                            │
│                                                               │
│  ┌───────────┐  ┌────────────┐  ┌──────────────────────────┐│
│  │  FastAPI   │  │  LLM Agent │  │   MCP Client             ││
│  │  Gateway   │──│  Engine    │──│   (Orchestrator)          ││
│  │           │  │  (GPT-4o)  │  │                           ││
│  └─────┬─────┘  └─────┬──────┘  │  ┌──────┐ ┌──────┐      ││
│        │               │         │  │Strava│ │Fitbit│      ││
│  ┌─────┴─────┐  ┌─────┴─────┐  │  │ MCP  │ │ MCP  │      ││
│  │ PostgreSQL │  │ Pinecone  │  │  └──────┘ └──────┘      ││
│  │ (Supabase) │  │ (context) │  │  ┌──────┐ ┌──────┐      ││
│  └───────────┘  └───────────┘  │  │ Oura │ │WHOOP │      ││
│                                 │  │ MCP  │ │ MCP  │      ││
│                                 │  └──────┘ └──────┘      ││
│                                 │  ┌────────────────┐      ││
│                                 │  │ Health Writer   │      ││
│                                 │  │ MCP Server      │      ││
│                                 │  └────────────────┘      ││
│                                 └──────────────────────────┘│
└────────────────────┬────────────────────────────────────────┘
                     │  REST / WebSocket / FCM Push
┌────────────────────┴────────────────────────────────────────┐
│                  EDGE AGENT (Flutter)                        │
│  ┌────────────────────────────────────────────────────┐     │
│  │            Dart Layer (~90-95%)                     │     │
│  │  Chat UI │ State (Riverpod) │ Network (Dio)        │     │
│  │  Dashboard Cards │ Onboarding │ Settings            │     │
│  └──────────────────┬─────────────────────────────────┘     │
│                     │  Platform Channels                     │
│  ┌──────────────────┴─────────────────────────────────┐     │
│  │          Native Bridge (~5-10%)                     │     │
│  │  Swift (HealthKit, HKObserver, Deep Links)          │     │
│  │  Kotlin (Health Connect, WorkManager, Deep Links)   │     │
│  └─────────────────────────────────────────────────────┘     │
└──────────────────────────────────────────────────────────────┘
```

### 2.2 Edge Agent — Flutter Application

**Architecture Pattern:** Feature-First Clean Architecture

**Directory Structure:**

```
life_logger/
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── core/
│   │   ├── network/
│   │   │   ├── api_client.dart           # Dio, interceptors, auth refresh
│   │   │   ├── ws_client.dart            # WebSocket for LLM streaming
│   │   │   └── fcm_service.dart          # FCM push handler
│   │   ├── health/
│   │   │   ├── health_bridge.dart        # Unified Dart API (platform channels)
│   │   │   ├── health_observer.dart      # Background observation coordinator
│   │   │   └── data_normalizer.dart      # Open mHealth normalization
│   │   ├── storage/
│   │   │   ├── local_db.dart             # Drift (SQLite) offline cache
│   │   │   └── secure_storage.dart       # Encrypted token storage
│   │   ├── deeplink/
│   │   │   └── deeplink_launcher.dart    # URI scheme library for app launching
│   │   └── di/
│   │       └── providers.dart            # Riverpod providers
│   ├── features/
│   │   ├── chat/                         # Primary feature (Chat-First)
│   │   │   ├── data/
│   │   │   │   ├── chat_repository.dart
│   │   │   │   └── models/
│   │   │   ├── domain/
│   │   │   │   └── chat_service.dart
│   │   │   └── presentation/
│   │   │       ├── chat_screen.dart
│   │   │       ├── widgets/
│   │   │       │   ├── message_bubble.dart
│   │   │       │   ├── streaming_text.dart
│   │   │       │   ├── voice_input.dart
│   │   │       │   └── insight_card.dart  # AI insight summary cards
│   │   │       └── chat_controller.dart
│   │   ├── onboarding/                   # App connection flow
│   │   │   ├── data/
│   │   │   ├── domain/
│   │   │   └── presentation/
│   │   │       ├── onboarding_screen.dart
│   │   │       ├── connect_health_store_screen.dart
│   │   │       ├── connect_apps_screen.dart
│   │   │       └── goal_setup_screen.dart
│   │   ├── dashboard/                    # Quick-glance data cards
│   │   │   ├── data/
│   │   │   ├── domain/
│   │   │   └── presentation/
│   │   │       ├── dashboard_widgets.dart
│   │   │       └── stat_card.dart
│   │   ├── integrations/                 # OAuth flows per app
│   │   │   ├── data/
│   │   │   │   └── oauth_repository.dart
│   │   │   ├── domain/
│   │   │   └── presentation/
│   │   │       └── integration_tile.dart
│   │   └── settings/
│   └── shared/
├── ios/Runner/
│   ├── HealthKitBridge.swift
│   ├── DeepLinkHandler.swift
│   └── AppDelegate.swift
├── android/app/src/main/kotlin/
│   ├── HealthConnectBridge.kt
│   ├── HealthObserverWorker.kt
│   └── DeepLinkHandler.kt
└── pubspec.yaml
```

**Key Package Decisions:**

| Package | Purpose | Justification |
|---|---|---|
| `riverpod` + `riverpod_generator` | State Management | Compile-safe, no BuildContext dependency — critical for background-triggered state updates. |
| `dio` | HTTP Client | Interceptors for auth token refresh, request logging, retry logic. |
| `web_socket_channel` | LLM Streaming | Native Dart WebSocket, no bridge overhead for streaming text responses. |
| `health` | HealthKit + Health Connect | Single package covers both platforms with unified API. |
| `go_router` | Navigation + Deep Links | Declarative routing with built-in deep link handling. |
| `drift` | Local SQLite | Type-safe queries, migrations, offline message cache for chat history. |
| `flutter_secure_storage` | Token Storage | Keychain (iOS) / EncryptedSharedPreferences (Android). |
| `firebase_messaging` | Push Notifications | FCM for Cloud-to-Device write payloads. |
| `record` | Voice Input | Audio recording for speech-to-text via Cloud Brain (Whisper). |
| `workmanager` | Background Tasks (Android) | WorkManager wrapper for periodic health sync. |
| `url_launcher` | Deep Linking | Launch external apps via URI schemes. |

### 2.3 Cloud Brain — Python Backend

**Framework:** FastAPI (async-native, WebSocket built-in, Pydantic validation)

**Directory Structure (MCP-First):**

```
cloud-brain/
├── app/
│   ├── main.py
│   ├── config.py
│   ├── api/v1/
│   │   ├── chat.py                     # POST /chat, WS /chat/stream
│   │   ├── auth.py                     # Login, refresh, OAuth callbacks
│   │   ├── integrations.py             # Connect/disconnect integrations
│   │   ├── webhooks.py                 # Inbound webhooks (Strava, Oura, etc.)
│   │   └── health_sync.py             # Cloud→Device push payloads
│   ├── agent/
│   │   ├── orchestrator.py             # LLM Agent loop (MCP tool selection)
│   │   ├── mcp_client.py              # MCP Client — routes tool calls to servers
│   │   ├── tools/
│   │   │   ├── health_writer.py        # Push payload generation
│   │   ├── context/
│   │   │   ├── memory_manager.py       # Pinecone long-term context
│   │   │   └── user_profile.py
│   │   └── prompts/
│   │       ├── system.py               # System prompt templates
│   │       └── tools_schema.py         # Consolidated MCP tool definitions
│   ├── mcp_servers/                    # ← MCP Servers (replaces integrations/)
│   │   ├── base_server.py             # Abstract MCP server class
│   │   ├── strava_server.py           # Strava MCP server
│   │   ├── fitbit_server.py           # Fitbit MCP server
│   │   ├── oura_server.py            # Oura MCP server
│   │   ├── whoop_server.py           # WHOOP MCP server
│   │   ├── garmin_server.py          # Garmin MCP server
│   │   └── health_writer_server.py   # Cloud→Device health store bridge
│   ├── analytics/
│   │   ├── reasoning_engine.py        # Cross-app correlation (Pearson/Spearman)
│   │   ├── deduplication.py           # Source-of-truth hierarchy
│   │   └── normalizer.py             # Open mHealth conversion
│   ├── models/                        # SQLAlchemy ORM
│   │   ├── user.py
│   │   ├── conversation.py
│   │   ├── integration.py
│   │   └── health_record.py
│   └── services/
│       ├── push_service.py            # FCM delivery
│       ├── subscription.py            # RevenueCat tier enforcement
│       └── rate_limiter.py            # LLM usage limits per tier
├── alembic/
├── tests/
├── Dockerfile
├── docker-compose.yml
└── pyproject.toml
```

### 2.4 MCP Architecture — Integration Layer

Each external app integration is an **MCP Server** that the LLM Agent's **MCP Client** orchestrates.

#### MCP Server Contract

Every MCP server implements:

```python
class BaseMCPServer:
    """Abstract MCP server interface."""

    def get_tools(self) -> list[ToolSchema]:
        """Return tool schemas the LLM can call."""

    async def execute_tool(self, tool_name: str, params: dict) -> ToolResult:
        """Execute a tool call and return structured results."""

    async def get_resources(self) -> list[Resource]:
        """Return available data resources (e.g., recent activities)."""
```

#### MCP Servers for MVP

| MCP Server | Tools Exposed | Auth | Rate Limits |
|------------|--------------|------|-------------|
| **Strava** | `get_activities`, `get_athlete_stats`, `create_activity`, `update_activity` | OAuth 2.0 | 100 req / 15 min |
| **Fitbit** | `get_daily_activity`, `get_sleep_log`, `get_heart_rate`, `get_body_weight`, `get_hrv` | OAuth 2.0 | 150 req / hour |
| **Oura** | `get_daily_sleep`, `get_readiness`, `get_daily_activity`, `get_heart_rate` | OAuth 2.0 / PAT | 5000 req / 5 min |
| **WHOOP** | `get_recovery`, `get_strain`, `get_sleep`, `get_workouts` | OAuth 2.0 | TBD |
| **Garmin** | Read via `health_writer` (Health Connect/Apple Health) - **NO DIRECT API** for MVP | N/A | N/A |
| **Health Writer** | `write_nutrition`, `write_workout`, `write_weight`, `read_metrics` | Internal (FCM) | N/A |

| **Deep Link** | `open_app`, `open_strava_recording` | Local (Edge) | N/A |

#### MCP Data Flow: Tool Call Lifecycle

```
1. User → "Log my 5K run from yesterday"
2. Flutter Chat → WebSocket → Cloud Brain

3. Cloud Brain orchestrator.py:
   a. LLM Agent receives message + user context
   b. LLM decides to call: strava_server.create_activity(
        name="5K Run", sport_type="Run",
        distance=5000, elapsed_time=1680,
        start_date_local="2026-02-17T18:00:00Z"
      )
   c. mcp_client.py routes call → strava_server.py
   d. strava_server.py → Strava API POST /activities
   e. Strava returns activity ID

4. Cloud Brain → WebSocket → Flutter
   "Done! Logged your 5K run (28 min) to Strava."
```

**Cloud Brain Tech Stack:**

| Component | Choice | Justification |
|---|---|---|
| FastAPI | Web Framework | Async-native, WebSocket support, Pydantic validation for MCP tool schemas. |
| GPT-4o (primary) | LLM | Structured tool calling for MCP execution. |
| PostgreSQL (Supabase) | Relational DB | Users, conversations, integration tokens. Supabase adds Auth + RLS for free. |
| Pinecone Serverless | Vector Store | Long-term user context retrieval. Free tier covers MVP. |
| Celery + Redis (Upstash) | Task Queue | Async scheduled tasks, integration sync. |
| Firebase Cloud Messaging | Push | Cross-platform push for Cloud→Device write payloads. |
| RevenueCat | Subscriptions | Wraps App Store + Play Store billing. Cross-platform subscription management. |

---

## 3. Critical Data Flows

### 3.1 Cloud-to-Device Write ("I ate a banana")

*Zero-Friction Vision: This flow assumes user manually logs via Life Logger text input, or we receive data from CalAI.*

```
1. User → Flutter chat (text): "I ate a banana"
2. Flutter → WebSocket → Cloud Brain
3. Cloud Brain LLM Agent:
   a. Intent: food logging
   b. health_writer MCP server: generates HealthKit-compatible payload
4. Cloud Brain → FCM push → Edge Agent
   Payload: {"action": "write_health", "type": "nutrition",
             "data": {"calories": 105, "carbs": 27, ...}}
5. Edge Agent (background):
   a. Platform channel → Swift HealthKit bridge
   b. Writes HKQuantitySample to HealthKit
   c. Confirms → Cloud Brain via REST
6. Chat UI: "Logged: Banana (105 cal) → Apple Health ✓"
```

### 3.2 Cloud-to-Cloud ("Log my run on Strava")

```
1. User → "I ran a 5K in 28 minutes yesterday"
2. Cloud Brain LLM → Strava MCP Server → Strava API POST /activities
3. Response streamed back to Flutter chat
4. No Edge Agent involvement needed
```

### 3.3 Cross-App Reasoning ("Why am I not losing weight?")

```
1. User → "Why am I not losing weight?"
2. Cloud Brain LLM Agent:
   a. Calls health_writer MCP: read nutrition data (last 30 days)
   b. Calls strava MCP: get_activities (last 30 days)
   c. Calls health_writer MCP: read weight data (last 30 days)
   d. Sends all data to reasoning_engine.py for statistical analysis
   e. reasoning_engine returns: {
        avg_daily_calories: 2180,
        estimated_maintenance: 1950,
        surplus: 230,
        run_sessions_this_month: 3,
        run_sessions_last_month: 8
      }
   f. LLM narrates findings in natural language
3. Response streamed to Flutter chat with actionable insights
```

### 3.4 Background Observation (Third-Party App Detection)

```
1. User completes run in another app (e.g., Nike Run Club)
2. That app writes workout to HealthKit
3. Edge Agent's HKObserverQuery fires (background)
4. Platform channel → Dart layer → REST to Cloud Brain
   Payload: {"event": "new_workout", "source": "NRC",
             "data": {"type": "run", "duration": 1800, ...}}
5. Cloud Brain LLM generates follow-up question
6. FCM push → Edge Agent → local notification:
   "I see you finished a run! How was your energy?"
7. User taps notification → opens chat with pre-filled context
```

### 3.5 Autonomous Deep Link ("Start a run for me")

```
1. User → "Start a run for me"
2. Cloud Brain LLM → determines user has Strava connected
3. Cloud Brain → response: {
     "message": "Opening Strava for you. Tap Start when ready!",
     "action": {"type": "deep_link", "uri": "strava://record?sport=running"}
   }
4. Edge Agent → url_launcher → opens Strava to recording screen
5. User taps "Start" in Strava
```

---

## 4. Infrastructure & Deployment

> For the full infrastructure guide including cost analysis, onboarding, and service details, see [Infrastructure & Deployment Guide](./infrastructure-memo.md).

### 4.1 Local Development (Hybrid Approach)

| Component | Tool | Notes |
|---|---|---|
| Python Backend | `uv` virtual environment (`.venv/`) | Runs natively on developer machine for fast I/O and hot-reload. |
| PostgreSQL + Redis | Docker Compose | Infrastructure services run in containers to keep the host OS clean. |
| Flutter | Native Flutter SDK | Docker is incompatible with mobile emulators. |

### 4.2 Production Deployment

| Component | Service | Justification |
|---|---|---|
| Backend Hosting | Railway or Fly.io | Docker deployment from GitHub, auto-scaling. Migrate to AWS ECS/Fargate at scale. |
| Database | Supabase (managed Postgres) | Postgres + Auth + Realtime + RLS. Free tier covers MVP. |
| Redis | Upstash (serverless) | Pay-per-request for Celery queue. ~$0-5/month at MVP scale. |
| Vector DB | Pinecone Serverless | Free tier, purpose-built for similarity search. |
| Flutter CI/CD | Codemagic | Purpose-built for Flutter. Handles iOS code signing and store uploads. |
| Error Tracking | Sentry | Flutter + Python SDKs. |
| Analytics | PostHog | Open-source, privacy-friendly — important optics for health data. |
| DNS + SSL | Cloudflare | Free SSL certs, DDoS protection, DNS management. |

---

## 5. Security & Privacy

| Concern | Strategy |
|---|---|
| Health data at rest | Never persisted on Cloud Brain. HealthKit/Health Connect data stays on-device. Cloud receives only processed summaries for correlation (e.g., "sleep_score: 78"). |
| Data in transit | TLS 1.3 for all APIs. WebSocket over WSS. |
| OAuth tokens | Integration tokens encrypted at rest in Postgres. Never exposed to frontend. |
| LLM data exposure | OpenAI API data usage policy (not used for training). Documented in Privacy Policy. |
| User data deletion | GDPR-compliant full account deletion. Device data managed by user. |
| MCP Server isolation | Each MCP server operates with scoped tokens. Compromising one integration doesn't expose others. |

---

## 6. Phase 1 MVP Scope

| Feature | Edge Agent (Flutter) | Cloud Brain | Integration Target |
|---|---|---|---|
| Chat (Text) | Chat UI, streaming text renderer | WebSocket, LLM orchestrator | — |
| Chat (Voice) | `record` → audio upload | Whisper STT → LLM | — |
| Apple Health R/W | Swift HealthKit bridge | Health Writer MCP server | HealthKit |
| Health Connect R/W | Kotlin Health Connect bridge | Health Writer MCP server | Health Connect |
| Strava R/W | OAuth flow (WebView) | Strava MCP server | Strava API v3 |
| Fitbit Read | OAuth flow (WebView) | Fitbit MCP server | Fitbit Web API |
| Oura Read | OAuth flow (WebView) | Oura MCP server | Oura API v2 |
| Cross-App Reasoning | Insight cards in chat | Reasoning engine + LLM narration | Multiple sources |
| Autonomous Actions | Deep link launcher | MCP tool execution | Strava, health stores |
| Onboarding | Connection flow screens | OAuth callback handling | All integrations |
| Dashboard Cards | Stat cards in chat view | Aggregated data endpoint | All connected apps |
| Subscription | RevenueCat paywall | Tier check middleware | App Store / Play Store |

---

## 7. Risks & Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| `health` Flutter package doesn't cover HKObserverQuery | Blocks background observation | Custom platform channels for observer queries. Use `health` for read/write, custom native code for observers. |
| FCM push delivery latency (5-10s cold start) | User feels logging is slow | Optimistic UI: show "Queued for logging..." immediately in chat. Confirm when write completes. |
| Strava/Fitbit/Oura API rate limits | Blocked integrations | Intelligent caching + Celery queue with exponential backoff. |
| App Store rejection for HealthKit usage | Blocks iOS launch | Apply for HealthKit entitlement early. Document clear user benefit per HK data type. |
| Garmin Health API requires commercial approval | Delays Garmin integration | **MITIGATED:** MVP uses Health Connect (Android) and Apple Health (iOS) to read Garmin data. Direct API pushed to Phase 2. |
| MCP server complexity overhead | Slower initial development | Start with 3 MCP servers (Strava, Fitbit, Oura). Validate the pattern before building WHOOP/Garmin. |


---

## 8. Future Considerations (Not MVP)

- **Phase 2:** WHOOP, Garmin full integration, Morning Briefing, Smart Reminders, Goal Tracking
- **Phase 3:** Notion, YNAB, Todoist, bi-directional triggers (Temporal workflow engine replaces Celery)
- **Web App:** Separate Next.js frontend, same Cloud Brain API, read-only dashboard (no health writes from web)
