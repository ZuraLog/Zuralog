# Zuralog — Mobile Screen Inventory

**Version:** 1.0  
**Last Updated:** 2026-03-03  
**Status:** Living Document

---

## Directive: Full UI Rebuild

The existing mobile UI is to be **fully rebuilt**. All current screens — Dashboard, Chat, Integrations Hub, Settings, Profile Side Panel — may be redacted or replaced entirely. The underlying functionality (API clients, Riverpod providers, platform channels, auth flows, health bridges) is retained; only the presentation layer changes.

The rebuild follows the screen inventory defined in this document. Existing screens that overlap with the new inventory (e.g., Dashboard → Data tab, Chat → Coach tab) should be reimplemented from scratch to match the new navigation structure and user experience model, not patched on top of the old layout.

**What is preserved:** All backend integration, state management, data layers, services, and core infrastructure.  
**What is rebuilt:** Every screen, widget, navigation route, and layout in `features/` and `shared/`.

---

## 1. User Intent Model

Every screen in the app exists to serve one of five user "jobs" — the reason someone opens Zuralog at a given moment. Screens that don't map to a job don't belong in the app.

| # | Job | Frequency | User Mindset |
|---|-----|-----------|-------------|
| 1 | **"What do I need to know right now?"** | Daily, passive | Receptive — user wants to be told what matters. The app leads. |
| 2 | **"Show me MY data, MY way."** | On-demand, exploratory | Curious — user wants control. They decide what to look at and how it's arranged. |
| 3 | **"Help me understand or do something."** | Intent-driven, conversational | Active — user has a question or a task. They initiate; the AI responds. |
| 4 | **"Am I actually getting better?"** | Weekly, reflective | Emotional — user wants proof of progress. Motivation, not raw data. |
| 5 | **"Show me the patterns."** | Weekly, analytical | Intellectual — user wants to understand what's connected and why. |

Setup tasks (integrations, profile, subscription, preferences) are a sixth job but they are rare and do not warrant primary navigation placement.

---

## 2. Navigation Structure

### Bottom Navigation Bar (5 tabs)

| Tab | Label | Maps to Job | Icon Concept |
|-----|-------|-------------|-------------|
| 1 | **Today** | Job 1 — "What do I need to know?" | Sun / calendar-today |
| 2 | **Data** | Job 2 — "Show me my data" | Grid / chart-bar |
| 3 | **Coach** | Job 3 — "Help me understand or do" | Chat bubble / sparkle |
| 4 | **Progress** | Job 4 — "Am I getting better?" | Target / trophy |
| 5 | **Trends** | Job 5 — "Show me the patterns" | Trend-up / wave |

### Non-Tab Screens

Settings, Profile, Integrations, Subscription, and legal pages are accessed from header icons, avatar taps, or navigation pushes — not from the bottom bar. They serve the rare "setup" job and should not compete with daily-use tabs.

---

## 3. Screen Inventory

### 3.1 Today Tab

The app's front door. A curated, AI-driven daily briefing. The user reads; the app decides what's important.

| Screen | Type | Purpose |
|--------|------|---------|
| **Today Feed** | Tab root | Vertical scroll of curated cards ordered by relevance. Morning briefing summary at top, AI insight cards (proactive observations from background sync), quick-action shortcuts ("Log a meal", "Start a run"), and a compact "your day so far" progress indicator (calories, steps, active minutes). Cards are time-aware — morning shows sleep recap + day plan, evening shows day summary. |
| **Insight Detail** | Pushed | Full-screen explanation of a single AI insight. Shows the data behind the observation (charts, numbers, source integrations), the AI's reasoning, and a "Discuss with Coach" action that opens a pre-filled chat thread for follow-up. |
| **Notification History** | Pushed (bell icon) | Scrollable list of all past push notifications grouped by day. Tapping a notification deep-links to the relevant insight or metric. Accessible from a bell icon in the Today header. |

### 3.2 Data Tab

The user's personal health canvas. Unlike Today (curated by AI), Data is user-controlled. They decide what's prominent, what's hidden, and how it looks.

