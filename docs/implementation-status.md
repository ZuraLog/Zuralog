## 2026-04-27 — Supplements Log Overhaul: Plans 9–11 (AI Conflict Warnings, Timing Suggestions, Correlation Insights)

**Branch:** `feat/supplements-log-overhaul`

Plans 9 through 11 of the 11-plan supplements overhaul. Adds a full AI intelligence layer on top of the supplement stack — conflict and overlap detection, meal-timing suggestions, and a correlation insights screen that surfaces relationships between supplement consistency and health metrics.

**Plan 9 — Conflict & Overlap Warnings:**

- **`POST /api/v1/supplements/check-conflicts`** (`cloud-brain/app/api/v1/supplements_routes.py`): Two-step conflict check — exact name match runs first (no LLM call) and returns immediately when a conflict is found. If no exact match, a semantic overlap check runs via LLM. Both paths fail open so a network or LLM error never blocks the user from adding a supplement.
- **`SupplementConflict` domain model** (`zuralog/lib/features/supplements/domain/supplement_conflict.dart`): Immutable value object representing a single detected conflict with `name`, `conflictType`, and `message` fields.
- **`checkSupplementConflicts` in `TodayRepository`** (`zuralog/lib/features/today/data/today_repository.dart`): Calls the conflict-check endpoint and deserializes results into `SupplementConflict` objects.
- **`_ConflictWarningCard` in `_AddEditForm`** (`zuralog/lib/features/supplements/presentation/supplements_stack_screen.dart`): Inline warning card that appears below the supplement name field when conflicts are detected. Fires after an 800ms debounce once the user stops typing. Client-side exact match runs first to avoid unnecessary API calls. "Adjust dose" and "Add anyway" actions let the user decide how to proceed.

**Plan 10 — Timing Suggestions:**

- **`GET /api/v1/supplements/timing-tip`** (`cloud-brain/app/api/v1/supplements_routes.py`): Query parameters `supplement_name` and `timing`. Analyses the user's meal log patterns, then generates a context-aware tip via LLM. Fails open to an empty tip string so the UI degrades gracefully.
- **`TimingSuggestion` domain model** (`zuralog/lib/features/supplements/domain/timing_suggestion.dart`): Immutable value object with `tip` (string) and `confidence` (optional double) fields.
- **`getTimingSuggestion` in `TodayRepository`** (`zuralog/lib/features/today/data/today_repository.dart`): Calls the timing-tip endpoint and returns a `TimingSuggestion`.
- **`ZAlertBanner` info variant below timing grid** (`zuralog/lib/features/supplements/presentation/supplements_stack_screen.dart`): Appears below the timing option grid in `_AddEditForm` when a tip is available. A `LinearProgressIndicator` displays while the tip is loading. A dismiss button allows the user to hide the banner.

**Plan 11 — Correlation Insights Screen:**

- **`GET /api/v1/supplements/insights?days=60`** (`cloud-brain/app/api/v1/supplements_routes.py`): Computes Pearson r between supplement consistency (days taken / days in window) and each DailySummary health metric (mood, energy, sleep quality, HRV, etc.). An LLM generates a plain-language insight text for each correlation. Rate-limited at 10 requests per minute per user.
- **`SupplementInsightItem` + `SupplementInsightsResult` domain models** (`zuralog/lib/features/supplements/domain/supplement_insight.dart`): `SupplementInsightItem` holds `supplementName`, `metric`, `correlationScore`, and `insightText`. `SupplementInsightsResult` is the top-level container with a list of items and a `generatedAt` timestamp.
- **`getSupplementInsights` in `TodayRepository`** (`zuralog/lib/features/today/data/today_repository.dart`): Calls the insights endpoint and deserializes into `SupplementInsightsResult`.
- **`SupplementInsightsScreen`** (`zuralog/lib/features/supplements/presentation/supplement_insights_screen.dart`): Full screen with loading state (skeleton cards), empty state (no data yet message), and data state (scrollable list of `_InsightCard` widgets). Powered by `insightsProvider` — a `FutureProvider.autoDispose` that calls `getSupplementInsights`.
- **`_InsightCard` widget** (`supplement_insights_screen.dart`): One card per correlation insight. Shows supplement name, the correlated metric, the Pearson r score visualised as a bar, and the LLM-generated insight text.
- **Routing** (`zuralog/lib/core/router/route_names.dart`, `zuralog/lib/core/router/app_router.dart`): `RouteNames.supplementInsightsPath = '/supplements/insights'` registered in GoRouter.
- **Entry point** (`zuralog/lib/features/supplements/presentation/supplements_stack_screen.dart`): `Icons.settings_outlined` gear icon added to `_PanelHeader` in `ZSupplementsLogPanel`. Tapping it calls `context.push` to navigate to `SupplementInsightsScreen`.

**Files created:**
- `zuralog/lib/features/supplements/domain/supplement_conflict.dart`
- `zuralog/lib/features/supplements/domain/timing_suggestion.dart`
- `zuralog/lib/features/supplements/domain/supplement_insight.dart`
- `zuralog/lib/features/supplements/presentation/supplement_insights_screen.dart`

**Files modified:**
- `cloud-brain/app/api/v1/supplements_routes.py` (conflict-check, timing-tip, and insights endpoints)
- `zuralog/lib/features/today/data/today_repository.dart` (`checkSupplementConflicts`, `getTimingSuggestion`, `getSupplementInsights`)
- `zuralog/lib/features/supplements/presentation/supplements_stack_screen.dart` (`_ConflictWarningCard`, `ZAlertBanner` timing tip, gear icon entry point)
- `zuralog/lib/core/router/route_names.dart` (`supplementInsightsPath`)
- `zuralog/lib/core/router/app_router.dart` (insights screen route)

---

## 2026-04-27 — Supplements Log Overhaul: Plans 4–8 (Daily Check-in, Panel Interactions, Stack Management, One-off Logging, Scan Label)

**Branch:** `feat/supplements-log-overhaul`

Plans 4 through 8 of the 11-plan supplements overhaul. Covers the full daily check-in panel, all panel interactions, the stack management screen, ad-hoc supplement logging, and the scan-label integration endpoint.

**Plan 4 — Daily Check-in Panel:**

- **`ZSupplementsLogPanel`** (`zuralog/lib/features/today/presentation/widgets/supplements_log_panel.dart`): Inline check-in panel on the Today screen. Renders the user's supplement stack as a tappable checklist. Write-first offline sync — marking a supplement taken writes to the local database immediately and syncs to the cloud in the background.
- **`SupplementSyncStatus` cloud icon** (`supplements_log_panel.dart`): A small cloud icon in the panel header reflects the current sync state (idle, syncing, error). Users can see at a glance whether their check-ins have reached the server.

**Plan 5 — Panel Interactions:**

- **4-second undo toast** (`supplements_log_panel.dart`): Marking a supplement taken shows an undo toast for 4 seconds before the action is committed. Prevents accidental double-taps from being permanent.
- **`ZToast.displayDuration` parameter** (`zuralog/lib/shared/widgets/feedback/z_toast.dart`): The shared toast widget now accepts a configurable `displayDuration` parameter so callers can control how long a toast stays visible. Added to the `widgets.dart` barrel export.
- **Uncheck confirmation dialog** (`supplements_log_panel.dart`): Unchecking a supplement that was already logged asks the user to confirm before deleting the log entry. Prevents accidental data loss.

**Plan 6 — Stack Management Screen:**

- **`SupplementsStackScreen`** (`zuralog/lib/features/supplements/presentation/supplements_stack_screen.dart`): Full stack management screen reachable from the Today panel. Supports reordering (drag handle), swipe-to-delete with undo, and an add/edit form.
- **Add/edit form with option grids** (`supplements_stack_screen.dart`): The add and edit form uses option grid chips for timing (Morning, Afternoon, Evening, Bedtime) and form factor (Pill, Capsule, Powder, Liquid, Gummy, Other). Free-text fields for name, dose amount, and dose unit.

**Plan 7 — One-off Daily Log:**

- **Ad-hoc supplement logging** (`supplements_log_panel.dart`): A "Log something else" affordance in the panel lets users log a supplement that is not in their stack. The logged entry is flagged as ad-hoc so it does not pollute the stack.
- **`SupplementTakenLog` ad-hoc fields** (database): The `supplement_taken_logs` table gained `is_ad_hoc` (boolean) and `ad_hoc_name` (text) columns to support one-off entries without a corresponding stack item.
- **`isAdHoc` sync branching** (`zuralog/lib/features/supplements/data/supplements_repository.dart`): The sync path branches on `isAdHoc` — ad-hoc entries go through a separate upsert path that does not touch the user's supplement stack.

**Plan 8 — Scan Label Integration:**

- **`POST /api/v1/supplements/scan-label`** (`cloud-brain/app/api/v1/supplements_routes.py`): Accepts either an image (base64, max 4 MB) or a barcode string. Barcode path returns product data from a public nutrition database. Image path is an AI-ready hook stubbed for future LLM wiring. SSRF guard rejects non-HTTPS and private-range URLs. Both paths return `SupplementScanResult`.
- **`SupplementScanResult`** (`cloud-brain/app/api/v1/supplements_routes.py`): Pydantic response model with `name`, `brand`, `dose`, `dose_unit`, `form`, `ingredients`, and `imageUrl` fields (all optional). Lets the caller pre-fill the add form without mapping differences.
- **Scan button in stack form** (`supplements_stack_screen.dart`): A camera icon in the add form header opens the device camera (or photo picker). The captured image is sent to the scan-label endpoint; on success the form fields are pre-filled automatically.
- **Scanner disposal** (`supplements_stack_screen.dart`): Camera resources are released in `dispose()` so the device camera is never left open after the screen closes.
- **3 backend tests** (`cloud-brain/tests/api/v1/test_scan_label.py`): Cover barcode happy path (fields returned), missing-input validation (400 when neither image nor barcode provided), and auth enforcement (401 without token). All pass.

**Files created:**
- `zuralog/lib/features/today/presentation/widgets/supplements_log_panel.dart`
- `zuralog/lib/features/supplements/presentation/supplements_stack_screen.dart`
- `zuralog/lib/shared/widgets/feedback/z_toast.dart` (if not pre-existing)
- `cloud-brain/tests/api/v1/test_scan_label.py`

