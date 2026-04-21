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