| Screen | Type | Purpose |
|--------|------|---------|
| **Health Dashboard** | Tab root | Customizable grid/list of health category cards. Users can **reorder via drag-and-drop** (long-press to enter edit mode) and **toggle categories on/off** (show/hide). Each card shows a compact summary (today's value + sparkline trend). Users can also **customize card accent colors** per category. Layout arrangement and visibility persist across sessions. |
| **Category Detail** | Pushed (x10 categories) | Drill-down into a specific health category: Activity, Body, Heart, Vitals, Sleep, Nutrition, Cycle, Wellness, Mobility, Environment. Shows all metrics within the category with richer charts and time-range selectors (day / week / month / year). |
| **Metric Detail** | Pushed | Single metric deep-dive. Full chart with pinch-to-zoom, data source attribution ("from Fitbit", "from Apple Health"), raw data table toggle, and an "Ask Coach about this" action that opens a chat thread with the metric pre-loaded as context. |

### 3.3 Coach Tab

The AI chat — Zuralog's most powerful feature. Modeled after modern AI chatbot apps (Gemini, ChatGPT). Opens to a fresh conversation; past conversations accessible via a side drawer.

| Screen | Type | Purpose |
|--------|------|---------|
| **New Chat** | Tab root | Opens directly to a fresh, empty conversation. Suggested prompt chips shown when the input is empty (e.g., "Why am I tired?", "Log my lunch", "What should I eat?"). A context banner indicates which integrations the AI has access to for this user. Side drawer (swipe or hamburger icon) opens the conversation history. |
| **Conversation Drawer** | Drawer overlay | List of all past conversations sorted by most recent. Each row shows an AI-generated title, timestamp, and preview snippet. Tapping opens that thread. Conversations can be deleted or archived from here. |
| **Chat Thread** | Pushed (from drawer) | An existing conversation. Streaming AI responses, voice input (hold-to-talk), markdown rendering. Same capabilities as New Chat but with loaded history. |
| **Quick Actions Sheet** | Bottom sheet | Accessible from a lightning bolt icon in the Coach tab header or from Today tab shortcuts. Pre-built action cards for common tasks: "Log a meal", "Log a workout", "Start a run", "Check my calories", "How did I sleep?". Tapping one opens a new chat thread with the prompt pre-filled and auto-sent. |

### 3.4 Progress Tab

The emotional/motivational tab. Answers "am I on track?" without requiring chart interpretation. Goals, streaks, achievements, and personal reflections.

| Screen | Type | Purpose |
|--------|------|---------|
| **Progress Home** | Tab root | Active goals with progress bars, current streaks (days of logging, workout consistency, calorie targets hit), and a "this week vs last week" comparison summary. Everything is glanceable — clear indicators (up/down arrows, completion percentages, streak counts), not dense charts. |
| **Goals** | Pushed | Full goal management. Create, edit, delete goals. Goal types: weight target, weekly run count, daily calorie limit, sleep duration target, step count, custom. Each goal shows a progress ring, deadline, and trend line. The `UserGoal` model already exists on the backend. |
| **Goal Detail** | Pushed | Single goal deep-dive. Full progress chart over time, milestones hit, projected completion date, AI commentary ("At your current pace, you'll hit your target weight by April 12"). |
| **Achievements** | Pushed | Unlockable badges and milestones marking real behavioral consistency: "First 10K run", "7-day logging streak", "30 days of calorie tracking", "Connected 3 apps". Functions as a "look how far you've come" motivational archive. |
| **Weekly Report** | Pushed | Auto-generated end-of-week summary. Total workouts, average sleep, calorie adherence, top insight of the week, comparison to previous week. Shareable as an image for social proof and accountability. Can also be pushed as a Sunday evening notification. |
| **Journal / Daily Log** | Pushed | Daily reflection entry. Mood rating (1-5 or emoji scale), short text note, and context tags ("rest day", "stressful", "traveled"). Over time this builds a personal health diary that the AI can correlate with quantitative data ("You tend to sleep worse on days you tag as 'stressful'"). |

### 3.5 Trends Tab

The analytical tab. Where Progress is emotional, Trends is intellectual. This is where Zuralog's cross-app reasoning becomes visual.

| Screen | Type | Purpose |
|--------|------|---------|
| **Trends Home** | Tab root | AI-surfaced correlation cards ("Your sleep quality improves by 22% on days you run before 6pm"). A scrollable time-machine strip at the top allows browsing week-by-week or month-by-month historical summaries. Each correlation card is tappable for full analysis. |
| **Correlations** | Pushed | Interactive correlation explorer. User picks two metrics (e.g., sleep duration vs. running distance) and sees a scatter plot or overlay chart. AI annotation explains the correlation in plain English. Backend `analytics/` engine already computes these — this is the visualization layer. |
| **Reports** | Pushed | Auto-generated monthly health report. A polished, scrollable page: key stats, biggest improvements, areas of concern, integration activity summary, goal adherence rate. Exportable as PDF or shareable image. |
| **Data Sources** | Pushed | Read-only transparency screen. Shows every integration feeding data into the app, what data types each provides, last sync time, and data freshness. Answers "where is this number coming from?" — this is about data provenance, not connection management. |

### 3.6 Auth & Onboarding (existing, rebuild as needed)

| Screen | Type | Purpose |
|--------|------|---------|
| **Welcome** | Standalone | Auth home screen — Apple Sign In, Google Sign In, email options. |
| **Onboarding** | Standalone | First-launch value-prop slideshow. |
| **Login** | Pushed | Email/password login form. |
| **Register** | Pushed | Email/password registration form. |
| **Profile Questionnaire** | Pushed | Post-registration questionnaire to personalize the experience (fitness level, goals, preferred integrations). |

### 3.7 Settings & Profile (pushed / modal — not in bottom nav)

| Screen | Access Point | Purpose |
|--------|-------------|---------|
| **Profile** | Avatar tap (side panel or header) | Display name, email, avatar, member-since date, subscription tier badge. Edit profile fields. |
| **Settings Hub** | Gear icon from Profile or header | Top-level settings menu: Account, Notifications, Appearance, Coach, Integrations, Privacy & Data, Subscription, About. |
| **Account Settings** | Settings > Account | Email, password change, linked social accounts, delete account. |
| **Notification Preferences** | Settings > Notifications | Toggle notification categories: insights, goal reminders, weekly reports, streak alerts, morning briefing. Per-category on/off and quiet hours. |
| **Appearance Settings** | Settings > Appearance | Dashboard card color customization (per-category accent picker), card layout density (compact / comfortable), and future display preferences. |
| **Coach Settings** | Settings > Coach | AI persona tuning (tone: tough love / balanced / gentle), response length preference (concise / detailed), suggested prompts on/off, voice input settings. |
| **Integrations Management** | Settings > Integrations | The integrations hub — relocated from a top-level tab. Connected / Available / Coming Soon sections. OAuth flows. Last sync status. |
| **Privacy & Data** | Settings > Privacy & Data | Data export (download all data as JSON/CSV), data deletion request, analytics opt-out toggle. Links to Privacy Policy and Terms of Service. |
| **Subscription** | Settings > Subscription (or paywall modal) | Current plan, upgrade/downgrade, billing history, restore purchases. RevenueCat paywall for Pro upgrade. |
| **About** | Settings > About | App version, build number, open-source licenses, support link, community guidelines link. |
| **Privacy Policy** | Link from Privacy & Data | Full GDPR/CCPA privacy policy. |
| **Terms of Service** | Link from Privacy & Data | Full terms of service. |

---

## 4. Screen Count Summary

| Area | Screens | New vs. Existing |
|------|---------|-----------------|
| Today tab | 3 | 3 new |
| Data tab | 3 | 3 existing (rebuilt) |
| Coach tab | 4 | 2 new, 2 existing (rebuilt) |
| Progress tab | 6 | 6 new |
| Trends tab | 4 | 4 new (backend exists, no UI) |
| Auth & Onboarding | 5 | 5 existing (rebuild as needed) |
| Settings & Profile | 12 | ~10 new, 2 existing (rebuilt) |
| **Total** | **~37** | **~25 new, ~12 rebuilt** |

---

## 5. Backend Dependencies

Screens that require new backend work (not just UI):

| Screen | Backend Requirement |
|--------|-------------------|
| Today Feed | New endpoint for curated daily insights feed. Background insight generation via Celery. |
| Notification History | Persist push notifications server-side (currently fire-and-forget). |
| Dashboard Customization | User preference storage for card order, visibility, and colors (can be client-side via Drift/SharedPreferences, or synced to backend for cross-device). |
| Goals (UI) | `UserGoal` model exists. May need additional endpoints for goal CRUD if not already complete. |
| Achievements | New achievement/badge model and tracking logic. |
| Weekly/Monthly Reports | Report generation endpoint (can leverage existing `analytics/` engine). |
| Journal | New `JournalEntry` model and CRUD endpoints. |
| Correlations (UI) | Backend `analytics/` endpoints exist. May need additional visualization-friendly response formats. |
| Coach Settings | New user preferences fields for AI persona, response length, prompt visibility. |
| Conversation Management | Conversation list, rename, delete, archive endpoints (some may exist via `Conversation` model). |