**Files modified:**
- `cloud-brain/app/api/v1/supplements_routes.py` (scan-label endpoint, `SupplementScanResult`, SSRF guard, image size cap)
- `zuralog/lib/features/supplements/data/supplements_repository.dart` (ad-hoc sync branching)
- `zuralog/lib/shared/widgets/widgets.dart` (barrel export for `ZToast`)

---

## 2026-04-27 — Wellness Log Overhaul: AI Voice/Text Check-In, 6-State Panel, Sentiment Selector

**Branch:** `feat/wellness-log-overhaul`

Complete replacement of the old slider-based wellness panel with an AI-first voice and text check-in system.

**What was built:**

- **`ZWellnessLogPanel` rewritten** (`zuralog/lib/features/today/presentation/widgets/wellness_log_panel.dart`): Six-state machine replacing the previous slider row. Two entry paths: an AI path (voice or typed transcript → AI parse → confirm/edit → save) and a quick check-in path (face-tap sentiment selectors, works fully offline). Optional "Talk to Zura" handoff to the Coach after saving.

- **AI path — recording state** (`wellness_log_panel.dart`): Microphone button starts recording. While recording, `ZAudioVisualizer` displays animated waveform bars. User can also type a free-form transcript directly.

- **AI path — parse + confirm state** (`wellness_log_panel.dart`): On transcript submission, the panel calls `parseWellnessTranscript` on `TodayRepository`, which hits the new backend endpoint. The returned `{mood, energy, stress, tags, summary}` values are pre-filled into an editable confirm screen before saving.

- **Quick check-in path** (`wellness_log_panel.dart`): Five `ZSentimentSelector` rows (one per metric level) for mood, energy, and stress. Fully offline — no AI or network required. Selection saves immediately.

- **Optional transcript storage** (`wellness_log_panel.dart`): A user-controlled toggle (default off) controls whether the raw transcript is stored. Off by default to protect privacy.

- **`ZSentimentSelector` — new shared widget** (`zuralog/lib/shared/widgets/inputs/z_sentiment_selector.dart`): Reusable five-level face icon row with selection state. Added to the `widgets.dart` barrel export.

- **`ZAudioVisualizer` — new shared widget** (`zuralog/lib/shared/widgets/feedback/z_audio_visualizer.dart`): Animated waveform bar widget that reflects live recording state. Added to the `widgets.dart` barrel export.

- **`logWellness` extended** (`zuralog/lib/features/today/data/today_repository.dart`): Now accepts `tags` (list of strings) and `aiSummary` (optional string) parameters. Also fixed a unit bug — `stress` was being sent as `/100` when the scale is `/10`.

- **`parseWellnessTranscript` added** (`zuralog/lib/features/today/data/today_repository.dart`): Calls `POST /api/v1/wellness/parse`, returns a `WellnessParseResult` domain model.

- **`WellnessParseResult` domain model** (`zuralog/lib/features/today/domain/wellness_parse_result.dart`): Immutable value object with `mood`, `energy`, `stress`, `tags`, and `summary` fields.

- **Backend: `POST /api/v1/wellness/parse`** (`cloud-brain/app/api/v1/wellness.py`): Accepts a free-form transcript (max 5,000 characters), calls an LLM to extract structured wellness data, returns `{mood, energy, stress, tags, summary}`. Rate-limited to 20 requests per minute per user. Requires authentication.

- **11 backend tests** (`cloud-brain/tests/api/v1/test_wellness.py`): Cover the happy path, input validation (empty transcript, over-limit length), auth enforcement, LLM failure handling, and boundary conditions on all numeric fields.

**Files created:**
- `zuralog/lib/shared/widgets/inputs/z_sentiment_selector.dart`
- `zuralog/lib/shared/widgets/feedback/z_audio_visualizer.dart`
- `zuralog/lib/features/today/domain/wellness_parse_result.dart`
- `cloud-brain/app/api/v1/wellness.py`
- `cloud-brain/tests/api/v1/test_wellness.py`

**Files modified:**
- `zuralog/lib/features/today/presentation/widgets/wellness_log_panel.dart`
- `zuralog/lib/features/today/data/today_repository.dart`
- `zuralog/lib/shared/widgets/widgets.dart`

---

## 2026-04-26 — Weight Log Overhaul: Large Number Input, Time-of-Day Chips, 7-Day Sparkline

**Branch:** `feat/weight-log-overhaul`

Completely redesigned the weight logging panel with a premium numeric input experience, metadata tracking, and data visualization.

**What was built:**

- **Large number display** (`weight_panel.dart`): The weight value now displays in a prominent 58px sans-serif number. Full-height left and right tap zones (`‹` `›`) allow stepping the value by 0.1 kg/lbs on each tap. Long-pressing either chevron triggers continuous fast-scroll for rapid adjustments, with haptic feedback on each step.

- **Tap-to-edit keyboard entry** (`weight_panel.dart`): Tapping the large number opens a `TextField` for direct numeric input from the device keyboard. The field is pre-filled with the current value and accepts decimal input. Saves on confirm/blur.

- **Last-logged delta strip** (`weight_panel.dart`): A 2-line row appears directly below the number showing the previous logged weight and a live delta pill (e.g., "+0.3 kg", "-1.2 lbs"). Uses color coding to indicate upward/downward trends.

- **Time-of-day metadata chips** (`weight_panel.dart`): Three toggle chips (Morning, Afternoon, Evening) are auto-selected based on the current hour and saved as `time_of_day` metadata with each log. Helps users track which time of day they usually weigh themselves. Only one chip can be active at a time.

- **Collapsible body fat % row** (`weight_panel.dart`): An optional expandable row below the time-of-day chips allows logging body fat percentage (0.1% steps, 1–80% range). The field is collapsed by default, with a tap-to-expand interaction. Saved as `body_fat_pct` metadata.

- **7-day sparkline visualization** (`weight_panel.dart`): A lightweight line chart using `ZMiniSparkline` component appears above the Save button, showing the last 7 days of logged weight values. Provides instant visual context of recent trends without requiring a separate detail screen.

- **Fixed pre-fill bug** (`weight_panel.dart`): The previous weight values were being read from the wrong map keys. Updated `getLatestLogValues` to use the correct Supabase column names so pre-fill works reliably on every fresh load.

- **Backend support** (`cloud-brain/app/api/v1/metrics.py`): New `GET /api/v1/metrics/weight/history?days=7` endpoint returns the last N days of weight logs as `[{timestamp, value, unit, time_of_day, body_fat_pct}, ...]` to feed the sparkline UI.

- **logWeight function extended** (`weight_panel.dart`, repository, API): The `logWeight` call now sends an optional `metadata` object containing `time_of_day` (string: "morning", "afternoon", "evening") and `body_fat_pct` (number, optional). The backend stores these as structured JSON in the metadata column of the metrics table.

**Files created:**
- None (all changes to existing weight panel files)

**Files modified:**
- `zuralog/lib/features/progress/presentation/widgets/weight_panel.dart`
- `zuralog/lib/features/progress/data/progress_repository.dart`
- `zuralog/lib/features/progress/providers/progress_providers.dart`
- `cloud-brain/app/api/v1/metrics.py`
- `zuralog/test/features/progress/presentation/weight_panel_test.dart`
- `zuralog/test/features/progress/providers/progress_providers_test.dart`

---

## 2026-04-23 — Exercise Catalogue Expansion: 839 Exercises, Equipment Filter, Image Assets

**Branch:** `feat/exercise-catalogue-expansion`

Expanded the exercise catalogue from 50 bundled exercises to 839, added secondary muscle targeting, equipment filtering, and image asset support for exercise icons.

**What was built:**

- **`exercises.json` expanded** (`assets/data/exercises.json`): 839 exercises across all muscle groups and equipment types, sourced from authoritative fitness databases. Each exercise now includes a `secondaryMuscles` array in addition to the primary `muscleGroup`.

- **`Exercise` model extended** (`zuralog/lib/features/workout/domain/exercise.dart`): Added `secondaryMuscles` field (list of `MuscleGroup` enums) to capture exercises that work multiple muscle groups. Domain model remains immutable with full JSON round-trip support.

- **Equipment filter added** (`zuralog/lib/features/workout/presentation/exercise_catalogue_screen.dart`): Horizontal scrollable chip row of equipment types (Barbell, Dumbbell, Kettlebell, Machine, Bodyweight, Bands) plus "All". Chips filter the exercise grid in real time. Chips use `AppColorsOf(context).primary` for active state.

- **Equipment filter provider** (`zuralog/lib/features/workout/providers/exercise_providers.dart`): New `exerciseEquipmentFilterProvider` (state) works alongside existing `exerciseMuscleGroupFilterProvider` and `exerciseSearchQueryProvider` for combined filtering across all three dimensions (muscle group + equipment + search).

- **Equipment repository support** (`zuralog/lib/features/workout/data/exercise_repository.dart`): `filter()` method now accepts an optional `Equipment` parameter and combines it with existing muscle-group and search filters.

- **Image asset pipeline** (`assets/images/exercises/`): Directory structure created with PNG icons for each exercise. `Exercise` model supports optional `imageAsset` field pointing to `assets/images/exercises/{exerciseId}.png`. UI renders real images where available, falls back to muscle-group icon when missing.

- **Image rendering** (`zuralog/lib/features/workout/presentation/widgets/exercise_grid_tile.dart`): `ExerciseGridTile` updated to display exercise images via `Image.asset()` with `fit: BoxFit.cover`. Fallback to muscle-group icon (`MuscleGroup.icon`) when image asset is not found (via `onError` callback).

**Files created:**
- `zuralog/lib/features/workout/providers/exercise_filter_provider.dart` (equipment filter logic)

**Files modified:**
- `assets/data/exercises.json` (expanded from 50 to 839 exercises, added `secondaryMuscles` field)
- `zuralog/lib/features/workout/domain/exercise.dart` (added `secondaryMuscles` field)
- `zuralog/lib/features/workout/presentation/exercise_catalogue_screen.dart` (equipment chip filter UI)
- `zuralog/lib/features/workout/providers/exercise_providers.dart` (equipment filter state)
- `zuralog/lib/features/workout/data/exercise_repository.dart` (equipment filtering logic)
- `zuralog/lib/features/workout/presentation/widgets/exercise_grid_tile.dart` (image asset rendering + fallback)
- `pubspec.yaml` (asset path registration for `assets/images/exercises/`)

