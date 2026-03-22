# Unified Health Data Architecture

**Date:** 2026-03-22
**Status:** Approved
**Scope:** Full backend database and API refactor — Cloud Brain + Supabase

---

## 1. Problem Statement

The current backend has 7+ separate health data tables (`quick_logs`, `daily_health_metrics`,
`sleep_records`, `weight_measurements`, `nutrition_entries`, `blood_pressure_records`,
`unified_activities`). Each time a new integration or metric is added, multiple tables must
be updated, migrations written, and sync logic maintained manually.

The result: data logged in the Today tab does not appear in the Data tab unless a manual
"mirror" sync is coded for each metric individually. Only water and wellness were wired up;
every other metric (sleep, steps, weight, meals, runs) is silently dropped.

The architecture cannot scale to 1 million users, cannot support unpredictable future
integrations cleanly, and breaks every time a new data source is added.

---

## 2. Goals

- Single source of truth for all health data
- Any new metric type requires zero schema migrations
- Any new integration (Garmin, Oura, Whoop, etc.) requires zero schema changes
- Manual logs and device syncs are additive and unified — always summed per day
- All 6 app tabs (Today, Data, Coach, Progress, Trends, Settings) read from the same
  consistent data layer
- Supports 1 million users with proper indexing; upgradeable to TimescaleDB without
  schema changes
- Full audit trail — raw events are never deleted or modified

---

## 3. Architecture Decision

**Event Sourcing with a pre-aggregated read cache (CQRS pattern).**

All health data writes go to one append-only `health_events` table. A triggered aggregation
process maintains `daily_summaries` as a pre-computed read cache. All app tabs read from
`daily_summaries`. Raw events are preserved forever for recomputation, auditing, and AI
context.

This is the same pattern used internally by Apple Health, Google Fit, Oura, and FHIR-
compliant health platforms.

---

## 4. Database Schema

### 4.1 `health_events` — Source of Truth

Every health measurement ever recorded, from any source, lands here as one row.
Append-only. Never updated. Never deleted.

```sql
CREATE TABLE health_events (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    metric_type     TEXT NOT NULL,          -- e.g. "steps", "water_ml", "mood"
    value           FLOAT NOT NULL,         -- the primary numeric value
    unit            TEXT NOT NULL,          -- e.g. "steps", "ml", "/10"
    source          TEXT NOT NULL,          -- "apple_health" | "manual" | "fitbit" | "garmin" | ...
    recorded_at     TIMESTAMPTZ NOT NULL,   -- when the health event actually occurred (device local time)
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(), -- when we received it
    granularity     TEXT NOT NULL DEFAULT 'point_in_time', -- "point_in_time" | "daily_aggregate"
    session_id      UUID,                   -- links measurements from the same event (nullable)
    metadata        JSONB                   -- extra structured fields (meal_type, effort_level, etc.)
);

-- Primary read pattern: user's history for a metric
CREATE INDEX idx_health_events_user_metric_time
    ON health_events (user_id, metric_type, recorded_at DESC);

-- Secondary read pattern: all events for a user in a time window
CREATE INDEX idx_health_events_user_time
    ON health_events (user_id, recorded_at DESC);

-- Session lookup: get all measurements from one activity/sleep/BP session
CREATE INDEX idx_health_events_session
    ON health_events (session_id)
    WHERE session_id IS NOT NULL;
```

**Key design decisions:**

- `recorded_at` stores the timestamp in the device's local timezone (converted to UTC with
  offset preserved). This ensures "what day was this?" is answered correctly per user.
- `granularity = 'daily_aggregate'` is used when a device (e.g. Apple Health) sends one
  number representing the entire day (e.g. total daily steps). `point_in_time` is used for
  individual log entries (e.g. 250ml water logged at 2:34pm).
- `session_id` is optional. It is populated when multiple metrics belong to the same event:
  a run (distance + duration + pace + HR + calories), a sleep night (duration + deep +
  REM + efficiency), or a blood pressure reading (systolic + diastolic).
- `metadata` JSONB stores supplementary context that does not need to be queried directly:
  meal description, run route, symptom notes, supplement names, etc.

---

### 4.2 `activity_sessions` — Session Metadata

