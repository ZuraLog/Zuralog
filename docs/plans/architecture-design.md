# Life Logger — Architecture Design Document

**Version:** 1.0
**Date:** February 18, 2026
**Status:** Approved Design

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

### 2.1 Overview

```
┌──────────────────────────────────────────────────────┐
│                   CLOUD BRAIN                         │
│  ┌───────────┐  ┌───────────┐  ┌──────────────────┐ │
│  │  FastAPI   │  │  LLM      │  │  MCP Clients     │ │
│  │  Gateway   │──│  Agent    │──│  (Strava, Notion, │ │
│  │           │  │  Engine   │  │   Oura, YNAB...) │ │
│  └─────┬─────┘  └─────┬─────┘  └──────────────────┘ │
│        │               │                              │
│  ┌─────┴─────┐  ┌─────┴─────┐                       │
│  │ PostgreSQL │  │ Pinecone  │                       │
│  │ (users,    │  │ (long-term│                       │
│  │  sessions) │  │  context) │                       │
│  └───────────┘  └───────────┘                       │
└────────────────────┬─────────────────────────────────┘
                     │  REST / WebSocket / FCM Push
┌────────────────────┴─────────────────────────────────┐
│                EDGE AGENT (Flutter)                   │
│  ┌────────────────────────────────────────────┐      │
│  │           Dart Layer (~90-95%)              │      │
│  │  Chat UI │ State (Riverpod) │ Network (Dio) │      │
│  └──────────────────┬─────────────────────────┘      │
│                     │  Platform Channels              │
│  ┌──────────────────┴─────────────────────────┐      │
│  │         Native Bridge (~5-10%)              │      │
│  │  Swift (HealthKit, HKObserver, Siri)        │      │
│  │  Kotlin (Health Connect, WorkManager)       │      │
│  └─────────────────────────────────────────────┘      │
└───────────────────────────────────────────────────────┘
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
│   │   │   └── deeplink_launcher.dart    # URI scheme library
│   │   └── di/
│   │       └── providers.dart            # Riverpod providers
│   ├── features/
│   │   ├── chat/                         # Primary feature
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
│   │   │       │   └── photo_capture.dart
│   │   │       └── chat_controller.dart
│   │   ├── onboarding/
│   │   ├── insights/
│   │   └── settings/
│   └── shared/
├── ios/Runner/
│   ├── HealthKitBridge.swift
│   └── AppDelegate.swift
├── android/app/src/main/kotlin/
│   ├── HealthConnectBridge.kt
│   └── HealthObserverWorker.kt
└── pubspec.yaml
```

**Key Package Decisions:**

| Package | Purpose | Justification |
|---|---|---|
| `riverpod` + `riverpod_generator` | State Management | Compile-safe, no BuildContext dependency — critical for background-triggered state updates. `AsyncNotifier` maps cleanly to streaming WebSocket data. Lower boilerplate than Bloc for MVP speed. |
| `dio` | HTTP Client | Interceptors for auth token refresh, request logging, retry logic. |
| `web_socket_channel` | LLM Streaming | Native Dart WebSocket, no bridge overhead for streaming text responses. |
| `health` | HealthKit + Health Connect | Single package covers both platforms with unified API. Reduces custom platform channel code. |
| `go_router` | Navigation + Deep Links | Declarative routing with built-in deep link handling. |
| `drift` | Local SQLite | Type-safe queries, migrations, offline message cache for chat history. |
| `flutter_secure_storage` | Token Storage | Keychain (iOS) / EncryptedSharedPreferences (Android). |
| `firebase_messaging` | Push Notifications | FCM for Cloud-to-Device write payloads. |
| `camera` | Food Photo Capture | Official Flutter team package. |
| `record` | Voice Input | Audio recording for speech-to-text via Cloud Brain (Whisper). |
| `workmanager` | Background Tasks (Android) | WorkManager wrapper for periodic health sync. |

### 2.3 Cloud Brain — Python Backend

**Framework:** FastAPI (async-native, WebSocket built-in, Pydantic validation)

**Directory Structure:**