---

## 2026-04-22 — Workout Polish: Pill Spacing, Collapsible Cards, and Android Notifications

**Branch:** `main` (merged from feat/progress-tab-redesign)

Five focused improvements to the active workout experience.

**What was built:**

- **Global workout pill spacing** (`active_workout_global_pill.dart`): Added 8px vertical padding above and below the floating pill so it no longer feels cramped against the navigation bar.

- **Collapsible exercise cards** (`workout_exercise_card.dart`, `workout_session_screen.dart`): Exercise cards now follow a Lyfta-style expand/collapse pattern — only one card is open at a time. A collapsed card shows the muscle icon, exercise name, and a "X/Y sets" badge (swaps to a green checkmark when all sets are done). Tapping expands it. When the last set on a card is checked off, that card auto-collapses and the next one auto-expands.

- **Foreground service notification shows set count** (`workout_notifications.dart`): The persistent Android notification now includes the set count in its text line. During a workout it reads "Workout 12:34  ·  6 sets"; during rest it reads "Rest  01:30  ·  6 sets".

- **Immediate rest-end notification** (`active_workout_provider.dart`): When the rest timer hits zero, the app fires an immediate notification instead of relying on a scheduled future notification. This bypasses Android's Doze mode, which was delaying the alert on some devices. The iOS scheduled notification (used as a background fallback) is unchanged.

- **Notification permission requested before foreground service starts** (`workout_service_controller.dart`, `workout_task_handler.dart`): `requestNotificationPermission()` is now called before the foreground service is started. This fixes a silent failure on Android 13+ where the persistent workout notification would not appear because the POST_NOTIFICATIONS permission had not been granted yet.

**Files modified:**
- `zuralog/lib/features/workout/presentation/widgets/active_workout_global_pill.dart`
- `zuralog/lib/features/workout/presentation/widgets/workout_exercise_card.dart`
- `zuralog/lib/features/workout/presentation/workout_session_screen.dart`
- `zuralog/lib/features/workout/background/workout_notifications.dart`
- `zuralog/lib/features/workout/providers/active_workout_provider.dart`
- `zuralog/lib/features/workout/background/workout_service_controller.dart`
- `zuralog/lib/features/workout/background/workout_task_handler.dart`

---

## 2026-04-22 — Workout Rest Timer Redesign

**Branch:** `fix/rest-timer-redesign`

Completely redesigned the workout rest timer from the ground up with Riverpod state management and a polished bottom sheet + mini banner UI.

**What was built:**

- **`rest_timer_provider.dart`** — Riverpod `StateNotifier<RestTimerState>` managing all timer logic (countdown, expiry, pause/resume, skip). Persists timer state to SharedPreferences so it survives app backgrounding and navigation. Auto-dismisses 3 seconds after expiry.

- **Full sheet overlay** (`WorkoutSessionScreen` Stack) — slides in from bottom showing mm:ss countdown, progress bar, +30s button, Skip, and Minimize actions. Urgency color (red) kicks in at ≤10s. "Time to work!" message on expiry. Drag-to-minimize gesture support.

- **Mini banner** — compact pill-shaped widget shown between exercise list and bottom actions when timer is minimized. Displays countdown, alerts user when rest is over. Tap to expand back to full sheet.

- **Rendered as Stack overlays** — never uses `showBottomSheet` or `showModalBottomSheet`, avoiding Scaffold context issues and enabling survival across navigation.

- **Auto-skip on discard/finish** — timer is cleared when the user discards or finishes the workout session.

- 2 new tests; all workout tests pass; zero new analyzer issues.

---

## 2026-04-21 — Workout Plan 4: Overview Screen + Input Focus Fix

**Branch:** `feat/workout-overview-screen`

Workout tile now lands on a proper overview screen instead of jumping straight into a session. Also fixed a visual bug where input fields flashed orange on focus in light mode.

**What was built:**

- **`WorkoutOverviewScreen`** (`zuralog/lib/features/workout/presentation/workout_overview_screen.dart`): ConsumerWidget following the same Sleep/Heart pattern. `CustomScrollView` + pinned `SliverAppBar` + `ZStaggeredList`. Sections: hero card (last workout with duration/volume/sets, skeleton while loading, empty state), Start Workout button, AI Summary placeholder with `ZProBadge`, weekly snapshot (last 7 days), View All History link.

- **Route restructure**: `/log/workout` (`workoutLogPath`) now resolves to `WorkoutOverviewScreen`. New `/log/workout/session` (`workoutSessionPath`) resolves to `WorkoutSessionScreen`. All existing navigation updated.

- **Input focus color fix**: `ZLabeledTextField`, `ZLabeledNumberField`, `goal_create_edit_sheet.dart`, and `emergency_card_edit_screen.dart` were using static `AppColors.categoryNutrition` (orange) or `AppColors.primary` (dark-mode-only Sage) for focused border and cursor colors. All replaced with `colors.primary` (theme-aware instance from `AppColorsOf(context)`).

**Tests:** 3 new widget tests for `WorkoutOverviewScreen`; 82 workout tests total, all green; zero new analyzer issues.

**Files created:**
- `zuralog/lib/features/workout/presentation/workout_overview_screen.dart`
- `zuralog/test/features/workout/presentation/workout_overview_screen_test.dart`

**Files modified:**
- `zuralog/lib/core/router/route_names.dart`
- `zuralog/lib/core/router/app_router.dart`
- `zuralog/lib/shared/widgets/inputs/z_labeled_text_field.dart`
- `zuralog/lib/shared/widgets/inputs/z_labeled_number_field.dart`
- `zuralog/lib/features/progress/presentation/goal_create_edit_sheet.dart`
- `zuralog/lib/features/profile/presentation/emergency_card_edit_screen.dart`

---

## 2026-04-21 — Workout Plan 3: Summary + History

**Branch:** `feat/workout-plan-1-foundation`

Completed the workout loop — finished sessions persist to local history, a real summary screen shows results, and a history screen lets users revisit past workouts.

**What was built:**

- **`CompletedWorkout` + `CompletedExercise`** (`zuralog/lib/features/workout/domain/completed_workout.dart`): Immutable value objects with full JSON round-trip and structural equality via `listEquals`. `CompletedWorkout.fromSession` normalizes mixed-unit session weights into kilograms using each exercise's `unitOverride` (falling back to the global units setting).

- **`WorkoutHistoryRepository`** (`zuralog/lib/features/workout/data/workout_history_repository.dart`): Offline-first persistence under SharedPreferences key `workout_history`. `loadAll` returns most-recent-first; `saveWorkout` appends and caps at 100 entries. Tolerates corrupt JSON and malformed entries by returning an empty list / filtering.

- **`finishSession` on `WorkoutSessionNotifier`** (`zuralog/lib/features/workout/providers/workout_session_providers.dart`): Awaits `saveWorkout`, then calls the existing `discardSession()` to clear the draft. Also exposes new `workoutHistoryRepositoryProvider` (Provider) and `workoutHistoryProvider` (FutureProvider.autoDispose).

- **`WorkoutSummaryScreen`** (`zuralog/lib/features/workout/presentation/workout_summary_screen.dart`): Replaced Plan 1 stub. Accepts a `CompletedWorkout?` from GoRouter extra — renders a friendly error state when null. Shows header (Activity-accent check icon + "Workout Complete" + localized date), totals row (Duration in Activity accent, Volume, Sets), per-exercise `ZuralogCard` blocks with muscle-group-tinted icon bubble and a read-only set table. Done button pops back to the log grid sheet.

- **`WorkoutHistoryScreen`** (`zuralog/lib/features/workout/presentation/workout_history_screen.dart`): Scrollable list of past workouts with tap-through to the summary screen. Empty state when no history. Error state with retry when load fails.

- **Routing**: `/log/workout/history` added. Summary route now reads `state.extra` as `CompletedWorkout?`. Session screen's app bar gets a history icon. `pushReplacement` used for finish flow so the session screen is gone from the stack when the summary appears.

**Tests:** 17 new tests (4 domain + 5 repository + 4 provider + 2 summary widget + 2 history widget); 78 workout tests total, all green; zero new analyzer issues in workout feature.

**Files created:**
- `zuralog/lib/features/workout/domain/completed_workout.dart`
- `zuralog/lib/features/workout/data/workout_history_repository.dart`
- `zuralog/lib/features/workout/presentation/workout_history_screen.dart`
- `zuralog/test/features/workout/domain/completed_workout_test.dart`
- `zuralog/test/features/workout/data/workout_history_repository_test.dart`
- `zuralog/test/features/workout/providers/workout_history_provider_test.dart`
- `zuralog/test/features/workout/presentation/workout_summary_screen_test.dart`
- `zuralog/test/features/workout/presentation/workout_history_screen_test.dart`

**Files modified:**
- `zuralog/lib/features/workout/providers/workout_session_providers.dart`
- `zuralog/lib/features/workout/presentation/workout_session_screen.dart`
- `zuralog/lib/features/workout/presentation/workout_summary_screen.dart` (stub replaced)
- `zuralog/lib/core/router/route_names.dart`
- `zuralog/lib/core/router/app_router.dart`
- `zuralog/test/features/workout/providers/workout_session_providers_test.dart`

---

## 2026-04-21 — Workout Plan 2: Active Session Tracking

**Branch:** `feat/workout-plan-1-foundation`

Full live workout session — offline-first, crash-safe, unit-aware.

**What was built:**

- **Domain models** (`zuralog/lib/features/workout/domain/workout_session.dart`): `SetType` enum (Warm-Up, Working, Drop Set, Failure, AMRAP), `WorkoutSet`, `WorkoutExercise`, `WorkoutSession`. Immutable value objects with `copyWith` (`_kUnset` sentinel pattern for nullable fields), full JSON round-trip, structural equality via `listEquals`. Top-level helpers: `effectiveUnitSystem`, `unitLabel`, `kgToLbs`, `lbsToKg`.

