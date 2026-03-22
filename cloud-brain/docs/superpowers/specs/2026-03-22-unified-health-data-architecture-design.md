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
- Manual logs and device syncs are additive — always summed per day (except sleep and
  body composition metrics which are single-measurement-per-night/per-day by nature)
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
    recorded_at     TIMESTAMPTZ NOT NULL,   -- when the health event occurred (device local time w/ offset)
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),  -- when we received it
    granularity     TEXT NOT NULL DEFAULT 'point_in_time', -- "point_in_time" | "daily_aggregate"
    session_id      UUID REFERENCES activity_sessions(id) ON DELETE SET NULL,
    idempotency_key TEXT,                   -- optional client-supplied deduplication key
    metadata        JSONB                   -- extra structured fields (meal_type, effort_level, etc.)
);

-- Prevent true duplicates for device syncs: same source cannot send the same
-- metric at the exact same recorded_at timestamp twice.
CREATE UNIQUE INDEX idx_health_events_device_dedup
    ON health_events (user_id, source, metric_type, recorded_at)
    WHERE source != 'manual';

-- Prevent manual entry duplicates via client-supplied idempotency key.
CREATE UNIQUE INDEX idx_health_events_idempotency
    ON health_events (user_id, idempotency_key)
    WHERE idempotency_key IS NOT NULL;

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

- `recorded_at` stores the timestamp in the device's local timezone with UTC offset
  preserved (e.g. `2026-03-22T23:45:00-05:00`). This allows correct local-date bucketing
  per user without requiring a separate timezone lookup on every insert.
- `granularity = 'daily_aggregate'` is used when a device (e.g. Apple Health) sends one
  number representing the entire day (e.g. total daily steps). `point_in_time` is used for
  individual log entries (e.g. 250ml water logged at 2:34pm).
- When two `daily_aggregate` events arrive for the same `(user_id, source, metric_type,
  recorded_at)` from a device re-sync, the unique index rejects the second one as a
  duplicate. If the device sends an *updated* value (different `recorded_at`), both are
  stored and summed — the API layer must deduplicate device re-syncs before inserting
  if the source guarantees idempotent daily values (see Section 6.1).
- `session_id` links measurements from the same real-world event. It references
  `activity_sessions.id` and is set to NULL if the session is deleted.
- `idempotency_key` is a client-supplied string (e.g. a UUID generated by the Flutter
  app before submission). If the same key is submitted twice (e.g. due to network retry),
  the second insert is silently ignored. This prevents double-tap and retry duplicates
  for manual logs.

---

### 4.2 `activity_sessions` — Session Metadata

Stores session-level information for grouped events. A session represents one real-world
event (a run, a sleep night, a blood pressure reading) that produced multiple measurements.

**Must be created before `health_events` in migrations** because `health_events.session_id`
references this table.

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
holds the container (what kind of event, when it started/ended); the individual metric
rows in `health_events` hold the measurements.

---

### 4.3 `daily_summaries` — Read Cache

Pre-aggregated daily totals per metric per user. Automatically maintained by the
aggregation layer (never written to directly by the app). All analytics endpoints read
from this table.

```sql
CREATE TABLE daily_summaries (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    date            DATE NOT NULL,          -- user's local date (derived from recorded_at + timezone)
    metric_type     TEXT NOT NULL,
    value           FLOAT NOT NULL,
    unit            TEXT NOT NULL,
    event_count     INTEGER NOT NULL DEFAULT 1,  -- number of raw events that contributed
    is_stale        BOOLEAN NOT NULL DEFAULT false, -- dirty flag: true = needs recomputation
    computed_at     TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (user_id, date, metric_type)     -- one aggregated row per user per day per metric
);

-- Primary read pattern: user's trend for a metric over a date range
CREATE INDEX idx_daily_summaries_user_metric_date
    ON daily_summaries (user_id, metric_type, date DESC);

-- Secondary read pattern: all metrics for a user on a specific date (Today tab)
CREATE INDEX idx_daily_summaries_user_date
    ON daily_summaries (user_id, date DESC);

-- Maintenance: find stale rows needing recomputation
CREATE INDEX idx_daily_summaries_stale
    ON daily_summaries (is_stale)
    WHERE is_stale = true;
```

**Note on the UNIQUE constraint and partitioning:** If `daily_summaries` is later
partitioned by `date` (monthly range partitions), the `UNIQUE (user_id, date, metric_type)`
constraint remains enforceable in PostgreSQL because `date` — the partition key — is
included in the constraint. This is a PostgreSQL requirement: unique constraints on
partitioned tables must include the partition key. See Section 8 for the partitioning
strategy.

