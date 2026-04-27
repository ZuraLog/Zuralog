## Supplements Log

### Complete — Plan 4: Daily Check-in Panel (2026-04-27)

**Status:** Shipped on `feat/supplements-log-overhaul`

What shipped:
- `ZSupplementsLogPanel` — inline Today panel with write-first offline sync
- `SupplementSyncStatus` cloud icon reflecting live sync state (idle / syncing / error)

### Complete — Plan 5: Panel Interactions (2026-04-27)

**Status:** Shipped on `feat/supplements-log-overhaul`

What shipped:
- 4-second undo toast before marking a supplement taken is committed
- `ZToast.displayDuration` parameter — configurable display time for the shared toast widget
- Uncheck confirmation dialog to prevent accidental log deletion

### Complete — Plan 6: Stack Management Screen (2026-04-27)

**Status:** Shipped on `feat/supplements-log-overhaul`

What shipped:
- `SupplementsStackScreen` — full stack management with drag reorder, swipe-to-delete, and add/edit form
- Option grids for timing (Morning, Afternoon, Evening, Bedtime) and form factor (Pill, Capsule, Powder, Liquid, Gummy, Other)

### Complete — Plan 7: One-off Daily Log (2026-04-27)

**Status:** Shipped on `feat/supplements-log-overhaul`

What shipped:
- Ad-hoc supplement logging from the Today panel ("Log something else" affordance)
- `SupplementTakenLog` gained `is_ad_hoc` and `ad_hoc_name` database columns
- `isAdHoc` sync branching in `SupplementsRepository` — ad-hoc entries follow a separate upsert path

### Complete — Plan 8: Scan Label Integration (2026-04-27)

**Status:** Shipped on `feat/supplements-log-overhaul`

What shipped:
- `POST /api/v1/supplements/scan-label` — accepts image (base64, max 4 MB) or barcode string; SSRF guard; returns `SupplementScanResult`
- Scan button in stack add/edit form — pre-fills form fields from scan result automatically
- Scanner disposal on screen close so the camera is never left open
- 3 backend tests covering barcode happy path, missing-input validation, and auth enforcement

### Complete — Plan 9: Conflict & Overlap Warnings (2026-04-27)

**Status:** Shipped on `feat/supplements-log-overhaul`

What shipped:
- `POST /api/v1/supplements/check-conflicts` — exact name match first (no LLM), then semantic overlap via LLM; fails open so the user is never blocked
- `SupplementConflict` domain model with `name`, `conflictType`, and `message` fields
- `checkSupplementConflicts` in `TodayRepository` — deserializes endpoint results into `SupplementConflict` objects
- `_ConflictWarningCard` in `_AddEditForm` — 800ms debounce, client-side exact match runs first; "Adjust dose" and "Add anyway" action buttons

### Complete — Plan 10: Timing Suggestions (2026-04-27)

**Status:** Shipped on `feat/supplements-log-overhaul`

What shipped:
- `GET /api/v1/supplements/timing-tip?supplement_name=&timing=` — meal pattern analysis + LLM tip; fails open to empty tip on any error
- `TimingSuggestion` domain model with `tip` and optional `confidence` fields
- `getTimingSuggestion` in `TodayRepository` — calls the timing-tip endpoint
- `ZAlertBanner` (info variant) below the timing grid in `_AddEditForm` — `LinearProgressIndicator` while loading, dismiss button to hide

### Complete — Plan 11: Correlation Insights Screen (2026-04-27)

**Status:** Shipped on `feat/supplements-log-overhaul`

What shipped:
- `GET /api/v1/supplements/insights?days=60` — Pearson r between supplement consistency and DailySummary health metrics; LLM-generated plain-language insight text per correlation; rate-limited at 10/min per user
- `SupplementInsightItem` + `SupplementInsightsResult` domain models
- `getSupplementInsights` in `TodayRepository` — calls the insights endpoint
- `SupplementInsightsScreen` with `insightsProvider` (FutureProvider.autoDispose) — loading, empty, and data states; `_InsightCard` widget per correlation
- Routing: `RouteNames.supplementInsightsPath = '/supplements/insights'` registered in GoRouter
- Entry point: gear icon (`Icons.settings_outlined`) in `_PanelHeader` of `ZSupplementsLogPanel`, navigates via `context.push`

