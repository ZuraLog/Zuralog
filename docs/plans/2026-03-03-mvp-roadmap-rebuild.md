# MVP Roadmap — Phased Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Complete all remaining MVP work — backend features, full UI rebuild (37 screens), design system updates, and observability — in a dependency-optimized sequence where related screens and features are built together.

**Architecture:** Each phase groups backend work, Flutter screens, and design tokens that depend on each other. No phase starts work that requires an output from a later phase. Within each phase, tasks are ordered so that foundational services come before the UI that consumes them.

**Tech Stack:** Python/FastAPI (Cloud Brain), Flutter/Dart + Riverpod (Mobile), Supabase Postgres, Redis, Celery, Pinecone, PostHog, Sentry, fl_chart

**Source Docs:** [roadmap.md](../roadmap.md) | [mvp-features.md](../mvp-features.md) | [screens.md](../screens.md) | [design.md](../design.md) | [implementation-status.md](../implementation-status.md)

---

## Status Legend

| Symbol | Meaning |
|--------|---------|
| `[ ]` | Not started |
| `[~]` | In progress |
| `[x]` | Complete |

---

## Dependency Map (Read First)

```
Phase 0: Design System Foundation
  └── Every subsequent phase depends on this (tokens, theme, components)

Phase 1: App Shell & Navigation
  └── Every screen depends on the 5-tab scaffold + GoRouter restructure

Phase 2: Core Backend Services (no UI)
  ├── Health Score engine ──────────────────────┐
  ├── Anomaly Detection engine ─────────────────┤
  ├── Pinecone AI Memory ───────────────────────┤
  ├── User Preferences API ─────────────────────┤
  ├── System Prompt Tuning ─────────────────────┤
  ├── Insight Generation pipeline ──────────────┤
  ├── Achievement model + tracker ──────────────┤
  ├── Streak engine ────────────────────────────┤
  ├── Journal model ────────────────────────────┤
  ├── Quick Log data model ─────────────────────┤
  ├── Conversation CRUD endpoints ──────────────┤
  ├── Morning Briefing Celery task ─────────────┤
  ├── Smart Reminder engine ────────────────────┤
  ├── Notification persistence ─────────────────┤
  ├── Report generation (weekly/monthly) ───────┤
  ├── Personalized prompt endpoint ─────────────┤
  ├── Contextual Quick Actions endpoint ────────┤
  ├── Correlation Suggestion engine ────────────┤
  ├── Data Maturity service ────────────────────┤
  ├── Emergency Health Card model ──────────────┤
  ├── NL Logging confirmation flow ─────────────┤
  └── File attachment pipeline ─────────────────┘
        │
        ▼
Phase 3: Today Tab (3 screens) ✅ ── needs: Health Score, Insights, Anomaly, Data Maturity, Quick Actions, Streaks
Phase 4: Coach Tab (4 screens) ── needs: Conversation CRUD, Pinecone Memory, NL Logging, File Attachments, Personalized Prompts
Phase 5: Data Tab (3 screens) ── needs: Health Score, User Preferences (dashboard layout)
Phase 6: Progress Tab (6 screens) ── needs: Goals, Streaks, Achievements, Journal, Weekly Report
Phase 7: Trends Tab (4 screens) ── needs: Correlations, Reports, Data Sources, Correlation Suggestions
Phase 8: Settings & Profile (12 screens) ── needs: User Preferences, all feature-specific settings
Phase 9: Onboarding Rebuild ── needs: Settings, Integrations, Goals, Persona
Phase 10: Engagement & Polish ── needs: All screens built (haptics, tooltips, smart reminders, morning briefing)
Phase 11: Observability & QA ── needs: Everything built (PostHog events, Sentry boundaries, final review)
```

---

## Phase 0: Design System Foundation

**Why first:** Every screen depends on these tokens and components. Building screens without them leads to hardcoded values and inconsistency.

**Branch:** `feat/design-system-v3`

### Task 0.1: Light Mode Color Tokens

**Files:**
- Modify: `docs/design.md` — add Light Mode section
- Modify: `zuralog/lib/core/theme/app_colors.dart`
- Modify: `zuralog/lib/core/theme/app_theme.dart`

**What to build:**
- [x] Define light mode surface tokens in `design.md`:
  - `scaffoldBackgroundColor`: `#FFFFFF`
  - `colorScheme.surface`: `#F2F2F7`
  - `cardBackground`: `#FFFFFF`
  - `elevatedSurface`: `#FFFFFF`
  - `divider`: `#E5E5EA`
  - `inputBackground`: `#F2F2F7`
  - `textPrimary`: `#000000`
  - `textSecondary`: `#636366`
  - `textTertiary`: `#ABABAB`
- [x] Add light mode color constants to `AppColors`
- [x] Create `AppTheme.light()` factory alongside existing `AppTheme.dark()`
- [x] Category colors remain identical across both themes
- [x] Wire theme selector to Riverpod provider (Dark / Light / System)
- [x] Test: theme switching produces correct surface/text colors

**Commit:** `feat(design): add light mode color tokens and AppTheme.light()`

### Task 0.2: Haptic Feedback Service

**Files:**
- Create: `zuralog/lib/core/haptics/haptic_service.dart`
- Create: `zuralog/lib/core/haptics/haptic_providers.dart`
- Create: `zuralog/lib/core/haptics/haptic.dart` (barrel)
- Test: `zuralog/test/core/haptics/haptic_service_test.dart`

**What to build:**
- [x] `HapticService` with semantic methods: `light()`, `medium()`, `success()`, `warning()`, `selectionTick()`
- [x] Platform channel or `HapticFeedback` Flutter API abstraction
- [x] Riverpod provider that reads the haptic toggle from user preferences
- [x] When toggle is off, all methods are no-ops
- [x] Tests for each haptic type + disabled state

**Commit:** `feat(design): add HapticService with semantic haptic types`

### Task 0.3: Onboarding Tooltip Widget

**Files:**
- Create: `zuralog/lib/shared/widgets/onboarding_tooltip.dart`
- Create: `zuralog/lib/shared/widgets/onboarding_tooltip_provider.dart`
- Test: `zuralog/test/shared/widgets/onboarding_tooltip_test.dart`

**What to build:**
- [x] `OnboardingTooltip` widget: bubble with pointer arrow, text, "Got it" dismiss button
- [x] `surface-700` background, `bodyMedium` text style, 12px radius
- [x] Sequential display: only show one tooltip at a time per screen
- [x] State stored in `SharedPreferences` per screen key
- [x] Riverpod provider for tooltip seen/unseen state
- [x] "Reset Tooltips" and "Disable Tooltips" methods for Settings
- [x] Tests: show on first visit, dismiss persists, reset re-enables

**Commit:** `feat(design): add OnboardingTooltip shared widget`

### Task 0.4: Health Score Widget Component

**Files:**
- Create: `zuralog/lib/shared/widgets/health_score_widget.dart`
- Test: `zuralog/test/shared/widgets/health_score_widget_test.dart`

**What to build:**
- [x] Animated ring/gauge component with color stops: red (0-39), yellow (40-69), green (70-100)
- [x] Two size variants: hero (120pt diameter) and compact (48pt diameter)
- [x] 800ms `easeOutCubic` fill animation on load
- [x] Inner label: score number in `displayLarge`
- [x] 7-day trend sparkline below (hero variant only)
- [x] AI commentary text slot (hero variant only)
- [x] Tappable — accepts `onTap` callback
- [x] Tests: renders both variants, correct color for score ranges, animation completes

**Commit:** `feat(design): add HealthScoreWidget ring/gauge component`

### Task 0.5: Shared UI Components

**Files:**
- Create: `zuralog/lib/shared/widgets/streak_badge.dart`
- Create: `zuralog/lib/shared/widgets/data_maturity_banner.dart`
- Create: `zuralog/lib/shared/widgets/confirmation_card.dart`
- Create: `zuralog/lib/shared/widgets/quick_log_sheet.dart`
- Create: `zuralog/lib/shared/widgets/category_card.dart`
- Create: `zuralog/lib/shared/widgets/time_range_selector.dart`