**Aggregation rules** (defined per metric in `metric_definitions`):

| Rule | Meaning | Example metrics |
|------|---------|-----------------|
| `sum` | Add all values from all sources for the day | steps, water_ml, active_calories, distance, exercise_minutes, calories, protein, carbs, fat |
| `avg` | Average all values from all sources for the day | resting_heart_rate, hrv_ms, mood, energy, stress, blood_glucose, walking_speed, running_pace |
| `latest` | Use the most recent value recorded that day | weight_kg, body_fat_percentage, vo2_max, sleep_duration, cycle_day |

**Special case — sleep metrics:** Sleep metrics (`sleep_duration`, `deep_sleep_minutes`,
`rem_sleep_minutes`, `sleep_efficiency`, `sleep_quality`) use `latest` rather than `sum`
or `avg`. This is intentional and is an explicit exception to the "all sources are
additive" rule. A person sleeps once per night. If an Oura ring and a manual log both
record sleep for the same night, taking the latest value (most recent sync) reflects the
best available data, not a physical impossibility. If a user has no device and logs sleep
manually, the manual entry is used as-is. This is the same approach used by Apple Health
and Google Fit for sleep data.

**Special case — blood pressure:** `blood_pressure_systolic` and `blood_pressure_diastolic`
use `avg`. Multiple readings per day (e.g. morning and evening) are clinically meaningful
to average. The `latest` rule would silently discard earlier readings. `avg` preserves
all readings and matches how most clinical guidelines compute daily BP estimates.

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
    min_value           FLOAT,              -- nullable: minimum valid value for API-layer validation
    max_value           FLOAT,              -- nullable: maximum valid value for API-layer validation
    is_active           BOOLEAN NOT NULL DEFAULT true,
    display_order       INTEGER NOT NULL DEFAULT 0,  -- sort order within category
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

**Initial metric definitions** (columns: metric_type | display_name | unit | category | aggregation_fn | min | max):

| metric_type | display_name | unit | category | aggregation_fn | min | max |
|-------------|--------------|------|----------|----------------|-----|-----|
| steps | Steps | steps | activity | sum | 0 | 100000 |
| active_calories | Active Calories | kcal | activity | sum | 0 | 10000 |
| distance | Distance | m | activity | sum | 0 | 500000 |
| exercise_minutes | Exercise Minutes | min | activity | sum | 0 | 1440 |
| walking_speed | Walking Speed | m/s | activity | avg | 0 | 10 |
| running_pace | Running Pace | s/km | activity | avg | 60 | 1800 |
| floors_climbed | Floors Climbed | floors | activity | sum | 0 | 500 |
| sleep_duration | Sleep Duration | min | sleep | latest | 0 | 1440 |
| deep_sleep_minutes | Deep Sleep | min | sleep | latest | 0 | 720 |
| rem_sleep_minutes | REM Sleep | min | sleep | latest | 0 | 720 |
| sleep_efficiency | Sleep Efficiency | % | sleep | latest | 0 | 100 |
| sleep_quality | Sleep Quality | score | sleep | latest | 0 | 100 |
| resting_heart_rate | Resting Heart Rate | bpm | heart | avg | 20 | 220 |
| hrv_ms | HRV | ms | heart | avg | 0 | 300 |
| vo2_max | VO₂ Max | mL/kg/min | heart | latest | 10 | 90 |
| respiratory_rate | Respiratory Rate | brpm | heart | avg | 5 | 60 |
| heart_rate_avg | Avg Heart Rate | bpm | heart | avg | 20 | 220 |
| weight_kg | Weight | kg | body | latest | 20 | 500 |
| body_fat_percentage | Body Fat | % | body | latest | 1 | 70 |
| body_temperature | Body Temperature | °C | body | avg | 34 | 42 |
| wrist_temperature | Wrist Temperature | °C | body | avg | 30 | 42 |
| muscle_mass_kg | Muscle Mass | kg | body | latest | 5 | 200 |
| blood_pressure_systolic | Blood Pressure (Sys) | mmHg | vitals | avg | 50 | 250 |
| blood_pressure_diastolic | Blood Pressure (Dia) | mmHg | vitals | avg | 30 | 150 |
| spo2 | Blood Oxygen | % | vitals | avg | 70 | 100 |
| blood_glucose | Blood Glucose | mmol/L | vitals | avg | 1 | 30 |
| calories | Calories | kcal | nutrition | sum | 0 | 20000 |
| protein_grams | Protein | g | nutrition | sum | 0 | 1000 |
| carbs_grams | Carbs | g | nutrition | sum | 0 | 2000 |
| fat_grams | Fat | g | nutrition | sum | 0 | 1000 |
| water_ml | Water | mL | nutrition | sum | 0 | 20000 |
| mood | Mood | /10 | wellness | avg | 0 | 10 |
| energy | Energy | /10 | wellness | avg | 0 | 10 |
| stress | Stress | /100 | wellness | avg | 0 | 100 |
| mindful_minutes | Mindful Minutes | min | wellness | sum | 0 | 1440 |
| cycle_day | Cycle Day | day | cycle | latest | 1 | 40 |
| noise_exposure | Noise Exposure | dB | environment | avg | 0 | 200 |
| uv_index | UV Index | UV | environment | avg | 0 | 20 |

