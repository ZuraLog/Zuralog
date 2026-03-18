# Zuralog — Mobile Screen Inventory

**Version:** 1.2  
**Last Updated:** 2026-03-16  
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
| **Today Feed** | Tab root | Vertical scroll of curated cards ordered by relevance. **Health Score hero widget** at the very top (ring/gauge, 120pt, animated fill, score number + label). **Data Maturity indicator banner** shown during first 30 days of use — "Zuralog works best with at least a week of data" with a progress bar and dismissible once 30 days pass. **Log Ring widget** (circular completion ring, 120pt, watching `logRingProvider`) positioned side-by-side with Health Score. **Snapshot Cards row** (horizontally scrollable, hidden until user logs anything) showing compact metric snapshots (today's value for one metric per card). **Daily Goals card** (shows "Set a daily goal →" until goals are configured). AI insight cards (proactive observations from background sync), and a compact "your day so far" progress indicator (calories, steps, active minutes). **Streak counter badge** (flame icon + number + freeze shield) shown inline with goals section. **Common Correlation Suggestion cards** when the AI detects a relationship forming between two metrics (e.g., "Track stress to unlock a sleep correlation"). **Floating Action Button (FAB)** — circular button in the bottom-right corner that opens the Log Grid Sheet. Cards are time-aware: morning shows sleep recap + day plan, afternoon shows calories + activity progress, evening shows day summary + wind-down suggestions, night shows minimal UI with Health Score and critical anomaly alerts only. |
| **Log Grid Sheet** | Modal bottom sheet | 10-tile 4-column grid for selecting log type: Wellness, Water, Sleep, Weight, Steps, Run, Meal, Supplements, Symptom, Workout. Tapping a tile animates to its inline log panel (Wellness, Water, Weight, Steps — Part 5: all wired to real APIs) or opens a full-screen log screen (Sleep, Run, Meal, Supplements, Symptom — Part 3 complete). Workout shows "coming soon" snackbar. Inline panels submit to live backend and invalidate `todayLogSummaryProvider`. `parentMessenger` threaded through for correct snackbar placement. |
| **Sleep Log Screen** | Full-screen (outside tab shell) | Bedtime/wake time pickers, sleep quality emoji selector, interruptions counter, sleep factors chips (stress, caffeine, exercise, alcohol, temperature), optional notes field. Floating submit button. Part 3 complete. |
| **Run Log Screen** | Full-screen (outside tab shell) | Mode picker (Open Strava / Log a past run / Record live coming soon), activity type selector, distance input, duration input, auto-calculated pace display, effort rating. Part 3 complete. |
| **Meal Log Screen** | Full-screen (outside tab shell) | Quick/Full toggle (persisted via `mealLogModeProvider` backed by SharedPreferences), meal type selector, description field, calorie presets, feel chips (satisfied, energized, sluggish, bloated), tags input. Part 3 complete; Part 9 refactored to use Riverpod provider instead of raw setState. |
| **Supplements Log Screen** | Full-screen (outside tab shell) | Tap-to-check-off checklist of user's supplements, inline add form for new supplements, optimistic UI updates. Part 3 complete. |
| **Symptom Log Screen** | Full-screen (outside tab shell) | Body area multi-select (head, chest, back, arms, legs, joints), symptom type selector, severity emoji scale, timing selector (onset, duration), optional notes. Part 3 complete. |
| **Steps Log Panel** | Inline in Log Grid Sheet | Step count entry with mode toggle (Add to today's total / Set as new total). Mode persisted via `stepsLogModeProvider` backed by SharedPreferences. Sync banner shows Apple Health / Health Connect source name when today's data is available. Goal progress from `dailyGoalsProvider`. "Confirm Steps" label when entered value matches synced total. Real `logSteps` API call. Part 5 complete. |
| **Insight Detail** | Pushed | Full-screen explanation of a single AI insight. Shows the data behind the observation (charts, numbers, source integrations), the AI's reasoning, and a "Discuss with Coach" action that opens a pre-filled chat thread for follow-up. |
| **Notification History** | Pushed (bell icon) | Scrollable list of all past push notifications grouped by day. Tapping a notification deep-links to the relevant insight or metric. Accessible from a bell icon in the Today header. |

### 3.2 Data Tab

The user's personal health canvas. Unlike Today (curated by AI), Data is user-controlled. They decide what's prominent, what's hidden, and how it looks.

| Screen | Type | Purpose |
|--------|------|---------|
| **Health Dashboard** | Tab root | **Health Score as a hero element at the very top** — positioned above all category cards. A customizable grid/list of health category cards below. Users can **reorder via drag-and-drop** (long-press to enter edit mode) and **toggle categories on/off** (show/hide). Each card shows a compact summary (today's value + sparkline trend). Users can also **customize card accent colors** per category. Layout arrangement and visibility persist across sessions. |
| **Category Detail** | Pushed (x10 categories) | Drill-down into a specific health category: Activity, Body, Heart, Vitals, Sleep, Nutrition, Cycle, Wellness, Mobility, Environment. Shows all metrics within the category with richer charts and time-range selectors (day / week / month / year). |
| **Metric Detail** | Pushed | Single metric deep-dive. Full chart with pinch-to-zoom, data source attribution ("from Fitbit", "from Apple Health"), raw data table toggle, and an "Ask Coach about this" action that opens a chat thread with the metric pre-loaded as context. |

### 3.3 Coach Tab

The AI chat — Zuralog's most powerful feature. Modeled after modern AI chatbot apps (Gemini, ChatGPT). Opens to a fresh conversation; past conversations accessible via a side drawer.

| Screen | Type | Purpose |
|--------|------|---------|
| **New Chat** | Tab root | Opens directly to a fresh, empty conversation. **Better empty state** with pulsing logo, "What I can do" capability row (4 icons), and grouped suggestion cards with colored left borders and category headers. **Personalized AI Conversation Starters** — prompt chips generated from the user's actual data patterns ("Why did my sleep drop this week?", "How are my running metrics trending?") rather than generic placeholders; falls back to smart defaults when data is insufficient. **File attachment button** in the input bar (image, PDF, text document). **Camera/photo capture button** for food logging via photo. **Integration context banner** showing which apps the AI has access to for this session (compact, dismissible). Side drawer (swipe or hamburger icon) opens the conversation history. |
| **Conversation Drawer** | Modal bottom sheet (`DraggableScrollableSheet` via `showModalBottomSheet` — not a standard Flutter `Drawer`) | List of all past conversations sorted by most recent. Each row shows an AI-generated title, timestamp, and preview snippet. Tapping opens that thread. **Search field** at the top with `AnimatedSize` — filters conversations by title and preview text (client-side, case-insensitive). Empty-results state when no matches. Conversations can be deleted or archived from here. |
| **Chat Thread** | Pushed (from drawer) | An existing conversation. Streaming AI responses with **stop generation button** (red, replaces spinner during streaming; cancels the request and commits partial content or shows `'_Generation stopped._'` placeholder). **Regenerate button** below the last AI message — re-sends the last user message without duplicate DB insert, respecting current persona/proactivity settings. Voice input (hold-to-talk), markdown rendering. **Long-press message actions** — any message bubble (user or AI) can be long-pressed to open a bottom sheet with "Copy" action (writes to clipboard). User messages also show "Edit" option (pre-fills input, truncates subsequent AI responses on save, snapshot-and-restore on cancel; editing indicator bar above input). Same capabilities as New Chat but with loaded history. **File attachment support** — attachment button and camera button in input bar. **Attachment preview cards** in message bubbles (image thumbnail or PDF icon + filename + page count). **Memory extraction confirmation card** shown after the AI processes a file attachment — displays extracted facts with confirm/dismiss options. **Food photo response card** — when a food photo is sent, the AI response includes a structured card showing the food item list, calorie/macro breakdown, and confirm/adjust buttons. **Natural language logging confirmation card** — when the user logs something via conversation ("I just drank 2 glasses of water"), the AI shows a structured confirm card before writing to the health data store. |
| **Quick Actions Sheet** | Bottom sheet | Accessible from a lightning bolt icon in the Coach tab header or from Today tab shortcuts. Pre-built action cards for common tasks: "Log a meal", "Log a workout", "Start a run", "Check my calories", "How did I sleep?". Tapping one opens a new chat thread with the prompt pre-filled and auto-sent. Also includes a **Quick Log** shortcut tile that opens the Quick Log Bottom Sheet (3.1) for structured metric entry without AI. |

### 3.4 Progress Tab

The emotional/motivational tab. Answers "am I on track?" without requiring chart interpretation. Goals, streaks, achievements, and personal reflections.

| Screen | Type | Purpose |
|--------|------|---------|
| **Progress Home** | Tab root | Active goals with progress rings and progress bars. **Streak counter badge** (flame + number) prominently displayed, with a **streak freeze toggle/indicator** — a shield icon that the user can tap to apply a streak freeze on days they can't meet their goal. **Streak milestone celebration card** shown inline when a major streak milestone is hit (7, 30, 100 days). Compact goal widgets with progress rings per goal. "This week vs last week" comparison summary. Everything is glanceable — clear indicators (up/down arrows, completion percentages, streak counts), not dense charts. **Empty state "Set First Goal" button** opens the goal creation form directly as a modal bottom sheet (no intermediate Goals list screen). After saving a goal, the home screen immediately reflects the new goal. |
| **Goals** | Pushed | Full goal management. Create, edit, delete goals. Goal types: weight target, weekly run count, daily calorie limit, sleep duration target, step count, custom. Each goal shows a progress ring, deadline, and trend line. The `UserGoal` model already exists on the backend. |
| **Goal Detail** | Pushed | Single goal deep-dive. Full progress chart over time, milestones hit, projected completion date, AI commentary ("At your current pace, you'll hit your target weight by April 12"). |
| **Achievements** | Pushed | **Full badge gallery with locked/unlocked states**, grouped by category (Consistency, Fitness, Nutrition, Sleep, Social, Milestones). Each badge shows its name, description, unlock conditions, and — if unlocked — the **unlock date**. Locked badges show progress toward unlock (e.g., "3 of 7 days complete"). Unlockable badges mark real behavioral consistency: "First 10K run", "7-day logging streak", "30 days of calorie tracking", "Connected 3 apps". Functions as a motivational archive. |
| **Weekly Report** | Pushed | **Instagram-story-style swipeable card sequence** (not a single scrollable page). Each card is full-screen with a gradient background per card type: Week Summary card (total workouts, avg sleep, calorie adherence), Top Insight card (biggest data-driven takeaway), Goal Adherence card, Comparison card (this week vs last week), and a closing card with the week's streak status. A dot indicator shows card position. **Share-as-image button** on each card exports it as a shareable graphic for social accountability. Can also be pushed as a Sunday evening notification. |
| **Journal / Daily Log** | Pushed | Daily reflection entry. Mood rating (1-5 or emoji scale), short text note, and context tags ("rest day", "stressful", "traveled"). Over time this builds a personal health diary that the AI can correlate with quantitative data ("You tend to sleep worse on days you tag as 'stressful'"). |

### 3.5 Trends Tab

The analytical tab. Where Progress is emotional, Trends is intellectual. This is where Zuralog's cross-app reasoning becomes visual.

| Screen | Type | Purpose |
|--------|------|---------|
| **Trends Home** | Tab root | AI-surfaced correlation cards ("Your sleep quality improves by 22% on days you run before 6pm"). A scrollable time-machine strip at the top allows browsing week-by-week or month-by-month historical summaries. Each correlation card is tappable for full analysis. **Common Correlation Suggestion cards** shown when the AI detects that additional tracked data would unlock a new correlation — e.g., "Start tracking stress to see how it affects your sleep" — tappable to open the Quick Log or relevant integration. |
| **Correlations** | Pushed | Interactive correlation explorer. User picks two metrics (e.g., sleep duration vs. running distance) and sees a scatter plot or overlay chart. AI annotation explains the correlation in plain English. If insufficient data: "Correlations need at least 7 days of data. You have 3 days — check back soon." Backend `analytics/` engine already computes these — this is the visualization layer. |
| **Reports** | Pushed | Auto-generated monthly health report. A polished, scrollable page: key stats, biggest improvements, areas of concern, integration activity summary, goal adherence rate. Exportable as PDF or shareable image. |
| **Data Sources** | Pushed | Read-only transparency screen. Shows every integration feeding data into the app with a **staleness indicator** (green/yellow/red dot per integration), **last sync timestamp** under each integration name, and a **Reconnect button** for error-state integrations. A **data type breakdown** per integration lists exactly which data types it provides (e.g., "Strava: workouts, GPS routes, heart rate during exercise"). Answers "where is this number coming from?" — this is about data provenance, not connection management. |

### 3.6 Auth & Onboarding

| Screen | Type | Purpose |
|--------|------|---------|
| **Welcome** | Standalone | Auth home screen — Apple Sign In, Google Sign In, email options. |
| **Onboarding** | Standalone | First-launch value-prop slideshow (existing `OnboardingPageView`). |
| **Login** | Pushed | Email/password login form. |
| **Register** | Pushed | Email/password registration form. |
| **Onboarding Flow** | Full-screen modal (post-registration) | 6-step paginated onboarding flow with dot indicator and Back/Next navigation. Replaces the old single-page `ProfileQuestionnaire`. **Step 1 — Welcome:** Animated logo fade-in with headline and brand tagline. Full-screen branded card. "Get Started" CTA navigates to step 2. **Step 2 — Goals:** Multi-select grid of 8 health goals (Lose Weight, Build Muscle, Improve Sleep, Boost Energy, Reduce Stress, Train for an Event, Track Nutrition, Improve Mobility). At least one required to proceed. **Step 3 — AI Persona:** 3 persona card options (Tough Love — direct and data-driven; Balanced — supportive with insights; Gentle — encouraging and kind) plus a Proactivity slider (Low / Medium / High) for how often the AI checks in. **Step 4 — Connect Apps:** Informational grid of 6 featured integrations (Strava, Fitbit, Apple Health, Health Connect, Oura, CalAI). Each tile shows the integration logo, name, and a brief data description. No OAuth here — users connect in Settings → Integrations post-onboarding. A "Later" badge reassures users they can skip this step. **Step 5 — Notifications:** Morning Briefing toggle + time picker, Smart Reminders master toggle. These mirror the Settings > Notifications options. **Step 6 — Discovery:** "Where did you hear about Zuralog?" single-select picker (App Store, Friend/Family, Social Media, Search, Other). Selection fires a `onboarding_discovery` PostHog event. Completion navigates to Today Feed. All selections persist to `/api/v1/preferences`. |

### 3.7 Settings & Profile (pushed / modal — not in bottom nav)

| Screen | Access Point | Purpose |
|--------|-------------|---------|
| **Profile** | Avatar tap (side panel or header) | Display name, email, avatar, member-since date, subscription tier badge. Edit profile fields. **Emergency Health Card link/button** — prominently displayed as a tappable card within the Profile screen (not buried in a sub-menu) with a red cross icon and label "Emergency Health Card". This ensures quick access for first responders or users sharing their device. |
| **Settings Hub** | Gear icon from Profile or header | Top-level settings menu: Account, Notifications, Appearance, Coach, Integrations, Privacy & Data, Subscription, About. |
| **Account Settings** | Settings > Account | Email, password change, linked social accounts, delete account. |
| **Notification Preferences** | Settings > Notifications | **Expanded notification settings:** Morning Briefing toggle + time picker (7:00 AM default). Smart Reminders master toggle with per-category sub-toggles (Pattern-based, Gap-based, Goal-based, Celebration). Reminder Frequency selector (Low 1/day / Medium 2/day / High 3/day). Streak Reminders toggle. Achievement Notifications toggle. Anomaly Alerts toggle. Integration Alerts toggle. Quiet Hours start/end time picker (10:00 PM – 7:00 AM default). |
| **Appearance Settings** | Settings > Appearance | Dashboard card color customization (per-category accent picker). Card layout density (compact / comfortable). **Theme selector** (Dark / Light / System — follows OS). **Haptic Feedback toggle** (on/off). **Reset Onboarding Tooltips button** (re-enables all first-visit tooltip overlays). **Disable Tooltips toggle** (globally suppress all onboarding tooltips). |
| **Coach Settings** | Settings > Coach | AI persona tuning (tone: Tough Love / Balanced / Gentle). Response length preference (Concise / Detailed). Suggested prompts on/off. Voice input settings. **Proactivity Level selector** (Low / Medium / High) positioned below the persona selector — controls how frequently the AI proactively surfaces insights, check-ins, and suggestions. |
| **Integrations Management** | Settings > Integrations | The integrations hub — relocated from a top-level tab. Connected / Available / Coming Soon sections. OAuth flows. **Compact sync status badge** (green/yellow/red colored dot) per connected integration. **Last synced timestamp** displayed under each connected integration name. |
| **Privacy & Data** | Settings > Privacy & Data | **AI Memory management** — view all stored AI memories as a list, delete individual memories, clear all with confirmation dialog. **Data Maturity Banner toggle** (show/dismiss the progress indicator). Data export (download all data as JSON/CSV). Data deletion request. Analytics opt-out toggle. Links to Privacy Policy and Terms of Service. |
| **Subscription** | Settings > Subscription (or paywall modal) | Current plan, upgrade/downgrade, billing history, restore purchases. RevenueCat paywall for Pro upgrade. |
| **About** | Settings > About | App version, build number, open-source licenses, support link, community guidelines link. |
| **Emergency Health Card** | Profile > Emergency Health Card button | Quick-access read-only view of the user's critical medical information: blood type, known allergies, current medications, emergency contacts (name + phone number), and any additional medical notes. Designed for fast retrieval — large typography, high contrast, no authentication required to view (accessible from lock screen shortcut in future). |
| **Emergency Health Card Edit** | Emergency Health Card > Edit button | Edit form for all medical info fields: blood type dropdown, allergies (add/remove chips), medications (add/remove with dosage field), emergency contacts (add/remove with name + phone), and a free-text medical notes field. Changes save immediately. |
| **Privacy Policy** | Link from Privacy & Data | Full GDPR/CCPA privacy policy. |
| **Terms of Service** | Link from Privacy & Data | Full terms of service. |

---

## 4. Shared Component Library

**Location:** `zuralog/lib/shared/widgets/` (barrel export: `widgets.dart`)

The following reusable components are available across all screens:

| Component | File | Purpose | Added |
|-----------|------|---------|-------|
| `SectionHeader` | `headers/section_header.dart` | Section title with optional trailing widget slot and left accent bar | Phase 10.9.5 |
| `ZInsightCard` | `cards/z_insight_card.dart` | Reusable AI insight card (extracted from Today screen) | Part 1 |
| `ZEmptyInsightsState` | `states/z_empty_insights_state.dart` | Empty insights state with two CTA callbacks | Part 1 |
| `ZLogRingWidget` | `health/z_log_ring_widget.dart` | Circular log completion ring watching `logRingProvider` | Part 1 |
| `ZSnapshotCard` | `cards/z_snapshot_card.dart` | Compact metric snapshot card (today's value for one metric) | Part 1 |
| `ZDailyGoalsCard` | `cards/z_daily_goals_card.dart` | Daily goals progress card with setup prompt | Part 1 |
| `ZIconBadge` | `badges/z_icon_badge.dart` | 36–44px rounded icon container | Phase 10.9.5 |
| `ZSettingsTile` | `tiles/z_settings_tile.dart` | Settings row: icon + title + subtitle + trailing | Phase 10.9.5 |
| `ZSelectableTile` | `tiles/z_selectable_tile.dart` | Animated selectable card frame | Phase 10.9.5 |
| `ZEmptyState` | `states/z_empty_state.dart` | Generic empty state with icon, headline, and CTA | Phase 10.9.5 |
| `ZErrorState` | `states/z_error_state.dart` | Generic error state with retry button | Phase 10.9.5 |
| `ZuralogSpringButton` | `buttons/zuralog_spring_button.dart` | Spring-animated button with press state | Phase 10.9.5 |
| `HealthScoreZeroState` | `health_score_zero_state.dart` | Zero-data state for Health Score with action rows | Phase 10.10 |
| `ZLogFab` | `buttons/z_log_fab.dart` | Circular floating action button for quick log entry | Part 2 |
| `ZLogGridSheet` | `sheets/z_log_grid_sheet.dart` | Modal bottom sheet with 10-tile 4-column log type selection grid | Part 2 |
| `ZLogGridCell` | `sheets/z_log_grid_cell.dart` | Single tile in the log type selection grid | Part 2 |
| `ZWaterLogPanel` | `log_panels/z_water_log_panel.dart` | Inline water log: vessel picker, custom input, today's total; oz/ml unit-aware; real `logWater` API call; error handling via parentMessenger | Part 5 |
| `ZWellnessLogPanel` | `log_panels/z_wellness_log_panel.dart` | Inline mood/energy/stress sliders + notes; real `logWellness` API call; error handling via parentMessenger | Part 5 |
| `ZWeightLogPanel` | `log_panels/z_weight_log_panel.dart` | Inline weight log with kg/lbs toggle; pre-fills from latest backend value; delta indicator vs previous; last-used unit persisted via SharedPreferences; real `logWeight` API call | Part 5 |
| `ZStepsLogPanel` | `log_panels/z_steps_log_panel.dart` | Inline step count entry; sync banner shows Apple Health / Health Connect source name; goal progress from `dailyGoalsProvider`; "Confirm Steps" label when value matches synced total; manual source omits banner; real `logSteps` API call | Part 5 |
| `ZSectionLabel` | `layout/z_section_label.dart` | Section title label for log screens | Part 3 |

---

## 4. Screen Count Summary

| Area | Screens | New vs. Existing |
|------|---------|-----------------|
| Today tab | 4 | 3 existing + 1 new (Quick Log Bottom Sheet) |
| Data tab | 3 | 3 existing (rebuilt) |
| Coach tab | 4 | 2 new, 2 existing (rebuilt) |
| Progress tab | 6 | 6 new |
| Trends tab | 4 | 4 new (backend exists, no UI) |
| Auth & Onboarding | 5 | 4 existing + 1 rebuilt (Onboarding Flow replaces Profile Questionnaire) |
| Settings & Profile | 14 | 12 existing + 2 new (Emergency Health Card + Edit) |
| **Total** | **~40** | **~27 new/rebuilt, ~13 carried forward** |

---

## 5. Backend Dependencies

Screens that require new backend work (not just UI):

| Screen | Backend Requirement |
|--------|-------------------|
| Today Feed | New endpoint for curated daily insights feed. Background insight generation via Celery. Health Score computation endpoint. Data Maturity tracking (days with data count). |
| Notification History | Persist push notifications server-side (currently fire-and-forget). |
| Quick Log Bottom Sheet | New endpoint for manual health metric entries (water, mood, energy, stress, pain, notes). |
| Dashboard Customization | User preference storage for card order, visibility, and colors (can be client-side via Drift/SharedPreferences, or synced to backend for cross-device). |
| Goals (UI) | `UserGoal` model exists. May need additional endpoints for goal CRUD if not already complete. |
| Achievements | New achievement/badge model and tracking logic. |
| Weekly/Monthly Reports | Report generation endpoint (can leverage existing `analytics/` engine). |
| Journal | New `JournalEntry` model and CRUD endpoints. |
| Correlations (UI) | Backend `analytics/` endpoints exist. May need additional visualization-friendly response formats. |
| Coach Settings | New user preferences fields for AI persona, proactivity level, response length, prompt visibility. |
| Conversation Management | Conversation list, rename, delete, archive endpoints (some may exist via `Conversation` model). |
| Emergency Health Card | New `EmergencyHealthCard` model and CRUD endpoints per user. |
| AI Memory Management | Pinecone integration. Memory list, delete, clear-all endpoints exposed to the client. |
| File Attachments | Supabase Storage upload endpoint. Multimodal message handling in the AI orchestrator. |