- **`WorkoutSessionNotifier`** (`zuralog/lib/features/workout/providers/workout_session_providers.dart`): `StateNotifier<WorkoutSession?>`, non-autoDispose (survives catalogue push). Auto-saves draft to SharedPreferences under `workout_active_draft` after every mutation. `startSession()` restores an existing draft or creates a new one. `toggleUnit()` converts all set weights and persists per-exercise unit override under `workout_exercise_unit_{exerciseId}`. `discardSession()` clears both the draft and all per-exercise unit keys. `ref.listen` on `unitsSystemProvider` keeps the global unit default current. Three derived providers: `workoutDurationProvider` (1 Hz `StreamProvider<Duration>`), `workoutVolumeProvider` (`Provider<double>`, completed sets only), `workoutSetsCompletedProvider` (`Provider<int>`).

- **`WorkoutStatsRow`** (`zuralog/lib/features/workout/presentation/widgets/workout_stats_row.dart`): Three-column live strip — Duration (h:mm:ss, Activity accent), Volume, Sets. Watches its own providers so the parent screen doesn't rebuild on every tick.

- **`WorkoutExerciseCard`** (`zuralog/lib/features/workout/presentation/widgets/workout_exercise_card.dart`): Per-exercise card with muscle-group color-coded icon bubble, inline notes `TextField` (auto-saved on change), rest timer row with `ZToggle`, set table (`_SetTableHeader` with tappable unit header + `_SetRow` per set), and "Add Set" `TextButton`. Set type picker and exercise action menu via `ZBottomSheet`. All mutations delegate to `workoutSessionProvider.notifier`.

- **`WorkoutSessionScreen`** (`zuralog/lib/features/workout/presentation/workout_session_screen.dart`): Replaced Plan 1 stub. `startSession()` called via `addPostFrameCallback`. AppBar: down-arrow (discard), timer icon centered, "Finish" TextButton. Body: `WorkoutStatsRow` → divider → exercise list or `_EmptyState` → `_BottomActions`. Finish guard: zero-sets confirmation dialog. Discard: `ZAlertDialog` with `isDestructive: true`, then `discardSession()` + `context.pop()`.

**Tests:** 35 new tests — 14 domain (workout_session_test.dart), 17 provider (workout_session_providers_test.dart), 4 widget (workout_session_screen_test.dart). 61 workout tests total, all green. Zero new analyzer issues.

**Files created:**
- `zuralog/lib/features/workout/domain/workout_session.dart`
- `zuralog/lib/features/workout/providers/workout_session_providers.dart`
- `zuralog/lib/features/workout/presentation/widgets/workout_stats_row.dart`
- `zuralog/lib/features/workout/presentation/widgets/workout_exercise_card.dart`
- `zuralog/test/features/workout/domain/workout_session_test.dart`
- `zuralog/test/features/workout/providers/workout_session_providers_test.dart`
- `zuralog/test/features/workout/presentation/workout_session_screen_test.dart`

**Files modified:**
- `zuralog/lib/features/workout/presentation/workout_session_screen.dart` (stub replaced)

---

## 2026-04-21 — Workout Plan 1: Foundation + Exercise Catalogue

**Branch:** `feat/workout-plan-1-foundation`

Laid the full foundation for the Workout feature. No backend dependency — everything runs offline from a bundled asset.

**What was built:**

- **`exercises.json`** (`assets/data/exercises.json`): 50 bundled exercises across all major muscle groups and equipment types. Loaded at runtime — no API call required.

- **Domain models** (`zuralog/lib/features/workout/domain/exercise.dart`): `Exercise`, `MuscleGroup` (11 groups including cardio and full_body), and `Equipment` (6 types). Pure value objects with `fromJson` factory.

- **`ExerciseRepository`** (`zuralog/lib/features/workout/data/exercise_repository.dart`): Loads from `rootBundle`, caches the parsed list in memory on first call, and exposes a `filter(muscleGroup, query)` method for combined search.

- **Riverpod providers** (`zuralog/lib/features/workout/providers/exercise_providers.dart`): `exerciseListProvider` (async, autoDispose), `exerciseSearchQueryProvider` (state), `exerciseMuscleGroupFilterProvider` (state), `exerciseSearchProvider` (derived, async). All propagate errors correctly.

- **`ExerciseCatalogueScreen`** (`zuralog/lib/features/workout/presentation/exercise_catalogue_screen.dart`): Search bar, horizontal muscle-group chip filter (plus "All"), multi-select exercise grid. Selection count badge on the sticky footer CTA. Empty state for no results.

- **`ExerciseGridTile`** (`zuralog/lib/features/workout/presentation/widgets/exercise_grid_tile.dart`): Shared widget with muscle-group color coding via `MuscleGroup.color` extension, selection overlay with checkmark, and press-scale animation.

- **Stub screens**: `WorkoutSessionScreen` and `WorkoutSummaryScreen` — placeholder routes for Plan 2.

- **Routes** (`route_names.dart`, `app_router.dart`): `/log/workout`, `/log/workout/exercises`, `/log/workout/summary`.

- **`ZLogGridSheet` wired**: Workout tile changed from `comingSoon` to `fullScreen` behaviour, navigating to `/log/workout` instead of showing a snackbar.

**Tests:** 26 new tests across domain, repository, and providers. Zero new analyzer issues vs main. The outdated "coming soon" snackbar test updated to verify the navigation callback.

**Files created:**
- `assets/data/exercises.json`
- `zuralog/lib/features/workout/domain/exercise.dart`
- `zuralog/lib/features/workout/data/exercise_repository.dart`
- `zuralog/lib/features/workout/providers/exercise_providers.dart`
- `zuralog/lib/features/workout/presentation/exercise_catalogue_screen.dart`
- `zuralog/lib/features/workout/presentation/workout_session_screen.dart`
- `zuralog/lib/features/workout/presentation/workout_summary_screen.dart`
- `zuralog/lib/features/workout/presentation/widgets/exercise_grid_tile.dart`
- `test/features/workout/domain/exercise_test.dart`
- `test/features/workout/data/exercise_repository_test.dart`
- `test/features/workout/providers/exercise_providers_test.dart`

**Files modified:**
- `zuralog/lib/core/router/route_names.dart`
- `zuralog/lib/core/router/app_router.dart`
- `zuralog/lib/shared/widgets/sheets/z_log_grid_sheet.dart`
- `pubspec.yaml`
- `test/shared/widgets/sheets/z_log_grid_sheet_test.dart`

---

## 2026-04-21 — Heart Section: Flutter Frontend

**Branch:** `feat/heart-flutter` (off `feat/heart-backend`)

Complete Flutter frontend for the Heart section, mirroring the Sleep section architecture.

**Domain + Data Layer:**

- **`HeartSource`, `HeartDaySummary`, `HeartTrendDay`** (`zuralog/lib/features/heart/domain/heart_models.dart`): Domain models for all heart metrics — resting HR, HRV, average HR, respiratory rate, VO2 max, SpO2, and blood pressure (systolic + diastolic). `HeartDaySummary` carries AI summary text, 7-day comparison deltas, and a list of data sources.

- **`HeartRepositoryInterface`, `ApiHeartRepository`, `MockHeartRepository`** (`zuralog/lib/features/heart/data/`): Repository layer. API repository calls `/api/v1/heart/summary`, `/api/v1/heart/trend`, and `/api/v1/heart/all-data`. Mock repository returns realistic hardwired data for development builds.

- **`heartRepositoryProvider`, `heartDaySummaryProvider`, `heartTrendProvider`** (`zuralog/lib/features/heart/providers/heart_providers.dart`): Riverpod providers. `heartDaySummaryProvider` and `heartTrendProvider` fail gracefully to empty state on any error.

**Shared Component Extensions:**

- **`AllDataMetricTab`** (`zuralog/lib/shared/all_data/all_data_models.dart`): Extended with two optional fields — `secondaryValueExtractor` and `secondaryLabel` — to support dual-line charts without breaking existing Sleep or Nutrition all-data screens.

- **`AllDataScreen`** (`zuralog/lib/shared/all_data/all_data_screen.dart`): Extended with a dual-line rendering branch. When a tab has `secondaryValueExtractor` set, two stacked `LineRenderer` charts (180px each) are rendered instead of a single chart. Used by the Blood Pressure tab.

**Screens:**

- **`HeartDetailScreen`** (`zuralog/lib/features/heart/presentation/heart_detail_screen.dart`): Route `/heart`. Full-screen detail view with a `SliverAppBar`, hero card, AI summary card, trend section, and a "View All Data" link that navigates to `HeartAllDataScreen`.

- **`HeartAllDataScreen`** (`zuralog/lib/features/heart/presentation/all_data/heart_all_data_screen.dart`): Route `/heart/all-data`. Seven metric tabs: Resting HR, HRV, Avg HR, Resp. Rate, VO2 Max, SpO2, and Blood Pressure. Blood Pressure tab uses the new dual-line chart (systolic + diastolic stacked).

**Widgets:**

- **`HeartHeroCard`** (`zuralog/lib/features/heart/presentation/widgets/heart_hero_card.dart`): RHR and HRV as the headline pair, with vs-7-day delta arrows for both, source chips, and an empty state with a "Connect wearable" CTA.

- **`HeartAiSummaryCard`** (`zuralog/lib/features/heart/presentation/widgets/heart_ai_summary_card.dart`): AI-generated daily heart summary with a skeleton loading state and a relative-time "Generated X ago" footer.

- **`HeartTrendSection`** (`zuralog/lib/features/heart/presentation/widgets/heart_trend_section.dart`): Two line charts (Resting HR + HRV) in a single card with a shared 7d/30d range toggle.

- **`HeartPillarCard`** (`zuralog/lib/features/today/presentation/widgets/heart_pillar_card.dart`): Updated to accept a real `HeartDaySummary` parameter. Displays resting HR as the headline, HRV and vs-avg delta as secondary stats.

**Routing + Today Tab:**

- **Route names** (`zuralog/lib/core/router/route_names.dart`): Added `heart` / `heartPath` (`/heart`) and `heartAllData` / `heartAllDataPath` (`/heart/all-data`).

- **Router** (`zuralog/lib/core/router/app_router.dart`): Heart GoRoute registered at `/heart` with nested `/heart/all-data` child, matching the Sleep section pattern.