**Notes on sleep units:** All sleep sub-metrics (`sleep_duration`, `deep_sleep_minutes`,
`rem_sleep_minutes`) use **minutes** as the unit for consistency. The Flutter display layer
is responsible for formatting minutes into "7h 36m" for human display. Storing in minutes
avoids fractional-hour precision loss and makes all sleep metrics comparable in the same
unit.

**Cycle tracking:** The current schema captures `cycle_day` (integer day of cycle) as the
primary cycle metric. Structured cycle data (phase, flow intensity, symptoms) is a known
simplification. This data can be captured via `health_events.metadata` JSONB with
`metric_type = 'cycle_day'` until a richer cycle tracking feature is designed. No data
is lost — the raw metadata is preserved in `health_events`.

---

### 4.5 Non-Health Tables (unchanged or minor updates)

These tables are not affected by this refactor:

| Table | Purpose | Changes |
|-------|---------|---------|
| `users` | Identity, profile, profile picture URL | None |
| `user_preferences` | Settings, units, layout, notifications, IANA timezone | Ensure `timezone` column exists (default: `'UTC'`) |
| `user_goals` | Target values per metric per period | Update `metric` column values to match new `metric_type` slugs |
| `conversations` | Coach chat history | None |
| `insights` | AI-generated insight cards | None |
| `achievements` | Gamification unlock state | None |
| `user_streaks` | Streak counters per metric | Update metric references to new slugs |
| `journal_entries` | Free-text daily reflections | None |

**Tables being removed:**

- `quick_logs` → replaced by `health_events`
- `daily_health_metrics` → replaced by `daily_summaries`
- `sleep_records` → data migrates to `health_events` + `daily_summaries`
- `weight_measurements` → data migrates to `health_events` + `daily_summaries`
- `nutrition_entries` → data migrates to `health_events` + `daily_summaries`
- `blood_pressure_records` → data migrates to `health_events` + `daily_summaries`
- `unified_activities` → data migrates to `health_events` + `activity_sessions`
- `cycle_tracking` → `cycle_day` values migrate to `health_events`
- `environment_metrics` → migrates to `health_events`

---

## 5. Data Flow

### 5.1 Write Path (any data source)

```
Manual log (Today tab)          Apple Health sync         Future: Garmin webhook
        │                               │                          │
        ▼                               ▼                          ▼
POST /api/v1/ingest            POST /api/v1/ingest/bulk   POST /api/v1/ingest/bulk
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
                           for affected (user_id, local_date, metric_type)
                           using aggregation_fn from metric_definitions
```

The aggregation step runs **synchronously** within the same request for single manual
log entries (fast, single metric, response includes the updated daily total).

For bulk device syncs (Apple Health sending 30 days of data at once), all events are
inserted in a single transaction, then aggregation runs as a **background task**. The
client receives a `202 Accepted` with a task ID. The Flutter app can poll
`GET /api/v1/ingest/status/{task_id}` or wait for a push notification.

### 5.2 Aggregation Logic

For each affected `(user_id, local_date, metric_type)`:

```
1. Resolve user's IANA timezone from user_preferences (default: 'UTC' if not set).
2. Determine local_date by converting recorded_at to user's local timezone and
   extracting the date component.
3. Query all health_events for this (user_id, local_date, metric_type).
4. Look up aggregation_fn from metric_definitions for this metric_type.
5. Apply aggregation:
   - sum:    value = SUM(e.value) for all events
   - avg:    value = AVG(e.value) for all events
   - latest: value = e.value WHERE e.recorded_at = MAX(recorded_at)
6. UPSERT into daily_summaries:
   INSERT ... ON CONFLICT (user_id, date, metric_type) DO UPDATE
   SET value = excluded.value,
       event_count = excluded.event_count,
       is_stale = false,
       computed_at = now()
```

If the aggregation step fails for any reason, the affected `daily_summaries` row is
marked `is_stale = true`. A background worker periodically scans for stale rows and
retries recomputation. The `health_events` row is always committed regardless of whether
aggregation succeeds — raw data is never lost.

### 5.3 Timezone Handling

The `date` stored in `daily_summaries` is the user's **local date**, not UTC.

When a `health_event` is being aggregated:
1. Read `user_preferences.timezone` for the user (e.g. `"America/New_York"`).
2. If not set, fall back to `'UTC'`. This is documented to users during onboarding.
3. Convert `recorded_at` (timestamptz with offset) to the user's IANA timezone.
4. Extract the local date (YYYY-MM-DD) as the bucket key.

Additionally, `recorded_at` itself should carry the client's UTC offset (e.g.
`2026-03-22T23:45:00-05:00`) so the correct local date can be inferred even before the
user's preferences are loaded. The Flutter app must always include the UTC offset when
submitting events.

This ensures an 11:45pm log in New York goes into December 31st, not January 1st.

### 5.4 Granularity Conflict Resolution

When multiple `daily_aggregate` events exist for the same `(user_id, date, metric_type)`
from the same device source (e.g. Apple Health re-sends updated step count), the unique
index on `(user_id, source, metric_type, recorded_at)` rejects true duplicates. If Apple
Health sends a corrected value with a slightly different `recorded_at`, both rows are
stored. The `sum` aggregation would then count both. To handle this:

- Device ingest endpoints (`/ingest/bulk` with `source != 'manual'`) must delete any
  existing `daily_aggregate` events for the same `(user_id, source, metric_type,
  floor(recorded_at to day))` before inserting the new one. This is handled server-side
  in the ingest service — the client does not need to be aware of it.
- `point_in_time` events are never deduplicated this way — each is a real occurrence.

### 5.5 Read Path (any tab)

```
Today Tab         Data Tab          Coach Tab         Progress Tab    Trends Tab
     │                 │                 │                  │               │
     ▼                 ▼                 ▼                  ▼               ▼
daily_summaries   daily_summaries   daily_summaries    daily_summaries  daily_summaries
(today only)      (7D/30D/90D)      (full history)     + user_goals     (self-join on
                                                                          date for
     │                                                                   correlations)
     ▼
health_events
(today's raw timeline:
 "drank water at 2pm,
  4pm, 7pm")
```

---

## 6. API Design

### 6.1 Unified Ingest Endpoint

All health data — manual logs, device syncs, future integrations — goes through one
endpoint family. The previous 10+ typed quick-log endpoints are replaced by these three.

**Single event (manual log):**
```
POST /api/v1/ingest
{
  "metric_type": "water_ml",
  "value": 250,
  "unit": "mL",
  "source": "manual",
  "recorded_at": "2026-03-22T14:30:00+05:00",
  "idempotency_key": "abc-123-client-generated-uuid",
  "metadata": {}
}

Response 201:
{
  "event_id": "uuid",
  "daily_total": 1250,       // updated daily_summaries value (synchronous)
  "unit": "mL",
  "date": "2026-03-22"
}
```

**Session (multiple linked metrics):**
```
POST /api/v1/ingest/session
{
  "activity_type": "run",
  "source": "manual",
  "started_at": "2026-03-22T07:00:00+05:00",
  "ended_at":   "2026-03-22T07:30:00+05:00",
  "idempotency_key": "run-session-client-uuid",
  "metrics": [
    { "metric_type": "distance",         "value": 5000, "unit": "m"     },
    { "metric_type": "exercise_minutes", "value": 30,   "unit": "min"   },
    { "metric_type": "running_pace",     "value": 360,  "unit": "s/km"  },
    { "metric_type": "heart_rate_avg",   "value": 155,  "unit": "bpm"   },
    { "metric_type": "active_calories",  "value": 130,  "unit": "kcal"  }
  ]
}

Response 201:
{
  "session_id": "uuid",
  "event_ids": ["uuid", "uuid", ...],
  "date": "2026-03-22"
}
```

