# Zuralog — Implementation Status

**Last Updated:** 2026-03-10 (Phase 10.7 — Coach chat UX polish; inactivity timeout + scroll-to-bottom button)  
**Purpose:** Historical record of what has been built, per major area. Synthesized from agent execution logs.

> This document covers *what was built*, including notable decisions made during implementation and deviations from the original plan. For *what's next*, see [roadmap.md](./roadmap.md).

---

## Coach Chat UX Polish (feat/coach-chat-ux-improvements, 2026-03-10)

**Scope:** Four UX improvements to the Coach chat screen, plus two follow-up refinements (inactivity timeout, scroll-to-bottom button).  
**Branch:** `feat/coach-chat-ux-improvements`  
**Commits:** `0342f02`, `5d58b15`

**Files changed:**
- `zuralog/lib/features/coach/presentation/chat_thread_screen.dart`
- `zuralog/lib/features/coach/providers/coach_providers.dart`

**What was built:**

1. **Thinking state** — Between when the user sends a message and when the first token arrives from the AI, the streaming bubble now shows the animated 3-dot typing indicator plus an italic "Thinking…" label. Previously the bubble only appeared once tokens were already flowing, so there was a silent gap where nothing indicated the AI was working. The bubble is now visible for the entire duration of `isSending == true`, regardless of whether tokens have arrived.

2. **Inactivity-based timeout** — `CoachChatNotifier` now uses a 10-minute inactivity timer (`_kInactivityTimeout = Duration(minutes: 10)`) instead of the original 30-second wall-clock timer. The key difference: `_resetInactivityTimer()` is called on every server event (`StreamToken`, `ToolProgress`, `StreamComplete`, `StreamError`, `ConversationCreated`), so the timer resets as long as the server is alive and sending data. The timer only fires when the connection goes completely silent — matching the OpenAI SDK default behavior. On timeout, `_onInactivityTimeout()` cancels the stream and shows: "The connection went silent. Please try again." `_cancelInactivityTimer()` is called on normal completion and in `cancelStream()`.

3. **Smart auto-scroll + scroll-to-bottom button** — Auto-scroll tracks whether the user has scrolled away from the bottom via a scroll listener on `_scrollCtrl` that sets `_userScrolledUp = true` when more than 80 px from the bottom. `_scrollToBottom()` is a no-op while `_userScrolledUp` is true. When streaming completes, the view no longer force-scrolls back — instead, a floating circular arrow button (sage green, 36×36, bottom-right of the message list) fades in when the user is scrolled up and fades out when they return to the bottom. Tapping the button clears `_userScrolledUp`, clears `_showScrollToBottom`, and calls `_scrollToBottom()`. The button uses `AnimatedOpacity` + `IgnorePointer` for a smooth appearance/disappearance.

4. **Regenerate in long-press sheet** — The standalone "Regenerate" text button below the last AI message has been removed. Long-pressing the last AI message now shows a bottom sheet with Copy and Regenerate. Long-pressing any other AI message shows only Copy. User messages continue to show Copy + Edit. The `_showRegenerateButton` getter and the associated `ListView` item have been deleted; `onRegenerate` is passed as a callback to `_MessageBubble` only for the last assistant message when nothing is in flight.

**Key decisions:**

| Decision | Rationale |
|----------|-----------|
| Show bubble on `isSending`, not just on first token | Eliminates the silent gap where the user sees nothing after pressing Send. The 3-dot + "Thinking…" label is immediately reassuring. |
| 10-minute inactivity timeout (not 30-second wall-clock) | A 30s wall-clock timer would kill the connection before the AI finishes thinking on complex queries. Inactivity detection — timer resets on every received event — matches OpenAI SDK behavior and is the correct approach for AI streaming. |
| 80 px scroll threshold | Small enough that "at the bottom" feels natural, large enough to not trip accidentally when the list grows by one line during streaming. |
| Floating arrow instead of force-scroll on complete | Force-scrolling the user back to the bottom when they've deliberately scrolled up to read history is disruptive. The arrow button gives the user agency — they can return when ready. |
| Regenerate in long-press, not a button | The button cluttered the thread between responses. Long-press is already the established gesture for message actions (Copy, Edit) in this chat — Regenerate belongs there. |

**`flutter analyze`:** No issues found.

---

## Coach Tab WebSocket Production Fix (2026-03-10)

**Scope:** End-to-end fix for the Coach tab AI chat against the production backend.  
**Commits:** `19537c3`, `3008934`, `503ca98`, `96481f1`, `13245b2`

**What was fixed:**

1. **WebSocket URI construction** (`zuralog/lib/core/network/ws_client.dart`) — `_deriveWsUrl()` was passing `wss://api.zuralog.com` to `dart:io WebSocket.connect()`, which left the port as 0. Fix: parse the base URL as `https://` first (Dart resolves this to port 443), then rebuild the URI as `wss://` with the port set explicitly.

2. **WebSocket `accept()` ordering** (`cloud-brain/app/api/v1/chat.py`) — `websocket.accept()` was called after auth validation. Starlette cannot close an unaccepted WebSocket; unanticipated failures returned HTTP 500 instead of a JSON error. Fix: moved `await websocket.accept()` to the very first line of `websocket_chat`, before all auth and DB work. Updated `_authenticate_ws` to send a JSON error before closing the socket on auth failure.

3. **`StorageService` missing from app state** (`cloud-brain/app/main.py`) — `StorageService` was used throughout `chat.py` but was never initialised in the lifespan startup, causing `AttributeError: 'State' object has no attribute 'storage_service'` on every WebSocket request. Fix: imported and wired up `StorageService` in the lifespan.

4. **Missing `archived`/`deleted_at` columns in production DB** — Alembic reported the migration `i4d5e6f7a8b9` as already applied (its revision ID was in the `alembic_version` table) but the columns had never actually been added. The `ALTER TABLE` SQL was run directly against the production Supabase database using the `DATABASE_URL` from Railway environment variables.

5. **New-conversation stale history bug** (`zuralog/lib/features/coach/presentation/chat_thread_screen.dart`, `zuralog/lib/features/coach/providers/coach_providers.dart`) — After streaming completed for a new conversation, `context.replaceNamed()` navigated to the real UUID. The new `ChatThreadScreen` called `loadHistory()` which replaced the just-streamed messages with stale data from the DB (which may not have fully persisted yet). Fix: added `seedFromPrior()` to `CoachChatNotifier` — seeds the incoming notifier (keyed on the real UUID) with already-streamed messages before `replaceNamed()` runs. `_initConversation` skips `loadHistory()` when messages are already present.

6. **Backend tests updated for streaming protocol** (`cloud-brain/tests/test_chat.py`) — `test_ws_connect_and_echo` and `test_ws_empty_message_returns_error` were written for the old single-message protocol. Updated to match the real sequence: `conversation_init` → `typing_start` → `stream_token` → `stream_end`. Fixed the LLM mock in the test fixture to use `stream_chat` (async generator) instead of the synchronous `chat` mock. All 7 tests pass.

**Key decisions:**

| Decision | Rationale |
|----------|-----------|
| Parse base URL as `https://` before rebuilding as `wss://` | Dart resolves default ports for `https://` (→443) but not for `wss://`. Parsing first ensures the correct port is always explicit. |
| `websocket.accept()` before all auth logic | Starlette requires an accepted WebSocket to be able to send or close it gracefully. Accepting first means every failure path can send a structured JSON error instead of crashing. |
| `seedFromPrior()` instead of relying on `loadHistory()` | `loadHistory()` is async and may race against the DB commit for the just-streamed messages. Seeding the notifier directly from in-memory state is instant and guaranteed correct. |
| Skip `loadHistory()` when notifier is pre-seeded | Prevents the new screen from overwriting perfectly good in-memory state with a potentially stale or slower DB read. |

**Verified working:** AI response rendered correctly in the production app on an Android emulator. The backend logs confirmed: WebSocket accepted, user authenticated, conversation created, LLM responded (`moonshotai/kimi-k2.5` via OpenRouter), `apple_health_read_metrics` tool call routed.

---

## Railway Infrastructure Optimization (2026-03-10)

**Scope:** Production cost reduction via Redis consolidation, Celery_Beat service elimination, and observability sampling tuning.  
**Commit:** `eed860f`

**What was done:**

1. **Upstash Redis Removal** — All three services (Zuralog, Celery_Worker, Celery_Beat) migrated from Upstash to Railway-native Redis at `redis.railway.internal:6379`. New `Redis` service provisioned in the Railway project. Cost reduction: Upstash ~$2.50/mo → Railway Redis ~$0.50/mo.

2. **Celery_Beat Service Consolidation** — Deleted the standalone `Celery_Beat` service. Beat (periodic task scheduler) merged into `Celery_Worker` via the `--beat` flag. Worker now runs: `celery -A app.worker worker --beat --loglevel=info --concurrency=2`. Cost reduction: 1 fewer service instance (~$1/mo).

3. **Beat Schedule Fixes** — Fixed broken task names (`report_tasks` → `report`), removed stub `sync-active-users-15m` task, extended 4 sync intervals from 15min to 60min (Fitbit, Oura, Withings, Polar), replaced raw float schedules with `crontab()` for weekly/monthly reports, added `celery-redbeat>=2.2.0` with `RedBeatScheduler` for crash-safe schedule persistence.

4. **Observability Cost Reduction** — Zuralog (web): `SENTRY_TRACES_SAMPLE_RATE=0.05` (5% sampling), `SENTRY_PROFILES_SAMPLE_RATE=0` (disabled). Celery_Worker: `SENTRY_TRACES_SAMPLE_RATE=0.0`, `SENTRY_PROFILES_SAMPLE_RATE=0.0` (task errors only, no tracing). PostHog: `POSTHOG_API_KEY=` (disabled).

5. **Database Optimization** — NullPool for all Celery worker tasks (correct for `asyncio.run()` boundaries), reduced FastAPI connection pool from 10+20 to 2+3, all task files now use `worker_async_session`.

6. **Task Cleanup** — Removed 3 dead Fitbit API calls (HR, SpO2, HRV — no DB models), lazy Firebase initialization in `push_service.py`.

7. **FastAPI Startup Hardening** — All 7 integrations (Strava, Fitbit, Oura, Withings, Polar, Pinecone, LLM) now guarded on credential env vars, `CeleryIntegration` removed from FastAPI Sentry init, `/health` excluded from Sentry middleware.

8. **Docker Image Size Reduction** — Replaced `numpy` with stdlib `statistics` (−50MB), removed `psycopg2-binary` (−10MB, unused), fixed `_get_release()` to read `RAILWAY_GIT_COMMIT_SHA` env var instead of subprocess git call, pinned uv to `0.10.9`, added `--timeout-keep-alive 15` to uvicorn.

**Key decisions:**

| Decision | Rationale |
|----------|-----------|
| Beat merged into Worker (single-replica constraint) | Eliminates a service and its cost. Safe only with 1 Worker replica; constraint documented in Railway config. If Worker scales to 2+, Beat must be split back to dedicated service. |
| Railway Redis over Upstash | Railway Redis is cheaper (~$0.50/mo vs ~$2.50/mo) and co-located with backend services (lower latency). No external vendor lock-in. |
| 5% Sentry traces for web, 0% for Celery | Web traces are valuable for debugging user-facing issues. Celery task errors are captured regardless of sampling; tracing overhead not justified for background jobs. |
| NullPool for Celery tasks | Celery tasks use `asyncio.run()` which creates a new event loop per task. Connection pooling across task boundaries is unsafe; NullPool creates a fresh connection per task. |
| Reduced FastAPI pool from 10+20 to 2+3 | FastAPI is a single-threaded async app. 10 connections is overkill; 2 is sufficient for typical request concurrency. Reduces idle connection overhead. |
| Lazy Firebase initialization | Firebase SDK is heavy (~10MB). Only initialize when actually sending push notifications. Saves startup time and memory for non-notification code paths. |

**Cost impact:**
- Before: ~$3.48/mo (Upstash ~$2.50 + Sentry ~$0.50 + 3 services ~$0.48)
- After: ~$0.95/mo (Railway Redis ~$0.50 + Sentry 5% sample ~$0.05 + 2 services ~$0.40)
- **Savings: ~$2.53/mo (73% reduction)**

---

## Coach Tab AI Features (feat/coach-tab-full-ai, 2026-03-09)

**Step:** Phase 10.5 — All 6 Coach tab AI conversation features.  
**Branch:** `feat/coach-tab-full-ai`

**Files changed:**
- `zuralog/lib/features/coach/presentation/chat_thread_screen.dart` — Stop button, regenerate, copy, edit, empty state
- `zuralog/lib/features/coach/presentation/new_chat_screen.dart` — Better empty state, search drawer
- `zuralog/lib/features/coach/providers/coach_providers.dart` — Provider updates
- `zuralog/lib/features/coach/data/api_coach_repository.dart` — API contract updates
- `zuralog/lib/features/coach/data/coach_repository.dart` — Interface updates
- `cloud-brain/app/api/v1/chat.py` — Backend support for message editing/deletion

**What was built:**

1. **Stop Generation Button** — During streaming, a red stop button replaces the spinner. Tapping calls `cancelStream()`, which commits any partial content received so far or displays `'_Generation stopped._'` as a placeholder if nothing was received. The WebSocket connection is cleanly closed. Prevents user frustration when the AI response is taking too long.

2. **Regenerate / Retry Last Response** — A "Regenerate" button appears below the last AI message in the thread. Tapping re-sends the last user message without creating a duplicate database entry. The request reads the user's current persona and proactivity settings from `userPreferencesProvider`, ensuring the regenerated response respects any preference changes since the original message.

3. **Copy Message (Long-press)** — Long-pressing any message bubble (user or AI) opens a bottom sheet with a "Copy" action. The message text is written to the clipboard via `Clipboard.setData()` with proper `await` handling. `ScaffoldMessenger` is correctly scoped to avoid cross-screen toast conflicts.

4. **Message Editing** — Long-pressing a user message adds an "Edit" option to the bottom sheet. Tapping opens the input field with the message text pre-filled. On submit, the message is updated and all subsequent AI responses are truncated from the thread (snapshot-and-restore pattern). On cancel, the original message is restored. An editing indicator bar appears above the input field while editing is active.

5. **Better Empty State & Suggestions** — Replaced the generic empty state with `_CoachEmptyState`: a fade-in animation, pulsing Zuralog logo, "What I can do" capability row (4 icons: analyze, suggest, log, discuss), and grouped suggestion cards below. Each suggestion card has a 4px left-side colored border matching its category (e.g., blue for "Sleep", green for "Activity"), a category header, and 2–3 suggestion prompts per category. Improves discoverability for new users.

6. **Search Conversations** — The `_ConversationDrawer` now includes an `AnimatedSize` search field at the top. Typing filters conversations by title and preview text (client-side, case-insensitive substring match). An empty-results state appears when no conversations match the query. Improves navigation for users with many past conversations.

