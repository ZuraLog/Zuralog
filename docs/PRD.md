# Zuralog — Product Requirements Document

**Version:** 3.0  
**Last Updated:** 2026-03-01  
**Status:** Living Document

---

## 1. What Zuralog Is

**Zuralog** is a centralized, AI-powered health platform that turns the fragmented landscape of fitness apps into a single intelligent system. The average health-conscious user runs 3–5 fitness apps simultaneously — CalAI for nutrition, Strava for runs, Fitbit for daily steps, Oura for sleep — yet none of these apps talk to each other. Platform hubs like Apple Health and Google Health Connect act as "dumb databases": they store numbers without providing intelligence, reasoning, or automation.

Zuralog solves this with a **Zero-Friction Connector** philosophy: instead of rebuilding features that best-in-class apps already do well, Zuralog connects those apps, reads their data, and provides a single intelligent interface on top of them.

**The platform delivers three core capabilities:**

1. **Cross-App Reasoning** — _"You're eating above your maintenance calories (CalAI) and your running frequency dropped 50% (Strava). That's why the scale isn't moving."_
2. **Autonomous Task Execution** — _"Start a run for me"_ → Zuralog deep-links to Strava's recording screen. _"Log yesterday's 5K"_ → creates a Strava activity via API.
3. **Centralized Intelligence** — One conversational interface to see, reason about, and act on all health data.

> **Core principle:** We do not rebuild features like food logging or workout tracking. We **connect** the best apps users already use, then add the intelligence layer they've always lacked.

---

## 2. Problem Statement

| Problem | Description |
|---------|-------------|
| **Fragmentation** | The average user has 3–5 fitness apps. Data is siloed; no single app connects them. |
| **Passive Hubs** | Apple Health and Google Health Connect are dumb data stores — they collect data but provide zero intelligence. |
| **Friction** | Logging across apps is tedious. Users forget to log meals, can't be bothered to enter workouts manually, and churn. |
| **No Cross-Domain Intelligence** | Single-vertical apps cannot answer "why am I not losing weight?" because the answer spans nutrition + exercise + sleep + consistency. |

---

## 3. Target Audience

### The Everyday Fitness Person (Core)
Regular people using 2–3 fitness apps who want them to work together. They track calories (CalAI), run occasionally (Strava), check their weight — and are frustrated by the manual effort and lack of connected insights.

### The Optimizer
Wears Oura or WHOOP. Tracks macros precisely. Wants deep correlation analysis between recovery scores, training load, and nutrition.

### The Life Quantifier
Tracks health, time, and money holistically. Wants Zuralog to integrate with YNAB, Todoist, and Notion to understand lifestyle tradeoffs.

---

## 4. User Scenarios

### "Why Am I Not Losing Weight?"
> Maria has CalAI and Strava connected.  
> _"Why am I not losing weight?"_  
> _"Over the last 4 weeks: Your CalAI data shows an average daily intake of 2,180 cal, but your maintenance based on Strava activity is ~1,950 cal. You're in a ~230 cal surplus. Your Strava runs dropped from 8 sessions last month to 3 this month. Would you like me to set a daily calorie target?"_

### "Start a Run For Me"
> _"Start a run for me"_ → Zuralog opens Strava to the recording screen via deep link.

### "I Forgot to Log Yesterday"
> _"I forgot to log yesterday. I had a burrito for lunch and ran 3 miles."_  
> _"Logged: Burrito (~750 cal) back-dated to yesterday noon via Apple Health. 3-mile run posted to Strava for yesterday at 6 PM."_

### "What Should I Eat?"
> _"I've hit 1,400 cal today. What should I eat for dinner to stay in deficit?"_  
> _"You've had 85g protein so far. Budget left: 400 cal. I see you usually log chicken salads in CalAI around this time — that would fit perfectly."_

### "Seamless Food Logging" (CalAI Indirect Integration)
> User logs lunch in CalAI. CalAI writes to Apple Health.  
> Zuralog (background): Detects new nutrition entry.  
> Zuralog (notification): _"Saw that Grilled Chicken Salad (420 cal) from CalAI. Nice protein hit! You're still 300 cal under your daily limit."_

---

## 5. Core Features

### AI Chat Interface
The primary interaction model. Users talk to Zuralog like a personal health assistant.
- Streaming text responses
- Voice input (Whisper STT via OpenAI API — coming soon)
- File attachments (coming soon)
- The AI has full context of all connected apps — no need to specify where data lives

### Integrations Hub
Onboarding and ongoing connection management for external apps.
- Browse available integrations by status (Connected / Available / Coming Soon)
- One-tap OAuth connection per app
- Status indicators with last sync time
- Platform compatibility awareness (iOS-only, Android-only, cross-platform)

### Cross-App AI Reasoning
The core differentiator. The AI synthesizes data across all connected apps simultaneously.
- Correlation analysis: nutrition ↔ exercise ↔ weight ↔ sleep ↔ HRV
- Trend detection: "Your running consistency dropped this month"
- Goal-aware reasoning: "Based on your goal, you need a 500 cal/day deficit"
- Proactive background insights pushed via notifications

### Autonomous Task Execution
The AI acts as a "Chief of Staff" for your apps — executing tasks, not just reporting on them.

| Action | Method | Autonomy |
|--------|--------|----------|
| Log a meal by description | Write to Apple Health / Health Connect | ✅ Fully autonomous |
| Log a manual workout | Strava API `POST /activities` | ✅ Fully autonomous |
| Start a run recording | Deep link to Strava recording screen | ⚠️ Semi (user taps Start) |
| Open CalAI camera | Deep link to CalAI | ⚠️ Semi |
| Read any connected app | API read via MCP tools | ✅ Fully autonomous |