**Bulk device sync (transactional):**
```
POST /api/v1/ingest/bulk
{
  "source": "apple_health",
  "events": [
    {
      "metric_type": "steps",
      "value": 10000,
      "unit": "steps",
      "recorded_at": "2026-03-22T23:59:00-05:00",
      "granularity": "daily_aggregate"
    },
    ...
  ]
}

Response 202 Accepted:
{
  "task_id": "uuid",
  "event_count": 847,
  "status": "processing"
}
```

The bulk insert is **fully transactional**: either all events insert successfully or none
do. If the transaction fails mid-batch, no partial data is committed. The client receives
a `202` immediately; aggregation runs in the background. If aggregation fails, raw events
are preserved and recomputed on the next background worker cycle (not retried
immediately to avoid thundering herd).

**Validation:** The ingest API validates `value` against `metric_definitions.min_value`
and `metric_definitions.max_value` if they are set. Out-of-range values return `422
Unprocessable Entity` with a descriptive error. Unknown `metric_types` not in
`metric_definitions` are accepted and stored, with an auto-inserted placeholder row
written to `metric_definitions` (`is_active = false`) by the server-side service account
(which bypasses RLS via the Supabase service role key, not the anon/client key).

**Rate limiting:** The ingest endpoint is rate-limited per user:
- Single event: 60 requests/minute
- Session: 20 requests/minute
- Bulk: 5 requests/minute, max 10,000 events per request

### 6.2 Analytics Endpoints (unchanged interface, new implementation)

All existing analytics endpoints (`/analytics/dashboard-summary`, `/analytics/category`,
`/analytics/metric`) keep the same request/response interface so the Flutter app requires
no changes. Internally they switch from querying the old tables to querying `daily_summaries`.

```sql
-- Dashboard summary: latest value per metric for the past 7 days
SELECT metric_type, value, unit, date
FROM daily_summaries
WHERE user_id = $1
  AND date >= current_date - interval '7 days'
ORDER BY metric_type, date DESC;

-- Category detail: 7D/30D/90D trend for all metrics in a category
SELECT ds.date, ds.metric_type, ds.value, ds.unit
FROM daily_summaries ds
JOIN metric_definitions md ON ds.metric_type = md.metric_type
WHERE ds.user_id = $1
  AND md.category = $2
  AND ds.date >= $3
ORDER BY ds.metric_type, ds.date;

-- Single metric time series
SELECT date, value
FROM daily_summaries
WHERE user_id = $1
  AND metric_type = $2
  AND date >= $3
ORDER BY date;
```

### 6.3 Today Tab Endpoints

```
GET /api/v1/today/summary
  → daily_summaries WHERE date = today (user local) — all metrics, current totals

GET /api/v1/today/timeline
  → health_events WHERE date(recorded_at AT TIME ZONE user_tz) = today
    ORDER BY recorded_at DESC
    (raw log history: "250mL water at 2pm, 300mL at 4pm, 200mL at 7pm")

GET /api/v1/today/goals-progress
  → daily_summaries for today JOIN user_goals ON metric_type
    returns: { metric_type, current_value, target_value, percentage }
```

### 6.4 Trends Tab Endpoints

```
GET /api/v1/trends/correlation?metric_a=sleep_duration&metric_b=mood&days=90

-- Self-join daily_summaries on (user_id, date):
SELECT a.date, a.value AS metric_a_value, b.value AS metric_b_value
FROM daily_summaries a
JOIN daily_summaries b
  ON a.user_id = b.user_id
 AND a.date = b.date
WHERE a.user_id = $1
  AND a.metric_type = $2
  AND b.metric_type = $3
  AND a.date >= current_date - ($4 || ' days')::interval
ORDER BY a.date;
```

This returns two parallel value arrays on matching dates. The backend computes Pearson
correlation and returns both the raw data points and the correlation coefficient.

---

## 7. Migration Plan

Since this is a development-stage application with no production users to protect,
the migration is a clean rebuild:

**Step 1 — Drop old tables (Supabase SQL editor or migration):**
```
quick_logs, daily_health_metrics, sleep_records, weight_measurements,
nutrition_entries, blood_pressure_records, unified_activities,
cycle_tracking, environment_metrics
```

**Step 2 — Create new tables via Alembic migrations in order:**
1. `activity_sessions` (no foreign key dependencies)
2. `metric_definitions` + seed initial rows
3. `health_events` (references `activity_sessions`)
4. `daily_summaries`

