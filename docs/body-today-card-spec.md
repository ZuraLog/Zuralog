# Body Today Card — Design Spec

**Date:** 2026-04-24  
**Status:** Approved  
**Scope:** Flutter mobile app (`zuralog/`) + FastAPI backend (`cloud-brain/`)

---

## Overview

The "Your Body Today" card is the hero card on the Today tab. It gives users a full-body snapshot across all four pillars — Nutrition, Fitness, Sleep, and Heart — alongside a visual muscle state map they can update manually. Currently the card runs entirely on hardcoded demo data. This spec defines the redesigned card, its data connections, its states, and the body logging feature with time, persistence, and next-day check-in.

---

## 1. Card Title

**Change:** "Your Body Now" → **"Your Body Today"**

"Now" is inaccurate — sleep data is from last night, average heart rate is from yesterday, calories accumulate across the day. "Today" is honest about the 24-hour window and aligns with the Today tab's name.

---

## 2. Removed Elements

- **Readiness score** — removed entirely from the card. It was shown as a prominent number (e.g., "86") above the metrics rail. No replacement. The muscle state headline takes the top position instead.
- **Legend** — removed. The Fresh / Worked / Sore colour coding on the silhouette is self-evident from context and the detail sheet.

---

## 3. Card Structure (Final)

```
ZuralogCard (hero variant, animated pattern)
├── Eyebrow row — "YOUR BODY TODAY" dot + label
├── Silhouette — coloured by muscle state (front half only in hero)
├── Metrics rail — 4 chips, one per pillar
└── Coach strip — Zura (CoachBlob) + message + optional CTA button
    (hidden when Zura has nothing to say)
```

---

## 4. Metrics Rail — 4 Pillars

Each chip maps to exactly one pillar. The chip shows the pillar's colour from the design system.

