# Zuralog MVP Feature Specification

> **Last updated:** 2026-03-16
>
> **Purpose:** This document defines every feature shipping in the initial App Store release (MVP) and documents justified post-MVP features for future development. It is the single source of truth for what Zuralog does.
>
> **Related docs:** [PRD](./PRD.md) | [Architecture](./architecture.md) | [Screens](./screens.md) | [Design](./design.md) | [Roadmap](./roadmap.md) | [Infrastructure](./infrastructure.md)

---

## Table of Contents

1. [Feature Philosophy](#1-feature-philosophy)
2. [MVP Features — AI & Intelligence Layer](#2-mvp-features--ai--intelligence-layer)
3. [MVP Features — Data & Health Management](#3-mvp-features--data--health-management)
4. [MVP Features — Onboarding & Personalization](#4-mvp-features--onboarding--personalization)
5. [MVP Features — Engagement & Retention](#5-mvp-features--engagement--retention)
6. [MVP Features — Speech & Input](#6-mvp-features--speech--input)
7. [MVP Features — Data Maturity & Transparency](#7-mvp-features--data-maturity--transparency)
8. [Consolidated Design Impact Summary](#8-consolidated-design-impact-summary)
9. [Observability & Analytics Principles](#9-observability--analytics-principles)
10. [Feature-Level Settings Reference](#10-feature-level-settings-reference)
11. [Post-MVP Features](#11-post-mvp-features)
12. [GitHub Issue Titles](#12-github-issue-titles)

---

## 1. Feature Philosophy

Zuralog is not another fitness tracker. It is an AI-powered health intelligence layer that sits on top of the apps users already love. Every feature decision is filtered through three principles:

### Zero-Friction Data Flow

Data should arrive automatically from connected apps via background sync (HealthKit observers, Health Connect WorkManager, webhook-driven integration syncs). When manual input is needed, natural language via the AI coach is the primary interface, with dedicated UI as a secondary path. The user should never feel like they are doing data entry.

### AI Earns Its Place

The AI does not just summarize data users can already see in their source apps. It cross-references sources (sleep from Oura + activity from Strava + nutrition from CalAI via HealthKit), detects anomalies against personal baselines, suggests correlations the user would never discover manually, and provides actionable insight. Every AI feature must answer: "Could the user get this from any single app they already have?" If yes, the feature is not differentiated enough.

### Premium by Default

Every interaction should feel like a $200/month health concierge, not a free pedometer. OLED-black canvas, confident typography, purposeful animation, haptic feedback on meaningful moments. The design language (see [design.md](./design.md)) targets Apple Fitness+ caliber — editorial, typographic, and award-worthy.

### MVP Scope

27 features spanning AI intelligence, health data management, personalization, engagement mechanics, and UX polish. The MVP proves the core thesis: connecting your health apps to an intelligent AI coach creates value none of them can deliver alone.

### Post-MVP Scope

14 documented features for subsequent releases, including social features, advanced AI programs, home screen widgets, a document vault, and a family plan.

---

## 2. MVP Features — AI & Intelligence Layer

These 14 features are the core differentiator. They are what makes Zuralog more than a dashboard.

### A. AI Conversation (Coach Tab)

**Implementation status:** Core WebSocket chat exists. UI rebuild planned per [screens.md](./screens.md).

The primary interface for interacting with Zuralog's intelligence. Users converse with an AI coach (Kimi K2.5 via OpenRouter) that has full context of their connected health data across all integrations. The orchestrator uses a ReAct-style tool-calling loop — it reasons about the question, calls MCP tools to fetch real data from connected integrations, and responds with specific numbers rather than generic advice.

**Capabilities:**
- Real-time streaming responses via WebSocket with REST fallback for history
- Full conversation history persisted server-side with AI-generated titles
- Conversation drawer for managing past threads (list, rename, delete, archive)
- Quick Actions sheet (bottom sheet with pre-built common tasks: "Log a meal", "Start a run", "How did I sleep?", "What should I eat?")
- Voice input via on-device speech-to-text (hold-to-talk, 30-second max session)
- Markdown rendering in AI responses (tables, bold/italic, lists, code blocks for data)
- Per-user rate limiting (free tier: 50 messages/day, pro tier: 500/day)
- Dynamic tool injection — the AI only has access to tools for integrations the user has actually connected, reducing token waste by ~90% for single-integration users

**User settings:** Rate limit is determined by subscription tier. No additional user-facing settings for core chat — persona and proactivity are configured separately (see [Feature S](#s-post-signup-onboarding-flow)).

### B. AI Long-Term Memory

**Implementation status:** Pinecone environment variable configured. `MemoryStore` protocol defined with `InMemoryStore` placeholder. No vector store implementation yet. MCP tools `save_memory` and `query_memory` exist in the orchestrator.

The AI remembers context across conversations. When a user mentions they are training for a marathon, started a new medication, or has a knee injury, the AI retains this and factors it into all future responses without the user needing to repeat themselves.

**How it works:**
- Pinecone vector store for semantic memory persistence (replacing the current ephemeral `InMemoryStore`)
- Automatic extraction of key facts from every conversation (the orchestrator identifies health-relevant statements and stores them as embeddings)
- Memory-aware system prompt injection: before each AI response, the orchestrator retrieves the most relevant stored memories based on the current query and includes them as context
- File attachment content is extracted and stored as memory (see [Feature C](#c-file-attachments-in-chat))
- Memories are namespaced per user with Supabase user ID

**User settings:** Settings > Privacy & Data: view all stored memories as a list, delete individual memories, clear all memory with confirmation dialog. Users must have full control over what the AI remembers about them.

### C. File Attachments in Chat

**Implementation status:** Not implemented. Listed as "Future" in [roadmap.md](./roadmap.md).

Users attach files directly in the AI conversation. The AI processes the content in-context using Kimi K2.5's native multimodal capabilities (trained on ~15T mixed visual and text tokens) AND extracts key health information into long-term memory.

**Supported formats:** Images (JPEG, PNG, HEIC), PDFs, text documents (.txt, .csv)

**Behavior:**
- User taps the attachment button in the chat input bar, selects a file from device storage or takes a photo
- The file is uploaded to the Cloud Brain and passed to Kimi K2.5 as part of the conversation context
- The AI reads the content and responds conversationally (e.g., "I can see your blood work results. Your vitamin D is at 22 ng/mL, which is below the recommended 30-50 range.")
- Key health facts are automatically extracted and stored in the vector memory (e.g., "Vitamin D level: 22 ng/mL as of 2026-02-15")
- The original file is not stored in a permanent vault — the extracted knowledge is what persists in memory
- A confirmation card is shown to the user listing what facts the AI extracted and will remember

**Constraints:** 10MB per attachment, 3 attachments per message. Unsupported file types show an error message with the list of supported formats.

**User settings:** No dedicated toggle — attachment functionality is always available in chat. Memory extraction follows the same controls as AI Long-Term Memory (users can delete extracted memories in Privacy & Data settings).

### D. AI Insights (Today / Weekly / Monthly)

**Implementation status:** Backend `InsightGenerator` exists (rule-based priority system). Today Feed screen planned in [screens.md](./screens.md). Weekly/Monthly report generation endpoints not built.

Three tiers of AI-generated intelligence delivered proactively at different cadences:

**Daily Insights (Today Feed):**
- AI-curated insight cards surfaced each day on the Today tab
- Generated by a Celery background job that runs after new health data is ingested
- Card types: sleep analysis, activity progress, nutrition summary, anomaly alerts, goal nudges, correlation discoveries
- Time-aware content ordering (see [Feature Y](#y-time-of-day-ui-awareness))
- Each card is tappable — opens an Insight Detail screen showing the full data, AI reasoning, source integrations that contributed, and a "Discuss with Coach" button that opens a new chat pre-filled with context

**Weekly Report (Story-Style Recap):**
- Auto-generated every Monday morning
- Presented as an Instagram-story-style swipeable card sequence: week summary > top metrics > streaks and goals > AI highlights > areas for improvement > next week focus
- Each card has charts, numbers, and AI commentary
- Shareable as a rendered image (organic growth mechanism)
- Stored in the app for historical reference

**Monthly Report:**
- Comprehensive health review generated on the 1st of each month
- Trend analysis across all tracked categories, goal completion rates, correlation discoveries, AI recommendations for the coming month
- Exportable as PDF or shareable image
- Accessible from the Trends tab Reports screen

**User settings:** Settings > Notifications: toggle for daily insight notifications, weekly report notification, monthly report notification. The reports are always generated and accessible in-app regardless of notification preference.

### E. AI Morning Briefing (Push Notification)

**Implementation status:** FCM push infrastructure fully built. `PushService` operational. Triggering logic for scheduled briefings not implemented.

A personalized push notification delivered at a user-configured time each morning:

- Content: 2-3 sentence briefing covering how the user slept (if sleep data is available), what the body needs today based on recent trends, and one concrete actionable suggestion
- Generated by a Celery scheduled task that runs per-user based on their configured briefing time
- Tapping the notification opens the Today Feed with the full daily briefing expanded
- Falls back gracefully when data is limited: "Good morning. Connect a sleep tracker to get personalized sleep insights, or tell me how you slept."

**User settings:** Settings > Notifications: Morning Briefing toggle (on by default for pro users, off for free), time picker (default: 7:00 AM local time).

### F. AI Conversation Starters (Personalized Prompts)

**Implementation status:** The New Chat screen in [screens.md](./screens.md) specifies "suggested prompt chips." Current implementation uses generic/static prompts.

When opening a new chat, users see contextual suggested prompts generated from their actual recent data — not static templates.

**How it works:**
- A backend endpoint analyzes the user's latest synced data and generates 3-5 relevant prompt suggestions
- Prompts reference specific data points: "Why was my HRV 15ms lower than usual last night?", "Compare my sleep this week vs last week", "I hit 12,000 steps yesterday — is that above my average?"
- Refreshed each time the user opens a new chat
- Tapping a prompt chip starts the conversation with that message pre-filled
- Fallback to smart defaults when data is insufficient: "What can you help me with?", "How do I get the most out of Zuralog?", "Tell me about my connected apps"

**User settings:** None — this is a contextual UI element that adapts automatically.

### G. Contextual Quick Actions

**Implementation status:** Quick Actions sheet planned in [screens.md](./screens.md) Coach Tab. Context-awareness logic not implemented.

The AI detects user context (time of day, recent data events, patterns) and surfaces relevant actions dynamically in the Today Feed and Quick Actions sheet:

- **Post-workout detection** (new activity synced): suggest logging a post-workout meal, rating recovery, or logging energy level
- **Late evening** (after 8pm): suggest reviewing the day, setting a sleep goal, or winding down
- **Sunday/Monday**: suggest reviewing the week or setting weekly goals
- **Missed logging day** (no manual entries in 24h when the user typically logs): suggest back-filling yesterday's data
- **Goal proximity** (close to hitting daily target): "You're 800 steps from your goal — a 10 minute walk would do it"
- **New integration connected**: suggest exploring the new data ("You just connected Strava — want to see your running trends?")

Actions are surfaced as tappable cards in the Today Feed and as prioritized items in the Quick Actions bottom sheet.

**User settings:** Governed by the proactivity level setting (Low/Medium/High) configured in Coach Settings. Low = only explicit user-triggered actions. High = proactive suggestions throughout the day.

### H. Metric Anomaly Detection

**Implementation status:** `TrendDetector` module exists in the analytics engine (moving average comparison). Anomaly detection (deviation from personal baseline) not implemented.

The AI flags when a health metric deviates significantly from a user's established personal baseline:

**Detection logic:**
- Maintains a rolling 30-day average and standard deviation per metric per user
- Triggers when a new reading exceeds 2 standard deviations from the personal mean
- Requires a minimum of 14 days of data before activating (silently builds baseline during data maturity period)
- Runs as part of the post-ingest Celery pipeline — whenever new health data arrives, check for anomalies

**Delivery:**
- Anomaly insight card in the Today Feed with the specific metric, current value, baseline value, and deviation magnitude
- Optional push notification for high-severity anomalies (e.g., resting heart rate +15bpm)
- Tapping opens Insight Detail with full context and a "Discuss with Coach" button

**Examples:**
- "Your resting heart rate is 78bpm — 12bpm higher than your 30-day average of 66bpm"
- "You slept 4.5 hours — 2.5 hours less than your typical 7 hours"
- "Your HRV dropped to 18ms — significantly below your baseline of 42ms"

**User settings:** Settings > Notifications: Anomaly alerts toggle (on by default). The detection runs regardless of notification preference — anomalies always appear in the Today Feed.

### I. Health Score / Readiness Score

**Implementation status:** Not implemented. No backend or frontend code exists.

A single composite 0-100 daily score that answers "How is my body doing today?" by combining data from ALL connected sources — not just one wearable.

**Score calculation:**
- Inputs (weighted by recovery impact): sleep duration and quality (30%), HRV (20%), resting heart rate (15%), activity level relative to personal baseline (15%), sleep consistency / bedtime regularity (10%), step count relative to goal (10%)
- Each input is normalized to a 0-100 sub-score based on the user's personal 30-day history (percentile-based)
- Missing inputs are excluded from the weighted average (the weights redistribute proportionally)
- Minimum requirement: at least one sleep OR one activity data source connected to generate a score

**Display:**
- Hero widget at the top of the Today Feed and the Health Dashboard (Data Tab)
- Animated ring/gauge visualization with color coding: red (0-39), yellow (40-69), green (70-100)
- Trend sparkline showing the last 7 days
- AI commentary explaining what drove the score: "Your score dropped 12 points because your sleep was 2 hours shorter than usual and your HRV is below baseline"
- Tappable — opens a detail view showing each input's contribution

**Differentiator from WHOOP/Oura:** Those scores use data from a single wearable. Zuralog's Health Score combines sleep from Oura + activity from Strava + HRV from Apple Watch + nutrition from CalAI — a holistic picture no single device can produce.

**User settings:** None — the score is always calculated when sufficient data exists. Users can hide the widget on the dashboard via the existing show/hide card toggle.

### J. Common Correlation Suggestions

**Implementation status:** Not implemented. The backend `CorrelationAnalyzer` exists but only analyzes data the user already has.

AI suggests what additional data the user should track to unlock better insights, based on their stated goals and existing data gaps:

**Trigger points:**
- During onboarding after goals are selected (Step 2 of the onboarding flow)
- In the Today Feed when the AI detects data gaps that limit insight quality
- In the Trends tab as suggestion cards alongside existing correlations

**Logic:**
- Goal "Lose Weight" + no nutrition data → "Connect CalAI or log your meals to unlock calorie balance insights"
- Goal "Improve Sleep" + no HRV data → "An Apple Watch or Oura Ring would let me track your HRV — a key sleep quality predictor"
- Goal "Run Faster" + Strava connected but no sleep data → "Connecting a sleep tracker would let me analyze how your recovery affects running performance"
- Has activity + sleep but no nutrition → "Adding nutrition tracking would complete the picture — I could tell you if your diet is helping or hurting your training"

**Presentation:** Suggestion cards with an icon, one-sentence explanation, and a CTA button ("Connect App" or "Start Logging"). Dismissable — once dismissed, a suggestion does not reappear for 30 days.

**User settings:** None — suggestions are informational and dismissable. They disappear naturally as data gaps are filled.

### K. Natural Language Logging via Chat

**Implementation status:** Partially exists — the AI orchestrator can invoke MCP tools to write health data (via FCM to the device for HealthKit/Health Connect writes). No explicit "logging mode" or confirmation UI.

Users log any health data by typing or speaking naturally in the chat — no forms, no navigation:

**Supported log types:**
- Hydration: "I drank 3 glasses of water today"
- Subjective metrics: "My energy is 7/10, mood is 8/10, stress is 3/10"
- Nutrition (approximate): "I ate a chicken salad for lunch, about 500 calories"
- Activity (manual): "I did a 30 minute yoga session"
- Notes: "I have a headache today" or "Felt dizzy after standing up"
- Supplements: "Took my creatine and vitamin D this morning"

**Behavior:**
- The AI parses the natural language input and identifies loggable data
- A confirmation card is displayed showing what the AI will log (metric, value, timestamp) before committing
- User taps "Confirm" to log or "Edit" to adjust values
- Logged data flows into the analytics engine and feeds into correlations, trends, and the Health Score
- Key facts are also stored in long-term memory for future reference

**User settings:** None — this is a core interaction pattern of the chat interface, always available.

### L. Food Photo Logging

**Implementation status:** Not implemented. Kimi K2.5 natively supports multimodal vision input.

User takes or selects a photo of their meal in the chat. Kimi K2.5's vision capabilities analyze the image and estimate nutritional content:

**Flow:**
1. User taps the camera/attachment button in chat, selects "Take Photo" or picks from gallery
2. Photo is sent as part of the chat message
3. AI analyzes the image: identifies visible foods, estimates portion sizes based on visual cues (plate size, utensil reference)
4. AI responds with estimated breakdown: calories, protein, carbs, fat, and identified food items
5. User reviews and confirms or adjusts the estimates
6. Confirmed data is logged as a nutrition entry and feeds into daily calorie tracking and AI insights

**Accuracy expectations:** This is an estimation tool, not a precise measurement. The AI should communicate this clearly: "Based on the photo, I estimate this is roughly 650 calories. For more precise tracking, you can adjust the values." Users who need exact macro tracking should use a dedicated app like CalAI (which syncs to Zuralog via HealthKit automatically).

**User settings:** None — this is part of the chat attachment flow. The feature is available whenever the user sends a food photo in conversation.

---

## 3. MVP Features — Data & Health Management

These 6 features cover how users view, manage, and interact with their health data.

### M. Customizable User Dashboard (Data Tab)

**Implementation status:** Planned in [screens.md](./screens.md) Health Dashboard specification. Not implemented.

The user's personal health command center with full layout customization:

**Layout:**
- Health Score widget displayed prominently at the top as the hero element
- Below: a grid/list of health category cards (up to 10 categories: Activity, Body, Heart, Vitals, Sleep, Nutrition, Cycle, Wellness, Mobility, Environment)
- Each card shows: category name, primary metric value, sparkline trend (7-day), delta indicator (up/down arrow with percentage)

**Customization:**
- Drag-and-drop card reorder (long-press to enter reorder mode)
- Show/hide toggle per category (categories with no data are hidden by default but can be manually shown)
- Accent color override per category card (defaults to the category color defined in [design.md](./design.md), user can pick from a palette)
- Layout persisted server-side per user for cross-device consistency

**Navigation:**
- Tapping a category card opens the Category Detail screen with rich charts and time-range selectors
- Category Detail > tapping a specific metric opens the Metric Detail screen with pinch-to-zoom, data source attribution, raw data table, and "Ask Coach about this" button

**User settings:** All customization (order, visibility, colors) is persisted automatically. No separate settings screen needed — the customization is inline on the dashboard itself.

### N. Deep Analytics & Correlations (Trends Tab)

**Implementation status:** Backend `CorrelationAnalyzer`, `TrendDetector`, `GoalTracker`, and `InsightGenerator` modules exist. Frontend Trends Tab screens planned in [screens.md](./screens.md) but not built.

Interactive analytics that let users discover patterns in their own data:

**Trends Home:**
- AI-generated correlation cards surfaced proactively: "Your sleep quality improves 23% on days you run" or "Your HRV is 8ms higher on days you eat under 2000 calories"
- Time-machine strip for browsing historical daily summaries (swipe through dates)
- Common Correlation Suggestion cards when data gaps limit analysis (see [Feature J](#j-common-correlation-suggestions))

**Correlations Explorer:**
- Interactive two-metric correlation explorer: user selects any two metrics from a picker
- Visualization: scatter plot with trend line, overlay time-series charts
- Pearson correlation coefficient displayed with plain-language interpretation ("Strong positive correlation", "Weak negative correlation", "No significant correlation")
- Lag support: "Does sleep quality affect next-day HRV?" (1-day, 2-day, 3-day lag analysis)
- AI annotation on each correlation: what it means and what to do about it

**Reports:**
- Monthly health report generated on the 1st of each month
- Exportable as PDF or shareable image
- Sections: category summaries, top correlations, goal progress, trend directions, AI recommendations

**Data Sources:**
- Data provenance transparency: which integration contributed which data points
- Per-integration data type breakdown
- Sync status and freshness indicators (see [Feature Q](#q-integration-health-monitor))

**Time-range selectors:** 7 days, 30 days, 90 days, and custom date range across all analytics views.

**User settings:** None — analytics are always available. Report generation notifications are controlled in notification settings.

### O. Quick Log / Manual Entry

**Implementation status:** Part 1 UI foundation complete (2026-03-16). Shared components created: `ZSnapshotCard` for metric display, `ZDailyGoalsCard` for goal tracking. Stub providers added (`todayLogSummaryProvider`, `userLoggedTypesProvider`, `logRingProvider`, `snapshotProvider`) pending real data wiring in Part 4. Water counter with units-aware label wired in feat/today-tab-settings-wiring (2026-03-08). Full Quick Log bottom sheet (mood, energy, stress, pain, notes) and FAB system planned for Part 2.

A dedicated quick-entry interface for data that does not come from integrations. This is the structured complement to natural language logging in chat — for users who prefer tapping over typing.

**Access points:**
- Quick Log button in the Today Feed (persistent, always visible)
- Quick Log option in the Quick Actions bottom sheet (Coach Tab)
- "Log" shortcut in the bottom navigation bar (optional — accessible via long-press on Today tab)

**Quick Log bottom sheet contents:**
- **Water:** tap-to-increment counter (glasses or ml), daily total shown
- **Mood:** 1-10 slider with emoji scale
- **Energy:** 1-10 slider
- **Stress:** 1-10 slider
- **Sleep quality:** 1-10 slider (for users without sleep wearables)
- **Pain/Symptoms:** text field with common symptom chips (headache, fatigue, soreness, nausea, dizziness) plus free-text
- **Notes:** free-text field for any context ("started new medication", "stressful day at work")

**Behavior:**
- Each metric is a single tap or slide — the entire check-in should take under 15 seconds
- Logged data appears in the relevant Category Detail screens and feeds into AI analytics
- History is viewable per metric in the Metric Detail screen

**User settings:** Settings > Privacy & Data: Wellness Check-in toggle controls whether the daily check-in prompt appears. The Quick Log entry point in the UI is always available regardless of this setting.

### P. Wearable-Free Wellness Check-in

**Implementation status:** Partially implemented. Card visibility gated on Privacy & Data toggle (feat/today-tab-settings-wiring, 2026-03-08). Full check-in flow (subjective rating prompt, push notification trigger) not yet implemented.

A daily prompted check-in for users who do not have wearables or who want to add subjective context alongside device data:

**Trigger:**
- Push notification at user-configured time (default: 9:00 AM)
- Card in the Today Feed (appears once daily until completed or dismissed)

**Check-in flow:**
- Compact inline card that expands in the Today Feed (not a separate screen)
- Rate: energy (1-10), mood (1-10), stress (1-10), sleep quality (1-10)
- Optional free-text note for context ("felt anxious about work", "great workout this morning")
- Submit button logs all values at once
- Total interaction time: under 30 seconds

**Value for AI:**
- Subjective data fills gaps that wearables cannot capture (mood, stress, perceived energy)
- Enables correlations like "Your mood rating is 2 points higher on days you exercise" or "Your stress spikes on Mondays"
- For users with no wearables at all, this is the primary data input that powers AI insights

**Relationship to Quick Log:** The Wellness Check-in is a prompted, time-based version of the Quick Log. The Quick Log bottom sheet is available anytime on-demand. They share the same underlying data storage.

**User settings:** Settings > Privacy & Data: toggle to enable/disable the daily check-in prompt (on by default). Settings > Notifications: check-in reminder time picker.

### Q. Integration Health Monitor

**Implementation status:** Backend `Integration` model tracks `sync_status` (idle/syncing/error), `sync_error`, and `last_synced_at`. Data Sources screen planned in [screens.md](./screens.md) Trends Tab. Staleness detection and proactive alerts not implemented.

Transparency into data flow health and connection status:

**Display (Data Sources screen in Trends Tab):**
- Per-integration card showing: integration name, icon, connection status, last sync timestamp, data types contributed, staleness indicator
- Staleness indicator: green (synced within 1 hour), yellow (synced within 24 hours), red (not synced in 24+ hours or error state)
- One-tap reconnect button for integrations in error state (re-triggers OAuth flow)
- Data type breakdown per integration (what categories and metrics each app contributes)

**Display (Integrations Hub in Settings):**
- Compact sync status badge on each connected integration card (green dot, yellow dot, red dot)
- Last synced timestamp shown under each integration name

**Proactive alerts:**
- Push notification if an integration stops syncing for 24+ hours: "Your Fitbit hasn't synced in 24 hours. Tap to reconnect."
- Today Feed card for stale integrations with a reconnect CTA

**User settings:** Settings > Notifications: Integration alerts toggle (on by default).

### R. Emergency Health Card

**Implementation status:** Not implemented. Not in current [screens.md](./screens.md).

A quick-access screen displaying critical medical information for emergency situations:

**Content:**
- Blood type (user-entered in profile)
- Known allergies (list, user-managed)
- Current medications (list, user-managed)
- Emergency contacts (name, relationship, phone number — up to 3)
- Medical conditions (list, user-managed — e.g., "Type 1 Diabetes", "Asthma")

**Access:**
- Accessible from Profile screen (prominent card/button)
- Accessible from Settings Hub as a dedicated row

**Design:**
- High-contrast, large text for readability in emergencies
- Minimal chrome — information density is the priority
- Works offline — data cached locally on device

**Data source:** User-entered via the Emergency Health Card edit screen. The AI is aware of this information (medications, allergies, conditions feed into long-term memory) and factors it into health advice.

**User settings:** All fields are user-managed in the Emergency Health Card edit view. No automatic population — the user explicitly enters and maintains this data.

---

## 4. MVP Features — Onboarding & Personalization

These 3 features configure the app to the user's needs and teach them how to use it.

### S. Post-Signup Onboarding Flow

**Implementation status:** `ProfileQuestionnaireScreen` exists as a single screen. The backend `User` model has `onboarding_complete`, `coach_persona`, and `birthday`/`gender` fields. Needs expansion to a multi-step flow.

A comprehensive onboarding flow immediately after account creation that configures the entire app experience. Designed to complete in under 2 minutes.

**Step 1 — Welcome & Value Prop** (1 screen)
- Brief animation showing data flowing from multiple app icons into the Zuralog logo
- Headline: "Your health apps, one intelligent brain"
- Subtext: "Let's personalize your experience in 2 minutes"
- CTA: "Get Started"

**Step 2 — Goals Selection** (1 screen)
- Multi-select grid of predefined goals with icons:
  - Lose Weight
  - Build Muscle
  - Improve Sleep
  - Run Faster / Further
  - Reduce Stress
  - General Wellness
  - Train for an Event
  - Recover from Injury
- Minimum 1 selection required, no maximum
- Selected goals drive: AI conversation context, correlation suggestions, Today Feed content priority, dashboard card ordering, smart reminder topics

**Step 3 — AI Coach Personality** (1 screen)
- Three persona cards with name, description, and an example response:
  - **Tough Love Coach** (recommended, indicated with a badge): "You skipped 3 runs this week. Your 5K time is going to suffer. Get out there tomorrow."
  - **Balanced Coach**: "You missed a few runs this week. Let's plan a shorter run tomorrow to get back on track."
  - **Gentle Coach**: "It's been a quiet week for running. Whenever you're ready, even a short jog would be great."
- Below the persona selection: Proactivity level toggle
  - Low: "I'll wait for you to ask"
  - Medium (default): "I'll share insights when I notice something important"
  - High: "I'll check in throughout the day with suggestions and nudges"

**Step 4 — Connect Your Apps** (1 screen)
- Show top integrations with one-tap connect buttons:
  - Apple Health (iOS) / Google Health Connect (Android) — highlighted as recommended
  - Strava
  - Fitbit
  - Oura Ring
  - Withings
  - Polar
- "Connect at least one app to unlock AI insights" prompt
- Skip button available — the app works without integrations via manual logging and wellness check-ins
- Trigger Common Correlation Suggestions (Feature J) based on selected goals if the user skips

**Step 5 — Notification Preferences** (1 screen)
- Morning Briefing: toggle + time picker (default: 7:00 AM)
- Smart Reminders: toggle (default: on)
- Wellness Check-in: toggle + time picker (default: 9:00 AM)
- Brief explanation of each: what it does, why it helps

**Step 6 — Discovery Question** (1 screen)
- "Where did you hear about Zuralog?" — dropdown options:
  - App Store / Play Store
  - Friend or Family
  - Social Media (Instagram, TikTok, X, etc.)
  - Podcast
  - Blog / Article
  - YouTube
  - Other
- Non-blocking: user can skip
- Data sent to PostHog for marketing attribution analysis

**Completion:** After Step 6, the user lands on the Today Feed with a welcome insight card and their first onboarding tooltips.

**User settings:** Users can redo any onboarding choice later: Coach Settings (persona, proactivity), Account (goals), Notifications (briefing, reminders, check-in). The discovery question is one-time and not re-editable.

**Design Impact:** Replaces the current single `ProfileQuestionnaireScreen` with a 6-step paginated flow. Update [screens.md](./screens.md) Auth & Onboarding section to specify each step.

### T. Per-Screen Onboarding Tooltips

**Implementation status:** Not implemented. Not in current [screens.md](./screens.md).

Contextual tooltip overlays that guide users through each major screen on their first visit:

**Behavior:**
- Triggered automatically on first visit to each tab/screen
- Coach-style tooltip bubble with a subtle pointer arrow aimed at the relevant UI element
- Short, actionable copy: 1-2 sentences maximum
- "Got it" dismiss button — tooltip never shown again for that screen
- Sequential: if a screen has multiple tooltips, they appear one at a time, each after dismissing the previous

**Tooltip content per screen:**
- **Today Feed:** "This is your daily briefing. It updates throughout the day based on your data and the time of day."
- **Health Dashboard:** "This is your data command center. Long-press a card to reorder, or tap the edit button to show/hide categories."
- **Coach Tab (New Chat):** "Ask me anything about your health. I can see data from all your connected apps and remember our past conversations."
- **Progress Tab:** "Set goals and I'll track your streaks automatically. Consistency is what matters most."
- **Trends Tab:** "This is where patterns hide. I'll surface correlations you'd never find on your own."
- **Quick Log:** "Tap here anytime to quickly log water, mood, energy, or anything else."

**Implementation:** A shared `OnboardingTooltip` widget that any screen can invoke. Tooltip seen/unseen state stored in local SharedPreferences per screen key.

**User settings:** Settings > Appearance: "Reset Onboarding Tooltips" button to re-enable all tooltips. Global "Disable Tooltips" toggle for users who do not want them.

### U. Dark/Light Mode Toggle

**Implementation status:** Dark mode fully built as the primary and default theme. Light mode listed as "supported" in [design.md](./design.md) but light mode color tokens are not defined.

A polished theme switcher with three options:

**Options:**
- **Dark** (default): OLED true black canvas, current design system
- **Light**: Inverted surface hierarchy with white/light gray backgrounds, same sage green accent, same Inter typography, same component shapes and proportions
- **System**: Follows the device OS setting (iOS appearance, Android dark theme toggle)

**Transition:** Smooth animated theme crossfade (200ms) when switching.

**Light mode token requirements (to be added to [design.md](./design.md)):**
- `scaffoldBackgroundColor`: `#FFFFFF` (true white)
- `colorScheme.surface`: `#F2F2F7` (iOS system gray 6)
- `cardBackground`: `#FFFFFF` (white cards on gray background)
- `elevatedSurface`: `#FFFFFF` (bottom sheets, drawers)
- `divider`: `#E5E5EA` (iOS system gray 5)
- `inputBackground`: `#F2F2F7`
- `textPrimary`: `#000000`
- `textSecondary`: `#636366`
- `textTertiary`: `#ABABAB`
- All category accent colors remain unchanged (they are designed to work on both dark and light backgrounds)

**User settings:** Settings > Appearance > Theme selector (Dark / Light / System). Default: Dark.

**Design Impact:** Requires defining the full light mode color token set in [design.md](./design.md). All screens must use theme tokens (via `AppColors`) and never hardcoded hex values to ensure both modes work correctly.

---

## 5. MVP Features — Engagement & Retention

These 4 features create engagement loops that bring users back daily.

### V. Gamification System (Streaks, Goals, Achievements)

**Implementation status:** `UserGoal` model exists in the backend with CRUD endpoints. `GoalTracker` analytics module calculates progress and streaks. Frontend Progress Tab screens (Progress Home, Goals, Goal Detail, Achievements, Weekly Report) planned in [screens.md](./screens.md) but not built. Achievement/badge model does not exist.

A multi-layered engagement system that rewards consistency without feeling gimmicky:

**Goals:**
- Full CRUD: create, edit, delete, toggle active/inactive
- Goal types: weight target, daily step count, weekly run count, daily calorie limit, sleep duration target, daily water intake, custom numeric target
- Each goal has: metric, target value, period (daily/weekly/long-term), current progress
- Progress rings (Apple Fitness+ style) with 800ms animated fill on load
- AI commentary on each goal: "You're 3 runs away from your weekly target — Tuesday and Thursday are your best running days based on your history"
- Projected completion date for long-term goals calculated from current trend line
- Goals surfaced on Progress Home and as compact widgets in the Today Feed

**Streaks:**
- Automatic streak tracking for:
  - Consecutive days logging any data (app engagement streak)
  - Consecutive days meeting step goal
  - Consecutive workout days
  - Consecutive days completing the wellness check-in
- Streak counter displayed on Progress Home and as a compact badge in the Today Feed
- **Streak freeze:** 1 free freeze per week — protects the streak if the user misses a day. Freezes accumulate up to a maximum of 2. Displayed as a "shield" icon next to the streak counter.
- **Streak milestone celebrations:** Haptic feedback (success pattern) + a celebratory card in the Today Feed at 7, 14, 30, 60, 90, 180, and 365 days. These are meaningful intervals, not every-day noise.

**Achievements / Badges:**
- New `Achievement` backend model: id, user_id, achievement_key, unlocked_at
- Unlockable badges for behavioral milestones grouped by category:
  - **Getting Started:** "First Steps" (connect first integration), "Hello Coach" (send first AI message), "Data Curious" (view first insight)
  - **Consistency:** "Week One" (7-day streak), "Month Strong" (30-day streak), "Quarterly Champion" (90-day streak), "Year of You" (365-day streak)
  - **Goals:** "Goal Setter" (create first goal), "Goal Crusher" (complete 5 goals), "Overachiever" (exceed a goal target by 20%+)
  - **Data:** "Connected" (connect 3+ integrations), "Data Rich" (30 days of continuous data), "Full Picture" (data in 5+ categories)
  - **Coach:** "Deep Diver" (50 AI conversations), "Insight Hunter" (view 100 insights), "Memory Maker" (AI stores 20+ memories)
  - **Health:** "Night Owl to Early Bird" (improve average bedtime by 30+ min over 30 days), "Personal Best" (new record in any tracked metric), "Anomaly Aware" (review 10 anomaly alerts)
- Achievement gallery in the Progress Tab with locked/unlocked states
- Subtle push notification on unlock with haptic feedback
- Unlocked badges show the date achieved

**User settings:** Settings > Notifications: Streak reminders toggle (on by default), Achievement notifications toggle (on by default). Progress Tab: streak freeze is managed inline (tap the shield icon to activate/view freezes).

### W. Smart Reminders / Nudges

**Implementation status:** FCM push infrastructure exists. Background insight alerts listed as planned in [roadmap.md](./roadmap.md). Triggering logic not implemented.

AI-driven proactive notifications based on detected patterns, data gaps, goal proximity, and milestones:

**Reminder categories:**

- **Pattern-based:** Derived from the user's behavioral history. "You usually run on Tuesdays — planning one today?", "Your sleep has been declining for 3 nights — consider going to bed 30 minutes earlier tonight"
- **Gap-based:** Triggered when expected data is missing. "You haven't logged water today", "No activity data synced in 24 hours — is your Fitbit connected?"
- **Goal-based:** Triggered by proximity to daily/weekly targets. "You're 800 steps from your daily goal — a 10 minute walk would do it", "One more workout this week hits your weekly target"
- **Celebration:** Triggered by positive milestones. "You just hit a 14-day streak!", "Your HRV is at a 30-day high — whatever you're doing, keep it up"

**Delivery constraints:**
- Frequency cap: maximum 3 nudges per day to avoid notification fatigue
- Smart timing: delivered at times when the user typically opens the app (learned from PostHog usage data)
- No duplicate nudges: same message topic not repeated within 48 hours
- Nudges are also logged in the Notification History screen (Today Tab) for users who miss them

**User settings:** Settings > Notifications:
- Smart Reminders master toggle (on by default)
- Per-category toggles: Pattern-based, Gap-based, Goal-based, Celebration (all on by default)
- Frequency selector: Low (max 1/day), Medium (max 2/day, default), High (max 3/day)

### X. Haptic Feedback System

**Implementation status:** Not implemented.

App-wide tactile feedback using native haptic APIs for a premium physical feel:

**Haptic types by interaction:**
- **Light impact:** Tab switches, card taps, list item selections, tooltip dismissals
- **Medium impact:** Sending a chat message, confirming a log entry, toggling a setting, completing a Quick Log entry
- **Success (notification pattern):** Goal reached, streak milestone hit, achievement unlocked, weekly report generated
- **Warning (error pattern):** Integration disconnection alert, anomaly detection alert
- **Selection tick:** Scrolling through picker wheels, slider value changes, reorder drag handles

**Implementation:**
- iOS: `UIImpactFeedbackGenerator` (light/medium/heavy), `UINotificationFeedbackGenerator` (success/warning/error), `UISelectionFeedbackGenerator` (selection)
- Android: `VibrationEffect.createOneShot()` and `VibrationEffect.createPredefined()` (EFFECT_TICK, EFFECT_CLICK, EFFECT_HEAVY_CLICK)
- Abstracted behind a shared `HapticService` in the Flutter layer that maps semantic haptic types to platform-specific implementations

**User settings:** Settings > Appearance: Haptic Feedback toggle (on by default). When off, all haptics are suppressed app-wide.

### Y. Time-of-Day UI Awareness

**Implementation status:** [screens.md](./screens.md) Today Feed spec mentions time-awareness ("morning = sleep recap, evening = day summary"). Full time-period logic not defined.

The Today Feed adapts its content, card ordering, and tone based on the current time of day:

**Time periods and content priority:**

- **Morning (5:00 AM – 11:00 AM):**
  - Health Score for today (hero position)
  - Sleep recap card (duration, quality, comparison to baseline)
  - AI Morning Briefing content (if notification was sent, the same content is available here)
  - Wellness Check-in prompt (if enabled and not yet completed)
  - Today's plan: active goals and what's needed to hit them
  - Contextual quick action: "Log your morning supplements"

- **Afternoon (11:00 AM – 5:00 PM):**
  - Health Score (hero position)
  - Progress toward daily goals (steps, calories, activity minutes)
  - Hydration reminder (if water not logged recently)
  - Mid-day insight: any anomalies detected, correlation discoveries
  - Contextual quick action: "Log your lunch" or "How's your energy?"

- **Evening (5:00 PM – 10:00 PM):**
  - Health Score (hero position)
  - Day summary card: what was accomplished, goals met/missed
  - Wind-down suggestions based on data: "Your HRV tends to be better when you stop screen time by 10pm"
  - Tomorrow planning prompt: "Any goals for tomorrow?"
  - Contextual quick action: "Rate your day" or "Set a sleep goal"

- **Night (10:00 PM – 5:00 AM):**
  - Minimal, calming UI — reduced card density
  - If the user opens the app late: gentle nudge — "It's past your usual bedtime. Getting to sleep now would give you 7.5 hours."
  - No proactive actions surfaced — just the Health Score and any critical anomaly alerts

**User settings:** Time boundaries are not user-configurable (they follow conventional day periods). Quiet Hours in notification settings control push notification delivery but do not affect in-app content ordering.

---

## 6. MVP Features — Speech & Input

### Z. Speech-to-Text (Voice Input)

**Implementation status:** Fully implemented. On-device STT via `speech_to_text` v7.3.0. Hold-to-talk UX. 35 tests passing. Audio never leaves the device.

Voice input for the AI Coach conversation:

- On-device speech recognition using the platform's native speech engine (iOS Speech Framework, Android SpeechRecognizer)
- Hold-to-talk button in the chat input bar — press and hold to record, release to transcribe
- Visual waveform/pulse indicator during active recording
- Transcribed text appears in the text input field for user review and editing before sending
- 30-second maximum session duration (auto-stops and transcribes)
- Works offline (on-device processing, no cloud dependency)
- Audio is never transmitted or stored — only the transcribed text is sent to the AI

**User settings:** None — voice input is an always-available input method in the chat. The microphone button is visible by default.

---

## 7. MVP Features — Data Maturity & Transparency

### AA. Data Maturity Indicator

**Implementation status:** Partially implemented. Banner dismiss persistence wired in feat/today-tab-settings-wiring (2026-03-08). Full maturity level logic (building/ready/strong/excellent) and per-feature soft gating not yet implemented.

A transparent system that communicates to users how much data the AI has and how insights will improve over time. This sets proper expectations and reduces frustration during the first week.

**Components:**

**Welcome banner (Today Feed, first 7 days):**
- Persistent card at the top of the Today Feed during the first week
- "Zuralog works best with at least a week of data. Your insights will get more accurate every day."
- Progress bar: "Data maturity: 3 of 7 days" — fills as days with data accumulate
- Dismissable after 7 days or manually at any time

**Maturity levels:**
- **Building** (days 1-6): "I'm still learning your patterns. Check back as more data flows in."
- **Ready** (days 7-13): "I have enough data for basic insights. Correlations need a bit more time."
- **Strong** (days 14-29): "Your personal baselines are established. Anomaly detection is active."
- **Excellent** (30+ days): Indicator disappears. Full feature fidelity.

**Per-feature soft gating (informational only, never blocks):**
- Correlations: "Correlations need at least 7 days of data. You have 3 days — check back soon." Shown on the Trends tab correlation cards.
- Health Score: Score is displayed from day 1 but with a footnote during the Building phase: "Based on limited data — accuracy improves with time"
- Anomaly Detection: Silently builds the 14-day baseline. No anomaly cards shown until day 14. No warning needed — the feature simply appears when ready.
- AI Conversation Starters: Falls back to smart defaults when personalized prompts lack sufficient data

**User settings:** Settings > Privacy & Data: dismiss/re-enable the data maturity banner. The per-feature soft gating is automatic and not user-configurable.

---

## 8. Consolidated Design Impact Summary

This section specifies all changes required to [screens.md](./screens.md) and [design.md](./design.md) to accommodate the MVP features defined above.

### New Screens to Add to screens.md

| Screen | Location | Purpose |
|--------|----------|---------|
| Quick Log Bottom Sheet | Today Tab / Coach Tab | Manual entry for water, mood, energy, stress, pain, notes |
| Emergency Health Card | Profile (Settings) | Quick-access medical info: blood type, allergies, meds, contacts |
| Emergency Health Card Edit | Profile (Settings) | Edit form for all medical info fields |
| Expanded Onboarding Flow (6 steps) | Auth & Onboarding | Replace single ProfileQuestionnaire with multi-step paginated flow |

### Screens to Modify in screens.md

| Screen | Modifications |
|--------|---------------|
| **Today Feed** | Add: Health Score hero widget at top. Data Maturity indicator banner (first 30 days). Wellness Check-in card (daily prompt). Contextual Quick Actions cards. Streak counter badge. Common Correlation Suggestion cards. Quick Log entry point button. Time-of-Day content ordering logic specification. |
| **Health Dashboard (Data Tab)** | Add: Health Score as hero element at top of the card grid, above all category cards. |
| **New Chat (Coach Tab)** | Add: Personalized AI Conversation Starters (replace generic prompts). File attachment button in input bar. Camera/photo capture button. Integration context banner showing which apps the AI can access. |
| **Chat Thread** | Add: File attachment support (images, PDFs). Attachment preview cards in message bubbles. Memory extraction confirmation card after AI processes a file. Food photo response card with nutrition estimate and confirm/adjust UI. Natural language logging confirmation card. |
| **Progress Home** | Add: Streak freeze toggle/indicator (shield icon). Streak milestone celebration card. Compact goal widgets with progress rings. |
| **Achievements** | Add: Full badge gallery with locked/unlocked states, grouped by category. Unlock date display. |
| **Weekly Report** | Change: From standard report screen to Instagram-story-style swipeable card sequence. Add: Share-as-image button. |
| **Trends Home** | Add: Common Correlation Suggestion cards ("Track X for better insights"). |
| **Data Sources (Trends Tab)** | Add: Staleness indicators (green/yellow/red dot per integration). Last sync timestamp. Reconnect button for error-state integrations. Data type breakdown per integration. |
| **Settings Hub** | No structural changes. Feature-specific settings are distributed across existing settings sub-screens. |
| **Notifications Settings** | Expand significantly: Morning Briefing toggle + time picker. Smart Reminders master toggle with per-category sub-toggles (pattern, gap, goal, celebration). Frequency selector. Streak reminders toggle. Achievement notifications toggle. Anomaly alerts toggle. Integration alerts toggle. Wellness Check-in reminder toggle + time picker. Quiet Hours start/end time. |
| **Appearance Settings** | Add: Theme selector (Dark / Light / System). Haptic Feedback toggle. Reset Onboarding Tooltips button. Disable Tooltips toggle. |
| **Coach Settings** | Add: Proactivity level selector (Low / Medium / High) below existing persona selector. |
| **Profile** | Add: Emergency Health Card link/button (prominent, possibly as a card). |
| **Integrations Hub** | Add: Compact sync status badge (colored dot) per connected integration. Last synced timestamp under each integration name. |
| **Auth & Onboarding** | Replace single ProfileQuestionnaire with 6-step paginated onboarding flow (see [Feature S](#s-post-signup-onboarding-flow) for full step definitions). |

### design.md Updates Required

| Update | Details |
|--------|---------|
| **Light mode color tokens** | Define full light mode surface hierarchy: scaffold, surface, card, elevated surface, divider, input background, text primary/secondary/tertiary. See [Feature U](#u-darklight-mode-toggle) for proposed values. |
| **Haptic feedback spec** | Add a haptic type table mapping interaction types to platform haptic APIs. Define semantic types: light, medium, success, warning, selection. |
| **Onboarding tooltip component** | Spec for tooltip bubble: background color, border radius, pointer arrow, text style, dismiss button, overlay dimming. |
| **Health Score widget** | Ring or gauge component spec: size variants (hero 120pt, compact 48pt), color stops (red/yellow/green), animation (800ms fill), inner label (score number). |
| **Data Maturity indicator** | Progress bar component spec: height, fill color (sage green), background, label position, dismiss interaction. |
| **Streak counter badge** | Compact badge: flame icon, number, shield icon for freeze. Inline and standalone variants. |
| **File attachment UI** | Attachment button icon spec, preview card for images (thumbnail + filename), preview card for PDFs (icon + filename + page count), upload progress indicator. |
| **Quick Log bottom sheet** | Grid layout for metric tiles, slider component, increment button, submit bar. |
| **Weekly Story Recap** | Swipeable full-screen card spec: background gradient per card type, chart placement, share button, dot indicator for card position. |
| **Confirmation card** | In-chat card for confirming natural language logs and memory extractions: card layout, confirm/edit buttons, data preview. |
| **Food photo response card** | In-chat card showing AI's nutrition estimate from a photo: food item list, calorie/macro breakdown, confirm/adjust buttons. |

---

## 9. Observability & Analytics Principles

These principles apply across every feature in this document. They are not optional — they are part of the implementation requirement.

### PostHog Event Instrumentation

Every feature must emit structured PostHog events for usage tracking and product analytics:

- **Feature adoption:** Track first-use events per feature per user (e.g., `first_quick_log`, `first_file_attachment`, `first_goal_created`). Track daily/weekly active usage per feature.
- **Funnel analysis:** Instrument the onboarding flow step-by-step (completion rate per step, drop-off points). Instrument goal creation through goal completion. Instrument chat message through AI response.
- **Feature-specific events:** AI messages sent, insights viewed and tapped, streaks started/broken/frozen, achievements unlocked, attachments sent by type, anomaly alerts viewed, wellness check-ins completed, quick logs submitted, correlation suggestions tapped.
- **Engagement metrics:** Session duration, screens visited per session, time-of-day usage distribution, notification tap-through rate by type.
- **A/B testing readiness:** PostHog feature flags should be used to gate experimental feature variants in future (notification frequency, AI persona defaults, onboarding flow order).

### Sentry Error Boundaries

Every new screen and service must be wrapped with Sentry error reporting:

- **Frontend:** Error boundary widgets per screen and per feature module. Breadcrumbs for navigation events, user actions, and API calls.
- **Backend:** Structured exception handling with Sentry breadcrumbs per endpoint. Transaction tracing for the full AI orchestration pipeline (LLM call > tool resolution > MCP execution > response).
- **AI-specific monitoring:** Track LLM response failures, tool call failures, memory store read/write failures, and anomaly detection errors as separate Sentry issue groups.
- **Performance:** Sentry performance monitoring on AI response latency, health data ingest pipeline duration, and report generation time.

### Privacy Guardrails

- PostHog must never receive PII (names, emails) or raw health data values. Track event names and counts, not content.
- Sentry must scrub PII from error reports (configure `before_send` to strip user data from payloads).
- File attachments must not be logged or persisted in any analytics or error tracking system.
- AI long-term memory content is never sent to PostHog or Sentry.

---

## 10. Feature-Level Settings Reference

A consolidated map of all user-configurable settings introduced by MVP features. This serves as the specification for the Settings screens.

### Settings > Coach Settings

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| AI Persona | Single select | Tough Love | Choose from Tough Love, Balanced, or Gentle coaching style |
| Proactivity Level | Single select | Medium | Low = waits for user, Medium = shares important insights, High = checks in throughout the day |

### Settings > Notifications

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| Morning Briefing | Toggle | On (Pro) / Off (Free) | Enable daily morning push notification |
| Morning Briefing Time | Time picker | 7:00 AM | When to deliver the morning briefing |
| Smart Reminders | Toggle | On | Master toggle for all AI-driven nudges |
| — Pattern-based | Toggle | On | Reminders based on behavioral patterns |
| — Gap-based | Toggle | On | Reminders when expected data is missing |
| — Goal-based | Toggle | On | Nudges when close to daily/weekly targets |
| — Celebration | Toggle | On | Positive milestone notifications |
| Reminder Frequency | Selector | Medium (2/day) | Low (1/day), Medium (2/day), High (3/day) |
| Streak Reminders | Toggle | On | Notify when streak is at risk |
| Achievement Notifications | Toggle | On | Notify when a badge is unlocked |
| Anomaly Alerts | Toggle | On | Notify on unusual metric readings |
| Integration Alerts | Toggle | On | Notify when an integration stops syncing |
| Wellness Check-in Reminder | Toggle | On | Daily prompt to complete the wellness check-in |
| Check-in Reminder Time | Time picker | 9:00 AM | When to prompt the wellness check-in |
| Quiet Hours | Time range | 10:00 PM – 7:00 AM | Suppress all non-critical notifications |

### Settings > Appearance

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| Theme | Selector | Dark | Dark, Light, or System (follows OS) |
| Haptic Feedback | Toggle | On | Enable/disable tactile feedback on interactions |
| Reset Onboarding Tooltips | Button | — | Re-enables all first-visit tooltips |
| Disable Tooltips | Toggle | Off | Globally suppress all onboarding tooltips |

### Settings > Privacy & Data

| Setting | Type | Default | Description | Status |
|---------|------|---------|-------------|--------|
| AI Memory | View/Manage | — | View stored memories, delete individual entries, clear all | 📋 Future |
| Wellness Check-in | Toggle | On | Enable/disable daily check-in prompt in Today Feed | ✅ Wired (feat/today-tab-settings-wiring) |
| Data Maturity Banner | Toggle | On | Show/dismiss the data maturity progress indicator | ✅ Wired (feat/today-tab-settings-wiring) |

### Settings > Account

| Setting | Type | Default | Description | Status |
|---------|------|---------|-------------|--------|
| Goals | Multi-select | Set during onboarding | Edit health/fitness goals that drive AI behavior | ✅ Complete (feat/progress-tab-gaps) |
| Units System | Segmented toggle | Metric | Metric (kg, cm, ml) or Imperial (lbs, in, oz) | ✅ Complete (feat/settings-providers) |
| Emergency Health Card | Link | — | Navigate to Emergency Health Card edit screen | 📋 Future |

---

## 11. Post-MVP Features

These features are justified and desirable but deferred from the initial App Store release due to implementation complexity. Each is documented with its value proposition and deferral rationale so that no context is lost when work begins on them.

### 1. Social Features

**Description:** Friend system, activity feed, shared goals, group challenges, profile sharing (similar to Strava's social layer).

**Value:** Massive retention driver. Social accountability is one of the strongest predictors of long-term fitness habit adherence. Shared weekly reports and challenges create organic growth loops.

**Deferral reason:** Requires friend request/accept system, activity feed infrastructure, privacy controls (who sees what), content moderation, and significant backend work (new models: Friendship, FeedItem, Challenge, SharedGoal). Build when the user base exists and the core product value is proven.

### 2. Document Vault

**Description:** A dedicated file management UI where users can upload, organize, search, and manage medical documents (vaccination records, lab results, prescriptions, doctor notes).

**Value:** Creates a "health filing cabinet" with AI-searchable access. Users would have one place for everything health-related.

**Deferral reason:** The MVP's chat attachment + memory extraction covers the majority of the value (AI reads documents and remembers key facts). The vault adds a dedicated management UI with folders, search, thumbnails, and organization features — substantial UI work with HIPAA/privacy implications for persistent medical document storage. Ship when the legal and compliance framework is established.

### 3. AI Experiment Suggestions

**Description:** AI proactively suggests structured N=1 self-experiments. Example: "Try sleeping without caffeine after 2pm for 7 days and I'll track if your sleep quality improves." The app tracks the experimental and control periods and reports results.

**Value:** Unique differentiator — "A/B test your own body." Transforms passive data viewing into active self-improvement with scientific rigor.

**Deferral reason:** Requires an experiment model (hypothesis, protocol, duration, control period, experimental period), state machine for experiment lifecycle, automated result analysis comparing control vs experimental data, and a dedicated experiment management UI.

### 4. Sleep Hygiene Coaching Program

**Description:** A dedicated multi-week guided program for improving sleep. AI analyzes sleep patterns, identifies specific issues (late caffeine, screen time, inconsistent schedule), creates a personalized improvement plan with daily check-ins and progress tracking.

**Value:** Sleep is the #1 most-tracked health metric. A structured program converts data viewers into active improvers.

**Deferral reason:** Requires a program/curriculum engine (multi-week plans with sequential steps), daily check-in framework, progress evaluation against the plan, and plan adjustment logic. The MVP's AI coach can provide sleep advice conversationally — the structured program formalizes this.

### 5. Recovery Advisor

**Description:** Post-workout or post-illness, AI recommends specific recovery actions based on HRV trends, sleep quality, activity history, and resting heart rate. Tells the user when to push hard vs when to rest.

**Value:** Bridges the gap between data and action for serious athletes and health-conscious users.

**Deferral reason:** Requires recovery modeling based on multiple biometric inputs, per-activity recovery profiles (a marathon requires different recovery than a yoga session), and validated recovery timelines. The MVP's Health Score provides a simplified version of this signal.

### 6. Habit Stacking Suggestions

**Description:** AI analyzes usage patterns and routines, then suggests attaching new healthy habits to existing behavioral anchors. "You always open the app at 7am — that's a great time to log your morning supplements."

**Value:** Based on established behavioral science (James Clear's "Atomic Habits" framework). Increases feature adoption by connecting new behaviors to existing routines.

**Deferral reason:** Requires a routine detection engine that analyzes weeks of usage data (PostHog events) to identify stable behavioral patterns. Needs sufficient data maturity before it can make useful suggestions.

### 7. AI Action Plans

**Description:** Based on user goals, AI creates structured multi-week plans with daily and weekly milestones. Not just insights but actual step-by-step programs (e.g., "8-Week 5K Training Plan" or "30-Day Sleep Improvement Plan").

**Value:** Transforms Zuralog from an insight tool into a coaching platform. Users who follow structured plans retain at significantly higher rates.

**Deferral reason:** Requires a plan model (plan, phase, milestone, daily task), plan tracking infrastructure, progress evaluation, plan adjustment when the user falls behind, and potentially expert-reviewed plan templates for safety.

### 8. Home Screen Widgets

**Description:** iOS WidgetKit and Android Glance widgets showing today's Health Score, active streak count, goal progress, or a quick-log button directly on the device home screen.

**Value:** Highest-visibility, lowest-friction engagement surface. Users see their health data without opening the app.

**Deferral reason:** iOS WidgetKit requires a separate Swift target with shared app groups for data passing. Android Glance requires Jetpack Compose. Both are significant native platform work outside the Flutter layer. The app must also support the data pipeline for widget refresh (background fetch on a schedule).

### 9. Focus / DND Mode

**Description:** User-configurable focus modes (Sleeping, Working Out, Working, Do Not Disturb) that adjust the app's notification behavior and UI surface.

**Value:** Premium UX that respects the user's context. Reduces notification fatigue by intelligently suppressing non-urgent communications during focused activities.

**Deferral reason:** Requires integration with OS-level focus systems (iOS Focus Filters API, Android DND API) for full effect. Per-platform implementation with graceful degradation. The MVP's Quiet Hours setting provides a simpler version.

### 10. Photo Progress Tracking

**Description:** Body composition photos with date stamps, stored locally on device. Side-by-side comparison view for visual progress over weeks/months. Paired with weight and body measurement data.

**Value:** Strong visual motivation tool. The combination of objective metrics (weight, body fat) with subjective visual progress is a powerful feedback loop.

**Deferral reason:** Requires local photo storage with privacy-first design (photos never leave the device), date-stamped gallery UI, side-by-side comparison view with alignment guides, and camera overlay for consistent positioning.

### 11. Supplement & Medication Tracker

**Description:** Dedicated tracking interface for daily supplements and medications with scheduled reminders and adherence tracking. Logged data feeds into AI correlations.

**Value:** Enables correlations like "Started creatine 3 weeks ago and noticed a 5% increase in strength metrics" or "Your sleep improved after starting magnesium." Medical adherence tracking has life-safety implications for users on prescription medications.

**Deferral reason:** Requires a new database model (Supplement, Medication, DoseLog), CRUD screens, reminder scheduler (per-supplement/medication with configurable frequency), and adherence rate calculation. The MVP handles this via natural language logging in chat — users can say "Took my creatine" and the AI logs and remembers it.

### 12. Custom Metric Creation

**Description:** Users define their own metrics beyond the 117 built-in ones. Track anything: caffeine cups per day, meditation minutes, cold plunge duration, sauna sessions, journaling streak. Custom metrics feed into the AI analytics and correlation engine.

**Value:** Power user feature that makes Zuralog infinitely extensible without requiring new code for each metric.

**Deferral reason:** Requires dynamic metric schema (user-defined name, unit, data type, aggregation method), custom chart rendering for arbitrary metrics, and integration with the analytics engine's correlation and trend detection. Needs careful UX design to avoid overwhelming casual users.

### 13. Data Export

**Description:** Export all personal health data as CSV or JSON. Covers all synced integration data, manual logs, AI conversation history, goals, and achievements.

**Value:** Builds user trust ("I can leave anytime"). May be legally required for GDPR compliance (Article 20 — right to data portability) before EU launch.

**Deferral reason:** Not a launch blocker for the US App Store. Implement before any EU marketing or when user base grows. Requires a background export job (data volume can be large), download link delivery via email or in-app, and format standardization.

### 14. Family Plan

**Description:** A family subscription tier where a parent or guardian can manage health data for their entire household under one account. Each family member has their own profile, their own connected integrations, and their own AI coach — but the parent has a unified dashboard view across all members.

**Value:** This is a significant retention moat. Once a parent manages their children's vaccination records, growth charts, activity data, and health milestones in Zuralog, the switching cost is enormous. It also opens a premium pricing tier ($14.99-$19.99/month for up to 5 family members). Families with young athletes, children with chronic conditions, or health-conscious households would find this indispensable.

**Deferral reason:** Requires a family group model (FamilyGroup, FamilyMember with roles: admin/member), per-member profile and data isolation, a unified family dashboard for the admin, age-appropriate AI persona adjustments for minor members, consent management for data sharing within the family, and a new RevenueCat subscription tier. This is a substantial feature that deserves its own design phase once the single-user experience is proven.

---

## 12. GitHub Issue Titles

Organized by category. Each title is an actionable implementation task suitable for a GitHub project board.

### AI & Intelligence Layer

```
[Feature] AI Long-Term Memory — Pinecone vector store integration with semantic search
[Feature] File Attachments in Chat — image, PDF, and document upload with AI processing
[Feature] Memory Extraction from Chat Attachments — auto-extract and store key health facts in vector memory
[Feature] AI Daily Insights — Today Feed insight card generation via Celery background job
[Feature] AI Weekly Report — auto-generated story-style swipeable recap with share-as-image
[Feature] AI Monthly Report — comprehensive exportable health review with trends and recommendations
[Feature] AI Morning Briefing — personalized daily push notification with configurable delivery time
[Feature] AI Conversation Starters — personalized suggested prompts generated from recent user data
[Feature] Contextual Quick Actions — time-aware and event-aware action suggestions in Today Feed
[Feature] Metric Anomaly Detection — flag deviations from personal 30-day baseline
[Feature] Health Score / Readiness Score — composite daily 0-100 score from all connected sources
[Feature] Common Correlation Suggestions — recommend data sources to track based on user goals
[Feature] Natural Language Logging — parse and log health data from free-text chat messages
[Feature] Food Photo Logging — meal photo to calorie/macro estimation via Kimi K2.5 multimodal vision
```

### Data & Health Management

```
[Feature] Customizable Dashboard — drag-and-drop reorder, show/hide categories, accent color override
[Feature] Deep Analytics UI — interactive two-metric correlation explorer with scatter/overlay charts
[Feature] Quick Log / Manual Entry — bottom sheet for water, mood, energy, stress, pain, and notes
[Feature] Wearable-Free Wellness Check-in — daily subjective rating prompt with push notification trigger
[Feature] Integration Health Monitor — sync status indicators, staleness alerts, one-tap reconnect
[Feature] Emergency Health Card — quick-access medical info screen (blood type, allergies, meds, contacts)
[Feature] Data Maturity Indicator — progressive transparency on data sufficiency for AI insights
```

### Onboarding & Personalization

```
[Feature] Post-Signup Onboarding Flow — 6-step flow: goals, persona, integrations, notifications, discovery
[Feature] Per-Screen Onboarding Tooltips — contextual first-visit guidance with shared tooltip widget
[Feature] Dark/Light Mode Toggle — three-option theme switcher with light mode color token definitions
[Feature] AI Persona Selection with Proactivity Level — 3 personas plus Low/Medium/High proactivity toggle
```

### Engagement & Retention

```
[Feature] Goals System — full CRUD with progress rings, AI commentary, and projected completion
[Feature] Streak Tracking — automatic streaks with freeze mechanic and milestone celebrations
[Feature] Achievement / Badge System — unlockable badges for behavioral milestones with gallery UI
[Feature] Smart Reminders / Nudges — AI-driven notifications with per-category controls and frequency cap
[Feature] Haptic Feedback System — app-wide tactile feedback with semantic haptic types
[Feature] Time-of-Day UI Awareness — Today Feed content adapts by morning/afternoon/evening/night
```

### Design & Infrastructure

```
[Design] Update screens.md — add new screens and modify existing screens for all MVP features
[Design] Update design.md — light mode tokens, haptic specs, and new component specifications
[Design] Onboarding Tooltip Component — shared widget spec for first-visit contextual guidance
[Design] Health Score Widget — ring/gauge component with size variants and color-coded score ranges
[Design] Quick Log Bottom Sheet Component — grid layout with sliders, increment buttons, and submit bar
[Design] File Attachment UI — attachment button, preview cards, upload progress, photo capture
[Design] Weekly Story Recap UI — swipeable full-screen card sequence with share-as-image rendering
[Design] Confirmation Card Component — in-chat card for natural language log and memory extraction confirmation
[Design] Food Photo Response Card — in-chat nutrition estimate display with confirm/adjust actions
[Design] Data Maturity Indicator Component — progress bar with maturity level labels
[Infra] PostHog Event Schema — define and document all events for MVP feature instrumentation
[Infra] Feature Settings Backend — add user preference fields for all configurable MVP settings
```

### Post-MVP (label as `post-mvp`)

```
[Post-MVP] Social Features — friend system, activity feed, shared goals, group challenges
[Post-MVP] Document Vault — persistent medical document management UI with search and organization
[Post-MVP] AI Experiment Suggestions — structured N=1 self-testing framework with result tracking
[Post-MVP] Sleep Hygiene Coaching Program — multi-week guided sleep improvement program
[Post-MVP] Recovery Advisor — HRV-based post-workout and post-illness recovery recommendations
[Post-MVP] Habit Stacking Suggestions — routine detection and new habit attachment engine
[Post-MVP] AI Action Plans — structured multi-week programs with daily milestones and plan adjustment
[Post-MVP] Home Screen Widgets — iOS WidgetKit and Android Glance for at-a-glance health data
[Post-MVP] Focus / DND Mode — context-aware notification management with OS-level integration
[Post-MVP] Photo Progress Tracking — local body composition photos with side-by-side comparison
[Post-MVP] Supplement / Medication Tracker — dedicated tracking with reminders and adherence rates
[Post-MVP] Custom Metric Creation — user-defined metrics with dynamic schema and analytics integration
[Post-MVP] Data Export — CSV/JSON export of all personal data for portability and GDPR compliance
[Post-MVP] Family Plan — multi-member household subscription with unified parent dashboard
```