**Key decisions:**

| Decision | Rationale |
|----------|-----------|
| Stop button replaces spinner | Streaming UI must show the user they can interrupt. A button is more discoverable than a hidden gesture. |
| Regenerate reads current preferences | If a user changed their persona/proactivity since the original message, they expect the regenerated response to reflect the new settings. |
| Copy via `Clipboard.setData()` with `await` | Ensures the write completes before dismissing the bottom sheet. Prevents race conditions on fast devices. |
| Edit truncates subsequent AI responses | Editing a user message invalidates all downstream AI reasoning. Truncation is the safest approach — no guessing which responses are still valid. |
| Grouped suggestion cards with colored borders | Visual categorization (color + header) helps users scan suggestions faster. The 4px left border is a subtle design cue borrowed from modern chat apps. |
| Client-side search filtering | Conversations are already loaded in memory. Client-side filtering is instant and requires no backend round-trip. |

**`flutter analyze`:** No new issues introduced.

---

## Trends Tab — Persist Dismissed Correlation Suggestion IDs (feat/trends-persist-dismissals, 2026-03-08)

**Step:** 3.8 — Dismissal persistence for correlation suggestion cards.  
**Branch:** `feat/trends-persist-dismissals`

**File changed:**
- `zuralog/lib/features/trends/presentation/trends_home_screen.dart`

**What was built:**

1. **`_loadDismissals()`** — Loads persisted dismissed suggestion IDs from SharedPreferences on `initState`. Since `initState` cannot be `async`, the method is fire-and-forget; the widget renders immediately with an empty set and a `setState` call triggers a rebuild once saved IDs are available. Intersects stored IDs against `widget.data.suggestionCards` to prune stale IDs from rotated suggestions — prevents unbounded set growth and ensures a reused suggestion ID always shows fresh. Guards with `mounted` check before calling `setState` to avoid post-dispose crashes.

2. **`_persistDismissals()`** — Fire-and-forget write to SharedPreferences called (without `await`) at the moment a card is dismissed, so `setState` is never blocked by I/O.

3. **Storage key:** `dismissed_correlation_suggestions` (plain string, JSON-encoded `List<String>`).

4. **Multi-account safety:** Suggestion IDs are derived server-side as `uuid5(userId, goal, category)` — they are unique per user. If a different user logs in, their suggestion IDs will never match the previous user's dismissed IDs; the intersection produces an empty set and `prefs.remove` cleans up the stale key automatically. No SharedPreferences namespacing by user ID is required.

5. **ID pruning:** Stale IDs from rotated suggestions are automatically removed on load — the intersection of stored IDs against current card IDs keeps storage bounded.

**Key decisions:**

| Decision | Rationale |
|----------|-----------|
| No per-user SharedPreferences namespace | `uuid5(userId, goal, category)` IDs are globally unique per user — cross-user bleed is structurally impossible. Adding a namespace prefix would be redundant and complicate key management. |
| Fire-and-forget `_persistDismissals()` | Dismiss gesture responsiveness must not be gated on I/O. Write failures are non-fatal; in-memory set remains correct for the session. |
| Intersection prune on load | Prevents unbounded set growth as the server rotates suggestions. Also ensures a suggestion ID that reappears (e.g., after data refresh) is never silently hidden. |
| `mounted` guard in `_loadDismissals` | The async gap between `SharedPreferences.getInstance()` and `setState` is enough for the widget to be disposed (e.g., user navigates away during cold-start). Guard prevents the "setState called after dispose" assertion. |

**`flutter analyze`:** No new issues introduced.

---

## Progress Tab — Settings Wiring (feat/progress-tab-units-wiring, 2026-03-08)

Completed both P1 Progress tab actions from the Settings Mapping Audit plan. Branch: `feat/progress-tab-units-wiring`.

**Files changed:**
- `zuralog/lib/features/progress/presentation/goal_create_edit_sheet.dart` — `_defaultUnitFor()` made units-system-aware for `weightTarget`
- `zuralog/lib/features/progress/presentation/goals_screen.dart` — `_GoalCard` converted to `ConsumerWidget`; goal unit labels use `displayUnit()`
- `zuralog/lib/features/progress/presentation/goal_detail_screen.dart` — `_GoalDetailView` gains `unitsSystem` parameter; hero section uses `displayUnit()`
- `zuralog/lib/features/progress/presentation/progress_home_screen.dart` — `_GoalCard` and `_WoWMetricRow` converted to `ConsumerWidget`; all unit display sites use `displayUnit()`

**What was implemented:**

1. **Goal default unit pre-fill (Task P1)** — `_defaultUnitFor(GoalType type)` in `goal_create_edit_sheet.dart` now reads `ref.read(unitsSystemProvider)` for the `weightTarget` case: returns `'lbs'` for imperial users, `'kg'` for metric. All other goal types (`weeklyRunCount`, `dailyCalorieLimit`, `sleepDuration`, `stepCount`, `waterIntake`, `custom`) are system-agnostic and remain unchanged. Uses `ref.read` (not `ref.watch`) because the method is called from a `setState` callback, not from `build()`.

2. **Goal display unit labels (Task P1)** — Every display site that renders a goal or metric unit string in the Progress tab now passes through `displayUnit(x.unit, unitsSystem)` from the shared `unit_converter.dart` domain utility. Three files updated:
   - `goals_screen.dart`: `_GoalCard` converted from `StatelessWidget` to `ConsumerWidget`; reads `ref.watch(unitsSystemProvider)` in `build()`.
   - `goal_detail_screen.dart`: `unitsSystem` parameter added to `_GoalDetailView`; read once in `GoalDetailScreen.build()` and passed down (prop-drilling preferred over making the private `StatelessWidget` a `ConsumerWidget`, keeping it easily testable in isolation).
   - `progress_home_screen.dart`: Both `_GoalCard` and `_WoWMetricRow` converted to `ConsumerWidget`; each reads `ref.watch(unitsSystemProvider)` in their own `build()`.

**Key decisions:**

| Decision | Rationale |
|----------|-----------|
| `ref.read` in `_defaultUnitFor` | Called from a `setState` callback (user tapping a type chip), not from `build()`. `ref.watch` in a non-build context would trigger a Riverpod assertion error. |
| Prop-drilling for `_GoalDetailView` | `_GoalDetailView` is a private `StatelessWidget` in the same file as its parent `ConsumerStatefulWidget`. Passing `unitsSystem` as a constructor parameter keeps it pure and testable. Consistent with existing architecture in the file. |
| No numeric value conversion | `displayUnit()` only maps unit label strings. Numeric values (e.g., kg → lbs) are a separate P2 task tracked in `unit_converter.dart` TODO comment. Label-only change prevents the `10 kg` goal from showing as `10 lbs` (which would be numerically wrong). |
| `_WoWMetricRow` also converted | The Week-over-Week section shows `currentValue unit` alongside each metric. Missed in initial scoping but caught during review; fixed in the same branch. |

**`flutter analyze`:** No issues found

---

## Data Tab — Settings Wiring (feat/data-tab-settings-wiring, 2026-03-08)

Completed all 3 Data tab actions from the Settings Mapping Audit plan. Branch: `feat/data-tab-settings-wiring`.

**Files changed:**
- `zuralog/lib/features/data/domain/unit_converter.dart` — NEW: shared domain utility for unit label display
- `zuralog/lib/features/data/presentation/metric_detail_screen.dart` — units system wiring, color override wiring, quality improvements
- `zuralog/lib/features/data/presentation/category_detail_screen.dart` — units system wiring, color override wiring, chart quality improvements

**What was implemented:**

1. **Unit display converter (Task P1, shared utility)** — Created `unit_converter.dart` as a pure domain function with no Flutter imports. `displayUnit(String apiUnit, UnitsSystem system)` maps 10 known metric → imperial unit label overrides (kg→lbs, km→mi, cm→in, °C→°F, ml→fl oz, L→fl oz, g→oz, m→ft, m/s→mph, km/h→mph). Unmapped units pass through unchanged. kJ intentionally NOT mapped to kcal (would misrepresent the numeric value by a factor of 4.2× without numeric conversion).

2. **Units system wired to Metric Detail (Task P1)** — `_MetricDetailBody` in `metric_detail_screen.dart` converted to `ConsumerStatefulWidget`/`ConsumerState`. Reads `unitsSystemProvider` and computes `unitLabel` per series, passing it to `_StatsRow` (current/average stats), `_ChartCard` (tooltip), `_RawTableToggle` (raw data table), and `_AskCoachButton` (coach prefill). Named constants `_kRawTableMaxRows = 30` and `_kCoachPrefillMaxLength = 500` replace magic numbers. Coach prefill truncation now appends `…` instead of hard-cutting mid-word. `_formatDate` made static with empty string guard.

3. **Units system wired to Category Detail (Task P1 extension)** — `_CategoryDetailScreenState` reads `unitsSystemProvider`. `_MetricChartCard` gained a `required String displayUnit` parameter; `itemBuilder` computes it per series. Category-level metric cards now show correct imperial/metric unit labels in both the value display and chart tooltip.