**Step 3 — Update Cloud Brain API:**
- Remove all 10+ individual typed quick-log endpoints
- Implement unified ingest endpoints (`/ingest`, `/ingest/session`, `/ingest/bulk`)
- Rewrite analytics queries to use `daily_summaries`
- Implement today summary endpoint using `health_events` + `daily_summaries`
- Implement trends correlation endpoint
- Implement background aggregation worker

**Step 4 — Update Flutter app:**
- Replace all typed quick-log API calls with unified ingest calls
- Analytics providers require no changes (same API interface)
- Today tab reads from new summary endpoint

**Step 5 — Supabase RLS policies:**
```sql
-- health_events: users can only read/write their own events
ALTER TABLE health_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY "users own their events"
  ON health_events FOR ALL USING (user_id = auth.uid());

-- activity_sessions: same
ALTER TABLE activity_sessions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "users own their sessions"
  ON activity_sessions FOR ALL USING (user_id = auth.uid());

-- daily_summaries: read-only for users (written only by service role)
ALTER TABLE daily_summaries ENABLE ROW LEVEL SECURITY;
CREATE POLICY "users can read their summaries"
  ON daily_summaries FOR SELECT USING (user_id = auth.uid());

-- metric_definitions: public read, service role write only
ALTER TABLE metric_definitions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "anyone can read metric definitions"
  ON metric_definitions FOR SELECT USING (true);
-- Writes to metric_definitions use the Supabase service role key (server-side only).
-- No client-side write policy is defined.
```

---

## 8. Performance at Scale

### Index strategy

The two most critical indexes:
- `daily_summaries (user_id, metric_type, date DESC)` — serves all trend queries
- `daily_summaries (user_id, date DESC)` — serves all today/dashboard queries

Both are partial covering indexes that fit in memory for a typical user's dataset.

### Partitioning strategy for `daily_summaries`

At 1 million users × 100 metrics × 365 days = ~36.5 billion rows per year in
`daily_summaries`. A single monthly partition would hold ~3 billion rows — not small.

**Recommended partition strategy: composite hash + range partitioning.**
- First: hash partition by `user_id` (e.g. 16 hash partitions) — distributes users
  evenly across shards
- Second: within each hash partition, range sub-partition by `date` (monthly) — enables
  archiving old months to cold storage

This keeps any single partition to ~36.5B / 12 months / 16 hash buckets ≈ 190M rows —
manageable for PostgreSQL with the above indexes.

### Path to TimescaleDB

`health_events` and `daily_summaries` are both time-series tables. If query performance
degrades at scale, converting to TimescaleDB hypertables requires no schema changes:
```sql
SELECT create_hypertable('health_events', 'recorded_at');
SELECT create_hypertable('daily_summaries', 'date', chunk_time_interval => INTERVAL '1 month');
```
TimescaleDB continuous aggregates can replace the manual `daily_summaries` recomputation
entirely, making the background aggregation worker redundant.

---

## 9. Error Handling

- **Unknown `metric_type` on ingest:** Accept and store the event. The server-side
  service role inserts a placeholder row into `metric_definitions` with `is_active = false`
  for review. Never silently drop data from unknown metric types.
- **Out-of-range value:** Return `422 Unprocessable Entity`. Do not store the event.
- **Aggregation failure:** Mark the affected `daily_summaries` row with `is_stale = true`.
  A background worker retries stale rows on a 5-minute interval. Raw events in
  `health_events` are always preserved regardless of aggregation outcome.
- **Duplicate manual event:** If `idempotency_key` matches an existing row for this user,
  return `200 OK` with the original event's data. No duplicate is inserted.
- **Duplicate device event:** The unique index on `(user_id, source, metric_type,
  recorded_at)` for non-manual sources rejects exact duplicates at the database level
  with a `409 Conflict` response. The client should treat `409` as success (event already
  recorded).
- **Bulk ingest partial failure:** The entire bulk transaction is rolled back. The client
  receives `500` with a message to retry. No partial data is committed.

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
disconnected, adding a new integration breaks things, no audit trail.

**After:** 3 health tables (`health_events`, `daily_summaries`, `metric_definitions`) +
1 session table (`activity_sessions`), all tabs read from the same data, new integrations
require zero schema changes, full audit trail preserved, timezone-correct daily buckets,
idempotent ingest, scalable to 1M+ users via partitioning, upgradeable to TimescaleDB
with two SQL commands.