```
cloud-brain/
├── app/
│   ├── main.py
│   ├── config.py
│   ├── api/v1/
│   │   ├── chat.py                     # POST /chat, WS /chat/stream
│   │   ├── auth.py                     # Login, refresh, OAuth callbacks
│   │   ├── integrations.py             # Connect/disconnect integrations
│   │   ├── webhooks.py                 # Inbound webhooks (Strava, etc.)
│   │   └── health_sync.py             # Cloud→Device push payloads
│   ├── agent/
│   │   ├── orchestrator.py             # LLM Agent loop (tool selection)
│   │   ├── tools/
│   │   │   ├── food_analyzer.py        # Photo → macros (GPT-4o Vision)
│   │   │   ├── health_writer.py        # Push payload generation
│   │   │   ├── strava_tool.py
│   │   │   ├── notion_tool.py
│   │   │   ├── oura_tool.py
│   │   │   ├── ynab_tool.py
│   │   │   └── todoist_tool.py
│   │   ├── context/
│   │   │   ├── memory_manager.py       # Pinecone long-term context
│   │   │   └── user_profile.py
│   │   └── prompts/
│   │       ├── system.py               # System prompt templates
│   │       └── tools_schema.py         # Tool definitions for the LLM
│   ├── analytics/
│   │   ├── correlation_engine.py       # Pearson/Spearman (deterministic)
│   │   ├── deduplication.py            # Source-of-truth hierarchy
│   │   └── normalizer.py              # Open mHealth conversion
│   ├── integrations/                   # API client wrappers
│   │   ├── strava_client.py
│   │   ├── notion_client.py
│   │   ├── oura_client.py
│   │   ├── whoop_client.py
│   │   ├── cronometer_client.py
│   │   ├── ynab_client.py
│   │   └── todoist_client.py
│   ├── models/                         # SQLAlchemy ORM
│   │   ├── user.py
│   │   ├── conversation.py
│   │   ├── integration.py
│   │   └── health_record.py
│   └── services/
│       ├── push_service.py             # FCM delivery
│       ├── subscription.py             # RevenueCat tier enforcement
│       └── rate_limiter.py             # LLM usage limits per tier
├── alembic/
├── tests/
├── Dockerfile
├── docker-compose.yml
└── pyproject.toml
```

**Cloud Brain Tech Stack:**

| Component | Choice | Justification |
|---|---|---|
| FastAPI | Web Framework | Async-native, WebSocket support, Pydantic validation for LLM tool schemas. |
| GPT-4o (primary) | LLM | Vision capability for food photos, structured tool calling for MCP execution. |
| PostgreSQL (Supabase) | Relational DB | Users, conversations, integration tokens. Supabase adds Auth + RLS for free. |
| Pinecone Serverless | Vector Store | Long-term user context retrieval. Free tier covers MVP. |
| Celery + Redis (Upstash) | Task Queue | Async food photo processing, scheduled Morning Briefing generation. |
| Firebase Cloud Messaging | Push | Cross-platform push for Cloud→Device write payloads. |
| RevenueCat | Subscriptions | Wraps App Store + Play Store billing. Cross-platform subscription management. |

---

## 3. Critical Data Flows

### 3.1 Cloud-to-Device Write ("I ate a banana")

```
1. User → Flutter chat (text/voice)
2. Flutter → WebSocket → Cloud Brain
3. Cloud Brain LLM Agent:
   a. Intent: food logging
   b. food_analyzer tool: "banana" → {calories: 105, carbs: 27g, ...}
   c. health_writer tool: generates HealthKit-compatible payload
4. Cloud Brain → FCM push → Edge Agent
   Payload: {"action": "write_health", "type": "nutrition",
             "data": {"calories": 105, "carbs": 27, ...}}
5. Edge Agent (background):
   a. Platform channel → Swift HealthKit bridge
   b. Writes HKQuantitySample to HealthKit
   c. Confirms → Cloud Brain via REST
6. Chat UI: "Logged: Banana (105 cal) → Apple Health"
```

### 3.2 Background Observation (Third-Party App Detection)