- **Today feed** (`zuralog/lib/features/today/presentation/today_feed_screen.dart`): Wired to `heartDaySummaryProvider`; `HeartPillarCard` now uses real data and navigates to `HeartDetailScreen` on tap.

**Files created:**
- `zuralog/lib/features/heart/domain/heart_models.dart`
- `zuralog/lib/features/heart/data/heart_repository_interface.dart`
- `zuralog/lib/features/heart/data/api_heart_repository.dart`
- `zuralog/lib/features/heart/data/mock_heart_repository.dart`
- `zuralog/lib/features/heart/providers/heart_providers.dart`
- `zuralog/lib/features/heart/presentation/heart_detail_screen.dart`
- `zuralog/lib/features/heart/presentation/all_data/heart_all_data_screen.dart`
- `zuralog/lib/features/heart/presentation/widgets/heart_hero_card.dart`
- `zuralog/lib/features/heart/presentation/widgets/heart_ai_summary_card.dart`
- `zuralog/lib/features/heart/presentation/widgets/heart_trend_section.dart`

**Files modified:**
- `zuralog/lib/shared/all_data/all_data_models.dart`
- `zuralog/lib/shared/all_data/all_data_screen.dart`
- `zuralog/lib/core/router/route_names.dart`
- `zuralog/lib/core/router/app_router.dart`
- `zuralog/lib/features/today/presentation/widgets/heart_pillar_card.dart`
- `zuralog/lib/features/today/presentation/today_feed_screen.dart`

---

## 2026-04-17 — Nutrition Phase 6: Walkthrough Answer Pipe, Refine Rounds, and Rule Suggestions

**Branch:** `feat/navigation-restructure` (31 commits, not yet pushed)

Four-plan push that fixes the silent-answer bug in the meal walkthrough, rebuilds the walkthrough answer pipe end-to-end with attribution, adds multi-round follow-up questions, and introduces a rule-suggestion system mined from the user's own answer history. Analyzer is clean; 23 tests pass.

**Plan 1 — UX cleanup pass:**

- **Walkthrough navigation moved into the question stack** (`meal_walkthrough_screen.dart`): Back, Skip, and Next buttons were previously pinned to the bottom of the screen, far from the question. They now sit in the same centered stack as the question card, which keeps them inside the natural thumb zone.

- **New shared widget `ZLabeledNumberField`** (`zuralog/lib/shared/widgets/`): A reusable numeric input with a persistent label (always visible, not a placeholder), unfocused outline, optional unit suffix, decimal-vs-integer modes, a semantic screen-reader label, and a guard against multiple decimal points. Added to the widgets barrel export.

- **Meal Edit + Meal Review inline edits adopt `ZLabeledNumberField`** for Calories, Protein, Carbs, and Fat. Previously the macro inputs were bare numbers with no label — now each one shows its name and unit (`kcal`, `g`) without the user having to guess.

**Plan 2 — Answer-flow fix with attribution badges:**

- **Root cause fixed** (`meal_review_screen.dart`): Yes/no walkthrough answers were being silently discarded because the handler had a hardcoded `break` inside its loop. The pipe was rebuilt end-to-end instead of patching the symptom.

- **Backend contract extended** (`cloud-brain/app/services/nutrition/schemas.py`, `parse.py`, `vision.py`): `GuidedQuestion` now carries an `on_answer` field — a discriminated union with four op types (`add_food`, `scale_food`, `replace_food`, `no_op`). `ParsedFoodItem` gained `origin`, `source_question_id`, and `source_answer_value` so every food can be traced back to where it came from. Parse and vision system prompts now emit the `on_answer` contract, and the old "do not add foods" rule (which was suppressing inferred ingredients like cooking oil) was removed.

- **Flutter executes the ops** (`meal_review_screen.dart`): `_applyWalkthroughAnswers` was rewritten to run through a Dart 3 sealed pattern switch over op types. A new `ZAnswerOriginBadge` (violet pill) renders next to any food that was added or changed by an answer. The food-detail bottom sheet now shows the source question, the answer given, and that food's contribution — with a Remove button (deletes the food AND flips yes→no on the source question) and a Change button.

**Plan 3 — Follow-up questions (multi-round walkthroughs):**

- **New op: `needs_followup`** plus free-text answers always route through refine. The walkthrough can now ask a second round of questions based on what the user said in the first round.

- **New endpoint `POST /api/v1/nutrition/meals/refine`** (`cloud-brain/app/api/v1/nutrition.py`, `refine.py`): Accepts the current food list and the latest round of answers, runs a dedicated system prompt that preserves attribution from earlier rounds, and returns the refined food list and (optionally) a new round of questions. Hard cap of 3 refine rounds enforced on both the server and the client. Same rate limiting and retry wrapper as the parse endpoint.

- **Flutter supports multiple rounds inside one `PageView`** (`meal_walkthrough_screen.dart`): New questions are appended as they arrive from the server. A new `ZRefineTransitionCard` renders between rounds with "Asking one more thing…" copy so the user sees that a round-trip is happening. Refine failures surface a toast and the flow advances gracefully — it never crashes. Meal Review adopts the refined food list wholesale whenever refine ran; otherwise it falls back to the Plan 2 local op application.

**Plan 4 — Rule suggestions:**

- **Database migration** (`supabase/migrations/`): Adds `origin`, `source_question_id`, and `source_answer_value` columns to `meal_foods` (all nullable, no backfill required), plus a partial composite index for fast detection queries. A new `rule_suggestion_snooze` table with a unique constraint stores dismissals.

- **Detection service** (`cloud-brain/app/services/nutrition/rule_suggestion.py`): Mines the user's last-60-days tagged `meal_foods` rows for `(source_question_id, source_answer_value)` combos with a count of 3 or more, filters out combos that already have a matching rule or an active snooze, and returns the best candidate. Runs on every parse, refine, and scan response so a suggestion can surface the moment the user hits the threshold.

- **Dismiss endpoint** (`POST /api/v1/nutrition/meals/rule-suggestion/dismiss`): Rate-limited, returns 204, upserts a snooze that suppresses the same suggestion for the next 10 occurrences. `POST /rules` gained optional `suppressed_question_id` and `suppressed_answer_value` fields so that accepting a rule automatically clears the matching snooze. Each meal save decrements active snoozes by 1, so the system gently relaxes if a user says "not now" but the pattern keeps appearing.

- **Flutter surface** (`meal_review_screen.dart`, `zuralog/lib/shared/widgets/`): Parse and refine results now carry a `SuggestedRule` model. A new `ZSuggestedRuleBanner` widget (lightbulb icon, "Suggested rule" eyebrow, rule text, Save rule + Not now buttons) renders directly above the "Here's what I found" list in Meal Review. Save calls `createRule` with the suppression fields set; Not now optimistically hides the banner and fires the dismiss endpoint.

**Known limitations (scoped out intentionally, not regressions):**

- Plan 4 Task 12 — backend integration tests for the detection and snooze logic — is not written. All existing backend tests still pass; the new logic is covered only by ad-hoc smoke tests.
- Plan 4 Task 15 — manual emulator verification across 6 scenarios — was not run. It requires interactive emulator use, which this autonomous execution pass can't do.
- Plan 4 Task 14's refine-path `suggestedRule` threading is not wired. If the user triggers a refine mid-flow, the banner won't refresh with an updated suggestion until the next parse.
- The rule-text template map in `rule_suggestion.py` is intentionally empty for this release. The generic fallback ("I always answer X for this question") ships today. Once the stable question IDs are defined, the map can be populated per-question without a migration.

**Open items for manual verification before merge:**

- Emulator smoke test: log "scrambled eggs with rice" → Guided → yes on oil → verify the cooking oil line appears with a violet badge and totals reflect the added fat.
- Emulator smoke test: free-text answer triggers the `ZRefineTransitionCard` and returns a refined food list.
- Emulator smoke test: log eggs 3 times in a row answering yes → on the 4th meal, the suggested-rule banner appears above "Here's what I found".

**Files changed:** Spread across `cloud-brain/app/api/v1/nutrition.py`, `cloud-brain/app/services/nutrition/` (schemas, parse, vision, refine, rule_suggestion), `supabase/migrations/`, `zuralog/lib/features/nutrition/` (meal walkthrough, meal review, meal edit, repositories, models), and `zuralog/lib/shared/widgets/` (`ZLabeledNumberField`, `ZAnswerOriginBadge`, `ZRefineTransitionCard`, `ZSuggestedRuleBanner`).

---

## 2026-04-04 — Coach Tab Security Hardening (Full Audit)

**Branch:** `fix/security-hardening`

A comprehensive security audit of the Coach Tab (WebSocket AI chat) followed by fixes for all 14 findings across severity levels H1–H4, M1–M5, and L1–L4.

**What was built:**

- **Push notification daily rate limit** (`app/mcp_servers/notification_server.py`, Task 1 / H1): Redis-backed per-user daily cap of 10 notifications. Uses atomic `incr`+`expire` to avoid race conditions. Fails open when Redis is unavailable. 13 new tests.

- **Server-side write confirmation gate** (`app/agent/orchestrator.py`, `app/api/v1/chat.py`, Task 7 / H2): 9 write tools now require explicit user confirmation before execution. Server generates a one-time token bound to the specific tool name (`write_confirm_tool`). Client sends token back via `{"type": "write_confirm", "token": str}`. Token is consumed on use and cannot authorize a different tool.

- **Redis fail-closed for rate limiting** (`app/services/rate_limiter.py`, Task 2 / H3): All three rate-limit check methods now deny rather than allow on `RedisError`. Narrowed broad `except Exception` to `except redis.RedisError`. Returns `remaining=0, reset_seconds=60` on failure. 4 new tests.

- **Memory preference-injection guard** (`app/mcp_servers/memory_server.py`, `app/utils/sanitize.py`, Tasks 3, 5 / H4+L4): `save_memory` tool now blocks content over 500 chars and content matching `is_memory_injection_attempt()`. 7 new high-signal bypass phrases added to the sanitize filter (tightened to require action-specific qualifiers). `_DANGEROUS_PATTERN` extended with `==SYSTEM==`, `<SYSTEM>`, `<|role|>`, `[CONTEXT]:` patterns.