**What to build:**
- [x] `StreakBadge`: flame icon + count + optional shield icon for freeze. Inline and standalone variants
- [x] `DataMaturityBanner`: progress bar (sage green fill), label ("Data maturity: X of 7 days"), dismiss button
- [x] `ConfirmationCard`: in-chat card with data preview, Confirm/Edit buttons. Used for NL logging and memory extraction
- [x] `QuickLogSheet`: bottom sheet grid layout with sliders (mood, energy, stress), increment buttons (water), text fields (notes, symptoms), submit bar
- [x] `CategoryCard`: health category card with category color accent, sparkline, delta indicator. Supports drag-and-drop reorder mode
- [x] `TimeRangeSelector`: segmented control (7D / 30D / 90D / Custom) with `surface-500` background and sage-green active indicator
- [x] All components use `AppColors` and `AppTextStyles` — zero hardcoded hex

**Commit:** `feat(design): add shared UI components for MVP features`

### Task 0.6: Update design.md

**Files:**
- Modify: `docs/design.md`

**What to document:**
- [x] Light mode color token table (from Task 0.1)
- [x] Haptic feedback specification table (interaction → haptic type → platform API)
- [x] Onboarding tooltip component spec (background, radius, pointer, text style, dismiss)
- [x] Health Score widget spec (sizes, color stops, animation)
- [x] Data Maturity indicator spec (height, fill color, label position)
- [x] Streak counter badge spec (flame, number, shield, variants)
- [x] Quick Log bottom sheet spec (grid layout, slider, increment, submit bar)
- [x] File attachment UI spec (button icon, preview cards, upload progress)
- [x] Confirmation card spec (layout, buttons, data preview)
- [x] Food photo response card spec (food list, macro breakdown, confirm/adjust)
- [x] Weekly Story Recap spec (swipeable cards, background gradients, share button)

**Commit:** `docs(design): add v3.1 component and light mode specifications`

---

## Phase 1: App Shell & Navigation Restructure

**Why second:** The 5-tab bottom nav is the skeleton everything else hangs on. Without it, no screen can be placed.

**Branch:** `feat/app-shell-rebuild`

### Task 1.1: Bottom Navigation Scaffold

**Files:**
- Modify: `zuralog/lib/core/navigation/` (GoRouter config)
- Create: `zuralog/lib/features/shell/app_shell.dart`

**What to build:**
- [x] 5-tab bottom nav: Today, Data, Coach, Progress, Trends
- [x] Frosted glass effect: `BackdropFilter` with Gaussian blur, `surface-900` at 70% opacity
- [x] Active tab: sage-green icon + label. Inactive: `text-tertiary`
- [x] 200ms cross-fade tab switch animation
- [x] Each tab maintains its own navigation stack (nested `Navigator` or `StatefulShellRoute`)
- [x] Settings/Profile pushed from header icons — not tabs
- [x] Placeholder screens for each tab root

**Commit:** `feat(nav): rebuild 5-tab bottom navigation scaffold`

### Task 1.2: GoRouter Route Restructure

**Files:**
- Modify: `zuralog/lib/core/router/app_router.dart`
- Modify: `zuralog/lib/core/router/route_names.dart`

**What to build:**
- [x] `StatefulShellRoute.indexedStack` for 5 tabs
- [x] Route definitions for all 37 screens (placeholder widgets initially)
- [x] Route paths:
  - `/today`, `/today/insight/:id`, `/today/notifications`
  - `/data`, `/data/category/:id`, `/data/metric/:id`
  - `/coach`, `/coach/thread/:id`
  - `/progress`, `/progress/goals`, `/progress/goals/:id`, `/progress/achievements`, `/progress/report`, `/progress/journal`
  - `/trends`, `/trends/correlations`, `/trends/reports`, `/trends/sources`
  - `/settings`, `/settings/account`, `/settings/notifications`, `/settings/appearance`, `/settings/coach`, `/settings/integrations`, `/settings/privacy`, `/settings/subscription`, `/settings/about`
  - `/profile`, `/profile/emergency-card`, `/profile/emergency-card/edit`
- [x] Auth guard preserved
- [x] Deep link routes preserved

**Commit:** `feat(nav): restructure GoRouter with all 37 screen routes`

---

## Phase 2: Core Backend Services

**Why third:** UI screens need data. This phase builds every backend service, model, and endpoint that the screens will consume. No Flutter UI in this phase — pure backend.

**Branch:** `feat/backend-mvp-services`

### Task 2.1: User Preferences API

**Files:**
- Create: `cloud-brain/app/models/user_preferences.py`
- Create: `cloud-brain/app/api/v1/preferences_routes.py`
- Modify: `cloud-brain/app/models/user.py` (add relationship)
- Migration: Alembic migration for `user_preferences` table
- Test: `cloud-brain/tests/api/test_preferences_routes.py`

**What to build:**
- [x] `UserPreferences` model: `user_id`, `coach_persona` (enum: tough_love/balanced/gentle), `proactivity_level` (enum: low/medium/high), `dashboard_layout` (JSON — card order + visibility + colors), `notification_settings` (JSON — all toggles from mvp-features.md Section 10), `theme` (enum: dark/light/system), `haptic_enabled` (bool), `tooltips_enabled` (bool), `onboarding_complete` (bool), `morning_briefing_time` (time), `checkin_reminder_time` (time), `quiet_hours_start` (time), `quiet_hours_end` (time), `goals` (JSON array)
- [x] CRUD endpoints: `GET /api/v1/preferences`, `PUT /api/v1/preferences`, `PATCH /api/v1/preferences` (partial update)
- [x] Default values populated on first access
- [x] RLS: users can only access their own preferences
- [x] Tests: CRUD operations, defaults, partial update, auth guard

**Commit:** `feat(api): add UserPreferences model and CRUD endpoints`

### Task 2.2: Health Score Engine

**Files:**
- Create: `cloud-brain/app/services/health_score.py`
- Create: `cloud-brain/app/api/v1/health_score_routes.py`
- Create: `cloud-brain/app/tasks/health_score_tasks.py`
- Test: `cloud-brain/tests/services/test_health_score.py`

**What to build:**
- [x] `HealthScoreCalculator` service:
  - Inputs: sleep duration/quality (30%), HRV (20%), resting HR (15%), activity vs baseline (15%), sleep consistency (10%), steps vs goal (10%)
  - Normalize each input to 0-100 sub-score based on 30-day personal history (percentile)
  - Missing inputs excluded — weights redistribute proportionally
  - Minimum: 1 sleep OR 1 activity source required
  - Returns: composite score (0-100), sub-scores dict, AI commentary string, 7-day history