---

## Wellness Log

### Complete — Wellness Log Overhaul (2026-04-27)

**Status:** Shipped on `feat/wellness-log-overhaul`

What shipped:
- Old slider-based panel replaced with an AI-first voice/text check-in system
- Six-state panel: recording → parsing → confirm/edit → saved; plus quick offline face-tap path
- `ZSentimentSelector` shared widget — five-level face icon row, reusable
- `ZAudioVisualizer` shared widget — animated waveform bars during recording
- `logWellness` extended with `tags` and `aiSummary`; stress unit bug fixed (`/100` → `/10`)
- `parseWellnessTranscript` added to `TodayRepository`, returns `WellnessParseResult` domain model
- Backend: `POST /api/v1/wellness/parse` — accepts transcript (max 5,000 chars), LLM extraction, returns `{mood, energy, stress, tags, summary}`, rate-limited 20/min per user, auth required
- 11 backend tests covering happy path, validation, auth, LLM failures, and boundary conditions

---

## Weight Log

### Complete — Weight Log Overhaul (2026-04-26)

**Status:** Shipped on `feat/weight-log-overhaul`

What shipped:
- Large 58px number display with full-height left/right chevron tap zones for 0.1 kg/lbs stepping
- Long-press chevrons for continuous fast-scroll with haptic feedback
- Tap the number to open keyboard for direct decimal entry
- Last-logged weight strip with live delta pill showing trend
- Time-of-day chips (Morning, Afternoon, Evening) auto-selected by current hour, saved as metadata
- Collapsible body fat % row (optional, 0.1% increments, 1–80% range)
- 7-day sparkline visualization using `ZMiniSparkline` component
- Backend: new `GET /api/v1/metrics/weight/history?days=7` endpoint for sparkline data
- `logWeight` now sends `time_of_day` and `body_fat_pct` as structured metadata
- Fixed pre-fill bug where wrong map keys prevented loading previous values
- All tests pass; zero new analyzer issues

---

## Workout

### Plan 1: Foundation + Exercise Catalogue — complete (2026-04-21)

Branch: `feat/workout-plan-1-foundation`

What shipped:
- `assets/data/exercises.json` — 50 bundled exercises across all major muscle groups (no network required)
- `Exercise`, `MuscleGroup`, `Equipment` domain models
- `ExerciseRepository` — offline, in-memory cached, with search + muscle-group filter
- Riverpod providers: `exerciseListProvider`, `exerciseSearchProvider`, `exerciseSearchQueryProvider`, `exerciseMuscleGroupFilterProvider` — all with `autoDispose` and error propagation
- `ExerciseCatalogueScreen` — search bar, muscle-group chip filter, multi-select grid, floating "Start Workout" CTA
- `ExerciseGridTile` — shared widget with muscle-group color coding and selection state
- Stub `WorkoutSessionScreen` and `WorkoutSummaryScreen` (placeholders for Plan 2+)
- 3 new routes: `/log/workout`, `/log/workout/exercises`, `/log/workout/summary`
- Workout tile in `ZLogGridSheet` wired to navigate to `/log/workout` (was "coming soon")
- 26 tests pass; zero new analyzer issues vs main

### Plan 7: Exercise Catalogue Expansion — complete (2026-04-23)

**Status:** Shipped on `feat/exercise-catalogue-expansion`

- Exercise catalogue expanded from 50 to 839 exercises
- Secondary muscle group targeting added to `Exercise` model
- Equipment filtering (Barbell, Dumbbell, Kettlebell, Machine, Bodyweight, Bands) with real-time grid updates
- Image asset pipeline with fallback to muscle-group icons
- All filtering dimensions (muscle group + equipment + search) combined in the catalogue screen

### Plan 6: Workout Polish — complete (2026-04-22)

**Status:** Shipped on `main`