```
1. User completes run in Nike Run Club
2. NRC writes workout to HealthKit
3. Edge Agent's HKObserverQuery fires (background)
4. Platform channel → Dart layer → REST to Cloud Brain
   Payload: {"event": "new_workout", "source": "NRC",
             "data": {"type": "run", "duration": 1800, ...}}
5. Cloud Brain LLM generates follow-up question
6. FCM push → Edge Agent → local notification:
   "I see you finished a run in Nike Run Club. How was your energy?"
7. User taps notification → opens chat with pre-filled context
```

### 3.3 Cloud-to-Cloud ("Log my run on Strava")

```
1. User → "I'm running a 5k"
2. Cloud Brain LLM → strava_tool → Strava API POST /activities
3. Response streamed back to Flutter chat
4. No Edge Agent involvement needed
```

---

## 4. Infrastructure & Deployment

| Component | Service | Justification |
|---|---|---|
| Backend Hosting | Railway or Fly.io | Docker deployment in minutes, auto-scaling. Migrate to AWS ECS/Fargate at scale. |
| Database | Supabase (managed Postgres) | Postgres + Auth + Realtime + RLS. Free tier covers MVP. |
| Redis | Upstash (serverless) | Pay-per-request for Celery queue. ~$0-5/month at MVP scale. |
| Vector DB | Pinecone Serverless | Free tier, purpose-built for similarity search. |
| Flutter CI/CD | Codemagic | Purpose-built for Flutter. Handles iOS code signing and store uploads. |
| Error Tracking | Sentry | Flutter + Python SDKs. |
| Analytics | PostHog | Open-source, privacy-friendly — important optics for health data. |

---

## 5. Security & Privacy

| Concern | Strategy |
|---|---|
| Health data at rest | Never persisted on Cloud Brain. HealthKit/Health Connect data stays on-device. Cloud receives only processed summaries for correlation (e.g., "sleep_score: 78"). |
| Data in transit | TLS 1.3 for all APIs. WebSocket over WSS. |
| OAuth tokens | Integration tokens encrypted at rest in Postgres. Never exposed to frontend. |
| LLM data exposure | OpenAI API data usage policy (not used for training). Documented in Privacy Policy. |
| User data deletion | GDPR-compliant full account deletion. Device data managed by user. |

---

## 6. Phase 1 MVP Scope

| Feature | Edge Agent (Flutter) | Cloud Brain | Integration Target |
|---|---|---|---|
| Chat (Text) | Chat UI, streaming text renderer | WebSocket, LLM orchestrator | — |
| Chat (Voice) | `record` → audio upload | Whisper STT → LLM | — |
| Photo-to-Macros | `camera` → image upload | GPT-4o Vision → macro extraction | Apple Health / Health Connect (write) |
| Apple Health R/W | Swift HealthKit bridge | Push payload generation | HealthKit |
| Health Connect R/W | Kotlin Health Connect bridge | Push payload generation | Health Connect |
| Strava | OAuth flow (WebView) | MCP tool: read/post activities | Strava API |
| Notion | OAuth flow (WebView) | MCP tool: create journal entries | Notion API |
| Subscription | RevenueCat paywall | Tier check middleware | App Store / Play Store |

---

## 7. Risks & Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| `health` Flutter package doesn't cover edge cases (e.g., HKObserverQuery) | Blocks background observation | Custom platform channels for observer queries. Use `health` for read/write, custom native code for observers. |
| FCM push delivery latency (5-10s cold start) | User feels logging is slow | Optimistic UI: show "Queued for logging..." immediately in chat. Confirm when write completes. |
| LLM hallucinated nutrition data from photos | Incorrect health data logged | Confidence threshold: if Vision model confidence < 80%, ask user to confirm before writing. |
| Strava/Notion API rate limits | Blocked integrations | Exponential backoff + queue. Celery handles retry logic. |
| App Store rejection for HealthKit usage | Blocks iOS launch | Apply for HealthKit entitlement early. Document clear user benefit per HK data type. |

---

## 8. Future Considerations (Not MVP)

- **Phase 2:** Oura, Whoop, Google Health Connect enhancements, Morning Briefing feature
- **Phase 3:** YNAB, Todoist, bi-directional triggers (Temporal workflow engine replaces Celery)
- **Web App:** Separate Next.js frontend, same Cloud Brain API, read-only dashboard (no health writes from web)