- **Extraction injection filter** (`app/agent/context_manager/memory_extraction_service.py`, Task 4 / M1): Auto-extracted memories from conversation also run through `is_memory_injection_attempt()` before being stored.

- **Per-turn tool call cap** (`app/agent/orchestrator.py`, Task 6 / M2): `MAX_TOOLS_PER_TURN = 6` constant added. ReAct loop enforces this per turn in addition to the existing `MAX_TOOL_TURNS = 5` total.

- **Memory length limit + user-scoped delete** (`app/mcp_servers/memory_server.py`, `app/agent/context_manager/pgvector_memory_store.py`, `app/agent/context_manager/memory_store.py`, Task 5 / M3+L2): `_MAX_MEMORY_LENGTH = 500`. `delete()` now requires `user_id` parameter and scopes the SQL `WHERE` clause to both `id` and `user_id` — prevents cross-user deletion.

- **Deep link URL encoding** (`app/mcp_servers/deep_link_registry.py`, Task 10 / M4): Search query in deep link now URL-encoded via `urllib.parse.quote` to prevent injection via crafted queries.

- **WebSocket concurrent connection limit** (`app/api/v1/chat.py`, Task 11 / M5): Limit reduced from 3→2 per user. Two-call `incr`+`expire` replaced with atomic `_INCR_EXPIRE_SCRIPT` Lua evaluation — eliminates TTL race condition.

- **Conversation summary injection filter** (`app/api/v1/chat.py`, `tests/api/v1/test_chat_history.py`, Task 8 / L1): Summaries loaded from the database are now checked with `is_memory_injection_attempt()` before being injected as a system message. Poisoned summaries are dropped with a warning log.

- **Oversized message disconnect** (`app/api/v1/chat.py`, Task 9 / L3): WebSocket sessions disconnect (code 1008) after 5 consecutive oversized messages (`_MAX_OVERSIZED = 5`, promoted to module level).

- **WebSocket message field coercion** (`app/api/v1/chat.py`, Task 12 / L1b): `message` field from WebSocket payload coerced to `str` before processing to prevent type-confusion attacks.

**Files modified:** `cloud-brain/app/api/v1/chat.py`, `cloud-brain/app/agent/orchestrator.py`, `cloud-brain/app/agent/context_manager/memory_extraction_service.py`, `cloud-brain/app/agent/context_manager/memory_store.py`, `cloud-brain/app/agent/context_manager/pgvector_memory_store.py`, `cloud-brain/app/mcp_servers/memory_server.py`, `cloud-brain/app/mcp_servers/notification_server.py`, `cloud-brain/app/mcp_servers/deep_link_registry.py`, `cloud-brain/app/services/rate_limiter.py`, `cloud-brain/app/utils/sanitize.py`, `cloud-brain/app/main.py`

**Files created:** `cloud-brain/tests/mcp/test_notification_server.py`, `cloud-brain/tests/services/test_rate_limiter.py`, `cloud-brain/tests/api/v1/test_chat_history.py`

---


## 2026-04-03 — AI Security Hardening Round 2

**Branch:** `fix/ai-security-hardening-round-2`

A second security pass focused on prompt injection defences, adversarial test coverage expansion, and model parity testing.

**What was built:**

- **Memory poisoning filter** (`app/utils/sanitize.py`, `app/agent/prompts/system.py`): Added `is_memory_injection_attempt()` — a general-purpose injection gate (separate from `sanitize_for_llm`) that runs at two points in the pipeline: before injecting stored memories into the system prompt, and before feeding tool results back to the model. Uses NFKC normalisation and invisible-character stripping. Patterns are tightened to avoid false positives on common health/coaching language (e.g. "ignore your cravings", "skip all processed foods") while still catching high-signal injection phrases. The section header is suppressed when all memories are filtered.

- **Tool result injection scanning** (`app/agent/orchestrator.py`, `app/agent/prompts/system.py`): Rule 9 added to `_SAFETY_BLOCK` — instructs the model to treat tool result content as untrusted data. In both `process_message` and `process_message_stream`, each successful tool result is scanned with `is_memory_injection_attempt` after the 32KB cap check; suspicious content is replaced with `[content redacted — potential injection attempt]` and a warning is logged.

- **Medical disclaimer authority hardening** (`app/agent/prompts/system.py`): Rule 7 in `_SAFETY_BLOCK` extended to explicitly state the disclaimer applies even when the user claims to be a doctor, nurse, researcher, or other medical professional. All three persona-level "NOT a medical doctor" notes updated to match.

- **PromptFoo suite expanded from 30 to 41 tests** (`promptfoo/promptfooconfig.yaml`, `promptfoo/provider.py`):
  - Provider now accepts `config.model` override and `conversation_history` var (list of `{role, content}` pairs prepended before the final user message).
  - Second provider added targeting `qwen/qwen3.5-flash-02-23` for parity — all 41 tests now run against both Kimi K2.5 and Qwen3.5-Flash (82 total runs).
  - 5 multi-turn tests: rapport-then-jailbreak, gradual scope expansion, false memory injection, persona erosion, authority build-up.
  - 3 hallucination-under-pressure tests: step estimate, heart rate guess, pretend-you-have-data roleplay.
  - 3 medical authority bypass tests: registered nurse claim, cardiologist referral, sports medicine doctor claim.

**Files modified:** `cloud-brain/app/utils/sanitize.py`, `cloud-brain/app/agent/prompts/system.py`, `cloud-brain/app/agent/orchestrator.py`, `promptfoo/provider.py`, `promptfoo/promptfooconfig.yaml`

**Files created:** `cloud-brain/tests/test_memory_injection_filter.py`, `cloud-brain/tests/test_tool_result_injection.py`, `cloud-brain/tests/test_promptfoo_provider.py`

---

## 2026-04-02 — System Prompt & Persona Hardening

**Branch:** `fix/system-prompt-persona-hardening`

A second focused security and quality pass — adding explicit AI output rules, consolidating duplicate persona code, closing a broken object-level authorization hole in memory management, promoting secrets to `SecretStr`, and expanding the adversarial test suite.

**What was built:**

- **No-emoji safety rule** (`app/agent/prompts/system.py`): Rule 8 added to `_SAFETY_BLOCK`. Zura now explicitly never uses emoji characters in any response — plain text only, unconditionally, regardless of persona.

- **Persona module consolidation** (`app/agent/prompts/system.py`, `app/agent/prompts/personas.py`): `personas.py` was a diverged duplicate that had richer persona texts than the live `system.py`. Now `system.py` is the single source of truth — it exports `PERSONAS`, `PROACTIVITY_MODIFIERS`, and a stricter `build_system_prompt` that raises `ValueError` for unknown personas, adds "not yet connected" text when no integrations are present, and includes the richer per-persona coaching texts. `personas.py` is a thin re-export wrapper with no duplicate definitions.

- **Memory deletion BOLA fix** (`app/agent/context_manager/pgvector_memory_store.py`, `app/api/v1/memory_routes.py`): `DELETE /api/v1/memories/{memory_id}` was missing user ownership verification — any authenticated user could delete another user's memory by ID. Fixed: `delete_memory()` now executes `DELETE FROM user_memories WHERE id = :id AND user_id = :user_id`, and the route passes the authenticated user's ID.

- **Webhook tokens promoted to `SecretStr`** (`app/config.py`, `app/api/v1/strava_webhooks.py`, `app/api/v1/fitbit_webhooks.py`, `app/tasks/fitbit_sync.py`): `strava_webhook_verify_token` and `fitbit_webhook_verify_code` were plain `str`. Both are now `SecretStr`, redacting them from logs and tracebacks. All call sites updated to use `.get_secret_value()`.

- **PromptFoo suite expanded from 20 to 30 tests** (`promptfoo/promptfooconfig.yaml`, `promptfoo/provider.py`): Provider now accepts `persona` and `proactivity` from test vars so tests can target specific personas. Added: per-persona safety checks for `tough_love` and `gentle`, and 6 new attack cases: multi-turn friendship exploit, translation wrapper injection, flattery-based persona switching, fake developer authority claim, hypothetical framing bypass, and a dedicated emoji-output check.

**Files modified:** `cloud-brain/app/agent/prompts/system.py`, `cloud-brain/app/agent/prompts/personas.py`, `cloud-brain/app/agent/context_manager/pgvector_memory_store.py`, `cloud-brain/app/api/v1/memory_routes.py`, `cloud-brain/app/config.py`, `cloud-brain/app/api/v1/strava_webhooks.py`, `cloud-brain/app/api/v1/fitbit_webhooks.py`, `cloud-brain/app/tasks/fitbit_sync.py`, `cloud-brain/tests/test_strava_webhooks.py`, `cloud-brain/tests/test_fitbit_webhooks.py`, `promptfoo/provider.py`, `promptfoo/promptfooconfig.yaml`

---

## 2026-04-02 — Security Hardening & Abuse Avoidance

**Branch:** `fix/abuse-avoidance-security-hardening`

A focused security pass across the backend — tightening the AI persona, closing webhook authentication gaps, normalizing untrusted input, and adding a dedicated adversarial test suite.

**What was built:**

- **System prompt security guardrails** (`app/agent/prompts/system.py`, `app/agent/prompts/personas.py`): A `_SAFETY_BLOCK` is now injected into all three persona prompts (tough love, balanced, gentle). It enforces role-lock ("You are Zura"), restricts the Coach to health-only topics, keeps system instructions and model/tool names confidential, resists prompt injection attempts, prevents PII requests, and appends a medical disclaimer. A companion `personas.py` file was added with richer per-persona text used by the test suite.

- **Unicode normalization in the input sanitizer** (`app/utils/sanitize.py`): NFKC normalization now runs before regex matching, collapsing Unicode homoglyphs (e.g. Turkish dotless-i, full-width characters) that could previously bypass keyword filters. Zero-width characters are also stripped. Four new tests cover this in `tests/test_sanitize.py`.

- **Fitbit webhook authentication hardened** (`app/api/v1/fitbit_webhooks.py`): Incoming payloads now have their `subscriptionId` field validated against the configured subscriber ID using `hmac.compare_digest`. Unknown subscription IDs are silently skipped rather than processed, preventing an attacker from spoofing webhook events for subscriptions they do not own.