- Global workout pill now has 8px breathing room above and below so it doesn't crowd the nav bar
- Exercise cards collapse/expand Lyfta-style — only one open at a time; collapsed cards show muscle icon + name + sets badge or green checkmark; auto-advances to the next card when the last set is checked off
- Android foreground service notification now shows set count ("Workout 12:34  ·  6 sets" / "Rest  01:30  ·  6 sets")
- Rest-end alert fires immediately when the timer hits zero instead of scheduling a future notification (fixes Doze mode delays on Android)
- `requestNotificationPermission()` called before the foreground service starts, fixing silent notification failure on Android 13+

### Plan 5: Rest Timer Redesign — complete (2026-04-22)

**Status:** Shipped on `fix/rest-timer-redesign`

- Rest timer state moved to Riverpod provider (survives navigation, no Scaffold context issues)
- Full sheet overlay + mini banner UI with drag-to-minimize gesture
- Urgency color at ≤10s, auto-dismiss 3s after expiry
- Persists across app backgrounding, clears on discard/finish

### Plan 2: Active Session Tracking — complete (2026-04-21)

Branch: `feat/workout-plan-1-foundation`

What shipped:
- `WorkoutSession`, `WorkoutExercise`, `WorkoutSet`, `SetType` domain models — immutable, full JSON round-trip, `copyWith` with `_kUnset` sentinel for nullable fields
- `WorkoutSessionNotifier` (`StateNotifier<WorkoutSession?>`) — offline-first with auto-save draft to SharedPreferences (`workout_active_draft`), per-exercise unit override persistence, `toggleUnit` with kg↔lbs conversion
- Derived providers: `workoutDurationProvider` (1 Hz stream), `workoutVolumeProvider`, `workoutSetsCompletedProvider`
- `WorkoutStatsRow` — three-column live stats strip (duration in Activity accent, volume, sets)
- `WorkoutExerciseCard` — muscle-group icon bubble, notes field, rest timer row, set table with tappable unit header and type picker, Add Set button
- `WorkoutSessionScreen` (replaced Plan 1 stub) — start/resume session on mount, catalogue navigation, finish with no-sets guard, discard with confirmation
- 35 new tests (17 provider + 4 widget + 14 domain); 61 workout tests total, all green; zero new analyzer issues

### Plan 3: Summary + History — complete (2026-04-21)

Branch: `feat/workout-plan-1-foundation`

What shipped:
- `CompletedWorkout` + `CompletedExercise` domain models (immutable, JSON round-trip, mixed-unit volume normalized to kg)
- `WorkoutHistoryRepository` — offline-only, capped at 100 entries under SharedPreferences key `workout_history`, most-recent-first
- `WorkoutSessionNotifier.finishSession()` — converts the active session to a `CompletedWorkout`, appends to history, clears the draft
- `workoutHistoryRepositoryProvider` (Provider) + `workoutHistoryProvider` (FutureProvider.autoDispose)
- `WorkoutSummaryScreen` (replaced Plan 1 stub) — header, totals, per-exercise set table, Done button
- `WorkoutHistoryScreen` — list of past workouts, tap to open read-only summary
- New route `/log/workout/history`
- History icon added to `WorkoutSessionScreen` app bar
- GoRouter wired to accept `CompletedWorkout` as extra on the summary route
- 17 new tests (4 domain + 5 repository + 4 provider + 2 summary widget + 2 history widget); 78 workout tests total, all green; zero new analyzer issues

### Plan 4: Workout Overview Screen — complete (2026-04-21)

Branch: `feat/workout-overview-screen`

What shipped:
- `WorkoutOverviewScreen` — landing page when the workout tile is tapped (replaces direct jump into the session screen)
- Hero card showing the last completed workout (duration, volume, sets) with skeleton loading state and empty state
- "Start Workout" button pushing `/log/workout/session`
- AI Summary placeholder card with `ZProBadge(showLock: true)` — coming soon
- Weekly snapshot (last 7 days) showing workout count and total volume
- "View All History" link to the history screen
- Route change: `/log/workout` now shows the overview; new `/log/workout/session` is the live session screen
- Input focus color fix: all outlined input fields across the app now use `colors.primary` (theme-aware) instead of hardcoded `AppColors.categoryNutrition` (orange) or dark-mode-only `AppColors.primary`
- 3 new widget tests for the overview screen; 82 workout tests total, all green; zero new analyzer issues