Stores session-level information for grouped events. A session represents one real-world
event (a run, a sleep night, a blood pressure reading) that produced multiple measurements.

```sql
CREATE TABLE activity_sessions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    activity_type   TEXT NOT NULL,   -- "run" | "walk" | "sleep" | "blood_pressure" | "strength" | ...
    source          TEXT NOT NULL,
    started_at      TIMESTAMPTZ NOT NULL,
    ended_at        TIMESTAMPTZ,
    notes           TEXT,
    metadata        JSONB,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_activity_sessions_user_type_time
    ON activity_sessions (user_id, activity_type, started_at DESC);
```

`activity_sessions.id` is the `session_id` stored in `health_events`. The session record
holds the "container" (what kind of event, when it started/ended); the individual metric
rows in `health_events` hold the measurements.

---

### 4.3 `daily_summaries` — Read Cache

Pre-aggregated daily totals per metric per user. Automatically maintained. Never written
to directly by the app — only by the aggregation layer. All analytics endpoints read from
this table.

```sql
CREATE TABLE daily_summaries (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    date            DATE NOT NULL,          -- user's local date (derived from recorded_at + user timezone)
    metric_type     TEXT NOT NULL,
    value           FLOAT NOT NULL,
    unit            TEXT NOT NULL,
    event_count     INTEGER NOT NULL DEFAULT 1,  -- number of raw events that contributed
    computed_at     TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (user_id, date, metric_type)     -- one aggregated row per user per day per metric
);

-- Primary read pattern: user's trend for a metric over a date range
CREATE INDEX idx_daily_summaries_user_metric_date
    ON daily_summaries (user_id, metric_type, date DESC);

-- Secondary read pattern: all metrics for a user on a specific date (Today tab)
CREATE INDEX idx_daily_summaries_user_date
    ON daily_summaries (user_id, date DESC);
```

**Aggregation rules** (defined per metric in `metric_definitions`):

| Rule | Meaning | Example metrics |
|------|---------|-----------------|
| `sum` | Add all values from all sources for the day | steps, water_ml, active_calories, distance, exercise_minutes |
| `avg` | Average all values from all sources for the day | resting_heart_rate, hrv_ms, mood, energy, stress, blood_glucose |
| `latest` | Use the most recent value recorded that day | weight_kg, body_fat_percentage, vo2_max |

Manual logs and device data are always combined using this rule. There is no source
priority — all sources contribute equally. A 200-step manual log adds to a 10,000-step
Apple Watch sync to produce 10,200 total steps.

---

### 4.4 `metric_definitions` — Metric Registry

The configuration table that makes the schema dynamic. Adding a new metric type requires
inserting one row here — no migrations, no code changes.