| Chip | Pillar | Metric | Source | Colour token |
|------|--------|--------|--------|--------------|
| Nutrition | Nutrition | Calories today (kcal) | `NutritionEntry.calories` | `categoryNutrition` (#FF9F0A) |
| Fitness | Fitness | Steps today | `DailyHealthMetrics.steps` | `categoryActivity` (#30D158) |
| Sleep | Sleep | Duration last night (hours + minutes) | `SleepRecord.hours` | `categorySleep` (#5E5CE6) |
| Heart | Heart | Average HR yesterday (bpm) | `DailyHealthMetrics.heart_rate_avg` | `categoryHeart` (#FF375F) |

**Delta display:** Each chip shows a delta vs. the previous day's value where available (e.g., "+1.2k steps", "+18m sleep"). Shown below the value in a small label. Positive deltas for Nutrition, Fitness, Sleep use `categoryActivity` green. Negative delta for Heart rate (lower avg HR = good) uses `categoryActivity` green. The direction of "good" is metric-specific.

**No-data chip:** When a chip's data source returns null, the value shows `—` in a muted opacity (28%). The chip label and colour dot still render — the structure never collapses.

---

## 5. Card States

The card always renders with its full structure. There is no separate "zero state" widget — the same card layout handles all states through data availability.

### State 1 — Zero (nothing connected)
- All 4 chips show `—`
- Silhouette is fully neutral (all muscles grey)
- Headline shows the muted placeholder text: "Your body snapshot will appear here" (Body Medium, Text Secondary colour, 45% opacity)
- Coach strip **visible** — Zura invites the user to connect a source:
  > "Hey! Connect Apple Health or your watch and I can start showing you how your body is actually doing each day. Sleep, steps, heart, the whole picture."
  - CTA button: "Go to Settings →" (navigates to integrations screen)

### State 2 — Partial (some pillars have data)
- Chips with data show live values; chips without show `—`
- Silhouette remains neutral (muscle state requires manual logging or workout data)
- Coach strip **visible** — Zura acknowledges what's there and nudges toward gaps:
  > "Good start! I can see your steps coming in. Add your sleep and heart data and I can give you a proper read on how your body is doing."
  - CTA button: "Connect more →" (navigates to integrations screen)

### State 3 — Full (all pillars have data)
- All 4 chips show live values with deltas
- Silhouette coloured by computed muscle state
- Coach strip **visible** when there is a meaningful insight — Zura gives a personalised daily read based on muscle state + metrics
- Coach strip **hidden** when there is no useful thing to say (edge case)

---

## 6. Backend Wiring — Flutter Providers

All four pillar metrics must be fetched from the backend via `GET /api/v1/metrics/latest`. The current provider stubs (`hrvTodayProvider`, `rhrTodayProvider`, `sleepLastNightProvider`) must be replaced or wired.

### New providers to wire

| Provider | Metric key | Backend field | Notes |
|----------|-----------|---------------|-------|
| `caloriesTodayProvider` | `calories` | `NutritionEntry.calories` | Today's total |
| `stepsTodayProvider` | `steps` | `DailyHealthMetrics.steps` | Today's total |
| `sleepLastNightProvider` | `sleep_duration` | `SleepRecord.hours` | Last night (most recent record) |
| `avgHrYesterdayProvider` | `heart_rate_avg` | `DailyHealthMetrics.heart_rate_avg` | Yesterday's date |

The backend endpoint `GET /api/v1/metrics/latest` already accepts a `types` query param. The implementer must confirm that `calories`, `steps`, `sleep_duration`, and `heart_rate_avg` are all valid values for that param. Any key not currently supported must be added to the route handler and its corresponding query logic before the Flutter providers are wired.

### `make run-mock`

The backend mock server (`make run-mock`) must return plausible seeded values for all four metric keys so the Flutter app renders a full card without real wearable data during development. Seed values:

```json
{
  "calories": { "value": 1240, "previous": 1800 },
  "steps": { "value": 6432, "previous": 5200 },
  "sleep_duration": { "value": 7.7, "previous": 7.4 },
  "heart_rate_avg": { "value": 78, "previous": 74 }
}
```

### Removed providers

`readinessScoreProvider`, `bodyNowMetricsProvider` (the composite bundle), `hrvTodayProvider`, `rhrTodayProvider` — remove or archive these. The new individual pillar providers replace them. The `readiness_score.dart` domain model can be removed.

---

## 7. Zura Coach Strip

**Widget:** Replace the current custom "Z" avatar in `BodyNowCoachStrip` with the existing `CoachBlob` widget (from `features/coach/presentation/widgets/coach_blob.dart`). This makes the Zura avatar consistent between the Today card and the Coach tab.

**Visibility rule:** The coach strip renders only when `bodyNowCoachMessageProvider` returns a non-null message. It is entirely absent from the layout when null (no empty space reserved).

**No em dashes** in any Zura message string. Use plain sentence structure.

---

## 8. Body Logging — Detail Sheet

Tapping the hero card opens `BodyDetailSheet` (existing draggable bottom sheet). The sheet shows enlarged front and back body figures side by side. Tapping a muscle region opens the state picker.

### 8a. State Picker — Updated

The existing `MuscleStatePickerSheet` gains a **time field**.

**Layout:**
1. Muscle name (large, bold)
2. Current state badge ("Currently: Sore")
3. Three state options — Fresh / Worked / Sore (existing)
4. Time section:
   - Label: "When did this happen?"
   - Row showing: clock icon + "Today at" + current time value
   - Tapping the row opens the platform time picker (Flutter `showTimePicker`)
   - Date is always today — no date picker, only time
   - Defaults to the current time on open
5. Save button (primary, sage)
6. "Clear override" text link below

**Time field behaviour:**
- Time is stored as metadata alongside the muscle state log entry
- Time does **not** drive automated state transitions — it is for logging context only
- When the user re-opens the picker for a muscle already logged today, the previously saved time pre-fills the field

### 8b. Log History Strip

At the bottom of `BodyDetailSheet`, a "Logged today" section lists all muscle entries saved today, each showing:
- Colour dot (state colour)
- Muscle name
- State label (Fresh / Worked / Sore)
- Time logged (e.g., "6:00 AM")

Entries are tappable to re-open the picker and edit. This strip is hidden when nothing has been logged yet today.

### 8c. "Clear all" button

Clears all muscle logs for today. This means:
1. Delete all Hive entries for today's date locally (immediate, no connectivity needed)
2. Fire `DELETE /api/v1/muscle-logs?date=today` to remove them from the backend
3. If offline, queue the delete for sync — same offline-first pattern as saves
4. Silhouette resets to all-neutral immediately after clearing

---

## 9. Muscle Log Persistence

### Data model

A new backend table: `muscle_logs`

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID | Primary key |
| `user_id` | UUID FK | Owner |
| `log_date` | Date | The calendar day this log belongs to (always today at time of creation) |
| `muscle_group` | Enum/string | e.g., `shoulders`, `quads`, `chest` |
| `state` | Enum/string | `fresh`, `worked`, `sore` |
| `logged_at_time` | Time | Time-of-day the user selected (no timezone — local) |
| `created_at` | Timestamp | Server receive time |
| `updated_at` | Timestamp | Last update |

One row per user / date / muscle group. Upsert on duplicate.

### Daily reset

"Reset" means: on each new calendar day, the previous day's logs are preserved in the database (for Zura's history reasoning) but are **not loaded** as today's state. The Flutter app queries logs filtered to `log_date = today`. Yesterday's logs do not carry forward automatically.

### Offline-first sync

Follows the same pattern as workout logging:
1. Log entry is written immediately to **Hive** (local on-device storage, same package already used for workout logging)
2. UI reflects the local state instantly
3. A background sync queue sends pending logs to `POST /api/v1/muscle-logs` when connectivity is available
4. On reconnect, any queued logs are flushed in order
5. Conflict resolution: server timestamp wins for same user/date/muscle combination

### New API endpoints

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/v1/muscle-logs` | Returns all logs for `?date=YYYY-MM-DD` for the authenticated user |
| `POST` | `/api/v1/muscle-logs` | Upsert one log entry (muscle + state + time) |
| `DELETE` | `/api/v1/muscle-logs` | Delete all logs for `?date=YYYY-MM-DD` (used by "Clear all") |

---

## 10. Next-Day Check-In

### Trigger condition

On first app open of a new calendar day, if the user logged **any muscle as "Sore"** on the previous day, the `bodyNowCoachMessageProvider` returns a check-in message instead of the regular insight.

### Message variants

**One sore muscle:**
> "Your [muscle name] was sore yesterday. How are they feeling this morning?"

**Multiple sore muscles:**
> "A few things were sore yesterday. Worth a quick check before you plan your day."

### UI

The message renders in the existing coach strip. Below the message text, a single outlined button:

```
[ How do you feel now? ]
```

Tapping this button opens `BodyDetailSheet`. If it was a single sore muscle, that muscle is pre-highlighted (picker opens directly for it). If multiple, the full body map opens.

The check-in strip persists in the card for the entire day — scrolling past it does not dismiss it, so the user can come back to it. It disappears only when the user taps "How do you feel now?" (regardless of whether they save anything in the body map). This is stored locally as a `checkin_seen_date` flag (date string). On the next calendar day the flag is irrelevant and the check-in logic re-evaluates from scratch.

### Non-intrusiveness rules

- Never triggers a push notification
- Only fires once per day, only on first open
- The user can scroll past it without responding — no modal, no blocker
- "Skip" is implicit: just scroll away

---

## 11. UI Consistency Fixes

Apply across all widgets in the `body_now/` folder and `body/` feature:

- Replace the "Z" text avatar in `BodyNowCoachStrip` with `CoachBlob` (matches Coach tab)
- Remove the `ReadinessScore` domain model and all references
- Remove the `BodyNowMetrics` bundle model; replace with individual pillar providers
- Remove the legend from `BodyDetailSheet`
- Ensure all elevation levels match the design system (`Surface` for cards, `SurfaceOverlay` for sheets)
- Ensure all chip text uses `Plus Jakarta Sans` at the correct weight (Label Small, Medium 500)
- No em dashes in any user-facing string

---

## 12. Nice-to-Have (Out of Scope for This Sprint)

These were surfaced during design but deferred:

- **Workout-driven muscle state:** Auto-suggest muscle states based on logged Strava/HealthKit workouts (e.g., a leg day run → prompt "did quads get worked?")
- **Recovery timer display:** "Quads ready in ~18 hours" shown on the detail sheet per muscle, computed from logged time
- **Soreness history in Coach:** Zura can surface patterns like "you've had sore shoulders 4 times this month" in the Coach tab conversation
- **Intensity field:** Light / Moderate / Heavy alongside Fresh / Worked / Sore for more granular logging

---

## Decisions Log

| Decision | Choice | Reason |
|----------|--------|--------|
| Card title | "Your Body Today" | Data spans the full day, not a live snapshot |
| Heart metric | Average HR yesterday | More available than resting HR; works without passive overnight monitoring |
| Readiness score | Removed | Adds complexity without a clear home; not a pillar |
| Legend | Removed | Colour coding is self-evident |
| Zero state | Same card, dashes + Zura | Avoids a separate empty-state widget; Zura gives the card purpose |
| Zura avatar | CoachBlob | Consistency with Coach tab |
| Time picker | Time only, date = today | Simpler than date+time; logs are always for the current day |
| Time effect on state | None (metadata only) | Avoids auto-resetting state the user didn't intend |
| Daily reset | New day = new query, old data preserved | Enables Zura history reasoning |
| Log storage | Backend DB + offline-first local cache | Zura needs access; must work without connectivity |
| Check-in mechanism | Button in coach strip, opens body map | Non-intrusive; reuses existing logging flow |