- **Oura webhook endpoint obscured** (`app/api/v1/oura_webhooks.py`): The route now requires a secret token in the URL path (`/webhooks/oura/{path_token}`). Requests with a mismatched token receive a 404 response, which prevents an attacker from discovering or enumerating the endpoint.

- **Secrets promoted to `SecretStr`** (`app/config.py`): `fitbit_webhook_subscriber_id`, `oura_webhook_path_token`, and `withings_webhook_secret` are now typed as `SecretStr` so they are redacted from logs and tracebacks. A startup validation check now requires `withings_webhook_secret` to be set whenever `withings_client_id` is configured, preventing production deployments with incomplete webhook authentication.

- **HTTP security headers middleware** (`app/main.py`): A `SecurityHeadersMiddleware` (Starlette `BaseHTTPMiddleware`) is mounted on every response. Headers added: `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, `Referrer-Policy: strict-origin-when-cross-origin`, `Strict-Transport-Security: max-age=63072000; includeSubDomains`, `X-XSS-Protection: 0`.

- **PromptFoo adversarial test suite** (`promptfoo/`): 20 test cases exercise the AI persona against real attack patterns — jailbreak attempts, role-play bypass, system prompt extraction, model/vendor name extraction, tool name extraction, off-topic requests, PII extraction, prompt injection, and instruction injection. Includes a provider bridge (`provider.py`) and usage guide (`README.md`).

**Pre-existing test failures fixed:**

- `tests/analytics/test_insight_signal_detector.py`: Deadline calculation changed from `date.today()` to `_NOW.date()` to match the frozen test timestamp.
- `tests/test_orchestrator.py`: Tool count assertion now filters to entries where `type == "function"`, accounting for the `openrouter:web_search` tool that `_build_tools_for_llm` always appends.
- `tests/test_rate_limit_middleware.py`: Wrong keyword argument `user=mock_user` corrected to `user_id="user-1"`.

**Files created:**
- `cloud-brain/app/agent/prompts/personas.py`
- `cloud-brain/tests/test_sanitize.py`
- `cloud-brain/promptfoo/promptfooconfig.yaml`
- `cloud-brain/promptfoo/provider.py`
- `cloud-brain/promptfoo/README.md`

**Files modified:** `app/agent/prompts/system.py`, `app/utils/sanitize.py`, `app/api/v1/fitbit_webhooks.py`, `app/api/v1/oura_webhooks.py`, `app/config.py`, `app/main.py`, `tests/analytics/test_insight_signal_detector.py`, `tests/test_orchestrator.py`, `tests/test_rate_limit_middleware.py`

---

## 2026-04-02 — Coach Skills: Platform-Specific Health Guidance

**Branch:** `feat/memory-mcp-server`

Extended the Coach Skill System with platform-specific health coaching for iOS and Android users.

**What was built:**

- **Apple Health skill** (`cloud-brain/app/coach_skills/apple_health.md`): Specialized guidance for iOS users and devices that sync with Apple Health. Covers reading HealthKit data, health data permissions, device ecosystem specifics, and best practices for health tracking on iPhone, Apple Watch, and other Apple devices. Helps the Coach answer questions like "Why isn't my watch syncing?", "Can I see my resting heart rate?", and "How do I share health data with my family?"

- **Health Connect skill** (`cloud-brain/app/coach_skills/health_connect.md`): Specialized guidance for Android users and devices that sync with Google Health Connect. Covers reading Health Connect data, app integration, permissions, and best practices for health tracking on Android devices. Helps the Coach answer questions about Android-specific health tracking, device compatibility, and data integration across health apps on Android.

- **Byte limit increase** (`cloud-brain/app/mcp_servers/coach_skill_server.py`): `MAX_SKILL_BYTES` increased from 6144 (6KB) to 12288 (12KB) to accommodate the new comprehensive health platform guides without truncation.

**Files created:**
- `cloud-brain/app/coach_skills/apple_health.md`
- `cloud-brain/app/coach_skills/health_connect.md`

**Files modified:** `cloud-brain/app/mcp_servers/coach_skill_server.py`

---

## 2026-04-01 — Coach Skill System

**Branch:** `feat/coach-skill-system`

Added a runtime skill system to the Coach AI so it can pull in domain-specific knowledge on demand — without any database changes, migrations, or per-user configuration.

**What was built:**

- **Skill documents** (`cloud-brain/app/coach_skills/`): Plain text files, one per domain, that describe how the Coach should reason and respond within that area. Three starter skills ship with this release: `strength_training.md`, `nutrition.md`, and `cardio_endurance.md`. Adding a new domain means dropping in a new file — no code changes required.

- **CoachSkillMCPServer** (`cloud-brain/app/mcp_servers/coach_skill_server.py`, server name `coach_skills`): An MCP server that loads all skill documents at startup and exposes a single `get_coach_skill` tool. The tool takes a skill name and returns the full document. A `get_skill_index()` method also generates a compact index listing all available skills and their one-line descriptions.

- **Skill index injection**: The skill index is injected into every system prompt under a `## Available Expertise` section. This tells the Coach what domains it can pull knowledge from before it decides whether to use any.

- **3-tier loading rule**: The Coach follows a simple rule when deciding whether to load a skill: simple conversational questions — no skill needed; questions requiring domain expertise — load 1 skill; complex questions spanning multiple domains — load up to 2 skills. This keeps context lean while still giving the Coach depth when it matters.

- **Registration**: `CoachSkillMCPServer` is started in the `main.py` lifespan block and listed in `ALWAYS_ON_SERVERS` in `user_tool_resolver.py`. It is available in every Coach session for all users — no integration or opt-in required.

**Files created:**
- `cloud-brain/app/mcp_servers/coach_skill_server.py`
- `cloud-brain/app/coach_skills/strength_training.md`
- `cloud-brain/app/coach_skills/nutrition.md`
- `cloud-brain/app/coach_skills/cardio_endurance.md`

**Files modified:** `main.py`, `user_tool_resolver.py`, `agent/prompts/system.py`, `orchestrator.py`

---

## 2026-04-01 — App MCP Servers (Progress, Wellbeing, Notifications)

**Branch:** `feat/app-mcp-servers`

Added three new MCP servers to the Coach AI so it can read and manage the user's goals, streaks, achievements, journal, supplements, wellbeing insights, and push notifications — all without requiring any third-party OAuth connection.

**What was built:**

- **UserProgressServer** (`user_progress_server.py`, server name `user_progress`): Gives the Coach full read/write access to the user's goals and read-only access to streaks and achievements. Goals support create, read, update, complete, and delete. Streaks and achievements are intentionally read-only — the AI observes them, it does not manufacture them. Achievements are sourced through `AchievementTracker.get_all()`. Queries the `user_goals`, `user_streaks`, and `achievements` tables.

- **UserWellbeingServer** (`user_wellbeing_server.py`, server name `user_wellbeing`): Gives the Coach access to the user's journal entries, supplement log, and AI-generated insights. Journal entries and insights are read-only by design — the Coach reads what the user wrote, it does not write journal entries on their behalf. Supplements support add and remove (soft delete). Queries the `journal_entries`, `user_supplements`, and `insights` tables.

- **NotificationServer** (`notification_server.py`, server name `notification`): Gives the Coach the ability to send a push notification to all of the user's registered devices. Uses `PushService.send_and_persist`, which delivers the message and writes a record to `notification_logs` in one step. The `notification_type` is hardcoded to `"coach"` so these messages are always identifiable as AI-initiated. The tool takes a `title` and `body` — nothing else.

- **Registration**: All three servers are started in the `main.py` lifespan block and listed in `ALWAYS_ON_SERVERS` in `user_tool_resolver.py`. No user action or OAuth flow is needed — they are available in every Coach session automatically.

- **System prompt updated**: The `_CAPABILITIES_BLOCK` in `agent/prompts/system.py` was extended with tool documentation for items 6–9 covering goals, streaks/achievements, wellbeing, and notifications.

**Files created:**
- `cloud-brain/app/mcp_servers/user_progress_server.py`
- `cloud-brain/app/mcp_servers/user_wellbeing_server.py`
- `cloud-brain/app/mcp_servers/notification_server.py`

**Files modified:** `main.py`, `user_tool_resolver.py`, `agent/prompts/system.py`

---

## 2026-04-01 — Coach Context Management (Three-Layer Memory)

**Branch:** `feat/context-management`

Added a full three-layer memory system to the Coach AI so it knows who the user is, remembers past conversations, and retains long-term facts across sessions.

**What was built:**

- **Layer 1 — Working memory** (`token_counter.py`): History is now trimmed by real token counts using `tiktoken` (`cl100k_base`). Budget is 8,192 tokens per request, with a 2,048-token cap per message. Replaced the old `MAX_HISTORY_CHARS = 40_000` character estimate.

- **Layer 2 — Episodic memory** (`summarization_service.py`): When a conversation exceeds 30 messages, the oldest messages are summarized by the LLM and stored in `conversations.summary`. The summary is prepended on future requests. Summarized messages are flagged `is_summarized = TRUE` and excluded from history loads. Runs fire-and-forget — no added latency.

- **Layer 3 — Semantic memory** (`pgvector_memory_store.py`, `memory_extraction_service.py`): User facts are stored as vector embeddings in the `user_memories` table in Supabase. After each session, up to five facts are extracted by the LLM, deduplicated at 0.92 cosine similarity, and stored. The top-5 most relevant facts (score ≥ 0.70) are injected into every system prompt. Uses OpenAI `text-embedding-3-small` (1536 dims) with an HNSW index.

- **User profile injection**: Every system prompt now includes a `## About This User` block — display name, goals, fitness level, units, timezone, computed age, and height. Sourced from a JOIN of `users` and `user_preferences` at request time.

- **Tool result truncation**: If accumulated tool messages in a single turn exceed 4,096 tokens, the oldest is truncated to a 150-token summary. Prevents a large health data dump from consuming the full context window.

- **Pinecone retired**: `PineconeMemoryStore` and its tests deleted. `PgVectorMemoryStore` now implements the `MemoryStore` protocol. `pinecone_api_key` removed from config. Long-term memory now runs entirely inside the existing Supabase instance.

