# Life Logger — Final Implementation Plan

**Document Version:** 1.0  
**Date:** February 18, 2026  
**Status:** For Review & Approval

---

## 1. Executive Summary

### 1.1 What is Life Logger?

Life Logger is a mobile AI health assistant that transforms the fragmented landscape of fitness applications into a unified, intelligent system. The application serves as a "Zero-Friction Connector" that integrates with the fitness apps users already love—including Apple Health, Google Health Connect, Strava, Fitbit, and Oura—delivering cross-app reasoning and autonomous task execution through a conversational AI interface.

### 1.2 Core Value Proposition

- **Unified Intelligence:** Users no longer need to manually check multiple apps. Life Logger synthesizes data from all connected sources into coherent insights.
- **Cross-App Reasoning:** The AI connects the dots between nutrition, exercise, sleep, and weight—answering questions like "Why am I not losing weight?" with data from CalAI, Strava, and Apple Health combined.
- **Zero-Friction Actions:** Users can log workouts, track nutrition, and start activities through simple voice or text commands. The AI handles the heavy lifting.
- **Personalized Coaching:** The AI adopts a "Tough Love Coach" persona—opinionated, direct, and proactive about user health goals.

### 1.3 Target Market

- **Primary (MVP):** Everyday fitness enthusiasts who use 2-3 fitness apps and want them to work together seamlessly.
- **Secondary (Phase 2):** Health optimizers who track macros, wear Oura/Whoop, and want deep correlation analysis.
- **Tertiary (Phase 3):** Life quantifiers who want integration with productivity and finance apps.

---

## 2. Problem Space & Solution

### 2.1 The Problem

The fitness app ecosystem is severely fragmented:

1. **Data Silos:** The average health-conscious user has 3-5 fitness apps. Each stores data in isolation with no cross-pollination.
2. **Passive Hubs:** Apple Health and Google Health Connect collect data but provide zero intelligence or reasoning.
3. **Manual Friction:** Logging data across multiple apps is tedious. Users forget to log meals, skip manual workout entries, and eventually churn.
4. **No Cross-Domain Intelligence:** Single-vertical apps cannot answer complex questions like "Why am I not losing weight?" because the answer requires combining nutrition + exercise + sleep + consistency data.

### 2.2 The Solution

Life Logger sits between the user and their existing app ecosystem:

- **Connects, Doesn't Replace:** Life Logger does NOT rebuild food logging or workout tracking. It connects to the best-in-class apps users already use.
- **Intelligent Layer:** The AI analyzes data across all sources, finding correlations humans miss.
- **Action-Oriented:** Beyond insights, the AI executes tasks—logging workouts, writing to Health Stores, creating Strava activities.

---

## 3. Product Vision & Roadmap

### 3.1 MVP (Months 1-4)

The MVP delivers the core "Smart Hub" experience:

- Chat-first AI interface with text and voice input
- Apple HealthKit integration (read/write) for iOS
- Google Health Connect integration (read/write) for Android
- Strava integration (read/write) for activity tracking
- Fitbit integration (read-only)
- Oura Ring integration (read-only)
- Cross-app AI reasoning engine
- Autonomous action execution via deep links
- App connection onboarding flow

### 3.2 Phase 2: "The Connected Self" (Months 5-7)

- WHOOP and Garmin integrations
- Morning Briefing (daily AI-generated summary)
- Smart Reminders ("You haven't run in 5 days")
- Goal tracking with progress indicators

### 3.3 Phase 3: "The Life OS" (Future)

- Notion, YNAB, and Todoist integrations
- Bi-directional triggers (e.g., "If sleep < 30%, reschedule workout")
- Advanced temporal workflows

---

## 4. Technical Architecture

### 4.1 Hybrid Hub Architecture

Life Logger uses a **Hybrid Hub** architecture combining cloud intelligence with on-device edge processing:

```
┌─────────────────────────────────────────────────────────────────┐
│                        CLOUD BRAIN                               │
│  (Python/FastAPI)                                               │
│  ┌─────────────┐  ┌────────────┐  ┌──────────────────────────┐│
│  │  FastAPI    │  │  LLM Agent │  │   MCP Client              ││
│  │  Gateway    │──│  Engine    │──│   (Orchestrator)          ││
│  │             │  │  (Kimi)    │  │                           ││
│  └─────────────┘  └────────────┘  └──────────────────────────┘│
│        │                │                      │              │
│  ┌─────┴─────┐  ┌──────┴─────┐        ┌───────┴──────┐       │
│  │ PostgreSQL │  │  Pinecone  │        │  MCP Servers │       │
│  │ (Supabase) │  │  (Vector)  │        │  (Strava,     │       │
│  └────────────┘  └────────────┘        │  Fitbit,      │       │
│                                        │  Oura, Health)│       │
│                                        └───────────────┘       │
└──────────────────────────┬──────────────────────────────────────┘
                          │  REST / WebSocket / FCM Push
┌──────────────────────────┴──────────────────────────────────────┐
│                    EDGE AGENT (Flutter)                           │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │                  Dart Layer (90-95%)                       │  │
│  │  Chat UI │ State (Riverpod) │ Network │ Dashboard         │  │
│  └────────────────────────────────────────────────────────────┘  │
│                              │ Platform Channels                  │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │              Native Bridge (5-10%)                        │  │
│  │  Swift (HealthKit) │ Kotlin (Health Connect)               │  │
│  └────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### 4.2 Technology Stack

#### Cloud Brain (Backend)

| Component | Technology | Justification |
|-----------|------------|---------------|
| Web Framework | FastAPI | Async-native, WebSocket support, Pydantic validation |
| LLM Engine | Kimi K2.5 (Moonshot AI) | Superior instruction following, interleaved reasoning |
| Database | PostgreSQL (Supabase) | Managed Postgres + Auth + RLS |
| Vector Store | Pinecone | Long-term user context retrieval |
| Task Queue | Celery + Redis | Async tasks, integration sync |
| Push Notifications | Firebase Cloud Messaging | Cross-platform push |
| Subscriptions | RevenueCat | App Store + Play Store billing |

#### Edge Agent (Mobile)

| Component | Technology | Justification |
|-----------|------------|---------------|
| Framework | Flutter (Dart) | 90-95% code sharing, platform channels |
| State Management | Riverpod | Compile-safe, no BuildContext dependency |
| HTTP Client | Dio | Interceptors, auth refresh, retry logic |
| WebSocket | web_socket_channel | Native Dart WebSocket |
| Health SDK | health (Flutter package) | Unified API across HealthKit + Health Connect |
| Navigation | go_router | Declarative routing + deep links |
| Local DB | Drift (SQLite) | Type-safe queries, offline cache |
| Secure Storage | flutter_secure_storage | Keychain / EncryptedSharedPreferences |
| Background Tasks | workmanager (Android) | Periodic health sync |

### 4.3 Integration Architecture: MCP (Model Context Protocol)

All external integrations are implemented as **MCP Servers**, providing a plug-and-play architecture:

| MCP Server | Capabilities | Auth Method |
|------------|-------------|-------------|
| **Strava** | Get/create activities, athlete stats | OAuth 2.0 |
| **Fitbit** | Daily activity, sleep, heart rate, weight | OAuth 2.0 |
| **Oura** | Sleep, readiness, activity, HRV | OAuth 2.0 / PAT |
| **WHOOP** | Recovery, strain, sleep, workouts | OAuth 2.0 |
| **Health Writer** | Write nutrition, workouts, weight | Internal (FCM) |
| **Deep Link** | Open external apps | Local (Edge) |

---

## 5. Key Features & Functionality

### 5.1 AI Chat Interface

The primary interaction model is conversational:

- **Text Input:** Users type messages and receive streaming AI responses
- **Voice Input:** Microphone button triggers Whisper STT transcription
- **Zero-Friction Context:** The AI knows everything connected apps know

### 5.2 App Connection Hub

Onboarding flow where users connect their fitness apps:

- Browse available integrations
- One-tap OAuth connection per app
- Status indicators showing connected/disconnected/syncing state

### 5.3 Cross-App AI Reasoning

The core differentiator—synthesizing data across multiple sources:

- **Correlation Analysis:** Nutrition vs. exercise vs. weight vs. sleep
- **Trend Detection:** "Your running consistency dropped this month"
- **Goal-Aware Reasoning:** "Based on your goal, you need a 500 cal/day deficit"

### 5.4 Autonomous Task Execution

The AI acts as a "Chief of Staff" for health apps:

| Action | Method | Autonomy Level |
|--------|--------|---------------|
| Log a meal (text) | Write to Apple Health / Health Connect | Fully autonomous |
| Log a manual workout | Strava API `POST /activities` | Fully autonomous |
| Start a run recording | Deep link to Strava recording screen | Semi-autonomous |
| Open CalAI camera | Deep link to CalAI | Semi-autonomous |
| Read data from any app | API read calls | Fully autonomous |

### 5.5 Unified Data Dashboard

Quick-glance cards within the chat interface:

- Today's nutrition (from Health Store)
- This week's activities (from Strava)
- Weight trend
- AI insight card at the top

### 5.6 AI Persona: "The Tough Love Coach"

The AI is designed to be opinionated and proactive:

- **Direct:** "You ran 5K, but you're still 10K short of your weekly goal."
- **Context-Aware:** "You slept 5 hours. Take it easy on the run today."
- **Proactive:** "I noticed you haven't logged food today."

---

## 6. Integration Details

### 6.1 Apple HealthKit (iOS)

**Priority:** P0 (MVP)

The primary health data store for iOS:

- **Read:** Steps, active energy, dietary energy, body mass, workouts, sleep
- **Write:** Nutrition entries, workouts, weight
- **Background:** HKObserverQuery detects new data from third-party apps
- **Permissions:** Requires HealthKit entitlement and usage descriptions

### 6.2 Google Health Connect (Android)

**Priority:** P0 (MVP)

Android's equivalent to HealthKit:

- **Read:** Steps, calories, sleep, weight, exercise sessions
- **Write:** Nutrition, weight, exercise sessions
- **Background:** WorkManager handles periodic sync
- **Permissions:** Declared in AndroidManifest.xml and health-permissions XML

### 6.3 Strava

**Priority:** P0 (MVP)

Primary activity tracking integration:

- **Read:** Activities, athlete stats, GPS data
- **Write:** Manual activities, activity updates
- **Deep Links:** `strava://record?sport=running` to open recording screen
- **OAuth:** Requires Strava developer application setup