```sql
CREATE TABLE metric_definitions (
    metric_type         TEXT PRIMARY KEY,   -- canonical slug, e.g. "steps", "water_ml"
    display_name        TEXT NOT NULL,      -- e.g. "Steps", "Water"
    unit                TEXT NOT NULL,      -- e.g. "steps", "mL", "bpm", "/10"
    category            TEXT NOT NULL,      -- "activity" | "sleep" | "heart" | "body" | "vitals" |
                                            -- "nutrition" | "wellness" | "mobility" | "cycle" | "environment"
    aggregation_fn      TEXT NOT NULL,      -- "sum" | "avg" | "latest"
    data_type           TEXT NOT NULL,      -- "integer" | "float" | "score" | "duration"
    is_active           BOOLEAN NOT NULL DEFAULT true,
    display_order       INTEGER NOT NULL DEFAULT 0,  -- sort order within category
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

**Initial metric definitions:**

| metric_type | display_name | unit | category | aggregation_fn |
|-------------|--------------|------|----------|----------------|
| steps | Steps | steps | activity | sum |
| active_calories | Active Calories | kcal | activity | sum |
| distance | Distance | m | activity | sum |
| exercise_minutes | Exercise Minutes | min | activity | sum |
| walking_speed | Walking Speed | m/s | activity | avg |
| running_pace | Running Pace | s/km | avg | activity |
| floors_climbed | Floors Climbed | floors | activity | sum |
| sleep_duration | Sleep Duration | hours | sleep | latest |
| deep_sleep_minutes | Deep Sleep | min | sleep | latest |
| rem_sleep_minutes | REM Sleep | min | sleep | latest |
| sleep_efficiency | Sleep Efficiency | % | sleep | latest |
| sleep_quality | Sleep Quality | score | sleep | latest |
| resting_heart_rate | Resting Heart Rate | bpm | heart | avg |
| hrv_ms | HRV | ms | heart | avg |
| vo2_max | VO₂ Max | mL/kg/min | heart | latest |
| respiratory_rate | Respiratory Rate | brpm | heart | avg |
| heart_rate_avg | Avg Heart Rate | bpm | heart | avg |
| weight_kg | Weight | kg | body | latest |
| body_fat_percentage | Body Fat | % | body | latest |
| body_temperature | Body Temperature | °C | body | avg |
| wrist_temperature | Wrist Temperature | °C | body | avg |
| muscle_mass_kg | Muscle Mass | kg | body | latest |
| blood_pressure_systolic | Blood Pressure (Sys) | mmHg | vitals | avg |
| blood_pressure_diastolic | Blood Pressure (Dia) | mmHg | vitals | avg |
| spo2 | Blood Oxygen | % | vitals | avg |
| blood_glucose | Blood Glucose | mmol/L | vitals | avg |
| calories | Calories | kcal | nutrition | sum |
| protein_grams | Protein | g | nutrition | sum |
| carbs_grams | Carbs | g | nutrition | sum |
| fat_grams | Fat | g | nutrition | sum |
| water_ml | Water | mL | nutrition | sum |
| mood | Mood | /10 | wellness | avg |
| energy | Energy | /10 | wellness | avg |
| stress | Stress | /100 | wellness | avg |
| mindful_minutes | Mindful Minutes | min | wellness | sum |
| cycle_day | Cycle Day | day | cycle | latest |
| noise_exposure | Noise Exposure | dB | environment | avg |
| uv_index | UV Index | UV | environment | avg |

---

### 4.5 Non-Health Tables (unchanged or minor updates)

These tables are not affected by this refactor:

| Table | Purpose | Changes |
|-------|---------|---------|
| `users` | Identity, profile, profile picture URL | Add `timezone` col if not present |
| `user_preferences` | Settings, units, layout, notifications | Keep as-is (already has JSONB) |
| `user_goals` | Target values per metric per period | Update `metric` column to use `metric_type` slugs from `metric_definitions` |
| `conversations` | Coach chat history | None |
| `insights` | AI-generated insight cards | None |
| `achievements` | Gamification unlock state | None |
| `user_streaks` | Streak counters per metric | Update metric references to new slugs |
| `journal_entries` | Free-text daily reflections | Keep as-is |

**Tables being removed:**

- `quick_logs` → replaced by `health_events`
- `daily_health_metrics` → replaced by `daily_summaries`
- `sleep_records` → data migrates to `health_events` + `daily_summaries`
- `weight_measurements` → data migrates to `health_events` + `daily_summaries`
- `nutrition_entries` → data migrates to `health_events` + `daily_summaries`
- `blood_pressure_records` → data migrates to `health_events` + `daily_summaries`
- `unified_activities` → data migrates to `health_events` + `activity_sessions`

---

## 5. Data Flow

### 5.1 Write Path (any data source)

```
Manual log (Today tab)          Apple Health sync         Future: Garmin webhook
        │                               │                          │
        ▼                               ▼                          ▼
POST /api/v1/ingest            POST /api/v1/ingest        POST /api/v1/ingest
        │                               │                          │
        └───────────────────────────────┴──────────────────────────┘
                                        │
                                        ▼
                              INSERT into health_events
                              (metric_type, value, source,
                               recorded_at, session_id, metadata)
                                        │
                                        ▼
                           Recompute daily_summaries
                           for affected (user_id, date, metric_type)
                           using aggregation_fn from metric_definitions
```

The aggregation step runs synchronously within the same request for manual logs (fast,
single metric). For bulk device syncs (Apple Health sending 30 days of data at once),
the aggregation runs as a background task after the insert batch completes.

### 5.2 Aggregation Logic

For each affected `(user_id, date, metric_type)`:

```
1. Query all health_events for this user + date + metric_type
2. Apply aggregation_fn from metric_definitions:
   - sum:    total = SUM(value)
   - avg:    total = AVG(value)
   - latest: total = value WHERE recorded_at = MAX(recorded_at)