**Files created:**
- `cloud-brain/app/agent/context_manager/token_counter.py`
- `cloud-brain/app/agent/context_manager/summarization_service.py`
- `cloud-brain/app/agent/context_manager/pgvector_memory_store.py`
- `cloud-brain/app/agent/context_manager/memory_extraction_service.py`
- `supabase/migrations/20260401000001_add_context_management.sql`
- `supabase/migrations/20260401000002_add_pgvector_memories.sql`

**Files modified:** `chat.py`, `orchestrator.py`, `system.py`, `memory_store.py`, `conversation.py`, `main.py`, `config.py`, `memory_routes.py`, `pyproject.toml`

**Files deleted:** `pinecone_memory_store.py`, `test_pinecone_memory_store.py`

---

## 2026-04-01 — Coach Ghost Mode Rework

**Files changed:** `coach_screen.dart`, `coach_ghost_banner.dart`, `coach_repository.dart`, `api_coach_repository.dart`, `coach_providers.dart`

- **Soft-brick bug fixed:** `_showActivateGhostSheet` and `_showExitGhostSheet` now `await` the modal sheet so state updates only fire after the dismiss animation fully completes. Previously, synchronous rebuilds during the pop animation left the Coach tab's modal barrier mounted and the whole tab unresponsive.
- **Vignette replaced:** `_GhostVignette` swapped from a full-screen radial gradient dim to a 2.5dp colored border using `AppColorsOf(context).primary` at 60% opacity. The center of the screen is now fully unobstructed.
- **Banner copy updated:** `CoachGhostBanner` text changed from "Ghost Mode — nothing is being saved" to "Ghost Mode — your conversation won't be saved or logged."
- **`ghost_mode` flag propagated through the full send chain:** `bool isGhost = false` added to `CoachRepository`, `ApiCoachRepository`, providers, and screen. When active, `ghost_mode: true` is included in the WebSocket payload.
- **Write-type tool indicators suppressed in ghost mode:** Tool call UI items whose names contain save, store, write, memory, log, create, update, delete, or archive are hidden from the chat while ghost mode is on.
- **Conversation refresh skipped in ghost mode:** `coachConversationsProvider.notifier.refresh()` is not called after ghost mode sends. `regenerate()` also forwards `isGhost`.

---

## 2026-03-31 — Coach Ghost Mode Redesign + Attachment Panel

### Ghost Mode
- **Soft-brick bug fixed:** `_showActivateGhostSheet` and `_showExitGhostSheet` in `coach_screen.dart` now wrap state changes in `WidgetsBinding.addPostFrameCallback` so the modal barrier clears before the screen rebuilds. Root cause was the branch navigator's `ModalBarrier` staying mounted due to synchronous rebuilds during the pop animation.
- **Icon:** Ghost mode button changed to `Icons.sentiment_very_dissatisfied_rounded`
- **App bar title:** Switches to 'Ghost Mode' when active, 'Coach' otherwise
- **Vignette overlay:** Background color swap removed. `_GhostVignette` widget added as last Stack child — `IgnorePointer`-wrapped `DecoratedBox` with `RadialGradient` (transparent center → `0x55000000` at edges, radius 1.2). Self-wraps `IgnorePointer` internally.
- **`canvasGhost` token:** Annotated as superseded by vignette in `app_colors.dart`

### Attachment Panel (`CoachAttachmentPanel`)
- New file: `zuralog/lib/features/coach/presentation/widgets/coach_attachment_panel.dart`
- Full-screen scrollable bottom sheet replacing `AttachmentPickerSheet`
- Sections: **Attach From** (Camera / Photos / Files — 10 MB guard, double-tap guard, `InkWell` ripple) + **Session Settings** (AI Persona cards, Proactivity `ZSegmentedControl`, Response Length `ZSegmentedControl`, Suggested Prompts + Voice Input `ZSettingsTile`/`ZToggle`)
- All settings read/write `userPreferencesProvider` — changes sync with Settings tab automatically
- Ghost mode: attachment section disabled with explanatory banner when `isGhost: true`
- `isGhost` parameter propagated through `CoachInputBar` → `CoachAttachmentPanel`
- Call site: `coach_input_bar.dart` — import and widget name updated; all other logic unchanged

---

## 2026-03-31 — Coach Tab Redesign

**Branch:** `feat/coach-tab-redesign`

Completed full redesign of the Coach Tab with a single adaptive screen replacing the previous two-screen flow.

**What was built:**

- **Single adaptive CoachScreen** replaces `NewChatScreen` and `ChatThreadScreen`. The screen manages three inline visual states: idle (greeting + suggestions), conversation (active message thread), and ghost mode (data not being saved).

- **Animated blob mascot** (`coach_blob.dart`) with three states (idle, thinking, talking) and two sizes (80px for idle UI, 28px embedded in messages).

- **10 supporting widgets** for a complete chat UX:
  - `coach_thinking_layer.dart` — collapsible "Zura is thinking..." strip
  - `coach_ai_response.dart` — 4-layer AI response (thinking + markdown text + actions + footer blob)
  - `coach_user_message.dart` — right-aligned bubble with long-press context menu
  - `coach_artifact_card.dart` — inline cards for memory/journal/data system actions
  - `coach_suggestion_card.dart` — suggestion cards with spring-press animation
  - `coach_idle_state.dart` — idle UI with blob + time-adaptive greeting + 3 hardcoded suggestions
  - `coach_message_list.dart` — scrollable message thread + scroll-to-bottom FAB
  - `coach_ghost_banner.dart` — persistent ghost mode banner with exit button

- **Ghost mode** state provider added to allow users to test features without data persistence.

- **CoachInputBar improvements** — added optional `placeholder` parameter (defaults to "Message Zura…").

- **Router refactored** — removed nested `/coach/thread/:id` route, replaced with single `CoachScreen` route. Removed `coachThread` and `coachThreadPath` constants.

**Files created:** 10 (coach_screen.dart + 9 widgets)
**Files modified:** 3 (providers, input bar, router)
**Files deleted:** 2 (new_chat_screen.dart, chat_thread_screen.dart)

---

## 2026-03-31 — Coach Thinking Display

**Branch:** `feat/coach-thinking-display` (not yet merged)

Added live "thinking" feedback to the Coach screen — while Zura reasons through a question, the UI shows what it is doing in real time rather than a blank loading state.

**What was built:**

- **Backend reasoning token extraction** (`cloud-brain/orchestrator.py`) — when the AI model returns reasoning tokens (the internal "thinking" text before its final answer), the server captures them from `delta.reasoning` (with a `model_extra` fallback for models that expose it differently) and forwards them to the client as `thinking_token` WebSocket events. These tokens are display-only and never written to the database.

- **Flutter data layer** (`coach_repository.dart`, `api_coach_repository.dart`) — a new `ThinkingToken` sealed subclass was added to the repository's event model. The API repository parses incoming `thinking_token` events into this type using its own `thinkingAccumulated` variable, separate from the regular streaming content accumulator.

- **Flutter state** (`coach_providers.dart`) — a `thinkingContent: String?` field was added to `CoachChatState`. It is populated as thinking tokens arrive and cleared on the first real content token so it disappears the moment Zura starts responding. It is also cleared on all exit paths: stream complete, error, cancel, timeout, `onError`, and tool start.

- **Flutter UI** (`coach_thinking_layer.dart`) — rewritten as a `StatelessWidget`. Displays a centered `CoachBlob(size: 48, BlobState.thinking)` with italic status text beneath it. The status text follows a priority order: "Checking [friendly tool name]…" during tool calls, the last 160 characters of the accumulated reasoning text when thinking tokens are arriving, or "Thinking…" as a fallback. The `isThinking` condition in `coach_screen.dart` was corrected to `chatState.isSending && chatState.streamingContent == null` so the thinking layer only appears before real content begins streaming.

**Files changed:** `orchestrator.py`, `chat.py`, `coach_repository.dart`, `api_coach_repository.dart`, `coach_providers.dart`, `coach_thinking_layer.dart`, `coach_ai_response.dart`, `coach_message_list.dart`, `coach_screen.dart`, `component_showcase_screen.dart`, `coach_thinking_layer_test.dart`

---

## 2026-03-30 — Settings Brand Bible Pass

**Branch:** `fix/settings-brand-bible`

Completed a full brand bible alignment pass across all settings screens.

**What was done:**

- **Design Catalog removed.** `catalog_screen.dart` deleted. The debug catalog route and route name constants were removed from the router. The harness screen no longer references it.

- **SliverAppBar replaced on every settings screen.** All settings screens that used `SliverAppBar` + `FlexibleSpaceBar` inside a `CustomScrollView` were converted to `ZuralogAppBar(showProfileAvatar: false)` on the scaffold. This fixes the app bar overlap bug and makes every screen consistent.

  Screens converted: Settings Hub, Subscription, About, Appearance, Coach, Journal, Integrations, Privacy & Data (plus Account, Edit Profile, Notification, Privacy Policy, Terms of Service were already using `ZuralogAppBar` or confirmed correct).

- **ZuraLog casing standardised.** Every displayed string that said "Zuralog" was updated to "ZuraLog" — including screen titles, hero widgets, legal body copy in the Privacy Policy and Terms of Service, share sheet text, and footer copyright lines. Code identifiers (class names, import paths) were left unchanged.

- **Surface tokens standardised.** All card/container backgrounds using `colors.cardBackground` in settings screens were changed to `colors.surface`.

- **Snackbars branded.** Plain `SnackBar` calls in the Privacy & Data screen were updated to use `colors.surface` background, floating behavior, and `AppTextStyles` body text — matching the design system.

- **Section labels standardised.** Inline `Text` section headers using ad-hoc style in Coach and other screens were replaced with the shared `SettingsSectionLabel` widget.

**Files changed:** All files in `lib/features/settings/presentation/`, plus `lib/core/router/app_router.dart`, `lib/core/router/route_names.dart`, `lib/features/harness/harness_screen.dart`.

**Analyze result:** Zero errors. Two pre-existing `info`-level lint hints in `edit_profile_screen.dart` (unnecessary braces in string interpolation) — unrelated to this pass.
