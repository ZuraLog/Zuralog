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

### Plan 3: History + Progress — not started