4. **Category color overrides propagated to detail screens (Task P2)** — Both `category_detail_screen.dart` and `metric_detail_screen.dart` now read `dashboardLayoutProvider.categoryColorOverrides[cat.name]` via `.select()` (targeting only the relevant category's override to avoid unnecessary rebuilds on unrelated layout mutations). `Color(overrideInt)` is applied when an override exists, with `overrideInt != 0` guard to prevent transparent-black artifacts. Fallback to `categoryColor(cat)` design-system token when no override is set.

5. **Chart quality improvements (bonus)** — `category_detail_screen.dart` chart: `preventCurveOverShooting: true` added to prevent cubic spline overshooting; horizontal interval changed from `+ 1` to `.clamp(0.1, 1e9)` (more robust for fractional metrics like blood glucose in mmol/L).

**Key decisions:**

| Decision | Rationale |
|----------|-----------|
| kJ NOT mapped to kcal | Displaying kcal label on a kJ value would be a 4.2× misrepresentation (1 kJ ≈ 0.239 kcal). Unit label changes without numeric conversion are harmful for health data. |
| `unit_converter.dart` as pure domain utility | No Flutter imports, no side effects. Trivially unit-testable. Shared between both detail screens without duplication. |
| `.select()` for color override watch | Watching `dashboardLayoutProvider` fully would rebuild detail screens on every card reorder, hide/show, or banner dismiss — unrelated to color. `.select()` scopes the rebuild to only the specific category's override value. |
| `overrideInt != 0` guard | `Color(0)` is fully transparent black. A zero value could result from a serialization bug or bad API response. The guard ensures the fallback design-system token is used in that edge case. |

**`flutter analyze`:** No issues found

---

## Today Tab — Settings Wiring (feat/today-tab-settings-wiring, 2026-03-08)

Completed 4 tasks from the Settings Mapping Audit plan, wiring persisted user preferences to the Today tab and Quick Log. Branch: `feat/today-tab-settings-wiring`.

**Files changed:**
- `zuralog/lib/features/today/presentation/today_feed_screen.dart` — greeting personalization, data maturity banner persistence, wellness check-in card gating
- `zuralog/lib/features/today/providers/today_providers.dart` — removed dead session-scoped `dataMaturityBannerDismissed` StateProvider
- `zuralog/lib/shared/widgets/quick_log_sheet.dart` — units-aware water label
- `zuralog/lib/features/settings/domain/user_preferences_model.dart` — added `UnitsSystemWaterLabel` extension

**What was implemented:**

1. **Greeting personalization (Task 3.1)** — `_timeOfDayGreeting()` now reads `profile?.aiName` and displays "Good morning, Alex" (or "Good morning" fallback). Fixes the bug where the greeting was always generic.

2. **Data Maturity Banner dismiss persistence (Task 3.2)** — Banner dismiss now writes to persisted `userPreferencesProvider` via `mutate()`. Progress mode `onDismiss` and stillBuilding `onPermanentDismiss` both persist to the backend. Session X-dismiss on stillBuilding remains session-only (intentional — users can re-dismiss daily). Removed dead session-scoped `dataMaturityBannerDismissed` StateProvider. Fixed race condition: `showBanner` logic now gates on both `!bannerDismissed` AND `!prefsAsync.isLoading` to prevent the banner from flickering when preferences are loading.

3. **Wellness Check-in card gated on Privacy toggle (Task 3.3)** — `_WellnessCheckinCard` is now wrapped in `if (wellnessCardVisible)`. The visibility is controlled by `wellnessCheckinCardVisibleProvider`, which reads from persisted `userPreferencesProvider`. The Privacy & Data settings screen's "Wellness Check-in" toggle now controls whether the card appears on the Today tab.

4. **Units-aware water label in Quick Log (Task 3.4)** — Added `UnitsSystemWaterLabel` extension to `user_preferences_model.dart` with a `waterUnitLabel` getter that returns `'glasses (250 ml)'` for metric units or `'glasses (8 oz)'` for imperial. `_WaterCounter` in `quick_log_sheet.dart` now accepts a `required String label` parameter and receives `unitsSystem.waterUnitLabel`. The backend `waterGlasses` payload remains unchanged.

**Key decisions:**

| Decision | Rationale |
|----------|-----------|
| Persist banner dismiss to backend | Users expect the banner to stay dismissed across sessions. Session-only dismissal would be frustrating. |
| Session-only X-dismiss on stillBuilding | The X button on the stillBuilding state is a "hide for now" action, not a permanent dismiss. Users should see it again tomorrow if they open the app. |
| Race condition fix: `!prefsAsync.isLoading` | Without this guard, the banner could flicker on/off as preferences load. The guard ensures the banner is only shown when we have definitive dismiss state. |
| Wellness check-in gating | Privacy & Data is the natural home for this toggle since it controls data collection. Gating the card on this toggle ensures the UI reflects the user's privacy preference. |
| Units-aware water label | Users in metric regions expect "ml" or "250 ml per glass"; imperial users expect "oz" or "8 oz per glass". The label is now context-aware. |

**`flutter analyze`:** 24 issues (all pre-existing — zero in Today tab files). Zero errors.

---

## Progress Tab — Gap Closure (feat/progress-tab-gaps, 2026-03-07)

Closed all 7 previously identified gaps across the Progress tab in a single parallel subagent session. Branch: `feat/progress-tab-gaps`.

**Files changed:**
- `zuralog/lib/features/progress/domain/progress_models.dart` — Added `milestoneStreakCount` to `ProgressHomeData`; added `progressCurrent`/`progressTotal`/`progressLabel` to `Achievement`; added `GoalType.waterIntake`
- `zuralog/lib/features/progress/data/progress_repository.dart` — Added `applyStreakFreeze(StreakType)` to interface and `ProgressRepository`
- `zuralog/lib/features/progress/data/mock_progress_repository.dart` — `applyStreakFreeze` stub; `milestoneStreakCount: 7` in home fixture; progress fields on locked achievements; 5-card canonical weekly report sequence
- `zuralog/lib/features/progress/presentation/progress_home_screen.dart` — Streak freeze tap-to-activate with confirmation dialog + analytics; `_MilestoneCelebrationCard` widget with scale pulse animation and haptic
- `zuralog/lib/features/progress/presentation/goal_detail_screen.dart` — `_projectCompletionDate()` linear trend extrapolation; projected date in details card + AI commentary
- `zuralog/lib/features/progress/presentation/achievements_screen.dart` — `_buildLockedProgress()` mini progress bar for locked badges using `LayoutBuilder`
- `zuralog/lib/features/progress/presentation/goal_create_edit_sheet.dart` — `_defaultUnitFor()` helper; `waterIntake` available in type picker
- `zuralog/lib/features/progress/presentation/weekly_report_screen.dart` — `ScreenshotController` + `Screenshot` widget wrapping current page; `_shareCurrentCard()` captures PNG to temp dir and calls `Share.shareXFiles()`
- `zuralog/pubspec.yaml` — Added `screenshot: ^3.0.0` and `share_plus: ^10.1.4`

**What was implemented:**

1. **Streak freeze tap-to-activate** — `_StreakCard` converted to `ConsumerStatefulWidget`. Tapping the shield icon shows a confirmation dialog ("Use a Streak Freeze?") with remaining freeze count. On confirm: POST to `/api/v1/streaks/{type}/freeze`, haptic medium, `streakFreezeUsed` analytics event, success snackbar. Guards: snackbar-only when already frozen or no freezes available. Shield opacity reflects availability.

2. **Streak milestone celebration card** — `_MilestoneCelebrationCard` shown inline at top of `_ContentView` when `data.milestoneStreakCount != null`. Animated scale-pulse (1.0→1.015, 2000ms loop), activity-green tint, haptic success on first render, `streakMilestoneViewed` analytics event.

3. **Projected completion date** — `_projectCompletionDate()` on `_GoalDetailView` uses last ≤14 history entries to compute average daily gain and extrapolate a target date. Shown in details card and appended to AI commentary.

4. **Progress-toward-unlock on locked achievements** — `Achievement` model extended with optional progress fields. Locked badges in `achievements_screen.dart` render a 3px `LayoutBuilder`-sized progress bar when `progressCurrent`/`progressTotal` are set.

5. **Water intake goal type** — `GoalType.waterIntake` added to enum, `fromString`, `apiSlug`, and `displayName`. Goal create/edit sheet auto-fills `'glasses'` as the default unit on selection.

6. **Weekly Report 5-card story sequence** — Mock always returns 5 canonical cards: Week Summary → Top Insight → Goal Adherence → vs. Last Week → Your Streak. Data-driven card order confirmed by `cardIndex`.

7. **Share-as-image** — Weekly report AppBar share button now captures the currently-visible card at 3× pixel density, writes to a temp PNG, and invokes `Share.shareXFiles()`. Error snackbar on failure.

**`flutter analyze`:** 24 issues (all pre-existing — zero in Progress tab files). Zero errors.

---

## Coach Tab — Gap Closure (feat/coach-tab-gaps, 2026-03-07)

Closed all 7 previously identified gaps across the Coach tab in a single subagent-driven session. Branch: `feat/coach-tab-gaps`.

**Files changed:**
- `zuralog/lib/features/coach/presentation/chat_thread_screen.dart` — 718 → 857 lines
- `zuralog/lib/features/coach/presentation/new_chat_screen.dart` — 1045 → 1354 lines
- `zuralog/lib/features/coach/data/coach_repository.dart` — 206 → 224 lines
- `zuralog/lib/features/coach/providers/coach_providers.dart` — `kDebugMode` guard added
- `zuralog/lib/features/settings/presentation/coach_settings_screen.dart` — 557 → 736 lines

**What was implemented:**

1. **Markdown rendering (Gap 1)** — `chat_thread_screen.dart`'s `_MessageBubble` now renders AI messages via `MarkdownBody` (flutter_markdown_plus) with a matching `MarkdownStyleSheet` (bold, italic, code, list bullets). User messages still use plain `Text`. This matches the legacy `features/chat/` implementation.

2. **Attachment thumbnails in bubbles (Gap 2)** — `_MessageBubble` now renders a `Wrap` of thumbnail cards above the bubble when `message.hasAttachments`. Images (jpg/jpeg/png/gif/webp) render as 80×80 `Image.network` with `ClipRRect(12)`; other files render as a 80×52 PDF card with icon + truncated filename.

3. **Integration context banner (Gap 3)** — New `_IntegrationContextBanner` `ConsumerStatefulWidget` in `new_chat_screen.dart`. Watches `integrationsProvider`, lists connected integration names (up to 2, then "+N more"), dismissible per-session. Appears between the suggestion chips body and the input bar.

4. **Delete & archive conversations (Gap 4)** — `_ConversationTile` upgraded to `ConsumerWidget`. Long-press opens an actions bottom sheet (Archive / Delete). Delete shows an `AlertDialog` confirmation before calling `coachRepositoryProvider.deleteConversation()` + `ref.invalidate(coachConversationsProvider)`. `CoachRepository` interface extended with `deleteConversation` and `archiveConversation`; `MockCoachRepository` provides no-op stubs.

5. **Quick Actions auto-send + Quick Log tile (Gap 5)** — Quick Actions now auto-send non-empty prompts via `_sendMessage()` on tap (empty "Ask Anything" just focuses the input). Added `_QuickLogTile` as the 7th tile in the Quick Actions grid — tapping closes the sheet and opens `QuickLogSheet` in a `DraggableScrollableSheet`.

6. **Coach Settings: missing fields + API persist (Gap 6)** — Added 3 new settings: Response Length (Concise / Detailed chip row), Suggested Prompts (toggle), Voice Input (toggle). The `_ProactivityChipRow` was generalized to accept an `options` parameter. Save button now calls `PATCH /api/v1/preferences` with all 5 preference fields; shows error snackbar on failure.

7. **`kDebugMode` guard in `coachRepositoryProvider` (Gap 7)** — `coachRepositoryProvider` now explicitly guards `MockCoachRepository` behind `kDebugMode`, matching the pattern used by Today/Data/Progress/Trends providers. A `TODO(phase9)` comment marks where the real `ApiCoachRepository` will be substituted.

**`flutter analyze`:** 24 issues (all pre-existing — none in Coach tab files). Zero errors.

---

## Railway Deploy Fix (main, 2026-03-07)

Fixed 9 consecutive Railway deployment failures that had been blocking all backend deploys since 2026-03-06 05:53.

**Root causes fixed:**
1. **`rootDirectory` misconfigured** — Railway service instance had `rootDirectory: "/cloud-brain"` (absolute path) instead of `"cloud-brain"` (relative). Fixed via Railway GraphQL API (`serviceInstanceUpdate`). This caused the build to fail immediately with "Could not find root directory".
2. **Non-idempotent Alembic migration** — `b3c4d5e6f7a8_add_attachments_to_messages` used `op.add_column()` without `IF NOT EXISTS`. The `messages.attachments` column already existed in the DB, so `alembic upgrade head` crashed with `DuplicateColumnError` on every deploy. Three other migrations had the same pattern (`050d7af3bdcf`, `a1b2c3d4e5f6`, `c8d60f5c8771`) — all fixed.

**Backend API now confirmed working:**
- `GET /api/v1/analytics/dashboard-summary` returns 8 categories with real data, sparklines, and deltas for the demo user.

**Flutter-side bug not yet fixed (outstanding):**
- Data tab category cards are empty even with mock data in debug mode.
- Screen turns black after navigating to Settings and back.
- Suspected causes: `hiddenCategories` filtering out all items, or `AnimationController` disposal in `HealthScoreWidget.hero`. See bug report in session notes.

---

## Data Screen — Feature Completion (feat/data-screen-complete, 2026-03-06)

All missing Data tab features from the `screens.md` / `mvp-features.md` specification are now implemented.

**Flutter — 11 files changed:**
- `health_dashboard_screen.dart` — Replaced inline `_HealthScoreHero` (CircularProgressIndicator) with `HealthScoreWidget.hero` (CustomPainter ring, 800ms easeOutCubic animation, 7-day sparkline, AI commentary); added `DataMaturityBanner` between score hero and category cards; `initState` restores `DashboardLayout` from `dashboardLayoutLoaderProvider` on cold-start; edit mode color picker via `_ColorPickerSheet` bottom sheet (14-color palette); color overrides wired through all `CategoryCard` usages
- `data_models.dart` — `DashboardLayout.categoryColorOverrides: Map<String,int>` added with full JSON round-trip
- `category_card.dart` — `onColorPick` callback; palette icon in `_EditModeControls`
- `time_range_selector.dart` — `customDateRange` + `onCustomRangePicked`; Custom segment opens `showDateRangePicker` with sage-green theme
- `category_detail_screen.dart` / `metric_detail_screen.dart` — wired custom date range into cache key and TimeRangeSelector
- `metric_detail_screen.dart` — `_AskCoachButton` sets `coachPrefillProvider` with `"Tell me about my [Metric]: [value] [unit]"` before navigating to Coach tab
- `coach_providers.dart` — `coachPrefillProvider StateProvider<String?>` added
- `new_chat_screen.dart` — `ref.listen(coachPrefillProvider)` injects prefill into input and clears after consumption
- `data_providers.dart` — `dashboardLayoutLoaderProvider FutureProvider<DashboardLayout?>` added
- `data_repository.dart` — `getPersistedLayout()` added to interface and real implementation (GET `/api/v1/preferences`)
- `mock_data_repository.dart` — All 10 categories now have real metrics: Nutrition (calories, protein), Body (weight, body fat), Vitals (SpO₂, respiratory rate), Wellness (HRV, stress), Mobility (flights climbed), Cycle (phase), Environment (noise exposure)

**Backend — 2 files changed:**
- `analytics_schemas.py` — 6 new Pydantic models: `CategorySummaryItem`, `DashboardSummaryResponse`, `MetricDataPointItem`, `MetricSeriesItem`, `CategoryDetailResponse`, `MetricDetailResponse`
- `analytics.py` — `/dashboard-summary` stub replaced with real 14-day queries across 8 tables (delta %, sparkline trends, visible_order); new `/category` endpoint (7D/30D/90D, dispatches by category slug); new `/metric` endpoint (18-metric METRIC_MAP, full time-series, template AI insight)

**Demo data:** Supabase `demo-full@zuralog.dev` verified current with 30 days of data through 2026-03-06.

---

## Cloud Brain (Backend)

### Built

The Cloud Brain is a fully functional FastAPI backend deployed on Railway with the following components:

**Authentication & Users**
- Supabase JWT validation on all protected endpoints via `deps.py`
- User creation on first login, linked to Supabase Auth identity
- Row Level Security (RLS) enforced at the Postgres level
- Google OAuth 2.0 (web + mobile)

**Agent Layer**
- Orchestrator with Reason → Tool → Act loop; persona/proactivity injected per request
- OpenRouter client calling `moonshotai/kimi-k2.5` (Kimi K2.5)
- MCP Client + Server Registry — plug-and-play tool routing
- Chat endpoint with Server-Sent Events (SSE) streaming
- Conversation history persistence + management (list/rename/archive/delete)
- Three AI personas: Tough Love / Balanced (default) / Gentle
- Three proactivity levels: Low / Medium (default) / High
- `PineconeMemoryStore` — per-user vector namespace; top-5 relevant memories injected per request; falls back to `InMemoryStore` when unconfigured
- `LogHealthDataTool` — NL logging MCP tool with two-phase confirmation flow

**MCP Servers (all production-registered)**
- `StravaServer` — activities, stats, create activity
- `FitbitServer` — 12 tools (activity, HR/HRV/intraday, sleep, SpO2, breathing rate, skin temp, VO2 max, weight, nutrition)
- `OuraServer` — 16 tools (sleep, readiness, activity, HR, SpO2, stress, resilience, cardiovascular age, VO2 max, workouts, sessions, tags, rest mode, sleep time, ring config)
- `WithingsServer` — 10 tools (body composition, blood pressure, temperature, SpO2, HRV, activity, workouts, sleep, sleep summary, ECG/heart)
- `AppleHealthServer` — ingest and read HealthKit data
- `HealthConnectServer` — ingest and read Health Connect data
- `DeepLinkServer` — URI scheme launch library for third-party apps

**Integrations**
- Strava: full OAuth 2.0, token auto-refresh, Celery sync (15min), webhooks, Redis sliding-window rate limiter
- Fitbit: OAuth 2.0 + PKCE, single-use refresh token handling, per-user Redis token-bucket rate limiter (150/hr), webhooks, Celery sync (15min) + token refresh (1hr)
- Oura Ring: OAuth 2.0 (no PKCE), long-lived tokens, app-level Redis sliding-window rate limiter (5,000/hr shared), per-app webhook subscriptions (90-day expiry with auto-renewal), sandbox mode, Celery sync
- Withings: OAuth 2.0 with HMAC-SHA256 request signing (unique), server-side callback, app-level rate limiter (120 req/min), 7 webhook `appli` codes, 10 MCP tools, `BloodPressureRecord` new model; credentials pending
- Apple Health: ingest-only (native bridge handles reading; backend receives via platform channel)
- Google Health Connect: same pattern as Apple Health

**Infrastructure Services**
- Celery + Redis (Railway) for background task queuing
- Sync scheduler orchestrating all provider syncs
- Firebase FCM push notification service + `send_and_persist()` method
- RevenueCat webhook handler + subscription entitlement service
- In-memory TTL cache layer (short/medium/long TTL patterns)
- SlowAPI rate limiter middleware
- Sentry error tracking (FastAPI + Celery + SQLAlchemy + httpx)
- Morning Briefing Celery Beat task (15-min schedule; per-user time window)
- Smart Reminder Engine (hourly Celery Beat; dedup/quiet hours/frequency cap)
- Background Alerts (post-ingest: anomaly, goal reached, streak milestone, stale integration)

**Phase 2 — MVP Backend Services (2026-03-04)**

All 24 Phase 2 tasks complete on branch `feat/backend-mvp-services`:

*Health Intelligence*
- `HealthScoreCalculator` — 6-metric weighted percentile composite score (sleep/HRV/RHR/activity/sleep-consistency/steps); 7-day history; AI commentary
- `AnomalyDetector` — 2-stddev rolling baseline detection; insight card + FCM push on critical findings
- `DataMaturityService` — 4-tier maturity (building/ready/strong/excellent); per-feature gating
- `InsightGenerator` — 8 insight types with time-of-day awareness; Celery post-ingest pipeline
- `CorrelationSuggester` — goal→gap mapping with 6 goal types; dismissal tracking

*Data Models + CRUD*
- `JournalEntry` — mood/energy/stress/sleep sliders + tags; one-per-day upsert
- `QuickLog` — 7 metric types; single + batch submit; feeds analytics
- `Achievement` + `AchievementTracker` — 18 achievements in 6 categories; push on unlock
- `UserStreak` + `StreakTracker` — 4 streak types; freeze mechanic (1/week, max 2); milestone celebrations
- `EmergencyCard` — blood type, allergies, medications, conditions, emergency contacts; feeds AI memory
- `NotificationLog` — persistence for all FCM pushes; grouped history API; mark-read endpoint

*Reporting*
- `ReportGenerator` — weekly (WoW deltas + highlights) and monthly (category summaries) generation
- `reports` table + `/api/v1/reports` endpoints (list/detail/on-demand generate)

*API Endpoints Added*
- `GET/PUT /api/v1/preferences` (Task 2.1 — already committed)
- `GET /api/v1/health-score` — today's score + 7-day trend
- `GET/PATCH /api/v1/insights` — insight card feed
- `GET /api/v1/achievements`, `GET /api/v1/achievements/recent`
- `GET /api/v1/streaks`, `POST /api/v1/streaks/{type}/freeze`
- `GET/PUT /api/v1/emergency-card`
- `GET/PATCH /api/v1/notifications` — history + mark-read
- `GET /api/v1/memories`, `DELETE /api/v1/memories/{id}`, `DELETE /api/v1/memories`
- `GET /api/v1/prompts/suggestions`
- `GET /api/v1/quick-actions`
- `GET /api/v1/reports`, `GET /api/v1/reports/generate`
- `POST /api/v1/chat/{id}/attachments`
- `GET/POST/PUT/DELETE /api/v1/journal`
- `POST /api/v1/quick-log`, `POST /api/v1/quick-log/batch`

*Migrations*
- `b2c3d4e5f6a7` — achievements, user_streaks, journal_entries, quick_logs, emergency_health_cards
- `d4e5f6a7b8c9` — notification_logs, reports

**Analytics**
- Correlation analysis engine
- Daily metrics aggregation
- Analytics API endpoints

**Database Models**
`User`, `Conversation`, `HealthData` (UnifiedActivity, SleepRecord, HealthMetric), `Integration`, `DailyMetrics`, `UserGoal`, `UserDevice`, `UsageLog`

### Key Deviations from Original Plan

| Original Plan | Actual Implementation | Reason |
|--------------|----------------------|--------|
| Direct Kimi K2.5 API | OpenRouter (`moonshotai/kimi-k2.5`) | OpenRouter provides routing flexibility and a single API surface for future model swaps |
| Fitbit marked as "Phase 5.1" | Fitbit fully implemented | Moved up due to high user value and available API |
| Pinecone vector store in Phase 1.8 | Not yet active | `PINECONE_API_KEY` env var exists; integration code not written yet |

---

## Flutter Edge Agent (Mobile)

### Built

**Core Infrastructure**
- Riverpod state management with code generation
- GoRouter navigation with authenticated route guards
- Dio HTTP client with auth interceptor (auto-attaches JWT)
- Drift local database for offline caching
- SecureStorage for JWT persistence
- `app_links` deep link interception
- Sentry + Sentry-Dio integration

**Auth**
- Email/password signup and login
- Google Sign In (native, iOS + Android)
- Onboarding screens
- Deep link OAuth callback handler (`zuralog://oauth/strava`, `zuralog://oauth/fitbit`, `zuralog://oauth/oura`, `zuralog://oauth/withings`)

**Chat**
- AI chat UI with streaming message display
- Markdown rendering (`flutter_markdown_plus`)
- Voice input button (UI present; backend endpoint exists; integration pending)
- File attachment button (UI present; feature pending)

**Dashboard**
- Health summary cards (steps, calories, sleep, activities)
- Charts (`fl_chart` — sparklines, trend charts)
- AI insight card

**Integrations Hub**
- Three sections: Connected / Available / Coming Soon
- Connected integrations: Strava, Apple Health (iOS), Google Health Connect (Android), Fitbit, Oura Ring
- Coming soon: Garmin, WHOOP
- Platform compatibility badges (iOS-only, Android-only)
- Persisted connection state via SharedPreferences

**Health Native Bridges**
- iOS: HealthKit native bridge with `HKObserverQuery` background observers, `HKAnchoredObjectQuery` incremental sync, 30-day initial backfill, iOS Keychain JWT persistence for background-only sync
- Android: Health Connect WorkManager periodic task, EncryptedSharedPreferences JWT persistence, 30-day initial backfill

**Settings & Profile — Phase 8 (12 screens, fully built)**

- **Settings Hub** — iOS-style grouped list, icon badges, section labels, `SliverAppBar` large-title header; routes to all settings sub-screens
- **Account Settings** — name, email, password change rows; destructive Delete Account with confirmation dialog
- **Notification Settings** — granular per-category toggles (Coach insights, workout reminders, streak alerts, weekly reports, security); time-range picker for quiet hours
- **Appearance Settings** — Dark / Light / System theme selector with visual tile picker; language selector
- **Coach Settings** — AI coach persona toggle, coaching style selector (3 options), response detail level, proactive suggestions toggle, data sharing consent toggle
- **Integrations Management** — status tiles for all connected integrations (Strava, Apple Health, Health Connect, Fitbit, Oura Ring) with connect/disconnect actions; routes back to main Integrations screen
- **Privacy & Data** — data export request, analytics opt-out, delete all data with confirmation; links to Privacy Policy and Terms of Service screens
- **Subscription** — Free vs. Pro tier comparison; feature matrix; upgrade CTA (RevenueCat); restore purchases
- **About** — app version, build number, acknowledgements; links to Privacy Policy and Terms of Service screens
- **Profile Screen** — avatar with initials fallback, inline name edit, subscription tier badge, Emergency Health Card banner, account stats (joined date, workouts logged), sign-out
- **Emergency Health Card (view)** — high-contrast read-only view (blood type, allergies, conditions, medications, 3 emergency contacts); formatted for first-responder legibility
- **Emergency Health Card (edit)** — blood type picker, tag-style chip inputs for allergies/conditions/medications, 3 structured contact editors; persisted via `emergencyCardProvider`
- **Privacy Policy** — full GDPR/CCPA-compliant policy (11 sections); `SliverAppBar` + scrollable rich text
- **Terms of Service** — full ToS (13 sections, medical disclaimer); same layout

Legal routes added: `/settings/privacy-policy`, `/settings/terms` in `route_names.dart` + `app_router.dart`

**Subscription**
- RevenueCat paywall (Pro upgrade flow)
- Entitlement-aware feature gating

**Testing**
- 36 unit tests + integration tests

### Key Deviations from Original Plan

| Original Plan | Actual Implementation | Reason |
|--------------|----------------------|--------|
| `health` Flutter package for unified health API | Native Swift/Kotlin platform channels directly | Better reliability, deeper API access, and avoids third-party wrapper maintenance |
| Cloud Whisper STT for voice input | On-device STT via `speech_to_text` Flutter package | Free, offline, no API key required; audio never leaves the device |
| Apple Sign In (live) | Coming soon (UI shows dialog) | Pending Apple Developer subscription |

---

## Voice Input — On-Device STT (2026-03-02)

**Branch:** `feat/voice-input-stt`

**Status:** ✅ Complete. On-device speech-to-text fully implemented and wired to Coach tab mic button. Audio never leaves the device.

**What was built:**

- `zuralog/lib/core/speech/` — New directory with `speech_notifier.dart` (Riverpod `AsyncNotifier` wrapping `speech_to_text` package), `speech_models.dart` (SpeechState enum: idle/listening/processing/done/error), `speech_providers.dart` (global `speechNotifierProvider`)
- `zuralog/lib/features/chat/presentation/chat_screen.dart` — Wires `SpeechNotifier` to `ChatInputBar`; listening overlay banner with `_PulsingDot`; speech error SnackBars; PostHog analytics (`voice_input_started`, `voice_input_completed` with `text_length` / `has_text` properties)
- `zuralog/lib/features/chat/presentation/widgets/chat_input_bar.dart` — Mic button (hold-to-talk) wired to `speechNotifierProvider.listen()`. On release, transcribed text is injected into the input field. User can review and edit before tapping Send.
- `zuralog/android/app/src/main/AndroidManifest.xml` — Added `RECORD_AUDIO` permission + speech `RecognitionService` query (BLUETOOTH/BLUETOOTH_CONNECT intentionally omitted — not required for on-device mic STT and would trigger Play Store dangerous-permission review)
- `zuralog/test/features/chat/presentation/widgets/chat_input_bar_test.dart` — Updated for new widget structure; 4 new voice input tests (11 total)
- `zuralog/pubspec.yaml` — Added `speech_to_text: ^7.3.0` (removed `record` and `audioplayers` packages)

**Key decisions:**

| Decision | Rationale |
|----------|-----------|
| On-device STT (not Cloud Whisper) | Free, offline, no API key; audio never leaves device |
| Hold-to-talk UX | Familiar pattern (like Slack, Discord). User taps mic, speaks, releases. Text appears in input field for review. |
| Text injection into input field | User can edit transcribed text before sending. Prevents sending incorrect transcriptions. |
| No audio storage | Audio is processed in-memory by the platform's native speech engine and discarded immediately. |
| RECORD_AUDIO permission only | Sufficient for on-device STT. BLUETOOTH permissions omitted to avoid Play Store review delays. |

**`flutter analyze`:** No new issues introduced.

---

## Website

### Built

A full marketing and waitlist site built on Next.js 16:

**Core Pages**
- Landing page with hero section, animated text
- 3D phone mockup (Three.js + React Three Fiber) rotates in hero
- GSAP + Framer Motion animations throughout
- Lenis smooth scroll

**Waitlist System**
- Supabase-backed signup
- Animated waitlist counter
- Support leaderboard
- Waitlist statistics bar
- Confetti burst on signup
- Google reCAPTCHA v2 on waitlist signup form

**User Experience**
- Multi-step onboarding quiz flow to personalize waitlist experience
- iPhone mockup component for app preview

**Legal & Company Pages**
- Privacy Policy (GDPR / CCPA compliant)
- Terms of Service
- Cookie Policy
- Community Guidelines
- About page
- Contact form
- Support page

**Technical**
- OpenGraph image (server-rendered)
- Sitemap + robots.txt
- Sentry error tracking
- Vercel Analytics
- Resend transactional email
- React Hook Form + Zod validation

### Key Deviations from Original Plan

| Original Plan | Actual Implementation | Reason |
|--------------|----------------------|--------|
| Simple landing page | Full marketing site with legal pages, About, Contact, Support | Required for App Store review + GDPR |
| Basic animations | Three.js, GSAP, Framer Motion, Lenis | Higher-quality brand impression |

---

## Design System v3.1 + App Shell Rebuild (2026-03-04)

### Phase 0: Design System Foundation

Full design system v3.1 established as the canonical token layer for all future Flutter work.

**Files created:**
- `zuralog/lib/core/theme/app_colors.dart` — All color tokens: `primary` (Sage Green `#CFE1B9`), OLED `scaffold` (`#000000`), `surface` (`#1C1C1E`), `cardBackground` (`#121212`), category colors (`categoryActivity`, `categorySleep`, `categoryHeart`, `categoryMindfulness`, `categoryNutrition`, `categoryBody`), semantic colors (`success`, `warning`, `error`, `info`), text hierarchy (`textPrimary`…`textQuaternary`)
- `zuralog/lib/core/theme/app_text_styles.dart` — Typography tokens: `h1`–`h3`, `body`, `caption`, `labelXs` (SF Pro Display / Inter)
- `zuralog/lib/core/theme/app_dimens.dart` — Spacing (`xs`=4…`xxl`=48), border radius (`cardRadius`=20, `buttonRadius`=14), icon sizes
- `zuralog/lib/core/theme/app_theme.dart` — `ThemeData` wired to all tokens; dark-first, OLED scaffold
- `zuralog/lib/core/haptics/haptic_service.dart` + `haptic_providers.dart` + `haptic.dart` barrel — `HapticService` with `selectionClick`, `lightImpact`, `mediumImpact`, `heavyImpact`, `success`, `error`, `warning`

**Key decisions:**
- Dark-first: `scaffoldBackgroundColor` is OLED true black (`#000000`); light mode tokens present but secondary priority
- No hardcoded hex in widget files — all widgets import `AppColors.*` and `AppTextStyles.*`
- Cards: `borderRadius: 20`, no border, no shadow — depth from background color contrast only
- Primary actions: `FilledButton` with `AppColors.primary`, `borderRadius: 14`

### Phase 1: App Shell & 5-Tab Navigation

Replaced the old 2-tab shell (Dashboard + Chat) with the full 5-tab architecture defined in `screens.md`.

**Files modified:**
- `zuralog/lib/shared/layout/app_shell.dart` — Rebuilt as 5-tab `NavigationBar` with `BackdropFilter` Gaussian blur (σ=20), frosted glass effect, 200ms curve animation, haptic selection tick via `hapticServiceProvider`, sage green active / `textTertiary` inactive, no indicator pill
- `zuralog/lib/core/router/app_router.dart` — Rebuilt with `StatefulShellRoute.indexedStack` (5 branches: Today / Data / Coach / Progress / Trends), all settings nested under `/settings`, profile sub-routes under `/profile`, auth guard preserved
- `zuralog/lib/core/router/route_names.dart` — All 37 route name + path constants

**Files created (placeholder screens):**
- Today: `today_feed_screen.dart`, `insight_detail_screen.dart`, `notification_history_screen.dart`
- Data: `health_dashboard_screen.dart`, `category_detail_screen.dart`, `metric_detail_screen.dart` (new `features/data/` directory)
- Coach: `new_chat_screen.dart`, `chat_thread_screen.dart`
- Progress: `progress_home_screen.dart`, `goals_screen.dart`, `goal_detail_screen.dart`, `achievements_screen.dart`, `weekly_report_screen.dart`, `journal_screen.dart`
- Trends: `trends_home_screen.dart`, `correlations_screen.dart`, `reports_screen.dart`, `data_sources_screen.dart`
- Settings (9 screens): hub, account, notifications, appearance, coach, integrations, privacy, subscription, about
- Profile: `profile_screen.dart`, `emergency_card_screen.dart`, `emergency_card_edit_screen.dart`

**Key decisions:**
- `StatefulShellRoute.indexedStack` preserves tab state across navigation (no re-renders on tab switch)
- Frosted glass nav bar keeps OLED background visible — no opaque bottom chrome
- All screens are placeholder scaffolds — real implementations follow in Phases 3–8

---

## Oura Ring Direct Integration (2026-03-01) — Code Complete, Credentials Blocked

> **Status:** All backend and Flutter code is implemented and merged on `feat/oura-direct-integration`. Deployment is blocked because registering an Oura OAuth application requires an active Oura account, which in turn requires owning an Oura Ring. Once the hardware is acquired, the remaining steps are: create account → register app at cloud.ouraring.com/oauth/applications → add credentials to Bitwarden + `.env` + Railway → flip the Flutter tile from "Coming Soon" to live.

## Oura Ring Direct Integration (2026-03-01)

Full Oura Ring integration implemented as a direct REST API connection, providing 16 data types unavailable via HealthKit/Health Connect alone.

**Backend files created (6):**
- `cloud-brain/app/services/oura_token_service.py` — OAuth 2.0 token management (no PKCE), refresh on 401, sandbox mode via `OURA_USE_SANDBOX=true`
- `cloud-brain/app/services/oura_rate_limiter.py` — App-level Redis sliding-window rate limiter (5,000 req/hr shared across all users; no response headers to track)
- `cloud-brain/app/mcp_servers/oura_server.py` — 16 MCP tools covering all Oura data types
- `cloud-brain/app/api/v1/oura_routes.py` — OAuth routes: `/authorize`, `/exchange`, `/status`, `/disconnect`
- `cloud-brain/app/api/v1/oura_webhooks.py` — Webhook receiver with HMAC verification; per-app subscription (90-day expiry)
- `cloud-brain/app/tasks/oura_sync_tasks.py` — Celery tasks: data sync, token refresh, webhook auto-renewal (runs daily; renews if < 7 days to expiry)

**Flutter files created (4):**
- `zuralog/lib/features/integrations/oura_oauth_page.dart` — OAuth flow + deep link callback (`zuralog://oauth/oura`)
- `zuralog/lib/features/integrations/providers/oura_provider.dart` — Riverpod provider for connection state
- `zuralog/lib/features/integrations/services/oura_integration_service.dart` — API calls: connect, disconnect, status
- `zuralog/lib/features/integrations/widgets/oura_tile.dart` — Integrations Hub tile

**Test coverage (171 tests total):**

| File | Tests |
|------|-------|
| `tests/services/test_oura_token_service.py` | 48 |
| `tests/services/test_oura_rate_limiter.py` | 12 |
| `tests/api/test_oura_routes.py` | 14 |
| `tests/mcp_servers/test_oura_server.py` | 49 |
| `tests/api/test_oura_webhooks.py` | 12 |
| `tests/tasks/test_oura_sync_tasks.py` | 36 |
| **Total** | **171** |

**Key implementation decisions:**

| Decision | Rationale |
|----------|-----------|
| No PKCE | Oura's OAuth spec does not use PKCE (unlike Fitbit); standard Authorization Code flow with Basic auth header on token exchange |
| App-level rate limiter | Oura enforces 5,000 req/hr per app (not per user); sliding-window counter in Redis is the only mechanism since Oura returns no rate-limit headers |
| Sandbox mode | `OURA_USE_SANDBOX=true` + `OURA_SANDBOX_TOKEN` allows full MCP tool testing without a real ring or OAuth credentials |
| Per-app webhook subscription | Unlike Fitbit (per-user subscriptions), Oura uses one subscription covering all users; stored in `oura_webhook_subscriptions` table; auto-renewed via Celery Beat 7 days before expiry |
| Webhook-only for 5 types | Only `daily_sleep`, `daily_activity`, `daily_readiness`, `daily_spo2`, `sleep` receive webhooks; stress, resilience, cardiovascular age, and ring data require periodic Celery poll |

---

## Celery / Railway Production Fix (2026-03-01)

All three Railway services (**Zuralog** web, **Celery_Worker**, **Celery_Beat**) are now fully deployed and running.

**Root causes fixed:**

1. **Missing `posthog` in lockfile** — `posthog>=3.7.0` was added to `pyproject.toml` but `uv.lock` was never regenerated. The Dockerfile uses `uv sync --frozen`, so `posthog` was absent at runtime, causing `ModuleNotFoundError` on uvicorn startup and failing every `/health` healthcheck.

2. **No Railway config for Celery services** — Worker and Beat had no `railway.*.toml` files, so Railway had no start command. Created `cloud-brain/railway.celery-worker.toml` and `cloud-brain/railway.celery-beat.toml` with Dockerfile builder, correct `celery` start commands, and no `healthcheckPath` (Celery is not an HTTP server).

3. **Celery SSL config for TLS Redis `rediss://`** — Celery 5.x requires explicit `broker_use_ssl` / `redis_backend_use_ssl` with `ssl_cert_reqs` when using TLS. Added to `worker.py` using `ssl.CERT_REQUIRED` (TLS Redis uses CA-signed certs).

**Security hardening applied:**

- `ssl.CERT_REQUIRED` (not `CERT_NONE`) — full TLS certificate verification against system CA bundle.
- Dockerfile runtime stage now creates a non-root `appuser` (uid=1000); Celery and uvicorn both run as non-root, eliminating Celery's SecurityWarning.

---

## Withings Direct Integration (2026-03-01) — Code Complete, Credentials Pending

> **Status:** All backend and Flutter code is implemented on `feat/withings-integration`. Deployment is blocked on setting `WITHINGS_CLIENT_ID` and `WITHINGS_CLIENT_SECRET` in Railway (credentials are in BitWarden). The `WITHINGS_REDIRECT_URI` is already set on the Zuralog Railway service. Once credentials are configured on all three Railway services (Zuralog, Celery_Worker, Celery_Beat), the branch can be deployed and E2E tested.

Full Withings integration providing body composition, sleep, blood pressure, temperature, SpO2, HRV, ECG, and activity data via the Withings Health API (HMAC-SHA256 request signing).

**Backend files created (8):**
- `cloud-brain/app/services/withings_signature_service.py` — HMAC-SHA256 nonce+signature service; every Withings API call gets a fresh nonce from `/v2/signature`, then signs `action,client_id,nonce` with HMAC-SHA256
- `cloud-brain/app/services/withings_token_service.py` — OAuth 2.0 token management (no PKCE); 3-hour access tokens with 30-minute proactive refresh buffer; stores `user_id` (not `"1"`) in Redis state for server-side callback resolution
- `cloud-brain/app/services/withings_rate_limiter.py` — App-level Redis Lua-atomic rate limiter (120 req/min shared; Withings enforces at app level)
- `cloud-brain/app/models/blood_pressure.py` — New `BloodPressureRecord` DB model; Supabase migration applied (`blood_pressure_records` table with uq constraint on `user_id+source+measured_at`)
- `cloud-brain/app/api/v1/withings_routes.py` — OAuth routes: `/authorize`, `/callback` (server-side; browser redirect then deep-link redirect to `zuralog://oauth/withings`), `/status`, `/disconnect`
- `cloud-brain/app/api/v1/withings_webhooks.py` — Webhook receiver (form-encoded POST, not JSON); dispatches Celery tasks per `appli` code
- `cloud-brain/app/mcp_servers/withings_server.py` — `WithingsServer` with 10 MCP tools covering all Withings data types
- `cloud-brain/app/tasks/withings_sync.py` — 5 Celery tasks: notification sync, 15-min periodic, 1-hr token refresh, 30-day backfill, webhook subscription creation

**Backend files modified (2):**
- `cloud-brain/app/main.py` — wired `WithingsSignatureService`, `WithingsTokenService`, `WithingsRateLimiter`, `WithingsServer`; mounted routes
- `cloud-brain/app/worker.py` — added Beat schedules: `sync-withings-users-15m` (900s), `refresh-withings-tokens-1h` (3600s)

**Flutter files modified (3):**
- `zuralog/lib/features/integrations/data/oauth_repository.dart` — added `getWithingsAuthUrl()` (GET `/api/v1/integrations/withings/authorize`)
- `zuralog/lib/features/integrations/domain/integrations_provider.dart` — added Withings to `_defaultIntegrations` and `connect()` switch case
- `zuralog/lib/core/deeplink/deeplink_handler.dart` — added `withings` provider case; reads `success` query param from `zuralog://oauth/withings?success=true`

**Test coverage (71 new tests):**

| File | Tests |
|------|-------|
| `tests/test_withings_signature_service.py` | 10 |
| `tests/test_withings_token_service.py` | 16 |
| `tests/test_withings_rate_limiter.py` | 12 |
| `tests/test_withings_routes.py` | 11 |
| `tests/test_withings_webhooks.py` | 7 |
| `tests/test_withings_server.py` | 15 |
| **Total** | **71** |

**Key implementation decisions:**

| Decision | Rationale |
|----------|-----------|
| Standalone `WithingsSignatureService` | HMAC-SHA256 nonce+signature is unique to Withings among all integrations; isolating it into its own class makes testing clean and reuse straightforward |
| Server-side OAuth callback | Withings validates callback URL reachability at app registration — `zuralog://` custom schemes are rejected. Backend receives the code at `https://api.zuralog.com/api/v1/integrations/withings/callback`, exchanges it within the 30-second window, then redirects the browser to `zuralog://oauth/withings?success=true` |
| `store_state` stores `user_id` | Unlike Oura (which stores `"1"`), Withings' server-side callback has no JWT available — user identity is resolved from the `state` → `user_id` Redis lookup |
| Webhook subscribe uses Bearer auth (no signing) | Only data API calls require HMAC-SHA256 signatures; Withings' `notify/subscribe` endpoint uses standard Bearer token auth |
| 30-minute refresh buffer | Access tokens expire in 3 hours (most aggressive of all integrations); 30-minute buffer ensures proactive refresh before expiry during long-running tasks |
| `BloodPressureRecord` as new model | No existing BP model in codebase; designed to support future integrations (not Withings-specific); includes `source` field for multi-provider dedup |
| App-level rate limiter at 120/min | Withings enforces 120 req/min at the application level (not per-user); Redis Lua atomic INCR+EXPIRE, fail-open on Redis errors |

**Webhook `appli` codes handled:**
```
1=weight/body comp → getmeas (1,5,6,8,76,77,88,91)
2=temperature → getmeas (12,71,73)
4=blood pressure/SpO2 → getmeas (9,10,11,54)
16=activity → getactivity / getworkouts
44=sleep → sleep v2 getsummary
54=ECG → heart v2 list
62=HRV → getmeas (135)
```

**MCP tools (10):** `withings_get_measurements`, `withings_get_blood_pressure`, `withings_get_temperature`, `withings_get_spo2`, `withings_get_hrv`, `withings_get_activity`, `withings_get_workouts`, `withings_get_sleep`, `withings_get_sleep_summary`, `withings_get_heart_list`

---

## WHOOP Integration — Deferred (2026-03-01)

WHOOP was researched and planned as a P1 direct integration. Implementation was deferred after confirming that the WHOOP Developer Dashboard (`developer-dashboard.whoop.com`) requires an active WHOOP membership to create an account and register an OAuth application. This is a hardware dependency, not a policy gate — there is no workaround.

**Decision:** Moved to P2/Future. Will revisit when user demand from the WHOOP member segment justifies acquiring hardware. All technical research and the implementation plan are preserved in `.opencode/plans/2026-02-28-direct-integrations-top10-research.md`.

**Next integration:** Withings (P1).

---

## Dynamic Tool Injection (2026-03-02)

**Branch:** `feat/dynamic-tool-injection`  
**Status:** Complete — squash-merged to main

### What Was Built

A per-user MCP tool filtering layer that injects only the tools for integrations the user has actually connected, rather than all registered MCP tools.

**New file:**
- `app/services/user_tool_resolver.py` — `UserToolResolver` class with `ALWAYS_ON_SERVERS` frozenset and `PROVIDER_TO_SERVER` allowlist dict. Uses `select(Integration.provider)` (column-only projection — no token data loaded) with `WHERE user_id = ? AND is_active IS TRUE` on the indexed column. Maps provider strings → server names, unions with always-on servers, calls `MCPServerRegistry.get_tools_for_servers()`.

**Modified files:**
- `app/mcp_servers/registry.py` — Added `get_tools_for_servers(server_names: AbstractSet[str])` filtered aggregation method
- `app/agent/mcp_client.py` — Added optional `tool_resolver` param to `__init__`; added `get_tools_for_user(db, user_id)` async method
- `app/agent/orchestrator.py` — `_build_tools_for_llm()` accepts pre-resolved tool list; `process_message()` accepts optional `db: AsyncSession | None = None`
- `app/main.py` — Wires `UserToolResolver` into `MCPClient` at startup
- `app/api/v1/chat.py` — Passes `db` session to `orchestrator.process_message()`; removed dead `_get_orchestrator` dependency function

**Test coverage:** 40 new/updated tests across 5 files including an end-to-end integration test.

### Key Decisions

- **Column-only query:** `select(Integration.provider)` — does not load OAuth tokens or metadata into memory. Returns plain strings.
- **DB query per request (no cache):** ~1ms async Postgres query on indexed `user_id` column. Revisit with Redis only if profiling shows bottleneck.
- **Fail-open:** DB failure falls back to all tools — chat never breaks due to resolver error.
- **Backwards-compatible:** All parameters default to `None`; existing call sites unchanged.
- **Allowlist mapping:** `PROVIDER_TO_SERVER` dict means unknown provider values in DB are silently dropped — no injection risk.

---

## Polar AccessLink Direct Integration (2026-03-01) — Code Complete, Credentials Set

Full Polar AccessLink integration providing exercise data, daily activity, continuous heart rate, sleep, Nightly Recharge (ANS/HRV recovery), cardio load, SleepWise alertness/circadian bedtime, Elixir body temperature, and physical information from Polar watches and sensors.

**New files:**
- `cloud-brain/app/services/polar_token_service.py` — OAuth 2.0 token lifecycle (auth URL, code exchange with Basic auth, mandatory user registration, save/retrieve/disconnect); no refresh tokens (~1 year access tokens)
- `cloud-brain/app/services/polar_rate_limiter.py` — Dynamic dual-window app-level rate limiter (short: `500 + N×20` per 15 min; long: `5000 + N×100` per 24 hr); limits updated from Polar response headers (`RateLimit-Usage`, `RateLimit-Limit`, `RateLimit-Reset`), fail-open
- `cloud-brain/app/api/v1/polar_routes.py` — OAuth endpoints: `GET /authorize`, `POST /exchange`, `GET /status`, `DELETE /disconnect`; IDOR prevention via state→user_id lookup; mandatory user registration step after token exchange
- `cloud-brain/app/api/v1/polar_webhooks.py` — Webhook handler with HMAC-SHA256 signature verification (`Polar-Webhook-Signature` header); handles PING event (sent on webhook creation); always returns 200 to prevent 7-day auto-deactivation
- `cloud-brain/app/mcp_servers/polar_server.py` — `PolarServer` with 14 MCP tools covering all Polar data types
- `cloud-brain/app/tasks/polar_sync.py` — 6 Celery tasks: webhook-triggered sync, 15-min periodic sync, daily token expiry monitor (push notification 30 days before expiry), 28-day backfill, webhook creation (client-level Basic auth), daily webhook status check + re-activation

**Modified files:**
- `cloud-brain/app/config.py` — added `polar_client_id`, `polar_client_secret`, `polar_redirect_uri`, `polar_webhook_signature_key`
- `cloud-brain/app/main.py` — wired `PolarTokenService`, `PolarRateLimiter`, `PolarServer`; mounted routes and webhook router
- `cloud-brain/app/worker.py` — added 3 Beat schedules: `sync-polar-users-15m`, `monitor-polar-token-expiry-daily`, `check-polar-webhook-status-daily`
- `zuralog/lib/features/integrations/data/oauth_repository.dart` — added `getPolarAuthUrl()` and `handlePolarCallback()`
- `zuralog/lib/features/integrations/domain/integrations_provider.dart` — added Polar to `_defaultIntegrations` (Available) and `connect()` switch case
- `zuralog/lib/core/deeplink/deeplink_handler.dart` — added `case 'polar':` and `_handlePolarCallback()`

**Tests:** 137 tests total across 5 test files (token service 42, rate limiter 20, webhooks 13, MCP server 33, sync tasks 29)

**Key decisions:**

| Decision | Rationale |
|----------|-----------|
| Basic auth on token exchange | Polar requires `Authorization: Basic base64(client_id:client_secret)` — unlike most providers that accept credentials in the POST body. `redirect_uri` must also be echoed per RFC 6749 §4.1.3 |
| Mandatory user registration | Polar AccessLink requires `POST /v3/users {"member-id": user_id}` after every first OAuth before any data can be fetched. 409 (already registered) is handled gracefully |
| No refresh tokens | Polar issues ~1-year access tokens with no refresh mechanism. Expired tokens require full re-auth; `monitor_polar_token_expiry_task` sends push notification 30 days before expiry |
| Single client-level webhook | Polar issues one webhook per client covering all users (unlike Fitbit/Withings which are per-user). Webhook auto-deactivates after 7 days of failures → `check_polar_webhook_status_task` checks daily and re-activates if needed |
| Dynamic dual-window rate limits | Polar's limits scale with registered user count: `500 + (N×20)` per 15 min, `5000 + (N×100)` per 24 hr. Headers are authoritative; formula is fallback. Block at 90% safety margin |
| Two auth modes | Bearer token for user data endpoints; Basic auth for client-level endpoints (webhook CRUD, pull notifications). `_basic_auth_header()` helper in sync tasks |
| Data window | Polar only exposes last 30 days and only data uploaded after user registration. Backfill uses 28-day window to be safe |

**MCP tools (14):** `polar_get_exercises`, `polar_get_exercise`, `polar_get_daily_activity`, `polar_get_activity_range`, `polar_get_continuous_hr`, `polar_get_continuous_hr_range`, `polar_get_sleep`, `polar_get_nightly_recharge`, `polar_get_cardio_load`, `polar_get_cardio_load_range`, `polar_get_sleepwise_alertness`, `polar_get_sleepwise_bedtime`, `polar_get_body_temperature`, `polar_get_physical_info`

---

## Waitlist Bug Fix (2026-02-24)

A critical bug in the waitlist signup flow was identified and fixed:

**Root cause:** Schema mismatch between the API payload and the Supabase database table. The API was sending fields that didn't exist or had wrong types in the `waitlist_signups` table.

**Fix applied:**
- Corrected Supabase table schema to match API expectations
- Updated API routes to use correct field names
- Fixed TypeScript types in the frontend
- Enhanced UI with animated counter and dark-only theme

---

## Voice Input — On-Device STT (2026-03-02)

**Branch:** `feat/voice-input-stt`
**Status:** Complete

On-device speech-to-text using the `speech_to_text` Flutter package (v7.3.0). Audio never leaves the device. No API key or network required (uses Apple Speech framework on iOS, Google Speech Services on Android).

**New files:**
- `zuralog/lib/core/speech/speech_state.dart` — Immutable state model (`SpeechStatus` enum, `SpeechState` class with `copyWith`, equality, `toString`)
- `zuralog/lib/core/speech/speech_service.dart` — Service wrapper around `SpeechToText` plugin (init, listen, stop, cancel, sound level normalization dBFS → 0–1)
- `zuralog/lib/core/speech/speech_providers.dart` — `SpeechNotifier` (StateNotifier) + `speechNotifierProvider` (Riverpod autoDispose)
- `zuralog/lib/core/speech/speech.dart` — Barrel export
- `zuralog/test/core/speech/speech_service_test.dart` — 29 unit tests using `_FakeSpeechToText extends SpeechToText` (hand-rolled fake using `withMethodChannel()` ctor)
- `zuralog/test/core/speech/speech_providers_test.dart` — 6 unit tests using `_FakeSpeechService extends SpeechService`

**Modified files:**
- `zuralog/lib/features/chat/presentation/widgets/chat_input_bar.dart` — Hold-to-talk `GestureDetector` on mic button; animated pulsing circle feedback; `didUpdateWidget` inserts recognized text into field on listen stop
- `zuralog/lib/features/chat/presentation/chat_screen.dart` — Wires `SpeechNotifier` to `ChatInputBar`; listening overlay banner with `_PulsingDot`; speech error SnackBars; PostHog analytics (`voice_input_started`, `voice_input_completed` with `text_length` / `has_text` properties)
- `zuralog/pubspec.yaml` — Added `speech_to_text: ^7.3.0`
- `zuralog/ios/Runner/Info.plist` — Added `NSSpeechRecognitionUsageDescription` + `NSMicrophoneUsageDescription`
- `zuralog/android/app/src/main/AndroidManifest.xml` — Added `RECORD_AUDIO` permission + speech `RecognitionService` query (BLUETOOTH/BLUETOOTH_CONNECT intentionally omitted — not required for on-device mic STT and would trigger Play Store dangerous-permission review)
- `zuralog/test/features/chat/presentation/widgets/chat_input_bar_test.dart` — Updated for new widget structure; 4 new voice input tests (11 total)

**UX:** Hold-to-talk. User long-presses mic button → listening starts → partial text shown in overlay banner → release → final text fills input field → user reviews/edits → taps send. Cancel by dragging away.

**Key decisions:**

| Decision | Rationale |
|----------|-----------|
| On-device STT (not Cloud Whisper) | Free, offline, no API key; audio never leaves device |
| Hold-to-talk (not tap-to-toggle) | More intuitive for short phrases; matches iMessage/WhatsApp voice note UX; natural start/stop boundary |
| Fill text field (not auto-send) | Users review and edit transcription before sending; prevents embarrassing mis-transcriptions |
| Lazy initialization | Speech engine initialized on first mic tap, not app startup; avoids permission prompt on first launch |
| Hand-rolled fakes (not Mockito) | `SpeechToText` and `SpeechService` are concrete classes with platform channels — cannot be mocked with `@GenerateMocks`; `SpeechToText.withMethodChannel()` is the plugin's `@visibleForTesting` extension point |
| 30-second listen limit | Apple recommends max 1 minute; 30s is sufficient for chat commands and reduces battery impact |
| Analytics captured in `ref.listen` (not `onVoiceStop`) | `stopListening()` fires before the plugin's async final result arrives; reading `recognizedText` in the callback gives 0/partial text. `ref.listen` fires on the `isFinal` transition which has the full final text |
| Error-state early return in `onVoiceStart` | Prevents a permission-denied error from looping silently on every long-press. The `ref.listen` SnackBar already surfaces the error; `onVoiceStart` returns early to avoid re-triggering |
| `SpeechNotifier` seeded from `currentState` | `autoDispose` notifier re-creates on re-navigation; seeding from the persistent service's `currentState` prevents the notifier from advertising `uninitialized` when the engine is already `ready` |

---

## Phase 7 — Trends Tab (2026-03-04)

**Branch:** `feat/trends-tab`
**Status:** Complete

Full Trends tab UI — 4 screens built with Riverpod state management, design system tokens, and dark-first layout.

**New files:**
- `zuralog/lib/features/trends/domain/trends_models.dart` — Domain models: `CorrelationHighlight`, `TimePeriodSummary`, `MetricHighlight`, `TrendsHomeData`, `AvailableMetric`, `ScatterPoint`, `CorrelationAnalysis`, `CorrelationTimeRange`, `GeneratedReport`, `ReportCategorySummary`, `TrendDirection`, `ReportList`, `DataFreshness`, `DataSource`, `DataSourceList`
- `zuralog/lib/features/trends/data/trends_repository.dart` — Data layer with 5-min TTL cache; endpoints: trends home, available metrics, correlation analysis (uncached family keyed by metric pair + time range + lag), reports, data sources
- `zuralog/lib/features/trends/providers/trends_providers.dart` — Riverpod providers: `trendsRepositoryProvider`, `trendsHomeProvider`, `availableMetricsProvider`, `selectedMetricAProvider`, `selectedMetricBProvider`, `selectedLagDaysProvider`, `selectedTimeRangeProvider`, `CorrelationKey` + `correlationAnalysisProvider` family, `reportsProvider`, `dataSourcesProvider`
- `zuralog/lib/features/trends/presentation/trends_home_screen.dart` — AI correlation cards, horizontal time-machine strip, quick-nav row (Explorer/Reports/Sources), loading skeleton, error state, onboarding empty state, pull-to-refresh
- `zuralog/lib/features/trends/presentation/correlations_screen.dart` — Two-metric picker (bottom sheet grouped by health category), time-range chips (7D/30D/90D), lag-day selector (same day/+1/+2/+3), scatter plot (`fl_chart` `ScatterChart`), Pearson coefficient card, AI annotation card, picker-prompt empty state
- `zuralog/lib/features/trends/presentation/reports_screen.dart` — Report list with category avatar dots, `_ReportDetailSheet` modal (category summaries, trend direction chips, top correlations, AI recommendations), export PDF + share placeholders with "coming soon" snackbar
- `zuralog/lib/features/trends/presentation/data_sources_screen.dart` — Connected/Not Connected grouped sections, per-source freshness dot (green/yellow/red based on `DataFreshness`), last sync timestamp, data type chips, Reconnect/Connect → `settingsIntegrationsPath`

**Key decisions:**

| Decision | Rationale |
|----------|-----------|
| Uncached `correlationAnalysisProvider` family | Correlation queries are keyed by 3 independent state variables; caching at repository layer would require LRU eviction logic; provider-level invalidation is simpler and sufficient |
| `CorrelationKey` value class for family key | Riverpod family requires a single key; `CorrelationKey` bundles metricA + metricB + timeRange + lagDays with `==`/`hashCode` to deduplicate in-flight requests |
| Scatter plot via `fl_chart` `ScatterChart` | Already a project dependency (used in Progress tab); avoids adding `syncfusion_flutter_charts` which requires a license key |
| "Coming soon" snackbar for PDF export | PDF generation requires a native plugin (`pdf`, `printing`) not yet in pubspec; surface the intent without a broken flow |
| `DataFreshness` color thresholds: green ≤1h, yellow ≤24h, red >24h | Matches Apple Health's own staleness UX; users expect sub-hour freshness for wearable data |

---

## Trends Tab — Gap Closure + Quality Review (feat/trends-gaps, 2026-03-07)

Closed all 8 feature gaps in the Trends tab and applied a comprehensive quality & security review fixing 11 issues across 8 files. Branches: `feat/trends-gaps` (merged) + fixes committed directly to `main` (commit `85365de`).

**Files changed:**
- `zuralog/lib/features/trends/domain/trends_models.dart` — Added `CorrelationSuggestion`, `GoalAdherenceItem`, `CorrelationTimeRange.custom`; null-safe `ScatterPoint.fromJson`, `ReportCategorySummary.fromJson`
- `zuralog/lib/features/trends/data/trends_repository.dart` — `getCorrelationAnalysis` interface + implementation extended with optional `customStart`/`customEnd` params forwarded as UTC ISO query strings
- `zuralog/lib/features/trends/data/mock_trends_repository.dart` — Seeded 3 `CorrelationSuggestion` cards and 2×3 `GoalAdherenceItem` fixtures; updated `getCorrelationAnalysis` signature
- `zuralog/lib/features/trends/providers/trends_providers.dart` — Added `customDateStartProvider`, `customDateEndProvider`; `CorrelationKey` extended with custom date fields; provider forwards `customStart`/`customEnd` to repository
- `zuralog/lib/features/trends/presentation/trends_home_screen.dart` — `_CorrelationSuggestionCard` widget with dismiss + analytics; `ctaRoute` validated against route allowlist
- `zuralog/lib/features/trends/presentation/correlations_screen.dart` — `_OverlayChartCard` (dual normalised `LineChart`); `_ChartTabSelector`; `_RegressionLinePainter` (OLS via `CustomPainter`); `_TimeRangeSelector` → `ConsumerStatefulWidget` with `mounted` guard + formatted Custom chip label; `_RangeChip.onTap` → `Future<void> Function()`; regression line positioned via `Positioned` + `ClipRect` over data area only; `_DataMaturityGate` for empty/< 2 points; `_LegendDot` dashed replaced with `_DashLinePainter`
- `zuralog/lib/features/trends/presentation/reports_screen.dart` — `_GoalAdherenceRow` widget; `Screenshot` moved to wrap `Column` inside `SingleChildScrollView` (not unbounded `ListView`); null-capture snackbar; `categoryLabel` empty-string guard
- `zuralog/lib/features/trends/presentation/data_sources_screen.dart` — `_IntegrationIcon` with `SimpleIcons` per integration ID; "Just now" for sub-minute sync timestamps

**What was implemented (Gap Closure — Phase 1–6):**

1. **Correlation suggestion cards** — `_CorrelationSuggestionCard` cards in "Track More, Learn More" section on Trends Home. Dismissible per session (local `Set<String>` state), analytics on CTA tap (`correlationSuggestionTapped`), populated from `TrendsHomeData.suggestionCards`.

2. **Overlay time-series chart** — `_OverlayChartCard` with dual `LineChartBarData` lines (Metric A solid / Metric B dashed), both normalised to 0–1 for shared Y-axis, legend with `_LegendDot`. Toggled via `_ChartTabSelector` (Scatter / Overlay tab chips).

3. **Regression trend line on scatter plot** — OLS computed client-side in `_regressionLine()` (sum of products formula). Rendered as `_RegressionLinePainter` (`CustomPainter`) inside a `Positioned` + `ClipRect` over the scatter chart data area only.

4. **Custom date range** — `CorrelationTimeRange.custom` enum value. Tapping the Custom chip opens `showDateRangePicker` with sage-green dark theme. Dates stored in `customDateStartProvider`/`customDateEndProvider`. After picking, the chip label updates to show a formatted range (e.g. "Feb 1–28"). Forwarded through `CorrelationKey` → provider → repository → API query params (`custom_start`, `custom_end` as UTC ISO strings).

5. **Share-as-image** — `ScreenshotController` wrapping the report detail `Column`. `Share.shareXFiles([xFile], text: title)` via `share_plus` v10 API. Error snackbar on null capture. `Screenshot` intentionally wraps `Column` (not `ListView`) to give `capture()` a bounded render tree.

6. **Brand integration icons** — `_IntegrationIcon` widget mapping `integrationId` → `SimpleIcons.*` SVG (Strava, Fitbit, Garmin, Apple, Google Fit) with fallback to `Icons.hub_rounded` for integrations not yet in `simple_icons` v14.6.1.

7. **Data maturity gate** — `_DataMaturityGate` widget shown when `scatterPoints.isEmpty` (scatter view) or `< 2` (overlay view). Hourglass icon, message, no crash on empty data.

8. **Goal adherence section** — `GoalAdherenceItem` model (`goalLabel`, `achievedPercent`, `streakDays`). `_GoalAdherenceRow` shows label, colour-coded percentage badge, `LinearProgressIndicator`, and streak days. Rendered in `_ReportDetailSheet` between category summaries and trend directions.

**What was fixed (Quality & Security Review):**

| ID | Severity | Fix |
|----|----------|-----|
| C-1/C-2 | Critical | `_RangeChip.onTap` → `Future<void> Function()`; `_TimeRangeSelector` → `ConsumerStatefulWidget` with `mounted` guard after `showDateRangePicker`; Custom chip shows formatted date |
| M-1 | Major | `Screenshot` wraps `Column` inside `SingleChildScrollView` — not unbounded `ListView` |
| M-2 | Major | Null capture → `ScaffoldMessenger` snackbar instead of silent `return` |
| M-3 | Major | Regression line `CustomPaint` positioned via `Positioned(left:40,bottom:24)` + `ClipRect`; painter simplified to fill its own bounds |
| M-4 | Major | `ctaRoute` validated against `const allowedRoutes = {RouteNames.settingsIntegrationsPath}` before `context.push` |
| M-5 | Major | `categoryLabel.substring(0,1)` → `isNotEmpty ? label[0] : '?'`; `fromJson` null-safe for `category`/`category_label` |
| m-3 | Minor | `_OverlayChartCard` returns `_DataMaturityGate()` when `points.length < 2` |
| m-9 | Minor | `ScatterPoint.fromJson` uses `num? ?? 0` / `String? ?? ''` casts |
| m-11 | Minor | `_lastSyncLabel()` returns `'Just now'` for `diff.inSeconds < 60` |
| I-3 | Info | `customStart`/`customEnd` forwarded through interface → repository → `correlationAnalysisProvider` |
| I-4 | Info | `_LegendDot(dashed:true)` renders real dashed line via `_DashLinePainter` `CustomPainter` |

**`flutter analyze lib/features/trends/`:** 0 issues.

---

## Phase 9 — Onboarding Rebuild (2026-03-05)

**Branch:** `feat/onboarding-rebuild`
**Status:** Complete

Replaced the old 3-field `ProfileQuestionnaireScreen` with a new 6-step paginated `OnboardingFlowScreen`. Updated `docs/screens.md` to v1.2 with all MVP feature additions from `mvp-features.md` Section 8.

**New files:**
- `zuralog/lib/features/onboarding/presentation/onboarding_flow_screen.dart` — `PageView` container with animated dot indicator, Back/Next bottom nav (hidden on step 0), completion handler writes to `/api/v1/preferences`
- `zuralog/lib/features/onboarding/presentation/steps/welcome_step.dart` — Animated logo fade/slide, brand headline, "Get Started" CTA
- `zuralog/lib/features/onboarding/presentation/steps/goals_step.dart` — 2-col multi-select grid of 8 health goals; requires ≥1 selection to advance
- `zuralog/lib/features/onboarding/presentation/steps/persona_step.dart` — 3 AI persona cards (Tough Love / Balanced / Gentle) + Proactivity slider (Low / Medium / High)
- `zuralog/lib/features/onboarding/presentation/steps/connect_apps_step.dart` — Informational grid of 6 featured integrations with "Later" badge; no OAuth during onboarding
- `zuralog/lib/features/onboarding/presentation/steps/notifications_step.dart` — Morning Briefing toggle + time picker, Smart Reminders toggle, Wellness Check-in toggle + time picker
- `zuralog/lib/features/onboarding/presentation/steps/discovery_step.dart` — "Where did you hear about us?" picker; fires `onboarding_discovery` PostHog event on selection

**Modified files:**
- `zuralog/lib/core/router/app_router.dart` — Route `profileQuestionnairePath` now imports and instantiates `OnboardingFlowScreen` instead of `ProfileQuestionnaireScreen`

**Documentation updates:**
- `docs/screens.md` → v1.2: Auth & Onboarding section replaced with 6-step flow spec; Quick Log Bottom Sheet added to Today Tab; Emergency Health Card + Edit added to Settings; all existing screen descriptions updated with MVP feature additions (Health Score hero, Data Maturity banner, Wellness Check-in, streak badges, file attachments, memory management, story-style Weekly Report, personalized AI starters, expanded Notifications settings, Appearance theme/haptics, Coach proactivity selector, Integrations sync badges, Emergency Health Card link in Profile)
- `docs/roadmap.md` → Onboarding Flow marked ✅ Complete; Emergency Health Card, Emergency Health Card Edit, and Quick Log Bottom Sheet added as 🔜 Planned

**Key decisions:**

| Decision | Rationale |
|----------|-----------|
| Keep `ProfileQuestionnaireScreen` on disk (unused) | Low risk to leave; avoids git history churn; router no longer references it so it's dead code harmlessly |
| `ConnectAppsStep` is informational only (no OAuth) | OAuth during onboarding creates drop-off; users who haven't decided which apps to connect are forced to skip anyway; Settings → Integrations is the right context for OAuth |
| `WelcomeStep` manages its own CTA (Back/Next hidden) | Step 0 has no "Back" destination and a custom "Get Started" CTA — the shared bottom nav would be redundant and visually wrong |
| `activeThumbColor` instead of deprecated `activeColor` on Switch | `activeColor` was deprecated in Flutter v3.31; `activeThumbColor` is the correct API going forward |
| PostHog event fired in `DiscoveryStep` on selection (not on complete) | The discovery question is the last step; firing on selection ensures the event is captured even if the user backgrounds the app before tapping "Finish" |

---

## Phase 10 — Engagement & Polish

**Branch:** `feat/engagement-polish`
**Status:** Complete (Tasks 10.1–10.4; Task 10.5 Apple Sign In blocked on Apple Developer subscription)

Completed the engagement and polish layer across the entire app. Coach screens were Phase 4 placeholders — fully rebuilt from scratch with production-grade implementations.

**New files:**
- `zuralog/lib/features/coach/domain/coach_models.dart` — Domain models: `Conversation`, `ChatMessage`, `MessageRole`, `PromptSuggestion`, `QuickAction`, `IntegrationContext`
- `zuralog/lib/features/coach/data/coach_repository.dart` — Abstract `CoachRepository` interface + `MockCoachRepository` with realistic seed data
- `zuralog/lib/features/coach/providers/coach_providers.dart` — Riverpod providers: conversations, messages (family), suggestions, quick actions, active conversation ID

**Modified files:**
- `new_chat_screen.dart` — Full rebuild: `OnboardingTooltip` on brand icon, animated shimmer `_CoachLoadingSkeleton` (1200ms), `_ConversationDrawer` bottom sheet, `_QuickActionsSheet` (2-col grid), `_ChatInputBar`, `_SuggestionChip` grid, haptics throughout
- `chat_thread_screen.dart` — Full rebuild: `_MessageBubble` (user sage-green / AI surface-dark), `_TypingIndicator` (3-dot animated), `_MessagesLoadingSkeleton`, `_ChatInputBar`, haptics throughout
- `progress_home_screen.dart` — Added `OnboardingTooltip` on title, replaced `_LoadingState` plain spinner with animated shimmer skeleton (goal cards + streaks shapes), haptics on refresh/nav/section headers
- `trends_home_screen.dart` — Added `OnboardingTooltip` on title, haptic on pull-to-refresh trigger, haptics on correlation cards + quick-nav buttons
- `correlations_screen.dart` — Haptics on range chips (`selectionTick`) + metric picker button (`light`)
- `reports_screen.dart` — Haptic on card tap (`light`) + refresh trigger (`light`); `_ReportCard` → `ConsumerWidget`
- `data_sources_screen.dart` — Haptic on connect/reconnect button (`medium`) + refresh trigger (`light`); `_DataSourceCard` → `ConsumerWidget`
- `quick_log_sheet.dart` — `ConsumerStatefulWidget`; haptic on submit (`success`), water buttons (`light`), symptom chips (`selectionTick`); `OnboardingTooltip` on title
- `health_dashboard_screen.dart` — `OnboardingTooltip` on AppBar title (existing haptics + skeletons preserved)

**Key decisions:**

| Decision | Rationale |
|----------|-----------|
| Coach screens rebuilt from scratch (not patched) | Phase 4 stubs were center-column text with zero functionality — patching would require rewriting anyway |
| `MockCoachRepository` rather than live API calls | Coach AI is a backend feature (Gemini); mock enables full UI testing without API keys |
| `ConsumerStatefulWidget` for `QuickLogSheet` | Sheet needed Riverpod for haptics; no clean way to thread haptic service through props |
| `_LoadingState` → animated shimmer (not `shimmer` package) | Zero additional dependency; `AnimationController` + `Color.lerp` achieves identical visual result |
| `OnboardingTooltip` on AppBar titles (not mid-screen) | Titles are the natural tap target on first encounter; tooltip fires once (SharedPreferences key) and never again |

---

## Task 11.2 — Sentry Error Boundaries & Performance Monitoring

**Branch:** `feat/sentry-boundaries`
**Status:** Complete

Added comprehensive Sentry instrumentation across the full Zuralog stack — Flutter Edge Agent and Python/FastAPI Cloud Brain.

**New files (Flutter):**
- `zuralog/lib/core/monitoring/sentry_error_boundary.dart` — `SentryErrorBoundary` StatefulWidget; wraps any child with a Sentry-reported error capture and a themed fallback UI (safe black screen with primary-color retry)
- `zuralog/lib/core/monitoring/sentry_breadcrumbs.dart` — `SentryBreadcrumbs` abstract class with static typed helpers: `apiRequest`, `aiMessageSent`, `healthSync`, `authEvent`, `userAction`, `navigation`, `aiResponseReceived`
- `zuralog/lib/core/monitoring/sentry_router_observer.dart` — `SentryRouterObserver` extending `NavigatorObserver`; emits structured `navigation` breadcrumbs on every route push/pop

**Modified files (Flutter):**
- `app_router.dart` — All GoRouter routes (25+) wrapped in `SentryErrorBoundary` with `module` tags; `SentryRouterObserver` added to observers
- `auth_providers.dart` — `authEvent` breadcrumbs for login/register/social/logout (attempt + success/failure)
- `chat_repository.dart` — `apiRequest` breadcrumbs on `connect` and `fetchHistory`; `aiMessageSent` breadcrumb on `sendMessage`
- `health_sync_service.dart` — `healthSync` breadcrumbs for `started`/`completed` (with `recordCount`)/`failed`; properly structured try/catch
- `chat_thread_screen.dart` — `Sentry.startTransaction('ai.chat_response', 'ai')` started on send with `conversation_id` tag; finished on post-frame callback (placeholder for streaming completion hook)

**Modified files (Backend):**
- `main.py` — Added `StarletteIntegration(transaction_style="endpoint")` + `CeleryIntegration()` to Sentry init integrations list
- `orchestrator.py` — Full `process_message` wrapped in `sentry_sdk.start_transaction(op="ai.process_message")`; child `ai.llm_call` span per LLM turn; child `ai.tool_call` span per tool execution with `tool.name` tag; custom fingerprints `["llm_failure", "{{ default }}"]` and `["tool_call_failure", func_name]` for AI error groups
- `llm_client.py` — `ai.error_type=llm_failure` + `ai.model` tags set before `capture_exception` in both `chat()` and `stream_chat()` except blocks
- `health_ingest.py` — `db.health_ingest` span wrapping `db.commit()` with record count in description
- `report_tasks.py` — `task.type=weekly/monthly` tag at task start; `task.report_generation` span wrapping `generator.generate_weekly/monthly()`
- `pinecone_memory_store.py` — `memory_store_failure` fingerprint + `ai.error_type=memory_store_error` + `memory.operation=save/query` tags in `save_memory` and `query_memory` except blocks

**Key decisions:**

| Decision | Rationale |
|----------|-----------|
| `SentryErrorBoundary` as a Flutter widget (not a global handler) | Per-screen isolation: one crashed screen doesn't crash the app; module tags route issues to the right team/alert |
| `start_transaction` in `_sendMessage` finishes on post-frame (not stream end) | Chat streaming is not yet wired in production; the stub is correct — replace finish call with stream completion callback when streaming lands |
| `push_scope` for tool call / memory store fingerprints | Scope is ephemeral per-exception; prevents fingerprint bleed across concurrent requests |
| `StarletteIntegration` added alongside `FastApiIntegration` | FastAPI is built on Starlette; both needed for full request lifecycle tracing including middleware spans |

---

## Phase 11.3 — PostHog Feature Flags / A/B Testing Readiness

Added a typed feature flag layer on top of the existing `AnalyticsService`, enabling PostHog-driven A/B test variants to be gated in future without code changes.

**New files (Flutter):**
- `zuralog/lib/core/analytics/feature_flag_service.dart` — `FeatureFlags` abstract class (3 flag key constants) + `FeatureFlagService` typed wrapper (`onboardingStepOrder()`, `notificationFrequencyDefault()`, `aiPersonaDefault()`) + `featureFlagServiceProvider` Riverpod provider. All methods return safe defaults on PostHog failure.

**Modified files (Flutter):**
- `onboarding_flow_screen.dart` — Converted `late final _pages` to a computed getter; `_stepOrder` field loaded async from `onboarding_step_order` flag in `initState`; analytics step index checks are now flag-aware (Goals/Persona indices swapped when `persona_first`)
- `notification_settings_screen.dart` — Converted `ConsumerWidget` → `ConsumerStatefulWidget`; `initState` loads `notification_frequency_default` flag and seeds `reminderFrequency` initial state if still at default
- `coach_settings_screen.dart` — Converted `ConsumerWidget` → `ConsumerStatefulWidget`; `initState` loads `ai_persona_default` flag and seeds `_personaProvider` if still at default
- `sentry_error_boundary.dart` — Removed unused `_handleError` / `_DefaultErrorFallback` (dead code from pre-existing `Sentry.withScope` API removal); `SentryWidget` handles automatic capture
- `sentry_router_observer.dart` — Removed invalid `const` from constructor (`NavigatorObserver` super is non-const)
- `app_router.dart` — Removed `showBackButton` parameter (no longer on `SentryErrorBoundary`)

**Key decisions:**

| Decision | Rationale |
|----------|-----------|
| Flag loaded in `initState` with safe default already set | UI renders immediately with the default; flag value is applied in the same frame once resolved, with no visible flicker |
| Guard `reminderFrequency == 2` / `_personaProvider == 'balanced'` before seeding | Prevents overwriting a value the user already changed in the same session |
| Analytics goal/persona indices computed from `_stepOrder` | Events must reflect *content* at each step, not raw page index, so PostHog funnels remain accurate under both variants |

---

## Mobile Bug Fix Sprint 1 (2026-03-05)

**Branch:** `fix/mobile-sprint-1`
**Status:** Complete — 11 commits

Bug fixes and feature completions addressing polish and usability issues surfaced after Phase 10.

### Fixes

**Android app name capitalisation** — `AndroidManifest.xml` `android:label` corrected from `zuralog` to `ZuraLog` (commit `2934720`).

**OnboardingTooltip overflow rewrite** — `onboarding_tooltip.dart` rewritten with Flutter `Overlay` instead of `Stack`-positioned absolute coordinates. The old implementation positioned tooltips relative to the widget's local coordinate space, causing overflow when the widget was near screen edges. The `Overlay` approach measures the global position of the target widget and places the tooltip layer above everything else in the widget tree, eliminating all overflow. (commit `2f8de31`)

**iOS app icons alpha channel removed** — All iOS `AppIcon.appiconset` PNGs regenerated without alpha channel. Apple App Store rejects icon submissions that contain transparency. (commit `57acaf9`)

### Features

**App launcher icons from brand logo** — Android mipmap icons and iOS AppIcon assets regenerated from `ZuraLog-Logo-Main.png` via `flutter_launcher_icons`. Replaces placeholder Flutter blue icons with the ZuraLog brand mark. `assets/images/icon_source.png` added as canonical source. (commit `cfacd03`)

**In-app brand SVG in Coach tab** — Coach New Chat screen and Chat Thread screen now render the `ZuraLog.svg` brand mark as the coach avatar / icon instead of a generic `Icons.auto_awesome` Material icon. `assets/images/ZuraLog.svg` asset registered in `pubspec.yaml`. (commit `3a87cff`)

**Mock data layer — Today, Data, Progress, Trends tabs** — Four mock repositories implemented with realistic seed data, all guarded by `kDebugMode`:

| Repository | File | Screens covered |
|-----------|------|----------------|
| `MockTodayRepository` | `mock_today_repository.dart` | Today Feed, Insight Detail, Notification History |
| `MockDataRepository` | `mock_data_repository.dart` | Health Dashboard, Category Detail, Metric Detail |
| `MockProgressRepository` | `mock_progress_repository.dart` | Progress Home, Goals, Achievements, Weekly Report, Journal |
| `MockTrendsRepository` | `mock_trends_repository.dart` | Trends Home, Correlations, Reports, Data Sources |

Each repository's provider file uses `if (kDebugMode) return MockXRepository()` — zero overhead in release builds. Abstract interfaces (`XRepositoryInterface`) extracted in each repository file as the contract. (commits `0a3c7eb`, `0ba667d`, `38d2e8e`)

**STT wired to Coach mic button** — `speech_providers.dart` updated so `SpeechNotifier` works with the rebuilt Coach screens (`new_chat_screen.dart`, `chat_thread_screen.dart`). The mic button in `_ChatInputBar` on both Coach screens now triggers hold-to-talk STT; recognized text fills the input field for user review before sending. (commit `81f0f61`)

**File attachment picker + preview in Coach chat** — Two new widgets:
- `attachment_picker_sheet.dart` — Bottom sheet with camera, photo library, and file picker options (using `image_picker` + `file_picker`)
- `attachment_preview_bar.dart` — Horizontal scrolling preview strip above the input bar; each attachment chip has a remove button

Both widgets are wired into `chat_thread_screen.dart` and `new_chat_screen.dart`. Attachment state is held locally in the screen's `StatefulWidget`. (commits `2dc677a`, `ad4b367`)

### Code Review Fixes (commit `ad4b367`)

Post-implementation code review pass:
- Removed redundant null checks in attachment state handlers
- Corrected `mounted` guard placement in async callbacks
- Consistent error handling pattern across both chat screens
- No new `print()`/`debugPrint()` statements introduced in any sprint commit

### Analyze Status

`flutter analyze` reports 23 issues (all pre-existing, none introduced by this sprint):
- 2 `warning` — `dead_code` + `dead_null_aware_expression` in `analytics_service.dart` (pre-existing)
- 2 `warning` — `experimental_member_use` in `main.dart` (Sentry experimental APIs; pre-existing)
- 19 `info` — `use_null_aware_elements` across `sentry_breadcrumbs.dart` + `progress_repository.dart` (pre-existing); `dangling_library_doc_comments` + `unintended_html_in_doc_comment` in analytics files (pre-existing)

## Settings Mapping Audit — Phases 1 & 2 (2026-03-08)

**Branch:** `feat/settings-providers` (merged to `main`)
**Status:** Complete — 3 commits

Systematic remediation of the Settings system: all user-configurable preferences are now persisted end-to-end (API + SharedPreferences offline fallback). Every settings screen reads from and writes to a single global `UserPreferencesNotifier`.

### New files

- `zuralog/lib/features/settings/domain/user_preferences_model.dart` — Immutable Dart model mirroring the backend `user_preferences` table. Includes all existing columns plus 6 new planned columns (`response_length`, `suggested_prompts_enabled`, `voice_input_enabled`, `wellness_checkin_card_visible`, `data_maturity_banner_dismissed`, `analytics_opt_out`). Enums with `fromValue` fallbacks; `fromJson`, `toJson`, `toPatchJson`, `copyWith`.
- `zuralog/lib/features/settings/providers/settings_providers.dart` — `UserPreferencesNotifier` (`AsyncNotifier`: `GET /api/v1/preferences` on build, SharedPrefs fallback, optimistic PATCH writes via `save()`/`mutate()`). 10 derived `Provider`s: `coachPersonaProvider`, `proactivityLevelProvider`, `responseLengthProvider`, `suggestedPromptsEnabledProvider`, `voiceInputEnabledProvider`, `themeModePreferenceProvider`, `wellnessCheckinCardVisibleProvider`, `dataMaturityBannerDismissedProvider`, `analyticsOptOutProvider`, `unitsSystemProvider`.

### Modified files

- `theme_provider.dart` — Converted from `StateProvider<ThemeMode>` (no persistence) to `AsyncNotifierProvider<ThemeModeNotifier, ThemeMode>`. Reads SharedPrefs on build; writes to both SharedPrefs + API via `setTheme()`. Fixed a rebuild loop where `build()` `watch`-ed `userPreferencesProvider` and `setTheme()` wrote to it — changed to `ref.read` pattern.
- `app.dart` — Updated `ref.watch(themeModeProvider)` to unwrap `AsyncValue` with `.valueOrNull ?? ThemeMode.system`.
- `appearance_settings_screen.dart` — Removed 3 broken file-private providers; wired haptic to `hapticEnabledProvider`, tooltips to `tooltipsEnabledProvider`, theme to `themeModeProvider.notifier.setTheme()`. Removed broken Dashboard Colors section (Data tab edit mode is canonical).
- `theme_selector.dart` — Updated to call `setTheme()` and unwrap `AsyncValue`.
- `catalog_screen.dart` — Dev screen theme toggle updated to use `setTheme()`.
- `coach_settings_screen.dart` — Removed 5 file-private `StateProvider`s + manual `_savePreferences()` PATCH; reads from `userPreferencesProvider.valueOrNull`, writes via `mutate()`.
- `notification_settings_screen.dart` — Seeds local `_notificationStateProvider` from `userPreferencesProvider` in `initState` via `addPostFrameCallback`; every change calls `_persist()` → `mutate()`.
- `privacy_data_screen.dart` — Removed `_PrivacyState` / `_privacyStateProvider`; reads from `wellnessCheckinCardVisibleProvider`, `dataMaturityBannerDismissedProvider`, `analyticsOptOutProvider`; writes via `prefsNotifier.mutate()`.
- `account_settings_screen.dart` — Added **Preferences** section with a `_UnitsTile` widget: compact segmented Metric/Imperial toggle reads `unitsSystemProvider`, writes via `userPreferencesProvider.notifier.mutate()`.

### Bugs fixed

| Bug | Impact |
|-----|--------|
| `themeModeProvider` was a `StateProvider` — reset to `ThemeMode.system` on every cold start | Theme preference lost on every app restart |
| All 5 Coach settings used file-private `StateProvider`s — saved to API but never loaded back | Coach persona/proactivity/etc. appeared to save but reverted on next launch |
| Appearance "Disable Tooltips" toggle wrote to a local provider, never reached `TooltipsEnabledNotifier` | Toggle had zero effect |
| Appearance "Haptic Feedback" toggle wrote to a local provider, disconnected from `hapticEnabledProvider` | Toggle had zero effect |
| `_categoryColorsProvider` in Appearance was disconnected from the Data tab's dashboard layout | Removed entirely — Data tab edit mode is the canonical color picker |
| All 17 notification preferences reset on cold start | All notification settings lost on every restart |
| All 3 privacy toggles reset on cold start | Privacy settings lost on every restart |
| `ThemeModeNotifier.build()` watch-looped through `userPreferencesProvider` | Potential infinite rebuild cycle on theme change |

### Analyze status

`dart analyze lib/features/settings/` — **No issues found.**
Project-wide baseline: 24 pre-existing warnings/infos in unrelated files (unchanged).

---

## Coach Tab — Settings Wiring (feat/coach-settings-wiring, 2026-03-08)

**Branch:** `feat/coach-settings-wiring` (commit `aa26e2c`)  
**Status:** Complete

Completed all P0, P1, and P2 items from the Settings Mapping Audit for the Coach tab. All coach preferences are now wired end-to-end: frontend reads from global `UserPreferencesNotifier`, chat screens pass preferences to backend on message send, and backend persists all 6 new preference columns.

### Files changed

**Frontend (Flutter):**
- `zuralog/lib/features/coach/presentation/new_chat_screen.dart` — `suggestedPromptsEnabled` gates prompt chip rendering; `voiceInputEnabled` gates mic button visibility; `sendMessage` calls include `persona`, `proactivity`, `responseLength` params
- `zuralog/lib/features/coach/presentation/chat_thread_screen.dart` — `voiceInputEnabled` gates mic button visibility; `sendMessage` calls include coach preferences; fixed duplicate `conversationId` bug; added `kDebugMode` guard for mock attachment URLs
- `zuralog/lib/features/coach/data/coach_repository.dart` — `sendMessage` contract extended with `persona`, `proactivity`, `responseLength` parameters
- `zuralog/lib/features/settings/domain/user_preferences_model.dart` — Added missing `onboarding_complete` field to `toPatchJson()`

**Backend (Python/FastAPI):**
- `cloud-brain/alembic/versions/l7g8h9i0j1k2_add_coach_preferences.py` — NEW migration adding 6 columns to `user_preferences` table:
  - `response_length` (VARCHAR, DEFAULT 'concise')
  - `suggested_prompts_enabled` (BOOLEAN, DEFAULT true)
  - `voice_input_enabled` (BOOLEAN, DEFAULT true)
  - `wellness_checkin_card_visible` (BOOLEAN, DEFAULT true)
  - `data_maturity_banner_dismissed` (BOOLEAN, DEFAULT false)
  - `analytics_opt_out` (BOOLEAN, DEFAULT false)
- `cloud-brain/app/schemas/preferences_schemas.py` — Pydantic models updated with 6 new fields; route validation updated
- `cloud-brain/tests/api/test_preferences.py` — 8/8 tests passing

### What was implemented

**P0 Items:**
1. **`suggestedPromptsEnabled` conditional rendering** — `new_chat_screen.dart` reads `suggestedPromptsEnabledProvider` and conditionally renders the prompt suggestion chips grid. When disabled, only the input bar and quick actions are shown.
2. **`voiceInputEnabled` conditional visibility** — Both `new_chat_screen.dart` and `chat_thread_screen.dart` read `voiceInputEnabledProvider` and conditionally show/hide the mic button in `_ChatInputBar`. When disabled, the input bar shows only the text field and send button.
3. **All 5 Coach Settings providers are GLOBAL** — `coachPersonaProvider`, `proactivityLevelProvider`, `responseLengthProvider`, `suggestedPromptsEnabledProvider`, `voiceInputEnabledProvider` are all derived from the global `userPreferencesProvider` (loaded from API on app start). No file-private providers.

**P1 Items:**
1. **`sendMessage` contract with coach preferences** — `CoachRepository.sendMessage()` interface now accepts `persona`, `proactivity`, `responseLength` parameters. Both `new_chat_screen.dart` and `chat_thread_screen.dart` read these from providers and pass them on every message send.
2. **Backend schema + validation** — 6 new columns added to `user_preferences` table via Alembic migration. Pydantic schemas updated; route validation enforces valid enum values for `persona` (tough_love/balanced/gentle), `proactivity` (low/medium/high), `response_length` (concise/detailed).
3. **Backend tests** — 8/8 tests passing for preferences CRUD and validation.

**P2 Items:**
1. **Chat message timestamps use system locale** — `chat_thread_screen.dart` now calls `TimeOfDay.format(context)` to render timestamps in the user's 12h/24h preference (system locale).

**Bonus Fixes:**
1. **Fixed duplicate `conversationId` bug** — `new_chat_screen.dart` was passing `conversationId` twice in the message payload. Removed the duplicate.
2. **Added `kDebugMode` guard for mock attachment URLs** — `chat_thread_screen.dart` now guards mock attachment URLs behind `kDebugMode` to prevent them from appearing in production builds.
3. **Added missing `onboarding_complete` field** — `user_preferences_model.dart` `toPatchJson()` was missing the `onboarding_complete` field. Added with proper null handling.

### Key decisions

| Decision | Rationale |
|----------|-----------|
| All coach providers derived from global `userPreferencesProvider` | Single source of truth; eliminates stale local state; all preferences load from API on app start and persist via `mutate()` |
| `sendMessage` params passed on every send (not cached) | Coach preferences can change mid-session; always passing current values ensures the backend receives the user's latest choice |
| 6 new columns in `user_preferences` table (not separate table) | Keeps all user preferences in one place; simplifies API contract (`GET/PATCH /api/v1/preferences`); no join complexity |
| `response_length` enum: concise/detailed (not numeric) | Semantic clarity; easier to extend with new options in future (e.g., "balanced") without numeric remapping |
| Timestamps via `TimeOfDay.format(context)` | Respects system locale setting; no hardcoded 12h/24h logic in the app |

### Test coverage

**Backend:** 8/8 tests passing in `test_preferences.py`
- Preferences CRUD (GET, PATCH)
- Enum validation (persona, proactivity, response_length)
- Default values on new user
- Null handling for optional fields

**Frontend:** No new tests added (settings wiring tested via integration with existing Coach tab tests)

### Analyze status

`flutter analyze lib/features/coach/` — **0 issues introduced.**  
`flutter analyze lib/features/settings/` — **0 issues introduced.**  
Project-wide baseline: 24 pre-existing warnings/infos (unchanged).