### 6.4 Fitbit

**Priority:** P1 (MVP)

Secondary fitness tracker:

- **Read:** Daily activity, sleep stages, heart rate, body weight, HRV
- **Write:** None (read-only)

### 6.5 Oura Ring

**Priority:** P1 (MVP)

Sleep and recovery tracking:

- **Read:** Daily sleep, readiness, activity, heart rate variability
- **Write:** None (read-only)

### 6.6 CalAI (Zero-Friction Strategy)

**Priority:** P0

Instead of direct API integration, CalAI data is read via Health Stores:

- User logs food in CalAI → CalAI writes to Apple Health/Health Connect → Life Logger reads from Health Store
- No OAuth required
- Deep link support: `calai://camera` for quick logging
- MyFitnessPal follows same pattern

---

## 7. Data Flows

### 7.1 Cloud-to-Device Write

When a user logs data via text:

1. User sends message: "I ate a banana"
2. Flutter sends via WebSocket to Cloud Brain
3. LLM determines intent and generates HealthKit-compatible payload
4. Cloud Brain sends FCM push to Edge Agent
5. Edge Agent writes to HealthKit via platform channel
6. Chat UI confirms: "Logged: Banana (105 cal) → Apple Health ✓"

### 7.2 Cloud-to-Cloud (Direct API)

When writing to Strava:

1. User: "I ran a 5K in 28 minutes yesterday"
2. Cloud Brain LLM calls Strava MCP Server
3. Strava MCP Server posts to Strava API
4. Response streamed back to Flutter

### 7.3 Cross-App Reasoning

1. User: "Why am I not losing weight?"
2. LLM Agent fetches:
   - Nutrition data (30 days) from Health Store
   - Activities from Strava (30 days)
   - Weight data from Health Store
3. Reasoning engine calculates correlations
4. LLM generates actionable insight

### 7.4 Background Observation

When third-party apps write data:

1. User completes run in Nike Run Club
2. Nike Run Club writes workout to HealthKit
3. Edge Agent's HKObserverQuery fires (background)
4. Platform channel notifies Dart layer
5. REST call to Cloud Brain
6. LLM generates follow-up
7. FCM push shows notification: "I see you finished a run!"

---

## 8. UI/UX Design

### 8.1 Design Philosophy

**Theme:** "Sophisticated Softness" — Apple-style health aesthetics

- Light and Dark mode support
- Subtle gradients and soft shadows
- Clean, minimal interface

### 8.2 Color Palette