- [x] `GET /api/v1/health-score` endpoint (returns today's score + 7-day trend)
- [x] Celery task: recalculate score when new health data is ingested
- [x] Tests: full data, partial data, no data edge case, score ranges, commentary generation

**Commit:** `feat(api): add Health Score calculation engine and endpoint`

### Task 2.3: Metric Anomaly Detection

**Files:**
- Create: `cloud-brain/app/services/anomaly_detector.py`
- Modify: `cloud-brain/app/tasks/` (add post-ingest anomaly check)
- Test: `cloud-brain/tests/services/test_anomaly_detector.py`

**What to build:**
- [x] `AnomalyDetector` service:
  - 30-day rolling average + standard deviation per metric per user
  - Trigger when reading > 2 standard deviations from mean
  - Minimum 14 days of data before activating
  - Returns: metric name, current value, baseline, deviation magnitude, severity (normal/elevated/critical)
- [x] Post-ingest Celery pipeline hook: check new data for anomalies
- [x] Generate anomaly insight cards (stored in insights table)
- [x] Push notification for critical severity anomalies
- [x] Tests: below threshold, above threshold, insufficient data, severity levels

**Commit:** `feat(api): add Metric Anomaly Detection service`

### Task 2.4: Pinecone AI Long-Term Memory

**Files:**
- Create: `cloud-brain/app/services/pinecone_memory_store.py`
- Modify: `cloud-brain/app/agent/orchestrator.py` (replace InMemoryStore)
- Create: `cloud-brain/app/api/v1/memory_routes.py`
- Test: `cloud-brain/tests/services/test_pinecone_memory_store.py`

**What to build:**
- [x] `PineconeMemoryStore` implementing `MemoryStore` protocol
- [x] Namespace per user (Supabase user ID)
- [x] `save_memory(user_id, text, metadata)`: embed text → upsert to Pinecone
- [x] `query_memory(user_id, query, top_k=5)`: embed query → similarity search
- [x] `list_memories(user_id)`: list all stored memories with metadata
- [x] `delete_memory(user_id, memory_id)`: delete single memory
- [x] `clear_memories(user_id)`: delete all memories for user
- [x] Orchestrator integration: inject top-5 relevant memories into system prompt per request
- [x] Memory extraction: identify health-relevant statements in conversation and auto-store
- [x] API endpoints for Privacy & Data settings: `GET /api/v1/memories`, `DELETE /api/v1/memories/:id`, `DELETE /api/v1/memories`
- [x] Tests: CRUD operations, query relevance, namespace isolation, orchestrator integration

**Commit:** `feat(api): add Pinecone vector store for AI long-term memory`

### Task 2.5: System Prompt Tuning

**Files:**
- Modify: `cloud-brain/app/agent/orchestrator.py`
- Create: `cloud-brain/app/agent/prompts.py`
- Test: `cloud-brain/tests/agent/test_prompts.py`

**What to build:**
- [x] Three persona system prompts: Tough Love, Balanced, Gentle
- [x] Proactivity level modifiers injected into system prompt
- [x] Memory-aware prompt template: `{base_persona} + {proactivity_modifier} + {relevant_memories} + {connected_integrations}`
- [x] Dynamic prompt assembly per request based on user preferences
- [x] Tests: correct persona selection, proactivity modifier injection, memory inclusion

**Commit:** `feat(agent): add configurable AI persona system prompts`

### Task 2.6: Insight Generation Pipeline

**Files:**
- Modify: `cloud-brain/app/services/insight_generator.py` (expand)
- Create: `cloud-brain/app/models/insight.py`
- Create: `cloud-brain/app/api/v1/insight_routes.py`
- Create: `cloud-brain/app/tasks/insight_tasks.py`
- Migration: Alembic migration for `insights` table
- Test: `cloud-brain/tests/services/test_insight_generator.py`

**What to build:**
- [x] `Insight` model: `id`, `user_id`, `type` (enum: sleep_analysis, activity_progress, nutrition_summary, anomaly_alert, goal_nudge, correlation_discovery, streak_milestone, welcome), `title`, `body`, `data` (JSON — charts, numbers, sources), `reasoning` (AI explanation), `priority`, `created_at`, `read_at`, `dismissed_at`
- [x] `InsightGenerator` expansion:
  - Generate daily insight cards after new health data ingestion (Celery)
  - Types: sleep analysis, activity progress, anomaly alerts, goal nudges, correlation discoveries
  - Time-of-Day awareness: morning/afternoon/evening/night content priority
  - Data Maturity awareness: adjust content based on data maturity level
- [x] API endpoints: `GET /api/v1/insights` (paginated, filtered by type/date), `PATCH /api/v1/insights/:id` (mark read/dismissed)
- [x] Tests: insight generation for each type, time-awareness, pagination, auth

**Commit:** `feat(api): expand InsightGenerator with daily card pipeline`

### Task 2.7: Conversation Management Endpoints

**Files:**
- Modify: `cloud-brain/app/api/v1/chat.py`
- Test: `cloud-brain/tests/api/test_conversation_management.py`

**What to build:**
- [x] `GET /api/v1/conversations` — list all conversations (title, created_at, preview snippet, message_count)
- [x] `PATCH /api/v1/conversations/:id` — rename, archive
- [x] `DELETE /api/v1/conversations/:id` — soft delete
- [x] AI-generated title on first user message (if not already implemented)
- [x] Tests: list, rename, archive, delete, auth guard

**Commit:** `feat(api): add conversation list, rename, archive, delete endpoints`

### Task 2.8: Personalized Prompt Suggestions Endpoint

**Files:**
- Create: `cloud-brain/app/api/v1/prompt_suggestions.py`
- Test: `cloud-brain/tests/api/test_prompt_suggestions.py`

**What to build:**
- [x] `GET /api/v1/prompts/suggestions` — returns 3-5 contextual prompt suggestions based on:
  - User's latest synced data (recent anomalies, sleep trends, activity patterns)
  - User's goals
  - Time of day
- [x] Fallback to smart defaults when data is insufficient
- [x] Tests: with data, without data, time-based variation

**Commit:** `feat(api): add personalized AI prompt suggestions endpoint`

### Task 2.9: Contextual Quick Actions Endpoint

**Files:**
- Create: `cloud-brain/app/api/v1/quick_actions.py`
- Test: `cloud-brain/tests/api/test_quick_actions.py`

**What to build:**
- [x] `GET /api/v1/quick-actions` — returns prioritized action list based on:
  - Time of day (morning/afternoon/evening/night)
  - Recent events (post-workout detection, new integration connected)
  - Data gaps (no water logged, no check-in today)
  - Goal proximity (800 steps from goal)
  - Proactivity level (low = fewer suggestions)
- [x] Each action: `id`, `title`, `subtitle`, `icon`, `prompt` (pre-filled chat message)
- [x] Tests: time-based actions, event-based actions, proactivity filtering

**Commit:** `feat(api): add contextual Quick Actions endpoint`

### Task 2.10: Achievement Model & Tracker

**Files:**
- Create: `cloud-brain/app/models/achievement.py`
- Create: `cloud-brain/app/services/achievement_tracker.py`
- Create: `cloud-brain/app/api/v1/achievement_routes.py`
- Migration: Alembic migration for `achievements` table
- Test: `cloud-brain/tests/services/test_achievement_tracker.py`

**What to build:**
- [x] `Achievement` model: `id`, `user_id`, `achievement_key` (string), `unlocked_at` (timestamp, nullable)
- [x] Achievement definitions (hard-coded registry):
  - Getting Started: first_integration, first_chat, first_insight
  - Consistency: streak_7, streak_30, streak_90, streak_365
  - Goals: first_goal, goals_5_complete, overachiever
  - Data: connected_3, data_rich_30, full_picture_5_categories
  - Coach: conversations_50, insights_100, memories_20
  - Health: improved_bedtime, personal_best, anomaly_aware_10
- [x] `AchievementTracker` service: check-and-unlock after relevant events
- [x] Push notification on unlock
- [x] API: `GET /api/v1/achievements` (all with locked/unlocked state), `GET /api/v1/achievements/recent` (last 5 unlocked)
- [x] Tests: unlock conditions, duplicate prevention, notification trigger

**Commit:** `feat(api): add Achievement model and tracking service`

### Task 2.11: Streak Engine

**Files:**
- Create: `cloud-brain/app/services/streak_tracker.py`
- Create: `cloud-brain/app/api/v1/streak_routes.py`
- Migration: Alembic migration for `user_streaks` table
- Test: `cloud-brain/tests/services/test_streak_tracker.py`

**What to build:**
- [x] `UserStreak` model: `user_id`, `streak_type` (enum: engagement, steps, workouts, checkin), `current_count`, `longest_count`, `last_activity_date`, `freeze_count` (max 2), `freeze_used_this_week`
- [x] Streak types: engagement (any data logged), step goal met, workout days, wellness check-in
- [x] Freeze mechanic: 1 free freeze per week, accumulates up to 2
- [x] Milestone celebrations at: 7, 14, 30, 60, 90, 180, 365 days
- [x] API: `GET /api/v1/streaks`, `POST /api/v1/streaks/:type/freeze` (use a freeze)
- [x] Celery task: end-of-day streak evaluation
- [x] Tests: increment, break, freeze, milestone detection, weekly freeze reset

**Commit:** `feat(api): add streak tracking engine with freeze mechanic`

### Task 2.12: Journal Model & Endpoints

**Files:**
- Create: `cloud-brain/app/models/journal_entry.py`
- Create: `cloud-brain/app/api/v1/journal_routes.py`
- Migration: Alembic migration for `journal_entries` table
- Test: `cloud-brain/tests/api/test_journal_routes.py`

**What to build:**
- [x] `JournalEntry` model: `id`, `user_id`, `date`, `mood` (1-10), `energy` (1-10), `stress` (1-10), `sleep_quality` (1-10, optional), `notes` (text), `tags` (JSON array: "rest day", "stressful", "traveled", etc.), `created_at`
- [x] CRUD endpoints: `POST`, `GET` (by date range), `PUT`, `DELETE`
- [x] One entry per day constraint (upsert behavior)
- [x] Tests: create, update, list by date range, one-per-day constraint, auth

**Commit:** `feat(api): add JournalEntry model and CRUD endpoints`

### Task 2.13: Quick Log Data Model & Endpoints

**Files:**
- Create: `cloud-brain/app/models/quick_log.py`
- Create: `cloud-brain/app/api/v1/quick_log_routes.py`
- Migration: Alembic migration for `quick_logs` table
- Test: `cloud-brain/tests/api/test_quick_log_routes.py`

**What to build:**
- [x] `QuickLog` model: `id`, `user_id`, `metric_type` (enum: water, mood, energy, stress, sleep_quality, pain, notes), `value` (float, nullable), `text_value` (string, nullable for pain/notes), `tags` (JSON array for symptom chips), `logged_at`
- [x] `POST /api/v1/quick-log` — single entry
- [x] `POST /api/v1/quick-log/batch` — batch submit (entire check-in at once)
- [x] `GET /api/v1/quick-log` — history by date range and metric type
- [x] Shared storage with Wellness Check-in (same model, different access point)
- [x] Feed into analytics engine for correlations
- [x] Tests: single log, batch, history query, analytics feed

**Commit:** `feat(api): add QuickLog model and endpoints for manual data entry`

### Task 2.14: Emergency Health Card

**Files:**
- Create: `cloud-brain/app/models/emergency_card.py`
- Create: `cloud-brain/app/api/v1/emergency_card_routes.py`
- Migration: Alembic migration for `emergency_health_cards` table
- Test: `cloud-brain/tests/api/test_emergency_card_routes.py`

**What to build:**
- [x] `EmergencyHealthCard` model: `user_id`, `blood_type`, `allergies` (JSON array), `medications` (JSON array), `conditions` (JSON array), `emergency_contacts` (JSON array of {name, relationship, phone}), `updated_at`
- [x] CRUD: `GET`, `PUT` (upsert)
- [x] Feed key fields into AI memory (medications, allergies, conditions)
- [x] Tests: create, update, read, memory integration

**Commit:** `feat(api): add EmergencyHealthCard model and endpoints`

### Task 2.15: Notification Persistence

**Files:**
- Create: `cloud-brain/app/models/notification_log.py`
- Modify: `cloud-brain/app/services/push_service.py` (persist on send)
- Create: `cloud-brain/app/api/v1/notification_routes.py`
- Migration: Alembic migration for `notification_logs` table
- Test: `cloud-brain/tests/api/test_notification_routes.py`

**What to build:**
- [x] `NotificationLog` model: `id`, `user_id`, `title`, `body`, `type` (enum: insight, anomaly, streak, achievement, reminder, briefing, integration_alert), `deep_link` (URI for tap navigation), `sent_at`, `read_at`
- [x] Modify `PushService.send()` to persist every sent notification
- [x] `GET /api/v1/notifications` — paginated history grouped by day
- [x] `PATCH /api/v1/notifications/:id` — mark read
- [x] Tests: persistence on send, history query, grouping, mark read

**Commit:** `feat(api): persist push notifications for Notification History screen`

### Task 2.16: Morning Briefing Celery Task

**Files:**
- Create: `cloud-brain/app/tasks/morning_briefing_task.py`
- Modify: `cloud-brain/app/worker.py` (add Beat schedule)
- Test: `cloud-brain/tests/tasks/test_morning_briefing_task.py`

**What to build:**
- [x] Celery Beat schedule: runs every 15 minutes, checks which users have briefing time in the current window
- [x] Per-user briefing generation:
  - Sleep recap (if sleep data available)
  - What the body needs today (based on trends)
  - One actionable suggestion
  - Graceful fallback when data is limited
- [x] Send via FCM push notification
- [x] Persist as insight card in Today Feed
- [x] Respect user preference: enabled/disabled, Pro/Free tier
- [x] Tests: briefing generation, time-window matching, fallback, tier gating

**Commit:** `feat(api): add Morning Briefing Celery task with per-user scheduling`

### Task 2.17: Smart Reminder Engine

**Files:**
- Create: `cloud-brain/app/services/smart_reminder.py`
- Create: `cloud-brain/app/tasks/smart_reminder_tasks.py`
- Modify: `cloud-brain/app/worker.py`
- Test: `cloud-brain/tests/services/test_smart_reminder.py`

**What to build:**
- [x] `SmartReminderEngine`:
  - Pattern-based reminders (from behavioral history)
  - Gap-based reminders (missing expected data)
  - Goal-based reminders (proximity to targets)
  - Celebration reminders (positive milestones)
- [x] Frequency cap: max 3/day per user (configurable: 1/2/3)
- [x] Deduplication: same topic not repeated within 48 hours
- [x] Quiet Hours respect
- [x] Per-category toggles from user preferences
- [x] Celery periodic task: evaluate and send reminders
- [x] Tests: each reminder type, frequency cap, dedup, quiet hours

**Commit:** `feat(api): add Smart Reminder engine with frequency cap and dedup`

### Task 2.18: Report Generation (Weekly + Monthly)

**Files:**
- Create: `cloud-brain/app/services/report_generator.py`
- Create: `cloud-brain/app/api/v1/report_routes.py`
- Create: `cloud-brain/app/tasks/report_tasks.py`
- Test: `cloud-brain/tests/services/test_report_generator.py`

**What to build:**
- [x] `ReportGenerator`:
  - Weekly: total workouts, avg sleep, calorie adherence, top insight, week-over-week comparison, AI highlights
  - Monthly: category summaries, top correlations, goal progress, trend directions, AI recommendations
- [x] Report data model: `id`, `user_id`, `type` (weekly/monthly), `period_start`, `period_end`, `data` (JSON), `created_at`
- [x] Celery tasks: weekly (Monday 6am), monthly (1st of month 6am)
- [x] API: `GET /api/v1/reports` (list), `GET /api/v1/reports/:id` (detail)
- [x] Tests: weekly generation, monthly generation, data edge cases

**Commit:** `feat(api): add weekly and monthly report generation`

### Task 2.19: Correlation Suggestion Engine

**Files:**
- Create: `cloud-brain/app/services/correlation_suggester.py`
- Test: `cloud-brain/tests/services/test_correlation_suggester.py`

**What to build:**
- [x] `CorrelationSuggester`:
  - Input: user goals + connected integrations + available data categories
  - Output: suggestions for what to track to unlock better insights
  - Goal→gap mapping (per mvp-features.md Feature J)
  - Dismissal tracking: suggestion not shown again for 30 days after dismiss
- [x] Integrated into insight generation pipeline (surfaces as Today Feed cards and Trends suggestions)
- [x] Tests: each goal→gap mapping, dismissal persistence, connected-app filtering

**Commit:** `feat(api): add Correlation Suggestion engine for data gap recommendations`

### Task 2.20: Data Maturity Service

**Files:**
- Create: `cloud-brain/app/services/data_maturity.py`
- Test: `cloud-brain/tests/services/test_data_maturity.py`

**What to build:**
- [x] `DataMaturityService`:
  - Calculate maturity level: Building (1-6 days), Ready (7-13), Strong (14-29), Excellent (30+)
  - Count days with data per user
  - Per-feature soft gating info: correlations (7d), anomaly detection (14d), Health Score footnote (<7d)
- [x] Integrated into insight and prompt endpoints
- [x] Tests: each maturity level, per-feature gating thresholds

**Commit:** `feat(api): add Data Maturity service for progressive feature transparency`

### Task 2.21: NL Logging Confirmation Flow

**Files:**
- Modify: `cloud-brain/app/agent/orchestrator.py`
- Create: `cloud-brain/app/agent/tools/log_health_data.py`
- Test: `cloud-brain/tests/agent/test_log_health_data.py`

**What to build:**
- [x] `log_health_data` MCP tool that:
  - Parses natural language input for loggable data (hydration, mood, energy, stress, nutrition, activity, notes, supplements)
  - Returns structured confirmation payload (metric, value, timestamp) for the client to render as a confirmation card
  - On user confirmation: write to QuickLog + feed into analytics
  - Key facts also stored in long-term memory
- [x] Tests: parse various NL inputs, confirmation payload structure, write-on-confirm

**Commit:** `feat(agent): add NL logging confirmation flow with structured confirmation cards`

### Task 2.22: File Attachment Pipeline

**Files:**
- Create: `cloud-brain/app/api/v1/attachments.py`
- Create: `cloud-brain/app/services/attachment_processor.py`
- Test: `cloud-brain/tests/api/test_attachments.py`

**What to build:**
- [x] `POST /api/v1/chat/:conversation_id/attachments` — upload file (10MB max, 3 per message)
- [x] Supported formats: JPEG, PNG, HEIC, PDF, TXT, CSV
- [x] File passed to Kimi K2.5 as multimodal input in conversation context
- [x] Memory extraction: AI identifies health facts → stored in Pinecone
- [x] Confirmation card returned listing extracted facts
- [x] Food photo detection: if image contains food, return nutrition estimate card
- [x] No permanent file storage — extracted knowledge persists in memory only
- [x] Tests: upload, format validation, size limit, memory extraction, food detection

**Commit:** `feat(api): add file attachment pipeline with memory extraction`

### Task 2.23: Fitbit Webhook Registration

**Files:**
- Modify: `cloud-brain/app/tasks/fitbit_sync_tasks.py`
- Test: existing test file

**What to build:**
- [x] Generate `FITBIT_WEBHOOK_VERIFY_CODE`
- [x] Register Fitbit webhook subscription via deployed endpoint
- [x] Tests: subscription creation, verification code handling

**Commit:** `feat(api): register Fitbit webhook subscription`

### Task 2.24: Background Insight Alerts

**Files:**
- Modify: `cloud-brain/app/tasks/insight_tasks.py`
- Modify: `cloud-brain/app/services/push_service.py`

**What to build:**
- [x] Trigger push notifications on health data events:
  - New anomaly detected → push
  - Goal reached → push
  - Streak milestone → push
  - Integration stale (24h+ no sync) → push
- [x] Respect user notification preferences and quiet hours
- [x] Tests: each trigger type, preference respect, quiet hours

**Commit:** `feat(api): add background insight alert triggers`

---

## Phase 3: Today Tab (3 Screens)

**Branch:** `feat/today-tab`

**Depends on:** Phase 0 (design tokens), Phase 1 (navigation), Phase 2 (Health Score, Insights, Anomaly, Data Maturity, Quick Actions, Streaks, Quick Log)

### Task 3.1: Today Feed Screen

**Files:**
- Create: `zuralog/lib/features/today/presentation/today_feed_screen.dart`
- Create: `zuralog/lib/features/today/providers/today_providers.dart`
- Create: `zuralog/lib/features/today/data/today_repository.dart`

**What to build:**
- [x] Health Score hero widget at top (from shared component)
- [x] Data Maturity banner (first 30 days, dismissable)
- [x] AI insight cards (from `/api/v1/insights` endpoint) — tappable, opens Insight Detail
- [x] Wellness Check-in card (daily prompt, expands inline)
- [x] Contextual Quick Action cards (from `/api/v1/quick-actions`)
- [x] Streak counter badge
- [x] Correlation Suggestion cards
- [x] Quick Log FAB button → opens QuickLogSheet
- [x] Time-of-Day content ordering (morning/afternoon/evening/night per Feature Y)
- [x] Pull-to-refresh with sage-green circular indicator
- [x] Skeleton loading states
- [x] Onboarding tooltip: "This is your daily briefing..."
- [x] Haptic feedback on card taps

**Commit:** `feat(today): build Today Feed screen with all card types`

### Task 3.2: Insight Detail Screen

**Files:**
- Create: `zuralog/lib/features/today/presentation/insight_detail_screen.dart`

**What to build:**
- [x] Full-screen insight with:
  - Charts/numbers showing the data behind the insight
  - AI reasoning explanation
  - Source integrations that contributed (with icons)
  - "Discuss with Coach" button → opens new chat with context pre-filled
- [x] Slide-up transition (per design.md)
- [x] Haptic feedback on "Discuss with Coach" tap

**Commit:** `feat(today): build Insight Detail screen`

### Task 3.3: Notification History Screen

**Files:**
- Create: `zuralog/lib/features/today/presentation/notification_history_screen.dart`

**What to build:**
- [x] Scrollable list of all past push notifications from `/api/v1/notifications`
- [x] Grouped by day
- [x] Tapping a notification deep-links to relevant insight/metric
- [x] Accessible from bell icon in Today header
- [x] Mark as read on view

**Commit:** `feat(today): build Notification History screen`

---

## Phase 4: Coach Tab (4 Screens)

**Branch:** `feat/coach-tab`

**Depends on:** Phase 2 (Conversation CRUD, Pinecone Memory, NL Logging, File Attachments, Personalized Prompts, Quick Actions)

### Task 4.1: New Chat Screen (Gemini-style)

**Files:**
- Create: `zuralog/lib/features/coach/presentation/new_chat_screen.dart`
- Create: `zuralog/lib/features/coach/providers/coach_providers.dart`
- Create: `zuralog/lib/features/coach/data/coach_repository.dart`

**What to build:**
- [ ] Opens to fresh empty conversation
- [ ] Personalized suggested prompt chips (from `/api/v1/prompts/suggestions`)
- [ ] Integration context banner showing which apps the AI can access
- [ ] Chat input bar with: text field, send button, mic button (hold-to-talk), attachment button, camera button
- [ ] Hamburger icon / swipe to open Conversation Drawer
- [ ] Lightning bolt icon to open Quick Actions Sheet
- [ ] Streaming message display with markdown rendering
- [ ] User bubbles: sage-green, right-aligned
- [ ] AI bubbles: `surface-700`, left-aligned, markdown
- [ ] Onboarding tooltip: "Ask me anything about your health..."
- [ ] Haptic feedback on send

**Commit:** `feat(coach): build New Chat screen with personalized prompts`

### Task 4.2: Conversation Drawer

**Files:**
- Create: `zuralog/lib/features/coach/presentation/conversation_drawer.dart`

**What to build:**
- [ ] Side drawer overlay (280ms `easeOutCubic` slide)
- [ ] List of all conversations from `/api/v1/conversations`
- [ ] Each row: AI-generated title, timestamp, preview snippet
- [ ] Tap to navigate to Chat Thread
- [ ] Swipe-to-delete or long-press context menu (delete, rename, archive)
- [ ] `surface-700` background

**Commit:** `feat(coach): build Conversation Drawer`

### Task 4.3: Chat Thread Screen

**Files:**
- Create: `zuralog/lib/features/coach/presentation/chat_thread_screen.dart`

**What to build:**
- [ ] Loaded conversation with full history
- [ ] Same capabilities as New Chat: streaming, voice input, markdown
- [ ] File attachment support:
  - Attachment button → file picker (images, PDFs, text)
  - Camera button → capture photo
  - Preview cards in message bubbles (image thumbnail, PDF icon)
  - Upload progress indicator
- [ ] In-chat confirmation cards:
  - NL logging confirmation (Confirm/Edit buttons)
  - Memory extraction confirmation (list of extracted facts)
  - Food photo response card (nutrition estimate, Confirm/Adjust)
- [ ] Back navigation to New Chat

**Commit:** `feat(coach): build Chat Thread with attachments and confirmation cards`

### Task 4.4: Quick Actions Sheet

**Files:**
- Create: `zuralog/lib/features/coach/presentation/quick_actions_sheet.dart`

**What to build:**
- [ ] Bottom sheet (28px top radius, 350ms `easeOutCubic` reveal)
- [ ] Pre-built action cards from `/api/v1/quick-actions`
- [ ] Each card: icon, title, subtitle
- [ ] Tap → opens new chat with prompt pre-filled and auto-sent
- [ ] Accessible from Coach tab header (lightning icon) and Today tab shortcuts
- [ ] Haptic feedback on selection

**Commit:** `feat(coach): build Quick Actions bottom sheet`

---

## Phase 5: Data Tab (3 Screens)

**Branch:** `feat/data-tab`

**Depends on:** Phase 2 (Health Score, User Preferences for dashboard layout)

### Task 5.1: Health Dashboard Screen

**Files:**
- Create: `zuralog/lib/features/data/presentation/health_dashboard_screen.dart`
- Create: `zuralog/lib/features/data/providers/data_providers.dart`
- Create: `zuralog/lib/features/data/data/data_repository.dart`

**What to build:**
- [ ] Health Score hero widget at top
- [ ] Grid/list of health category cards (up to 10 categories)
- [ ] Each card: category name, primary metric value, sparkline trend (7d), delta indicator
- [ ] Category color accent from `AppColors.category*`
- [ ] Drag-and-drop reorder: long-press to enter edit mode, drag to reorder, haptic on pick-up/drop
- [ ] Show/hide toggle per category in edit mode (eye icon)
- [ ] Layout persisted via user preferences API
- [ ] Tap card → push to Category Detail
- [ ] Skeleton loading states
- [ ] Onboarding tooltip: "This is your data command center..."

**Commit:** `feat(data): build customizable Health Dashboard screen`

### Task 5.2: Category Detail Screen

**Files:**
- Create: `zuralog/lib/features/data/presentation/category_detail_screen.dart`

**What to build:**
- [ ] Parameterized by category (Activity, Body, Heart, Vitals, Sleep, Nutrition, Cycle, Wellness, Mobility, Environment)
- [ ] All metrics within the category with rich `fl_chart` charts
- [ ] Time-range selector (7D / 30D / 90D / Custom)
- [ ] Category color theming throughout
- [ ] Tap metric → push to Metric Detail
- [ ] Animated chart draw-in (400ms `easeOutCubic`)

**Commit:** `feat(data): build Category Detail screen with time-range charts`

### Task 5.3: Metric Detail Screen

**Files:**
- Create: `zuralog/lib/features/data/presentation/metric_detail_screen.dart`

**What to build:**
- [ ] Single metric deep-dive
- [ ] Full chart with pinch-to-zoom
- [ ] Data source attribution ("from Fitbit", "from Apple Health")
- [ ] Raw data table toggle
- [ ] "Ask Coach about this" button → opens chat with metric context pre-loaded
- [ ] Time-range selector

**Commit:** `feat(data): build Metric Detail screen with source attribution`

---

## Phase 6: Progress Tab (6 Screens)

**Branch:** `feat/progress-tab`

**Depends on:** Phase 2 (Goals, Streaks, Achievements, Journal, Weekly Report)

### Task 6.1: Progress Home Screen

**Files:**
- Create: `zuralog/lib/features/progress/presentation/progress_home_screen.dart`
- Create: `zuralog/lib/features/progress/providers/progress_providers.dart`

**What to build:**
- [ ] Active goals with progress rings (800ms animated fill)
- [ ] Current streaks display with freeze indicator (shield icon)
- [ ] Week-over-week comparison summary (up/down arrows, percentages)
- [ ] Streak milestone celebration cards
- [ ] Navigation to: Goals, Achievements, Weekly Report, Journal
- [ ] Onboarding tooltip: "Set goals and I'll track your streaks..."

**Commit:** `feat(progress): build Progress Home screen`

### Task 6.2: Goals Screen

**Files:**
- Create: `zuralog/lib/features/progress/presentation/goals_screen.dart`
- Create: `zuralog/lib/features/progress/presentation/goal_create_edit_sheet.dart`

**What to build:**
- [ ] Goal list with progress rings
- [ ] Create goal: type picker, target value, period (daily/weekly/long-term)
- [ ] Edit/delete goals
- [ ] Each goal: metric, target, current progress, progress ring, AI commentary
- [ ] Projected completion date for long-term goals
- [ ] Haptic on goal creation

**Commit:** `feat(progress): build Goals screen with CRUD`

### Task 6.3: Goal Detail Screen

**Files:**
- Create: `zuralog/lib/features/progress/presentation/goal_detail_screen.dart`

**What to build:**
- [ ] Full progress chart over time
- [ ] Milestones hit
- [ ] Projected completion date
- [ ] AI commentary
- [ ] Edit/delete actions

**Commit:** `feat(progress): build Goal Detail screen`

### Task 6.4: Achievements Screen

**Files:**
- Create: `zuralog/lib/features/progress/presentation/achievements_screen.dart`

**What to build:**
- [ ] Badge gallery grouped by category (Getting Started, Consistency, Goals, Data, Coach, Health)
- [ ] Locked/unlocked states with visual distinction
- [ ] Unlocked badges show date achieved
- [ ] Achievement unlock animation: scale-up with glow pulse
- [ ] Haptic on viewing newly unlocked badge

**Commit:** `feat(progress): build Achievements gallery screen`

### Task 6.5: Weekly Report Screen

**Files:**
- Create: `zuralog/lib/features/progress/presentation/weekly_report_screen.dart`

**What to build:**
- [ ] Story-style swipeable card sequence (PageView):
  - Week summary → Top metrics → Streaks and goals → AI highlights → Areas for improvement → Next week focus
- [ ] Each card: charts, numbers, AI commentary
- [ ] Share-as-image button (render to image, share via platform share sheet)
- [ ] Dot indicator for card position
- [ ] Background gradient per card type

**Commit:** `feat(progress): build Weekly Report story-style screen`

### Task 6.6: Journal / Daily Log Screen

**Files:**
- Create: `zuralog/lib/features/progress/presentation/journal_screen.dart`
- Create: `zuralog/lib/features/progress/presentation/journal_entry_sheet.dart`

**What to build:**
- [ ] Calendar or date-list view of journal entries
- [ ] Create/edit entry: mood slider (1-10 with emoji), energy, stress, sleep quality, notes text field, context tags (chips: "rest day", "stressful", "traveled" etc.)
- [ ] History view: scrollable list of past entries with mood/energy indicators
- [ ] Tap entry to view/edit

**Commit:** `feat(progress): build Journal/Daily Log screen`

---

## Phase 7: Trends Tab (4 Screens)

**Branch:** `feat/trends-tab`

**Depends on:** Phase 2 (Analytics endpoints, Correlation Suggestions, Reports, Data Sources)

### Task 7.1: Trends Home Screen

**Files:**
- Create: `zuralog/lib/features/trends/presentation/trends_home_screen.dart`
- Create: `zuralog/lib/features/trends/providers/trends_providers.dart`

**What to build:**
- [ ] AI correlation cards ("Your sleep quality improves by 22% on days you run")
- [ ] Time-machine strip at top: swipe through week-by-week or month-by-month summaries
- [ ] Correlation Suggestion cards when data gaps exist
- [ ] Onboarding tooltip: "This is where patterns hide..."

**Commit:** `feat(trends): build Trends Home screen`

### Task 7.2: Correlations Screen

**Files:**
- Create: `zuralog/lib/features/trends/presentation/correlations_screen.dart`

**What to build:**
- [ ] Two-metric picker (select any two metrics)
- [ ] Scatter plot with trend line (fl_chart)
- [ ] Overlay time-series charts
- [ ] Pearson correlation coefficient with plain-language interpretation
- [ ] Lag support selector (0-day, 1-day, 2-day, 3-day)
- [ ] AI annotation explaining the correlation
- [ ] Time-range selector (7D / 30D / 90D)

**Commit:** `feat(trends): build interactive Correlations Explorer screen`

### Task 7.3: Reports Screen

**Files:**
- Create: `zuralog/lib/features/trends/presentation/reports_screen.dart`

**What to build:**
- [ ] List of generated monthly reports from `/api/v1/reports`
- [ ] Tap to view report detail: category summaries, top correlations, goal progress, trend directions, AI recommendations
- [ ] Export as PDF button
- [ ] Share-as-image button

**Commit:** `feat(trends): build Reports screen with export`

### Task 7.4: Data Sources Screen

**Files:**
- Create: `zuralog/lib/features/trends/presentation/data_sources_screen.dart`

**What to build:**
- [ ] Per-integration card:
  - Name, icon, connection status
  - Last sync timestamp
  - Staleness indicator (green/yellow/red dot)
  - Data types contributed
  - Reconnect button for error-state integrations
- [ ] Read-only — this is data provenance, not connection management

**Commit:** `feat(trends): build Data Sources transparency screen`

---

## Phase 8: Settings & Profile (12 Screens)

**Branch:** `feat/settings-rebuild`

**Depends on:** Phase 2 (User Preferences API), all feature-specific settings

### Task 8.1: Settings Hub Screen

**Files:**
- Create: `zuralog/lib/features/settings/presentation/settings_hub_screen.dart`

**What to build:**
- [ ] Top-level settings menu: Account, Notifications, Appearance, Coach, Integrations, Privacy & Data, Subscription, About
- [ ] Each row: icon, title, subtitle, chevron
- [ ] Pushed from gear icon in Profile or header

**Commit:** `feat(settings): build Settings Hub screen`

### Task 8.2: Account Settings Screen

**Files:**
- Create: `zuralog/lib/features/settings/presentation/account_settings_screen.dart`

**What to build:**
- [ ] Email display
- [ ] Password change
- [ ] Linked social accounts (Google, Apple)
- [ ] Goals editor (multi-select grid, same as onboarding Step 2)
- [ ] Emergency Health Card link
- [ ] Delete account (with confirmation dialog)

**Commit:** `feat(settings): build Account Settings screen`

### Task 8.3: Notification Settings Screen

**Files:**
- Create: `zuralog/lib/features/settings/presentation/notification_settings_screen.dart`

**What to build:**
- [ ] Morning Briefing: toggle + time picker
- [ ] Smart Reminders: master toggle + per-category sub-toggles (pattern, gap, goal, celebration)
- [ ] Reminder Frequency: selector (Low 1/day, Medium 2/day, High 3/day)
- [ ] Streak Reminders: toggle
- [ ] Achievement Notifications: toggle
- [ ] Anomaly Alerts: toggle
- [ ] Integration Alerts: toggle
- [ ] Wellness Check-in Reminder: toggle + time picker
- [ ] Quiet Hours: start/end time pickers
- [ ] All values persisted via `/api/v1/preferences`

**Commit:** `feat(settings): build Notification Settings screen`

### Task 8.4: Appearance Settings Screen

**Files:**
- Create: `zuralog/lib/features/settings/presentation/appearance_settings_screen.dart`

**What to build:**
- [ ] Theme selector (Dark / Light / System) with 200ms crossfade preview
- [ ] Haptic Feedback toggle
- [ ] Reset Onboarding Tooltips button
- [ ] Disable Tooltips toggle
- [ ] Dashboard card color customization (per-category accent picker with curated palette)

**Commit:** `feat(settings): build Appearance Settings screen`

### Task 8.5: Coach Settings Screen

**Files:**
- Create: `zuralog/lib/features/settings/presentation/coach_settings_screen.dart`

**What to build:**
- [ ] AI Persona selector: Tough Love / Balanced / Gentle (card-style, like onboarding)
- [ ] Proactivity Level: Low / Medium / High
- [ ] Persisted via `/api/v1/preferences`

**Commit:** `feat(settings): build Coach Settings screen`

### Task 8.6: Integrations Management Screen

**Files:**
- Create: `zuralog/lib/features/settings/presentation/integrations_screen.dart`

**What to build:**
- [ ] Rebuild of existing Integrations Hub, relocated under Settings
- [ ] Connected / Available / Coming Soon sections
- [ ] Compact sync status badge (green/yellow/red dot) per connected integration
- [ ] Last synced timestamp under each integration
- [ ] OAuth flows preserved
- [ ] Platform badges (iOS-only, Android-only)

**Commit:** `feat(settings): rebuild Integrations Management screen`

### Task 8.7: Privacy & Data Settings Screen

**Files:**
- Create: `zuralog/lib/features/settings/presentation/privacy_data_screen.dart`

**What to build:**
- [ ] AI Memory: view stored memories list, delete individual, clear all (with confirmation)
- [ ] Wellness Check-in: toggle
- [ ] Data Maturity Banner: dismiss/re-enable toggle
- [ ] Data Export placeholder ("Coming soon")
- [ ] Data Deletion request
- [ ] Analytics opt-out toggle
- [ ] Links to Privacy Policy and Terms of Service

**Commit:** `feat(settings): build Privacy & Data screen with memory management`

### Task 8.8: Subscription Screen

**Files:**
- Create: `zuralog/lib/features/settings/presentation/subscription_screen.dart`

**What to build:**
- [ ] Rebuild of existing RevenueCat paywall
- [ ] Current plan display
- [ ] Upgrade/downgrade options
- [ ] Restore purchases
- [ ] Billing history (if available via RevenueCat)

**Commit:** `feat(settings): rebuild Subscription screen`

### Task 8.9: About Screen

**Files:**
- Create: `zuralog/lib/features/settings/presentation/about_screen.dart`

**What to build:**
- [ ] App version and build number
- [ ] Open-source licenses
- [ ] Support link
- [ ] Community guidelines link

**Commit:** `feat(settings): build About screen`

### Task 8.10: Profile Screen

**Files:**
- Create: `zuralog/lib/features/settings/presentation/profile_screen.dart`

**What to build:**
- [ ] Display name, email, avatar
- [ ] Member-since date
- [ ] Subscription tier badge
- [ ] Edit profile fields
- [ ] Emergency Health Card link (prominent card)
- [ ] Gear icon → Settings Hub

**Commit:** `feat(settings): rebuild Profile screen`

### Task 8.11: Emergency Health Card Screens

**Files:**
- Create: `zuralog/lib/features/settings/presentation/emergency_card_screen.dart`
- Create: `zuralog/lib/features/settings/presentation/emergency_card_edit_screen.dart`

**What to build:**
- [ ] View screen: high-contrast, large text, minimal chrome
  - Blood type, allergies, medications, conditions, emergency contacts
  - Works offline (cached locally)
- [ ] Edit screen: form fields for all medical info
  - Allergies, medications, conditions as tag-style inputs
  - Emergency contacts: name, relationship, phone (up to 3)

**Commit:** `feat(settings): build Emergency Health Card view and edit screens`

### Task 8.12: Legal Pages

**Files:**
- Create: `zuralog/lib/features/settings/presentation/privacy_policy_screen.dart`
- Create: `zuralog/lib/features/settings/presentation/terms_of_service_screen.dart`

**What to build:**
- [ ] Privacy Policy: full GDPR/CCPA text (load from asset or API)
- [ ] Terms of Service: full legal text
- [ ] Both accessible from Privacy & Data settings

**Commit:** `feat(settings): add Privacy Policy and Terms of Service screens`

---

## Phase 9: Onboarding Rebuild

**Branch:** `feat/onboarding-rebuild`

**Depends on:** Phase 8 (Settings exists for "change later" flow)

### Task 9.1: 6-Step Onboarding Flow

**Files:**
- Replace: `zuralog/lib/features/onboarding/presentation/profile_questionnaire_screen.dart`
- Create: `zuralog/lib/features/onboarding/presentation/onboarding_flow_screen.dart`
- Create: `zuralog/lib/features/onboarding/presentation/steps/`
  - `welcome_step.dart`
  - `goals_step.dart`
  - `persona_step.dart`
  - `connect_apps_step.dart`
  - `notifications_step.dart`
  - `discovery_step.dart`

**What to build:**
- [ ] Step 1 — Welcome: animation + headline + CTA
- [ ] Step 2 — Goals: multi-select grid (8 predefined goals)
- [ ] Step 3 — AI Persona: 3 persona cards + proactivity toggle
- [ ] Step 4 — Connect Apps: integration tiles with one-tap connect
- [ ] Step 5 — Notifications: morning briefing toggle/time, smart reminders, wellness check-in
- [ ] Step 6 — Discovery: "Where did you hear about Zuralog?" dropdown (PostHog event)
- [ ] PageView with dot indicator
- [ ] Back/Next navigation
- [ ] Completion → land on Today Feed with welcome insight card
- [ ] All selections persist via `/api/v1/preferences`

**Commit:** `feat(onboarding): build 6-step onboarding flow replacing ProfileQuestionnaire`

### Task 9.2: Update screens.md

**Files:**
- Modify: `docs/screens.md`

**What to update:**
- [ ] Replace Auth & Onboarding section with 6-step flow specification
- [ ] Add Quick Log Bottom Sheet to Today/Coach sections
- [ ] Add Emergency Health Card screens to Settings section
- [ ] Update all existing screen descriptions with MVP feature additions (per mvp-features.md Section 8)

**Commit:** `docs(screens): update screen inventory with all MVP feature additions`

---

## Phase 10: Engagement & Polish

**Branch:** `feat/engagement-polish`

**Depends on:** All screens built

### Task 10.1: Haptic Integration Across All Screens

**What to build:**
- [x] Wire `HapticService` calls to all interaction points:
  - Light: tab switches, card taps, list selections, tooltip dismissals
  - Medium: send message, confirm log, toggle setting, submit Quick Log
  - Success: goal reached, streak milestone, achievement unlock, report generated
  - Warning: integration disconnect, anomaly alert
  - Selection tick: pickers, sliders, drag handles

**Commit:** `feat(ux): integrate haptic feedback across all screens`

### Task 10.2: Onboarding Tooltips Across All Screens

**What to build:**
- [x] Wire `OnboardingTooltip` to:
  - Today Feed, Health Dashboard, Coach (New Chat), Progress Home, Trends Home, Quick Log
- [x] Content per mvp-features.md Feature T

**Commit:** `feat(ux): add onboarding tooltips to all major screens`

### Task 10.3: Skeleton Loading States

**What to build:**
- [x] Add shimmer skeleton screens to:
  - Today Feed, Health Dashboard, Coach (loading history), Progress Home, Trends Home
- [x] Base: `surface-800`, highlight: `surface-600`, 1200ms loop
- [x] Shapes match content layout

**Commit:** `feat(ux): add skeleton loading states to all tab root screens`

### Task 10.4: Pull-to-Refresh

**What to build:**
- [x] Custom sage-green circular progress indicator on:
  - Today Feed, Health Dashboard, Progress Home, Trends Home
- [x] Triggers data refresh from backend

**Commit:** `feat(ux): add custom pull-to-refresh to all tab root screens`

### Task 10.5: Apple Sign In

**What to build:**
- [ ] Apple Sign In (iOS native) — pending Apple Developer subscription
- [ ] Wire into auth flow alongside Google Sign In and email

**Commit:** `feat(auth): add Apple Sign In (iOS)`

**Note:** This is blocked on Apple Developer subscription. Include as a task but mark blocked if subscription is not yet acquired.

---

## Phase 11: Observability & QA

**Branch:** `feat/observability`

**Depends on:** Everything built

### Task 11.1: PostHog Event Instrumentation

**What to build:**
- [ ] Define and emit events per mvp-features.md Section 9:
  - Feature adoption: `first_quick_log`, `first_file_attachment`, `first_goal_created`, etc.
  - Funnel analysis: onboarding step completion, goal creation→completion, chat→response
  - Feature-specific: messages sent, insights viewed/tapped, streaks started/broken/frozen, achievements unlocked, attachments by type, anomaly alerts viewed, check-ins completed, quick logs submitted, correlations tapped
  - Engagement: session duration, screens per session, time-of-day distribution, notification tap-through
- [ ] Privacy: no PII, no raw health values in PostHog events

**Commit:** `feat(analytics): add PostHog event instrumentation across all features`

### Task 11.2: Sentry Error Boundaries

**What to build:**
- [ ] Error boundary widgets per screen and feature module
- [ ] Breadcrumbs for navigation events, user actions, API calls
- [ ] Backend: structured exception handling per endpoint
- [ ] AI-specific: LLM failures, tool call failures, memory store errors as separate issue groups
- [ ] Performance monitoring: AI response latency, ingest pipeline, report generation

**Commit:** `feat(observability): add Sentry error boundaries and performance monitoring`

### Task 11.3: Final Documentation Updates

**Files:**
- Modify: `docs/roadmap.md` — update all status columns
- Modify: `docs/implementation-status.md` — add summary of all new work
- Modify: `docs/screens.md` — final screen inventory alignment
- Modify: `docs/design.md` — any new tokens or component changes

**Commit:** `docs: update roadmap, implementation status, screens, and design docs`

### Task 11.4: Comprehensive QA Review

**What to do:**
- [ ] Test every screen on iOS simulator and Android emulator
- [ ] Test dark mode and light mode on all screens
- [ ] Test haptic feedback on physical devices
- [ ] Test onboarding flow end-to-end
- [ ] Test streak/achievement mechanics
- [ ] Test file attachments in chat
- [ ] Test voice input in chat
- [ ] Test all integration OAuth flows
- [ ] Test push notifications (morning briefing, smart reminders, anomaly alerts)
- [ ] Delete all temporary artifacts (screenshots, scratch files, test outputs) from working tree
- [ ] Squash merge to `main` when all phases are complete with zero errors/warnings

---

## Phase Summary

| Phase | Tasks | Scope | Key Deliverables |
|-------|-------|-------|-----------------|
| 0 | 6 | Design system | Light mode tokens, haptic service, tooltip widget, shared components, design.md update |
| 1 | 2 | Navigation | 5-tab bottom nav, 37 routes defined |
| 2 | 24 | Backend | All remaining backend services, models, endpoints, Celery tasks |
| 3 | 3 | Today tab | Today Feed, Insight Detail, Notification History |
| 4 | 4 | Coach tab | New Chat, Conversation Drawer, Chat Thread, Quick Actions Sheet |
| 5 | 3 | Data tab | Health Dashboard, Category Detail, Metric Detail |
| 6 | 6 | Progress tab | Progress Home, Goals, Goal Detail, Achievements, Weekly Report, Journal |
| 7 | 4 | Trends tab | Trends Home, Correlations, Reports, Data Sources |
| 8 | 12 | Settings | All 12 settings/profile screens |
| 9 | 2 | Onboarding | 6-step flow, screens.md update |
| 10 | 5 | Polish | Haptics, tooltips, skeletons, pull-to-refresh, Apple Sign In |
| 11 | 4 | QA | PostHog, Sentry, docs, comprehensive review |
| **Total** | **75** | | |

---

## Execution Notes

1. **Branch per phase.** Each phase gets its own branch from `main`. Squash merge on phase completion.
2. **Commit at every logical checkpoint.** Do not wait for phase completion to commit.
3. **Run tests before merge.** `pytest` for backend, `flutter test` for mobile.
4. **Update `docs/roadmap.md`** status after each phase completes.
5. **No phase depends on a later phase.** The dependency chain flows strictly downward.
6. **Phase 2 is the largest.** Consider splitting backend work across 2-3 branches if it gets unwieldy.
7. **Blocked items:** Apple Sign In (Phase 10.5) requires Apple Developer subscription. Oura credentials require hardware. Both are noted but should not block other work.
