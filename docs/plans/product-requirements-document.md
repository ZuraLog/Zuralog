# Product Requirements Document (PRD): Life Logger

**Version:** 2.1
**Status:** Draft
**Date:** February 18, 2026
**Author:** AI Solutions Architect

---

## 1. Executive Summary

**Life Logger** is a mobile AI health assistant that turns the fragmented landscape of fitness apps into a single, intelligent system. Today, users juggle CalAI for nutrition, Strava for runs, Fitbit for steps, Oura for sleep — and none of these apps talk to each other. Platform hubs like Apple Health and Google Health Connect collect this data, but they are "dumb databases": they store numbers without providing any intelligence, reasoning, or automation.

Life Logger solves this by acting as a **Zero-Friction Connector** on top of the user's existing fitness ecosystem. It connects the apps users already love, reads their data, and uses an AI agent to deliver:

1.  **Cross-App Reasoning** — "You're eating above your maintenance calories (CalAI) and your running frequency dropped 50% (Strava). That's why the scale isn't moving."
2.  **Autonomous Task Execution** — "Start a run for me" → Life Logger deep-links to Strava's recording screen. "Log yesterday's 5K" → creates a manual Strava activity via API.
3.  **Centralized Intelligence** — One conversational interface to see, reason about, and act on all health data.

**Core Philosophy:** We do NOT rebuild features (like food logging or workout tracking). We **connect** the best-in-class apps that users already use.

---

## 2. Problem Statement

1.  **Fragmentation:** The average health-conscious user has 3-5 fitness apps. Data is siloed. No single app connects these dots.
2.  **Passive Hubs:** Apple Health and Google Health Connect are "dumb databases." They collect data but provide zero intelligence.
3.  **Friction:** Logging data across multiple apps is tedious. Users forget to log meals, can't be bothered to manually enter workouts, and churn.
4.  **No Cross-Domain Intelligence:** Single-vertical apps cannot answer "why am I not losing weight?" because the answer spans nutrition + exercise + sleep + consistency.

---

## 3. Target Audience

### Primary (MVP): The Everyday Fitness Person
Regular people who use 2-3 fitness apps and want them to work together. They track calories (e.g., CalAI), run occasionally (Strava), check their weight, but are frustrated by the manual work and lack of connected insights.

### Secondary (Phase 2): The Optimizer
Wears Oura/Whoop, tracks macros meticulously, wants deep correlation analysis.

### Tertiary (Phase 3): The Life Quantifier
Tracks health, time, and money. Wants Life Logger to integrate with YNAB and Todoist.

---

## 4. User Scenarios

### Scenario 1: "Why Am I Not Losing Weight?"
> **Maria** has CalAI and Strava connected.
> Maria: *"Why am I not losing weight?"*
> Life Logger: *"Over the last 4 weeks: Your CalAI data shows an average daily intake of 2,180 cal, but your maintenance based on Strava activity is ~1,950 cal. You're in a ~230 cal surplus. Your Strava runs dropped from 8 sessions last month to 3 this month. Would you like me to set a daily calorie target?"*

### Scenario 2: "Start a Run For Me"
> **Jake** has Strava connected.
> Jake: *"Start a run for me"*
> Life Logger: *Opens Strava to the recording screen via deep link. Jake taps "Start."*

### Scenario 3: "I Forgot to Log Yesterday"
> **User:** *"I forgot to log yesterday. I had a burrito for lunch and ran 3 miles."*
> Life Logger: *"Logging specific entries: Burrito (~750 cal) back-dated to yesterday noon via Apple Health. 3-mile run (~30 min) posted to Strava for yesterday at 6 PM. Done."*

### Scenario 4: "What Should I Eat?"
> **Priya** has CalAI connected.
> Priya: *"I've hit 1,400 cal today. What should I eat for dinner to stay in deficit?"*
> Life Logger: *"You've had 85g protein so far. Budget left: 400 cal. I see you usually log chicken salads in CalAI around this time — that would fit perfectly."*

### Scenario 5: "Show Me Everything"
> User opens Life Logger and sees a chat-first interface with an AI insight pinned at top:
> *"You've been consistent with runs this week but calorie intake increased 15% vs last week."*
> Below: quick-glance cards showing today's calories (from CalAI), this week's activities (from Strava), weight trend.

### Scenario 6: "Seamless Food Logging" (CalAI Integration)
> User takes a photo of their lunch in **CalAI**.
> Life Logger (background): *Detects new nutrition entry in Apple Health/Health Connect.*
> Life Logger (notification): *"Saw that Grilled Chicken Salad (420 cal) from CalAI. Nice protein hit! You're still 300 cal under your daily limit."*

---

## 5. Core Features (MVP)

### 5.1 AI Chat Interface (Chat-First Design)
The primary interaction model. Users talk to Life Logger like a personal health assistant.
- Text input with streaming AI responses
- Voice input (Whisper STT on Cloud Brain)
- **Zero-Friction Context:** The AI knows everything your other apps know.

### 5.2 App Connection Hub
Onboarding flow where users connect their fitness apps via OAuth.
- Browse available integrations
- One-tap OAuth connection per app
- Status indicators (connected/disconnected/syncing)

