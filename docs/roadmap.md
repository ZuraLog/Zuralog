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

### Plan 2: Active Session Tracking — not started

### Plan 3: History + Progress — not started
