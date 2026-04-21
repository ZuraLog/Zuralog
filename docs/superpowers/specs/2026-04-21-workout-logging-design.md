# Workout Logging — Design Spec
**Date:** 2026-04-21
**Status:** Approved for implementation

---

## What This Is

A live workout logging feature on the Today Tab. The user opens ZuraLog at the gym, starts a blank session, logs every exercise and set as they actually do them, finishes, and saves. The workout syncs to the ZuraLog backend so Zura (the AI) can see it.

---

## What This Is NOT

- Saved routines or templates (v2)
- Workout history / detail screen (separate task)
- WorkoutsPillarCard data wiring (separate task)
- Exercise illustrations / GymVisual assets (deferred — placeholders for now)
- Celebratory notifications
- Social features
- Wearable / watch integration

---

## Architecture Approach: Offline-First Session + Sync Queue

The user must be able to log and finish a workout with no internet. This is non-negotiable — gyms often have poor signal.

**How it works:**

1. Active session lives in a Riverpod `StateNotifier` (`WorkoutSessionNotifier`)
2. Every time the user adds a set or changes data, the full session is auto-saved as JSON to SharedPreferences under the key `'workout_active_draft'`
3. On finish:
   - If online → POST the completed workout to Cloud Brain immediately, clear draft
   - If offline → serialize the completed workout and append to a pending queue in SharedPreferences (`'workout_sync_queue'`), clear draft
4. On app resume and on connectivity restored → check `'workout_sync_queue'`, POST any pending workouts to Cloud Brain, clear the queue on success
5. On app launch → if `'workout_active_draft'` exists, show a "Resume your workout?" recovery banner on the Today tab

**Session data structure (in-memory and draft):**
```
WorkoutSession {
  id: String (UUID, generated at session start)
  startedAt: DateTime
  exercises: List<WorkoutExercise>
}

WorkoutExercise {
  exerciseId: String
  exerciseName: String
  muscleGroup: String
  sets: List<WorkoutSet>
  notes: String?
  restTimerEnabled: bool
  restTimerWarmUpSeconds: int   // default 90
  restTimerWorkingSeconds: int  // default 90
  unitOverride: String?         // 'metric' | 'imperial' | null (null = use global default)
}

WorkoutSet {
  setNumber: int
  type: SetType  // warmUp | working
  weightValue: double?
  reps: int?
  isCompleted: bool
  previousRecord: String?  // e.g. "50kg x 12" — from locally cached last session; blank if no cache
}
```

---

## Exercise Catalogue Data

- A bundled JSON asset file ships inside the Flutter app (`assets/data/exercises.json`)
- Source: public domain exercise metadata (wrkout/exercises.json or equivalent)
- Fields per exercise: `id`, `name`, `muscleGroup`, `equipment`, `instructions`
- Fully offline — no API call needed to browse or select exercises
- Placeholder image: a color-coded icon based on `muscleGroup` (no exercise-specific illustrations for now)
- GymVisual illustrated assets are noted for a future upgrade (see library research)

**Muscle groups covered:**
Chest, Back, Shoulders, Biceps, Triceps, Forearms, Abs, Quads, Hamstrings, Glutes, Calves, Cardio, Full Body, Other

---

## New Routes

Three new full-screen routes pushed over the shell (same pattern as `RunLogScreen`, `SleepLogScreen` — no bottom nav visible):

| Route | Screen | Purpose |
|-------|--------|---------|
| `/log/workout` | `WorkoutSessionScreen` | Active live workout session |
| `/log/workout/exercises` | `ExerciseCatalogueScreen` | Browse + search + add exercises |
| `/log/workout/summary` | `WorkoutSummaryScreen` | Review + interview + save |

Added to `RouteNames`: `workoutLog`, `workoutExercises`, `workoutSummary`

**Entry point:** The `'workout'` tile in `ZLogGridSheet` changes from `comingSoon` to `fullScreen → RouteNames.workoutLog`.

---

## Screen 1: Active Workout Session (`WorkoutSessionScreen`)