### 5.3 Cross-App AI Reasoning
The core differentiator. The AI synthesizes data across multiple apps.
- Correlation analysis: nutrition ↔ exercise ↔ weight ↔ sleep
- Trend detection: "Your running consistency dropped this month"
- Goal-aware reasoning: "Based on your goal, you need a 500 cal/day deficit"

### 5.4 Autonomous Task Execution
The AI acts as a "Chief of Staff" for your apps.

| Action | Method | Autonomy Level |
|--------|--------|---------------|
| Log a meal (text description) | Write to Apple Health / Health Connect | ✅ Fully autonomous |
| Log a manual workout | Strava API `POST /activities` | ✅ Fully autonomous |
| Start a run recording | Deep link to Strava recording screen | ⚠️ Semi-autonomous (user taps "Start") |
| Open CalAI camera | Deep link to CalAI | ⚠️ Semi-autonomous |
| Read data from any app | API read calls | ✅ Fully autonomous |

**(Note: We do NOT process food photos directly. We rely on CalAI/MyFitnessPal to do that, and we read the result.)**

### 5.5 Unified Data Dashboard
Quick-glance cards within the chat interface showing aggregated stats:
- Today's nutrition (calories, protein from Health Store)
- This week's activities (from Strava)
- Weight trend (from Health Store)
- AI insight card at the top

---

## 6. Integration Strategy

### 6.1 Integration via MCP (Model Context Protocol)
All external app integrations are implemented as **MCP Servers**. This allows plug-and-play expansion.

### 6.2 MVP Integrations (Top 5 + Platform Health Stores)

| Priority | Integration | API Status | Type | Data We Read | Data We Write |
|----------|------------|------------|------|-------------|---------------|
| **P0** | **Apple HealthKit** | Native SDK | Edge | Weight, nutrition (from CalAI), workouts, sleep | Nutrition entries, workout summaries |
| **P0** | **Google Health Connect** | Native SDK | Edge | Same as HealthKit (Android) | Same as HealthKit |
| **P0** | **Strava** | Public REST API v3 | Cloud | Activities, stats, GPS | Manual activities, updates |
| **P1** | **Fitbit** | Public Web API | Cloud | Steps, sleep stages, HR, weight | — (Read-only) |
| **P1** | **Oura Ring** | Public API v2 | Cloud | Sleep, readiness, HRV, temp | — (Read-only) |
| **P2** | **WHOOP** | Public API | Cloud | Recovery, strain, sleep | — (Read-only) |
| **P2** | **Garmin Health** | REST API | Cloud | Steps, sleep, stress, Body Battery | — (Read-only) |

### 6.3 CalAI Strategy (The "Zero-Friction" Approach)
- **Primary Data Flow:** User logs food in CalAI (or any nutrition app).
- **Sync:** CalAI writes to Apple Health / Health Connect.
- **Read:** Life Logger reads from Apple Health / Health Connect.
- **Benefit:** We don't rebuild complex computer vision features. We let CalAI do what it does best, and we act as the intelligence layer on top of it.
- **Future:** If CalAI exposes a public API for richer data (meal photos, timestamps) that isn't in HealthKit, we can integrate directly.

---

## 7. Business Model

**Strategy:** B2C Subscription (SaaS)

- **Free Tier:** Read-only access to health store data. Basic chat.
- **Pro Tier ($9.99/mo — Early Adopter):** Unlimited chat & voice. Full autonomous actions (deep links, API writes). Cross-app AI reasoning.

---

## 8. Technical Architecture Overview

See the companion [Architecture Design Document](file:///c:/Projects/life-logger/docs/plans/architecture-design.md).
- **Hybrid Hub Architecture:** Cloud Brain (Python/FastAPI) + Edge Agent (Flutter/Dart).
- **MCP-First:** All integrations via MCP servers.
- **Connector Philosophy:** We build "bridges", not "islands".

---

## 9. Functional Requirements

### 9.1 The Connector Layer (Autonomy)
- **Deep Linking:** Library of URI schemes (`strava://`, `calai://`, `myfitnesspal://`) to launch apps to specific screens.
- **Background Observation:** `HKObserverQuery` / `WorkManager` to detect when *other* apps write data. This is critical for the "I saw you logged X" feedback loop.

### 9.2 AI Reasoning Engine
- **Narrator, not Calculator:** Uses deterministic stats (Pearson correlations) to find patterns, uses LLM to explain them.
- **Data Normalization:** Converts all incoming data (Strava runs, Oura sleep, CalAI food) into a standard format for analysis.

---

## 10. Roadmap

### Phase 1: MVP — "The Smart Hub" (3-4 months)
- Chat-first AI interface (text, voice)
- Apple Health + Health Connect (read/write)
- Strava integration (read/write)
- Fitbit + Oura (read-only)
- **Zero-Friction Connector:** Deep links to CalAI, Strava; auto-reading data from them.
- Cross-app AI reasoning.
- App connection onboarding.

### Phase 2: "The Connected Self" (2-3 months post-MVP)
- WHOOP + Garmin integrations.
- Morning Briefing (daily summary).
- Smart Reminders ("You haven't run in 5 days").
- Goal tracking.

### Phase 3: "The Life OS"
- Notion, YNAB, Todoist integrations.
- Bi-directional triggers ("If sleep < 30%, reschedule workout").