### Unified Dashboard
At-a-glance health overview alongside the chat interface.
- Today's calories and macros (from nutrition apps)
- Week's activities and workout load (from fitness apps)
- Weight trend and body composition
- Recovery score and sleep quality (from Oura/WHOOP/Fitbit)
- AI insight card pinned at the top

### Notifications & Background Intelligence
Zuralog watches your health data in the background — even when the app isn't open.
- Background health observers (HealthKit `HKObserverQuery`, Android WorkManager)
- Real-time webhooks from Strava, Fitbit, WHOOP, Withings
- Push notifications for insights, reminders, and anomaly alerts

---

## 6. AI Persona: "The Tough Love Coach"

Zuralog's AI is not a passive dashboard. It is an active, opinionated coach that respects users enough to tell them the truth.

- **Opinionated:** "You ran 5K, but you're still 10K short of your weekly goal. You need to run tomorrow."
- **Proactive:** "I noticed you haven't logged food today. Forgetting something?"
- **Context-Aware:** "You slept 5 hours. Take it easy on the run today — keep heart rate in Zone 2."
- **Data-First:** Backs every observation with specific numbers from connected apps.

---

## 7. Integration Strategy

All external integrations are implemented as **MCP (Model Context Protocol) Servers**. This creates a plug-and-play expansion model — adding a new integration means writing a single MCP server, not rewriting the orchestration layer.

Integrations fall into two layers:
- **Cloud integrations** — REST APIs with OAuth 2.0 accessed directly by the Cloud Brain (Strava, Fitbit, Oura, WHOOP, Withings, etc.)
- **Edge integrations** — Native platform SDKs accessed by the mobile app (Apple HealthKit, Google Health Connect)

### CalAI Strategy (Indirect Integration)
CalAI and similar best-in-class apps (MyFitnessPal, Cronometer, Sleep Cycle) don't have public APIs — or their APIs are too limited. Zuralog reads their output indirectly through Apple HealthKit and Google Health Connect, which act as data aggregators. This means we don't need to rebuild computer vision for food logging — we let CalAI do that, and we add the intelligence layer on top.

See [integrations/](./integrations/) for per-integration detail.

---

## 8. AI Decision Record (ADR 001): LLM Selection

### Context
The Cloud Brain requires a highly reliable LLM to handle complex MCP tool orchestration, health data writes, and cross-app reasoning — where data corruption would be catastrophic.

**Calculated usage:** ~30 turns/day/user, ~1.35M input / ~450K output tokens/month.

### Options Evaluated

| Model | Cost/User/Month | Gross Margin | Key Tradeoff |
|-------|----------------|-------------|--------------|
| **Kimi K2.5** ✅ | ~$2.16 | ~78% | High reliability, "interleaved reasoning," slower latency |
| MiniMax M2.5 | ~$0.90 | ~91% | Cheaper but prone to "lazy coder" syndrome — risk of data corruption |
| Claude Opus 4.6 | ~$18.00 | Negative | Smartest, but catastrophic unit economics |
| Gemini 3 Pro | High | TBD | Massive context window but overkill for agentic tasks |

### Decision: Kimi K2.5 via OpenRouter

**Why Kimi K2.5:**
1. **Data integrity is the product.** In a health application, one corrupted Apple Health write (e.g., 5,000 kcal instead of 500) destroys user trust. Kimi's interleaved reasoning acts as an insurance policy against careless tool calls.
2. **78% gross margin is excellent SaaS.** Optimizing for the last 13% of margin at the expense of reliability is premature optimization.
3. **Strategic fit.** The "Tough Love Coach" persona requires nuanced reasoning across multiple data streams. Kimi's instruction-following is the most reliable for MCP schema adherence.

**Access:** Kimi K2.5 is accessed via **OpenRouter** (`moonshotai/kimi-k2.5`) rather than directly, providing routing flexibility and a single API surface.

**Mitigation of cons:**
- Implement optimistic UI in Flutter to mask latency
- Reserve Kimi for write/reasoning tasks; simpler summarization can use cheaper models in future
- Monitor blended token costs as usage scales

---

## 9. Business Model

**Strategy:** B2C Subscription (SaaS)

| Tier | Price | Features |
|------|-------|----------|
| **Free** | $0 | Read-only health store data. Basic AI chat (limited turns). |
| **Pro** | $9.99/mo | Unlimited chat + voice input. Full autonomous actions. Cross-app AI reasoning. Background insights. |

**Unit Economics (Pro, at scale):**
- LLM cost: ~$2.16/user/month (Kimi K2.5)
- Infrastructure: ~$0.50/user/month
- RevenueCat + Store fees: ~$3.00/user/month (30% App Store cut)
- **Net gross margin: ~42% post-App Store, ~78% pre-App Store**

---

## 10. Platform Architecture (Overview)

See [architecture.md](./architecture.md) for full detail.

- **Hybrid Hub:** Cloud Brain (Python/FastAPI on Railway) + Edge Agent (Flutter mobile app)
- **MCP-First:** All integrations implemented as MCP servers for plug-and-play expansion
- **Database:** Supabase (PostgreSQL) with Row Level Security
- **Background sync:** Celery + Upstash Redis for task queuing
- **Monitoring:** Sentry across all three platforms (cloud-brain, mobile, website)