| Role | Light Mode | Dark Mode | Usage |
|------|------------|-----------|-------|
| Primary | Sage Green (#CFE1B9) | Sage Green (#CFE1B9) | Main actions |
| Secondary | Muted Slate (#5B7C99) | Muted Slate (#7DA4C7) | Secondary elements |
| Accent | Soft Coral (#E07A5F) | Soft Coral (#FF8E72) | Alerts |
| Background | #FAFAFA | #000000 (OLED) | Main background |
| Surface | #FFFFFF | #1C1C1E | Cards |

### 8.3 Navigation Structure

**Pattern:** Bottom Tab Bar + Stack Navigation

- **Tab 1:** Dashboard ("Home") — Command center with health rings
- **Tab 2:** Chat ("Coach") — AI conversation interface
- **Tab 3:** Integrations ("Apps") — Connection management
- **Profile/Settings:** Accessed via avatar in Dashboard header

### 8.4 Key Screens

1. **Welcome/Auth:** Value proposition, Apple/Google sign-in
2. **Dashboard:** Insight card, health rings, integrations rail, metrics grid
3. **Chat:** Message stream, voice input, rich activity widgets
4. **Integrations:** List view with connection toggles
5. **Settings:** Profile, appearance, coach persona, privacy, subscription

---

## 9. LLM & AI Strategy

### 9.1 Model Selection: Kimi K2.5

**Primary Model:** Kimi K2.5 (Moonshot AI)

**Justification:**

- **Reliability:** Superior instruction following for MCP tool calls
- **Reasoning:** Interleaved reasoning reduces hallucinations in critical data paths
- **Cost:** ~$2.16/user/month with 78% gross margin on $9.99 subscription
- **Health Critical:** Data integrity is paramount—cost savings from cheaper models aren't worth the risk of data corruption

### 9.2 Reasoning Patterns

- **Cross-App Correlation:** Combines nutrition + activity + sleep data
- **Pattern Detection:** Pearson correlation, week-over-week trends
- **Goal Tracking:** Progress against user-defined targets

### 9.3 Context Management

- **Pinecone:** Vector store for long-term user context
- **User Profile:** Coach persona, goals, connected apps stored in PostgreSQL

---

## 10. Business Model

### 10.1 Revenue Strategy

**B2C Subscription (SaaS)**

| Tier | Price | Features |
|------|-------|----------|
| Free | $0 | Read-only access to health data, basic chat |
| Pro | $9.99/mo | Unlimited chat & voice, full autonomous actions, cross-app reasoning |

### 10.2 Unit Economics

- **Cost/User/Month:** ~$2.16 (Kimi K2.5 API)
- **Gross Margin:** ~78%
- **Scale Assumption:** 1,000 paying users = ~$7,800/month revenue

---

## 11. Security & Privacy

| Concern | Strategy |
|---------|---------|
| Health data at rest | Never persisted on Cloud Brain. Stays on-device. Cloud receives only processed summaries. |
| Data in transit | TLS 1.3 for all APIs, WSS for WebSockets |
| OAuth tokens | Encrypted at rest in PostgreSQL, never exposed to frontend |
| LLM data exposure | OpenAI API data usage policy (not used for training) |
| User data deletion | GDPR-compliant full account deletion |
| MCP isolation | Each MCP server operates with scoped tokens |

---

## 12. Infrastructure & Deployment

| Component | Service | Notes |
|-----------|---------|-------|
| Backend Hosting | Railway or Fly.io | Docker deployment, auto-scaling |
| Database | Supabase (managed Postgres) | Postgres + Auth + Realtime + RLS |
| Redis | Upstash (serverless) | Pay-per-request for Celery queue |
| Vector DB | Pinecone Serverless | Free tier covers MVP |
| Mobile CI/CD | Codemagic | Flutter-specific, handles iOS code signing |
| Error Tracking | Sentry | Flutter + Python SDKs |
| Analytics | PostHog | Privacy-friendly, open-source |

---

## 13. Implementation Phases

### Phase 1: Backend Implementation (Weeks 1-8)

**Focus:** Core infrastructure, authentication, MCP framework, API integrations

| Week | Deliverables |
|------|-------------|
| 1-2 | Cloud Brain project setup, Supabase database, Flutter project shell |
| 3-4 | Authentication (Supabase Auth), user management |
| 5-6 | MCP base framework (server class, client, registry) |
| 7-8 | Apple HealthKit integration (iOS) |
| 9-10 | Google Health Connect integration (Android) |
| 11-12 | Strava MCP server, integration tests |
| 13-14 | AI Brain integration (Kimi K2.5), reasoning engine |
| 15-16 | End-to-end verification with test harness |

### Phase 2: Frontend Implementation (Weeks 17-24)

**Focus:** Visual design, user experience, production UI

| Week | Deliverables |
|------|-------------|
| 17-18 | Design system setup (colors, typography, theme) |
| 19-20 | Welcome & Auth screens |
| 21-22 | Chat interface with voice input |
| 23-24 | Dashboard, Integrations hub, Settings |
| 25-26 | Navigation, animations, polish |
| 27-28 | End-to-end testing, beta release prep |

---

## 14. Success Metrics

### 14.1 Technical Metrics

- API latency < 500ms (p95)
- WebSocket connection stability > 99%
- HealthKit/Health Connect sync success rate > 98%
- App crash rate < 0.1%

### 14.2 Product Metrics

- DAU/MAU ratio > 30%
- Average messages per user per day: 10-30
- Integrations connected per user: 3-5
- 7-day retention > 40%
- 30-day retention > 25%

### 14.3 Business Metrics

- Pay conversion rate: 5-10%
- Monthly recurring revenue growth
- Customer support ticket volume
- NPS score > 50

---

## 15. Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| HealthKit HKObserverQuery reliability | Critical | Custom platform channels + health package |
| FCM push latency | Medium | Optimistic UI with "Queued..." state |
| API rate limits (Strava, Fitbit, Oura) | Medium | Intelligent caching + Celery backoff |
| App Store HealthKit rejection | Critical | Early entitlement application, clear user benefit docs |
| MCP server complexity | Medium | Start with 3 servers (Strava, Fitbit, Oura), validate pattern |

---

## 16. Deliverables Summary

### 16.1 Cloud Brain (Backend)

- [ ] FastAPI application with health endpoints
- [ ] Supabase database with user and integration models
- [ ] Authentication system (register, login, logout, token refresh)
- [ ] MCP framework (base server, client, registry)
- [ ] Strava MCP server
- [ ] Fitbit MCP server
- [ ] Oura MCP server
- [ ] Health Writer MCP server
- [ ] Kimi K2.5 LLM integration
- [ ] Reasoning engine for cross-app analysis
- [ ] WebSocket endpoint for streaming chat
- [ ] FCM push service

### 16.2 Edge Agent (Mobile App)

- [ ] Flutter project (iOS + Android)
- [ ] Authentication flow
- [ ] Apple HealthKit bridge (Swift)
- [ ] Google Health Connect bridge (Kotlin)
- [ ] Platform channel integration
- [ ] Chat UI with streaming
- [record → upload → ] Voice input ( transcribe)
- [ ] Dashboard with insight cards
- [ ] Integrations hub
- [ ] Settings screen
- [ ] Deep link handler
- [ ] Offline caching (Drift)

### 16.3 Infrastructure

- [ ] Supabase project configured
- [ ] Pinecone index created
- [ ] FCM project set up
- [ ] RevenueCat integration
- [ ] CI/CD pipeline (Codemagic)

---

## 17. Approval Request

This document represents the comprehensive implementation plan for the Life Logger MVP. The plan covers:

1. **Product vision** — Unified AI health assistant connecting fragmented fitness apps
2. **Technical architecture** — Hybrid Hub with Cloud Brain + Edge Agent
3. **Feature scope** — Chat interface, integrations, cross-app reasoning, autonomous actions
4. **Implementation roadmap** — 28-week plan (16 weeks backend, 12 weeks frontend)
5. **Business model** — $9.99/mo Pro subscription with ~78% margin
6. **Risk mitigation** — Strategies for technical and business risks

**Request:** Approval to proceed with Phase 1: Backend Implementation

---

## Appendix: Document References

| Document | Location |
|----------|----------|
| Product Requirements Document (PRD) | `docs/plans/product-requirements-document.md` |
| Architecture Design | `docs/plans/architecture-design.md` |
| Model Selection (Kimi K2.5) | `docs/plans/model-selection.md` |
| View Design | `docs/plans/view-design.md` |
| Execution Plan | `docs/plans/execution-plan.md` |
| Backend Implementation | `docs/plans/backend-implementation.md` |
| Frontend Implementation | `docs/plans/frontend-implementation.md` |
| Strava Integration | `docs/plans/integrations/strava-integration.md` |
| Apple HealthKit Integration | `docs/plans/integrations/apple-health-integration.md` |
| Google Health Connect Integration | `docs/plans/integrations/google-health-connect-integration.md` |
| CalAI Integration | `docs/plans/integrations/calai-integration.md` |
| AI Brain Integration | `docs/plans/integrations/ai-brain-integration.md` |
| App Launch Checklist | `docs/plans/app_launch_checklist.md` |

---

*End of Document*