3. UPSERT into daily_summaries (insert or update on conflict)
```

### 5.3 Timezone Handling

The `date` stored in `daily_summaries` is the user's **local date**, not UTC.

When a `health_event` arrives:
1. Look up `user_preferences.timezone` for the user (e.g. "America/New_York")
2. Convert `recorded_at` (UTC) to the user's local time
3. Extract the local date (YYYY-MM-DD)
4. Use that local date as the key for `daily_summaries`

This ensures a 11:45pm log in New York goes into December 31st, not January 1st.

### 5.4 Read Path (any tab)

```
Today Tab       Data Tab        Coach Tab       Progress Tab    Trends Tab
     │               │               │                │               │
     │               │               │                │               │
     ▼               ▼               ▼                ▼               ▼
daily_summaries  daily_summaries  daily_summaries  daily_summaries  daily_summaries
(today only)     (7D/30D/90D)     (full history)   + user_goals     (self-join on date
                                                                      for correlations)
     │
     ▼
health_events
(today's raw timeline —
 "I drank water at 2pm,
  4pm, 7pm")
```

---

## 6. API Design

### 6.1 Unified Ingest Endpoint

All health data — manual logs, device syncs, future integrations — goes through one
endpoint.

**Single event:**
```
POST /api/v1/ingest
{
  "metric_type": "water_ml",
  "value": 250,
  "unit": "mL",
  "source": "manual",
  "recorded_at": "2026-03-22T14:30:00+05:00",  // device local time with offset
  "metadata": {}
}
```

**Session (multiple linked metrics at once):**
```
POST /api/v1/ingest/session
{
  "activity_type": "run",
  "source": "manual",
  "started_at": "2026-03-22T07:00:00+05:00",
  "ended_at":   "2026-03-22T07:30:00+05:00",
  "metrics": [
    { "metric_type": "distance",        "value": 5000, "unit": "m"     },
    { "metric_type": "exercise_minutes","value": 30,   "unit": "min"   },
    { "metric_type": "running_pace",    "value": 360,  "unit": "s/km"  },
    { "metric_type": "heart_rate_avg",  "value": 155,  "unit": "bpm"   },
    { "metric_type": "active_calories", "value": 130,  "unit": "kcal"  }
  ]
}
```

**Bulk device sync (Apple Health, Fitbit, etc.):**
```
POST /api/v1/ingest/bulk
{
  "source": "apple_health",
  "events": [
    { "metric_type": "steps", "value": 10000, "recorded_at": "...", "granularity": "daily_aggregate" },
    { "metric_type": "resting_heart_rate", "value": 62, "recorded_at": "...", ... },
    ...
  ]
}
```

### 6.2 Analytics Endpoints (unchanged interface, new implementation)

All existing analytics endpoints (`/analytics/dashboard-summary`, `/analytics/category`,
`/analytics/metric`) keep the same request/response interface so the Flutter app requires
no changes. Internally they switch from querying the old tables to querying `daily_summaries`.

```
GET /analytics/dashboard-summary
  → SELECT metric_type, value, unit FROM daily_summaries
    WHERE user_id = ? AND date >= ? GROUP BY metric_type ORDER BY date DESC

GET /analytics/category?category=activity&time_range=7D
  → SELECT date, metric_type, value FROM daily_summaries
    WHERE user_id = ? AND metric_type IN (activity metrics) AND date >= ?

GET /analytics/metric?metric_id=steps&time_range=30D
  → SELECT date, value FROM daily_summaries
    WHERE user_id = ? AND metric_type = 'steps' AND date >= ?
```

### 6.3 Today Tab Endpoints

```
GET /api/v1/today/summary
  → daily_summaries for today (all metrics)

GET /api/v1/today/timeline
  → health_events for today, ordered by recorded_at (raw log history)

GET /api/v1/today/goals-progress
  → daily_summaries for today JOIN user_goals (progress toward daily targets)
```

### 6.4 Trends Tab Endpoints

```
GET /api/v1/trends/correlation?metric_a=sleep_duration&metric_b=mood&days=90
  → Self-join on daily_summaries:
    SELECT a.date, a.value AS metric_a, b.value AS metric_b
    FROM daily_summaries a
    JOIN daily_summaries b ON a.user_id = b.user_id AND a.date = b.date
    WHERE a.metric_type = 'sleep_duration' AND b.metric_type = 'mood'
    AND a.user_id = ? AND a.date >= ?
```

---

## 7. Migration Plan

Since this is a development-stage application with no production users to protect,
the migration is a clean rebuild:

1. **Drop** all old health data tables: `quick_logs`, `daily_health_metrics`,
   `sleep_records`, `weight_measurements`, `nutrition_entries`, `blood_pressure_records`,
   `unified_activities`, `cycle_tracking`, `environment_metrics`

2. **Create** new tables via Alembic migrations in order:
   - `metric_definitions` (seed with initial metric rows)
   - `health_events`
   - `activity_sessions`
   - `daily_summaries`

3. **Update** Cloud Brain API:
   - Remove all individual typed quick-log endpoints
   - Implement unified ingest endpoints
   - Rewrite analytics queries to use `daily_summaries`
   - Rewrite today summary to use `health_events` + `daily_summaries`

4. **Update** Flutter app:
   - Replace all typed quick-log API calls with unified ingest calls
   - Analytics providers require no changes (same API interface)

5. **Supabase RLS policies:**
   - `health_events`: `user_id = auth.uid()`
   - `activity_sessions`: `user_id = auth.uid()`
   - `daily_summaries`: `user_id = auth.uid()`
   - `metric_definitions`: public read, no write from client

---

## 8. Performance at Scale

### Current approach (PostgreSQL)

With proper indexes on `(user_id, metric_type, date)`, `daily_summaries` supports
fast reads for all tabs. A user with 100 active metrics over 365 days = 36,500 rows.
For 1 million users = 36.5 billion rows per year. This requires table partitioning.

### Partitioning strategy

Partition `daily_summaries` by `date` (monthly range partitions). Each partition covers
one month of data across all users. Older partitions can be archived to cold storage.
This keeps the active partition (current month) small and fast.

### Path to TimescaleDB

`health_events` and `daily_summaries` are both time-series tables. If query performance
degrades at scale, converting to TimescaleDB hypertables requires no schema changes —
just `SELECT create_hypertable('health_events', 'recorded_at')`. TimescaleDB continuous
aggregates can replace the manual `daily_summaries` recomputation entirely.

---

## 9. Error Handling

- **Unknown metric_type on ingest:** Accept and store the event. Insert a placeholder
  row in `metric_definitions` with `is_active = false` so it can be reviewed. Never
  silently drop data.
- **Aggregation failure:** Log the error, mark the affected `daily_summaries` row with
  `computed_at = NULL` as a dirty flag, retry on next read.
- **Duplicate events (device re-sync):** `health_events` is append-only — duplicates
  from re-syncs are accepted. The aggregation naturally handles them since it recomputes
  from all events. To prevent inflating sums from true duplicates, a `(user_id,
  source, metric_type, recorded_at)` unique constraint can be added for device sources.

---

## 10. What Each Tab Uses

| Tab | Primary Tables | Use |
|-----|---------------|-----|
| Today | `daily_summaries` (today) + `health_events` (today) | Current day totals + raw log timeline |
| Data | `daily_summaries` (7D/30D/90D) | Trend charts and tile values |
| Coach | `daily_summaries` + `health_events` | AI context — structured summaries + raw history |
| Progress | `daily_summaries` + `user_goals` | Goal progress computation |
| Trends | `daily_summaries` (self-join) | Correlation analysis between any two metrics |
| Settings | `users` + `user_preferences` | Profile and preferences only |

---

## 11. Summary

**Before:** 7+ tables, manual sync required for each metric, Today tab and Data tab
disconnected, adding a new integration breaks things.

**After:** 3 health tables (`health_events`, `daily_summaries`, `metric_definitions`),
all tabs read from the same data, new integrations require zero code changes, full audit
trail preserved, scalable to 1M+ users.