### Header bar
- Left: collapse/minimize icon (folds the screen into a floating persistent indicator — future enhancement, noted but not in scope for v1)
- Center: stopwatch icon
- Right: **Finish** button (pill-shaped, teal/brand color)

### Stats row (below header)
Three stats shown at all times, updating live:
- **Duration** — elapsed time from session start, formatted as `h:mm:ss`, shown in brand accent color
- **Volume** — total weight moved (sum of weight × reps for all completed sets), shown in kg or lbs based on the user's global unit preference
- **Sets** — total number of completed sets across all exercises

### Exercise list
Each exercise added shows as a card in this order:
1. Exercise thumbnail (placeholder icon, color-coded by muscle group) + exercise name + 3-dot context menu
2. Notes field (tappable placeholder text "Notes...")
3. Rest timer row (see Rest Timer section below)
4. Set table header row: `Set | Previous | [lbs/kg] | Reps`
5. Set rows (see Set Logging section below)
6. **+ Add Set** button at bottom of each exercise card

### Bottom buttons (below all exercises)
- **Add Exercises** — navigates to `ExerciseCatalogueScreen`
- **More** — bottom sheet with: Share Workout, Pause Workout, Add Photo, Add Notes, Workout Settings, Discard Workout

---

## Screen 1a: Set Logging (within `WorkoutSessionScreen`)

Each set row has four columns:

| Column | Content |
|--------|---------|
| Set # | Number (1, 2, 3…). First set defaults to type `warmUp`, subsequent sets default to `working`. Tapping the set number opens a type picker: Warm-Up / Working / Drop Set / Failure / AMRAP |
| Previous | Shows the weight × reps from the same exercise in the user's last workout (e.g. `50kg × 12`). Read-only, greyed out. Sourced from a locally cached copy of the last session (written to SharedPreferences after each successful save); blank if no cached history exists |
| Weight | Editable number field. Pre-fills with the previous session's weight if available |
| Reps | Editable number field |
| Checkmark | Tapping marks the set as completed. Triggers the rest timer if enabled for this exercise |

### Units (lbs / kg) — per-exercise memory
- The column header shows either `lbs` or `kg` as tappable text
- Tapping toggles the unit for this exercise only (converts existing values)
- The override persists in SharedPreferences under `'workout_exercise_unit_{exerciseId}'`
- On next open of the same exercise, the app restores the last-used unit
- If no override exists, defaults to the global `unitsSystemProvider` value (metric → kg, imperial → lbs)
- The user's global default in Settings is never changed by this interaction

---

## Screen 2: Exercise Catalogue (`ExerciseCatalogueScreen`)

### Top bar
- Title: "Add Exercises"
- Search icon → expands to full search bar
- Filter icon → secondary filter sheet (equipment type)
- + icon → create custom exercise (future, noted but not in scope v1)

### Muscle group filter strip (horizontal scroll)
- Body silhouette icons, one per muscle group — tapping filters the list below
- Unfiltered (all) is the default

### Recent Performed section
- Shows the last 5–10 exercises the user has logged in previous sessions, in order of most recent
- Populated from sync'd session history

### Exercise grid
- Two-column grid
- Each card: placeholder image (muscle-group color tile), exercise name, muscle group label
- Bookmark icon on each card (save as favourite — future, noted)

### Selection behaviour
- Tapping a card selects/deselects it (checkmark overlay appears)
- Multiple exercises can be selected at once
- Bottom of screen shows "Add Exercise" button with count (e.g. "Add 3 Exercises")

---

## Rest Timer (per-exercise, baked into exercise row)

### Toggle row inside each exercise
Appears below the Notes field, above the set table. Matches the Lyfta layout from the reference screenshot:
- Stopwatch icon + label "Rest Timer"
- Toggle switch (ON/OFF)
- When ON: shows current duration (e.g. "1 min 30s"), tappable to open duration picker

### Duration picker
Bottom sheet, opens when the user taps the duration:
- Two segments: **Warm-Up Sets** / **Working Sets**
- Scroll picker for each (options in 15-second increments: 0:30, 0:45, 1:00, 1:15, 1:30, 2:00, 2:30, 3:00, 3:30, 4:00, 4:30, 5:00)
- Done button

### Default behaviour
- Rest timer is **ON by default** for all exercises, **90 seconds** for both warm-up and working sets
- Per-exercise setting persists in SharedPreferences under `'workout_rest_timer_{exerciseId}'`

### What happens when a set is checked off
1. Rest timer popup slides up from the bottom of the screen
2. Shows the countdown (large text), the exercise name, and set type (warm-up or working, uses the corresponding duration)
3. Three controls: **Skip** (dismisses immediately), **+1:00** (adds 60 seconds), current time is tappable to edit
4. The popup does NOT block the screen — the user can scroll, edit other sets, tap elsewhere
5. Tapping outside the popup minimizes it to a persistent pill at the very bottom of the screen showing the remaining time
6. When timer reaches 0: haptic buzz, pill flashes briefly, then fades
7. If rest timer is OFF for this exercise: no popup, nothing happens

---

## Screen 3: Workout Summary + Interview (`WorkoutSummaryScreen`)

### Summary section
- Total duration
- Total volume (formatted in user's unit)
- Total sets completed
- List of every exercise with each set logged (set type, weight, reps)

### Interview section (3 questions, quick taps)
These feed directly into Zura's context for the day:

1. **How hard was today?** — 5-tap effort scale (1 = very easy → 5 = max effort)
2. **How did you feel going in?** — 3 options: Low energy / Normal / High energy (tap to select)
3. **Anything to note?** — optional open text field, 500 char max

All three are optional. The user can tap Save without answering any of them.

### Save button
- Triggers the offline/online logic described in the Architecture section
- If save succeeds: pop all workout routes, return to Today tab, show a toast "Workout saved"
- If offline: show a toast "Saved locally — will sync when you're back online"
- After save, invalidate `todayLogSummaryProvider`, `progressHomeProvider`, `goalsProvider` (same as RunLogScreen)

---

## Backend — Cloud Brain

### New endpoint: `POST /api/v1/workouts`
Request body:
```json
{
  "session_id": "uuid",
  "started_at": "2026-04-21T10:00:00Z",
  "finished_at": "2026-04-21T10:45:00Z",
  "exercises": [
    {
      "exercise_id": "bench_press",
      "exercise_name": "Bench Press",
      "muscle_group": "Chest",
      "sets": [
        { "set_number": 1, "type": "warm_up", "weight_kg": 40.0, "reps": 15, "completed": true },
        { "set_number": 2, "type": "working", "weight_kg": 80.0, "reps": 8, "completed": true }
      ],
      "notes": "Felt strong today"
    }
  ],
  "perceived_effort": 4,
  "energy_level": "high",
  "user_notes": "Great session overall"
}
```

Response: `201 Created` with the saved workout object including a server-assigned ID.

### Existing sync (no change)
The existing `HealthSyncService` continues to sync workouts from Apple Health / Health Connect as `exercise_minutes` events. This new manual logging is separate and additive — it sends richer data (individual exercises, sets, weight, reps) that the passive health sync cannot provide.

---

## What Changes in Existing Code

| File | Change |
|------|--------|
| `z_log_grid_sheet.dart` | Change `'workout'` tile from `comingSoon` to `fullScreen → RouteNames.workoutLog` |
| `app_router.dart` | Add 3 new routes: `/log/workout`, `/log/workout/exercises`, `/log/workout/summary` |
| `route_names.dart` | Add `workoutLog`, `workoutExercises`, `workoutSummary` constants |
| `today_providers.dart` | No change — invalidation of existing providers on save (same as RunLogScreen) |

---

## Out of Scope (Tracked for Later)

- **WorkoutsPillarCard real data** — currently shows hardwired mock data; wiring it to real backend data is a separate task
- **Workout history / detail screen** (`/workout`, `/workout/all-data`) — same pattern as Sleep and Heart detail screens, separate task
- **GymVisual exercise illustrations** — replace placeholders once illustrations are purchased
- **Saved routines / templates** — build on top of this logging foundation
- **Custom exercise creation** — `+` icon in catalogue is a noted future feature
- **Bookmark / favourite exercises** — noted, not in scope
