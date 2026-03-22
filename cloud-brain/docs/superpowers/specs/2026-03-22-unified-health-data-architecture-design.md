# Unified Health Data Architecture

**Date:** 2026-03-22
**Status:** Approved — Revised post-architectural-review
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
- Full audit trail — raw events are preserved; corrections use soft-delete, not hard delete

---

## 3. Architecture Decision

**Event Sourcing with a pre-aggregated read cache (CQRS pattern).**

All health data writes go to one append-only `health_events` table. A triggered aggregation
process maintains `daily_summaries` as a pre-computed read cache. All app tabs read from
`daily_summaries`. Raw events are preserved for recomputation, auditing, and AI context.

This is the same pattern used internally by Apple Health, Google Fit, Oura, and FHIR-
compliant health platforms.

**Two classes of events:**

| Class | Granularity | Semantics | Example |
|-------|-------------|-----------|---------|
| Point-in-time | `point_in_time` | Append-only, immutable. Each occurrence is a real event. | "Drank 250mL water at 2:34pm" |
| Device daily aggregate | `daily_aggregate` | Upsertable. The device provides its best-known daily total, which may be revised on re-sync. | "Apple Health reports 10,000 steps for March 22" |

This distinction is fundamental. Point-in-time events are never modified. Device daily
aggregates are updated in-place (with `updated_at` tracking revisions) because the device
is providing an authoritative correction, not a new independent event.

---

## 4. Database Schema

### 4.1 `health_events` — Source of Truth

Every health measurement ever recorded, from any source, lands here as one row.
Point-in-time events are append-only and never modified. Device daily aggregates are
upserted (one authoritative row per device/metric/day).

```sql
CREATE TABLE health_events (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    metric_type     TEXT NOT NULL,          -- e.g. "steps", "water_ml", "mood"
    value           FLOAT8 NOT NULL,        -- the primary numeric value (double precision)
    unit            TEXT NOT NULL,          -- e.g. "steps", "ml", "/10"
    source          TEXT NOT NULL,          -- "apple_health" | "manual" | "fitbit" | "garmin" | ...
    recorded_at     TIMESTAMPTZ NOT NULL,   -- when the health event occurred (stored as UTC)
    local_date      DATE NOT NULL,          -- user's local date at time of event (server-computed
                                            -- from UTC offset in the original recorded_at string;
                                            -- never recomputed after insert)
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),  -- when we first received it
    updated_at      TIMESTAMPTZ,            -- non-null only when a daily_aggregate was re-synced
    deleted_at      TIMESTAMPTZ,            -- non-null = soft-deleted (user correction)
    granularity     TEXT NOT NULL DEFAULT 'point_in_time', -- "point_in_time" | "daily_aggregate"
    session_id      UUID REFERENCES activity_sessions(id) ON DELETE SET NULL,
    idempotency_key TEXT,                   -- client-supplied deduplication key for manual logs
    metadata        JSONB                   -- extra structured fields (meal_type, effort_level, etc.)
);

-- Point-in-time dedup: same device source cannot send the same reading at the exact
-- same recorded_at twice. Does NOT apply to daily_aggregate (see next index).
CREATE UNIQUE INDEX idx_health_events_device_point_dedup
    ON health_events (user_id, source, metric_type, recorded_at)
    WHERE source != 'manual' AND granularity = 'point_in_time';

-- Device daily aggregate dedup: one authoritative row per (user, source, metric, local_date).
-- Inserts use ON CONFLICT DO UPDATE to handle device re-syncs without duplicate rows.
-- This is intentional: the device is providing a revised authoritative total, not a new event.
CREATE UNIQUE INDEX idx_health_events_device_daily_dedup
    ON health_events (user_id, source, metric_type, local_date)
    WHERE granularity = 'daily_aggregate';

-- Manual entry dedup: client-supplied idempotency key (e.g. UUID generated before submission).
-- If the same key arrives twice (network retry), the second insert is silently rejected.
CREATE UNIQUE INDEX idx_health_events_idempotency
    ON health_events (user_id, idempotency_key)
    WHERE idempotency_key IS NOT NULL;

-- Primary read pattern: user's history for a metric (Data tab trends, Coach context)
CREATE INDEX idx_health_events_user_metric_time
    ON health_events (user_id, metric_type, recorded_at DESC)
    WHERE deleted_at IS NULL;

-- Secondary read pattern: all events for a user on a local date (Today tab timeline)
CREATE INDEX idx_health_events_user_local_date
    ON health_events (user_id, local_date DESC)
    WHERE deleted_at IS NULL;

-- Session lookup: get all measurements from one activity/sleep/BP session
CREATE INDEX idx_health_events_session
    ON health_events (session_id)
    WHERE session_id IS NOT NULL AND deleted_at IS NULL;
```

**Key design decisions:**

- `recorded_at` is stored as UTC (PostgreSQL `TIMESTAMPTZ` normalizes all values to UTC
  internally). The client must submit timestamps with a UTC offset
  (e.g. `2026-03-22T23:45:00-05:00`). The ingest API extracts the local date from this
  offset **before** PostgreSQL normalizes the value, then stores it in `local_date`. Once
  stored, `local_date` is never recomputed — it is the canonical local date for that event.

- `local_date` is server-computed at insert time. The ingest API parses the UTC offset
  from the raw `recorded_at` string and applies it to extract the local date
  (e.g. `2026-03-22T23:45:00-05:00` → `local_date = 2026-03-22`). This avoids the
  requirement to look up the user's IANA timezone on every insert and prevents the
  wrong-day bug that occurs when PostgreSQL normalizes `23:45:00-05:00` to
  `2026-03-23T04:45:00Z` (which appears to be March 23 in UTC).

- `granularity = 'daily_aggregate'` is used when a device sends one number representing
  the entire day (e.g. total daily steps). `point_in_time` is used for individual
  occurrences (e.g. 250mL water logged at 2:34pm). The ingest API sets this field — the
  client does not need to supply it.

- **Device re-sync (daily aggregate):** When Apple Health sends a corrected step count
  for a day it already reported, the ingest API uses `INSERT ... ON CONFLICT
  (user_id, source, metric_type, local_date) WHERE granularity = 'daily_aggregate'
  DO UPDATE SET value = excluded.value, recorded_at = excluded.recorded_at,
  updated_at = now()`. The original row is updated in-place; no duplicate row is created.
  `created_at` reflects the original ingest time; `updated_at` reflects the correction.

- **User corrections (soft delete):** Users may delete an incorrectly logged manual entry.
  The API sets `deleted_at = now()` and triggers re-aggregation for the affected
  `(user_id, local_date, metric_type)`. The event is preserved in the database for audit
  purposes. All aggregation queries filter `WHERE deleted_at IS NULL`.

- `session_id` links measurements from the same real-world event. It references
  `activity_sessions.id` and is set to NULL if the session is deleted.

- `idempotency_key` is a client-supplied string for **manual** (`point_in_time`) events.
  If the same key arrives twice (network retry), the second insert is rejected silently
  and the original event data is returned. Device daily aggregates use the
  `idx_health_events_device_daily_dedup` index for deduplication instead.

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
    idempotency_key TEXT,            -- client-supplied; prevents duplicate sessions on retry
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Idempotency: if the same session is submitted twice (e.g. network retry), reject the duplicate.
CREATE UNIQUE INDEX idx_activity_sessions_idempotency
    ON activity_sessions (user_id, idempotency_key)
    WHERE idempotency_key IS NOT NULL;

CREATE INDEX idx_activity_sessions_user_type_time
    ON activity_sessions (user_id, activity_type, started_at DESC);
```

`activity_sessions.id` is the `session_id` stored in `health_events`. The session record
holds the container (what kind of event, when it started/ended); the individual metric
rows in `health_events` hold the measurements.

---

### 4.3 `daily_summaries` — Read Cache

Pre-aggregated daily totals per metric per user. Maintained exclusively by the aggregation
layer via the Supabase service role key. The Flutter app and Cloud Brain client-facing
endpoints never write to this table directly.

```sql
CREATE TABLE daily_summaries (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    date            DATE NOT NULL,          -- user's local date (= local_date from health_events)
    metric_type     TEXT NOT NULL,
    value           FLOAT8 NOT NULL,
    unit            TEXT NOT NULL,
    event_count     INTEGER NOT NULL DEFAULT 1,  -- number of non-deleted raw events that contributed
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

**Aggregation rules** (defined per metric in `metric_definitions`):

| Rule | Meaning | Example metrics |
|------|---------|-----------------|
| `sum` | Add all non-deleted values from all sources for the day | steps, water_ml, active_calories, distance, exercise_minutes, calories, protein, carbs, fat |
| `avg` | Average all non-deleted values from all sources for the day | resting_heart_rate, hrv_ms, mood, energy, stress, blood_glucose, walking_speed, running_pace |
| `latest` | Use the most recent non-deleted value recorded that day | weight_kg, body_fat_percentage, vo2_max, sleep_duration, cycle_day |

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

**Note on UNIQUE constraint and future partitioning:** If `daily_summaries` is later
partitioned by `date` (monthly range partitions), the `UNIQUE (user_id, date, metric_type)`
constraint remains enforceable in PostgreSQL because `date` — the partition key — is
included in the constraint. This is a PostgreSQL requirement: unique constraints on
partitioned tables must include the partition key. See Section 8 for the partitioning
strategy.

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
    min_value           FLOAT8,             -- nullable: minimum valid value for API-layer validation
    max_value           FLOAT8,             -- nullable: maximum valid value for API-layer validation
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
| `user_preferences` | Settings, units, layout, notifications, IANA timezone | Ensure `timezone TEXT NOT NULL DEFAULT 'UTC'` column exists; must be a valid IANA tz string (e.g. `'America/New_York'`) |
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
                              Cloud Brain: validate + compute local_date
                              from UTC offset in recorded_at string
                                        │
                                        ▼
                              INSERT/UPSERT into health_events
                              (point_in_time: append-only INSERT)
                              (daily_aggregate: ON CONFLICT DO UPDATE)
                                        │
                                        ▼
                           Recompute daily_summaries
                           for affected (user_id, local_date, metric_type)
                           using aggregation_fn from metric_definitions
```

The aggregation step runs **synchronously** within the same request for single manual
log entries (fast, single metric, response includes the updated daily total).

For bulk device syncs (Apple Health sending 30 days of data at once), all events are
inserted/upserted in a single transaction, then aggregation runs as a **FastAPI
background task** (via `BackgroundTasks`). The client receives `202 Accepted` with a
task ID. The Flutter app can poll `GET /api/v1/ingest/status/{task_id}` to check
completion status.

For the periodic stale-row recomputation, an **APScheduler** job runs every 5 minutes
inside the FastAPI process (see Section 9 for the background worker specification).

**User correction (soft delete):**

```
DELETE /api/v1/events/{event_id}
        │
        ▼
Set health_events.deleted_at = now()
        │
        ▼
Mark daily_summaries.is_stale = true
for (user_id, local_date, metric_type)
        │
        ▼
Recompute daily_summaries synchronously
(re-aggregates remaining non-deleted events for that day/metric)
```

Soft-deleted events are preserved in `health_events` for audit purposes. They are
excluded from all aggregation queries via `WHERE deleted_at IS NULL`.

### 5.2 Aggregation Logic

For each affected `(user_id, local_date, metric_type)`:

```
1. local_date is already stored on health_events — no timezone lookup needed.
2. Look up aggregation_fn from metric_definitions for this metric_type.
3. Query all health_events for this (user_id, local_date, metric_type)
   WHERE deleted_at IS NULL.
4. Apply aggregation:
   - sum:    value = SUM(e.value) for all non-deleted events
   - avg:    value = AVG(e.value) for all non-deleted events
   - latest: value = e.value WHERE e.recorded_at = MAX(recorded_at)
             (ties broken by created_at DESC)
5. UPSERT into daily_summaries:
   INSERT ... ON CONFLICT (user_id, date, metric_type) DO UPDATE
   SET value = excluded.value,
       event_count = excluded.event_count,
       is_stale = false,
       computed_at = now()
```

If the aggregation step fails for any reason, the affected `daily_summaries` row is
marked `is_stale = true`. The APScheduler job retries stale rows every 5 minutes.
The `health_events` row is always committed regardless of whether aggregation
succeeds — raw data is never lost.

**Aggregation note on mixed granularities:** For `avg` metrics, all non-deleted events
(both `point_in_time` and `daily_aggregate`) contribute equally to the average. This is
correct for health data: a device's daily aggregate resting HR (58 bpm) and a manual
spot reading (60 bpm) should both inform the daily average. If only device daily_aggregate
events exist, the avg reduces to the single device value.

### 5.3 Timezone Handling

The `date` stored in `daily_summaries` is the user's **local date**, not UTC.

**On INSERT:** The ingest API receives `recorded_at` as an ISO 8601 string with a UTC
offset (e.g. `2026-03-22T23:45:00-05:00`). Before inserting, the API:
1. Parses the UTC offset from the raw string (`-05:00` = −300 minutes).
2. Applies the offset to the datetime to get the local time (`23:45:00`).
3. Extracts the local date (`2026-03-22`).
4. Stores `local_date = '2026-03-22'` in `health_events`.
PostgreSQL normalizes `recorded_at` to UTC (`2026-03-23T04:45:00Z`) internally, but
`local_date` is already computed and stored correctly before normalization.

**On READ (for "today" queries):** The Cloud Brain API reads `user_preferences.timezone`
(IANA tz string, e.g. `"America/New_York"`), converts UTC now to the user's local date,
and passes it as a parameter `$user_local_date` to all queries. It never uses `current_date`
(database server's UTC date) for user-facing date queries.

**Fallback:** If the client omits the UTC offset (forbidden but handled gracefully), the
API falls back to the user's IANA timezone from `user_preferences`. If that is also
missing, UTC is used and the user is prompted to set their timezone.

**Required contract:** The Flutter app MUST always submit `recorded_at` with a UTC offset.
This is enforced at the API validation layer — requests without a UTC offset are rejected
with `422 Unprocessable Entity`.

### 5.4 Device Daily Aggregate Re-Sync

When a device (e.g. Apple Health) re-sends an updated daily total for a metric:

- The ingest API uses `INSERT ... ON CONFLICT (user_id, source, metric_type, local_date)
  WHERE granularity = 'daily_aggregate' DO UPDATE SET value = excluded.value,
  recorded_at = excluded.recorded_at, updated_at = now()`.
- The existing row's `value` is updated to the device's latest total.
- `created_at` is preserved (original ingest time). `updated_at` records when the
  correction arrived.
- The corresponding `daily_summaries` row is immediately re-aggregated.
- **Retry safety:** Submitting the same bulk ingest payload a second time is safe.
  Point-in-time events are rejected by the unique index (no-op). Daily aggregate events
  are upserted to the same value (no-op). The bulk endpoint is fully idempotent.

---

## 6. API Design

### 6.1 Unified Ingest Endpoint

All health data — manual logs, device syncs, future integrations — goes through one
endpoint family. The previous 10+ typed quick-log endpoints are replaced by these four.

**Authentication:** All ingest endpoints require a valid Supabase JWT in the
`Authorization: Bearer <token>` header. The Cloud Brain API validates the JWT and
extracts `user_id` server-side. Clients never supply `user_id` in the request body.

**Single event (manual log):**
```
POST /api/v1/ingest
{
  "metric_type": "water_ml",
  "value": 250,
  "unit": "mL",
  "source": "manual",
  "recorded_at": "2026-03-22T14:30:00+05:00",   -- UTC offset REQUIRED
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

Response 200 (idempotent repeat):
{
  "event_id": "uuid",        // original event_id
  "daily_total": 1250,
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
  "idempotency_key": "run-session-client-uuid",   -- applied to activity_sessions
  "metrics": [
    { "metric_type": "distance",         "value": 5000, "unit": "m",     "idempotency_key": "run-distance-uuid" },
    { "metric_type": "exercise_minutes", "value": 30,   "unit": "min",   "idempotency_key": "run-exmin-uuid"   },
    { "metric_type": "running_pace",     "value": 360,  "unit": "s/km",  "idempotency_key": "run-pace-uuid"    },
    { "metric_type": "heart_rate_avg",   "value": 155,  "unit": "bpm",   "idempotency_key": "run-hr-uuid"      },
    { "metric_type": "active_calories",  "value": 130,  "unit": "kcal",  "idempotency_key": "run-cal-uuid"     }
  ]
}

Response 201:
{
  "session_id": "uuid",
  "event_ids": ["uuid", "uuid", ...],
  "date": "2026-03-22"
}

Response 200 (idempotent repeat — session idempotency_key already exists):
{
  "session_id": "uuid",      // original session_id
  "event_ids": ["uuid", ...],
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
      // No idempotency_key needed: daily_aggregate dedup index handles re-syncs
    },
    {
      "metric_type": "resting_heart_rate",
      "value": 58,
      "unit": "bpm",
      "recorded_at": "2026-03-22T06:30:00-05:00",
      "granularity": "point_in_time"
      // idempotency_key optional; device dedup index uses (user, source, metric, recorded_at)
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

The bulk insert is **fully transactional**: all events in a batch are validated before
the transaction begins. Out-of-range values are rejected with `422` before any inserts
are attempted. If the transaction fails at the database layer, no partial data is
committed. The client receives `202` immediately; aggregation runs in a FastAPI
background task. Retrying the same bulk payload is safe (idempotent — see Section 5.4).

**Event correction (soft delete):**
```
DELETE /api/v1/events/{event_id}

Response 200:
{
  "event_id": "uuid",
  "deleted_at": "2026-03-22T15:30:00Z",
  "updated_daily_total": 1000   // re-aggregated value after deletion
}

Response 404: event not found or not owned by authenticated user
Response 422: event is from a device source (source != 'manual') — device events
             cannot be deleted by users; they are corrected via re-sync
```

Users can only delete their own `manual` events. Device-sourced events are authoritative
from the device — if the device sends corrected data, it will re-sync via the bulk
endpoint. This prevents users from accidentally erasing valid device readings.

**Validation:** The ingest API validates `value` against `metric_definitions.min_value`
and `metric_definitions.max_value` if they are set. Out-of-range values return `422
Unprocessable Entity` with a descriptive error. Unknown `metric_types` not in
`metric_definitions` are accepted and stored, with an auto-inserted placeholder row
written to `metric_definitions` (`is_active = false`) by the server-side service account
(which bypasses RLS via the Supabase service role key).

**Rate limiting** (enforced via slowapi middleware in Cloud Brain):
- Single event: 60 requests/minute per user
- Session: 20 requests/minute per user
- Bulk: 5 requests/minute per user, max 10,000 events per request
- Delete: 30 requests/minute per user

### 6.2 Analytics Endpoints (unchanged interface, new implementation)

All existing analytics endpoints (`/analytics/dashboard-summary`, `/analytics/category`,
`/analytics/metric`) keep the same request/response interface so the Flutter app requires
no changes. Internally they switch from querying the old tables to querying `daily_summaries`.

**Important:** All queries use `$user_local_date` (the user's current local date, computed
by Cloud Brain from `user_preferences.timezone`) as the date boundary. Never use
`current_date` (database server UTC date) — this would show wrong data for users whose
local date differs from UTC.

```sql
-- Dashboard summary: latest value per metric for the past 7 days
-- $1 = user_id, $2 = user_local_date (today in user's timezone)
SELECT metric_type, value, unit, date
FROM daily_summaries
WHERE user_id = $1
  AND date >= $2 - INTERVAL '7 days'
  AND date <= $2
ORDER BY metric_type, date DESC;

-- Category detail: 7D/30D/90D trend for all metrics in a category
-- $1 = user_id, $2 = category, $3 = start_date (user's local date - N days)
SELECT ds.date, ds.metric_type, ds.value, ds.unit
FROM daily_summaries ds
JOIN metric_definitions md ON ds.metric_type = md.metric_type
WHERE ds.user_id = $1
  AND md.category = $2
  AND ds.date >= $3
ORDER BY ds.metric_type, ds.date;

-- Single metric time series
-- $1 = user_id, $2 = metric_type, $3 = start_date (user's local date - N days)
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
  → Cloud Brain computes user_local_date from user_preferences.timezone
  → SELECT * FROM daily_summaries WHERE user_id = $1 AND date = $user_local_date
  → Returns all metrics with their current day totals

GET /api/v1/today/timeline?limit=50&before=<uuid>
  → Paginated cursor-based list of today's raw events (log history)
  → SELECT * FROM health_events
      WHERE user_id = $1
        AND local_date = $user_local_date
        AND deleted_at IS NULL
        [AND id < $cursor]  -- cursor pagination using UUID ordering
      ORDER BY recorded_at DESC
      LIMIT $limit
  → Returns: { events: [...], next_cursor: "uuid" | null }
  → Raw log history: "250mL water at 2pm, 300mL at 4pm, 200mL at 7pm"
  → Default limit: 50. Maximum limit: 200.

GET /api/v1/today/goals-progress
  → SELECT ds.metric_type, ds.value, ds.unit, ug.target_value,
           ROUND((ds.value / ug.target_value) * 100, 1) AS percentage
    FROM daily_summaries ds
    JOIN user_goals ug ON ds.user_id = ug.user_id AND ds.metric_type = ug.metric_type
    WHERE ds.user_id = $1 AND ds.date = $user_local_date
  → Returns: [{ metric_type, current_value, target_value, unit, percentage }]
```

### 6.4 Trends Tab Endpoints

```
GET /api/v1/trends/correlation?metric_a=sleep_duration&metric_b=mood&days=90

-- Self-join daily_summaries on (user_id, date):
-- $1 = user_id, $2 = metric_a, $3 = metric_b, $4 = start_date
SELECT a.date, a.value AS metric_a_value, b.value AS metric_b_value
FROM daily_summaries a
JOIN daily_summaries b
  ON a.user_id = b.user_id
 AND a.date = b.date
WHERE a.user_id = $1
  AND a.metric_type = $2
  AND b.metric_type = $3
  AND a.date >= $4
ORDER BY a.date;
```

This returns two parallel value arrays on matching dates. The backend computes Pearson
correlation and returns both the raw data points and the correlation coefficient.

### 6.5 Coach Tab Endpoints

The Coach tab needs both structured summaries and raw event history to build full AI
context. These endpoints are read-only and are never paginated with a hard cap (the Coach
consumes as much history as the context window allows).

```
GET /api/v1/coach/context?days=30
  → Returns structured summary for AI context:
    {
      "daily_summaries": [               // daily_summaries for past N days
        { "date": "2026-03-22", "metrics": { "steps": 8500, "sleep_duration": 420, ... } },
        ...
      ],
      "recent_events": [                 // last 200 raw health_events (across all dates)
        { "metric_type": "water_ml", "value": 250, "recorded_at": "...", "source": "manual" },
        ...
      ],
      "sessions": [                      // activity_sessions for past N days
        { "activity_type": "run", "started_at": "...", "ended_at": "..." },
        ...
      ]
    }

GET /api/v1/coach/events?metric_type=sleep_duration&days=90
  → Raw health_events for a specific metric over a time window
  → SELECT * FROM health_events
      WHERE user_id = $1
        AND metric_type = $2
        AND local_date >= $start_date
        AND deleted_at IS NULL
      ORDER BY recorded_at DESC
      LIMIT 500
```

---

## 7. Migration Plan

Since this is a development-stage application with no production users to protect,
the migration is a clean rebuild. RLS policies are created alongside the tables in
Step 2 — tables must never exist without row security enabled.

**Step 1 — Drop old tables (Supabase SQL editor):**
```
quick_logs, daily_health_metrics, sleep_records, weight_measurements,
nutrition_entries, blood_pressure_records, unified_activities,
cycle_tracking, environment_metrics
```

**Step 2 — Create new tables + enable RLS (single Alembic migration, ordered):**

1. `activity_sessions` (no foreign key dependencies)
2. `metric_definitions` + seed initial rows from Section 4.4
3. `health_events` (references `activity_sessions`)
4. `daily_summaries`
5. **RLS policies — enabled immediately in the same migration:**

```sql
-- health_events: authenticated users can SELECT their own events.
-- INSERT/UPDATE/DELETE are performed exclusively via Cloud Brain using the
-- Supabase service role key (which bypasses RLS). Users cannot write
-- health events directly via the Supabase client.
ALTER TABLE health_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY "users can read their own events"
  ON health_events FOR SELECT USING (user_id = auth.uid());

-- activity_sessions: same access pattern as health_events.
ALTER TABLE activity_sessions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "users can read their own sessions"
  ON activity_sessions FOR SELECT USING (user_id = auth.uid());

-- daily_summaries: read-only for users. Written exclusively by Cloud Brain
-- service role during aggregation. No user write policy is defined.
ALTER TABLE daily_summaries ENABLE ROW LEVEL SECURITY;
CREATE POLICY "users can read their own summaries"
  ON daily_summaries FOR SELECT USING (user_id = auth.uid());

-- metric_definitions: public read (all users see the same metric catalog).
-- Writes use the service role key only. No user write policy is defined.
ALTER TABLE metric_definitions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "metric definitions are publicly readable"
  ON metric_definitions FOR SELECT USING (true);
```

**Step 3 — Ensure `user_preferences.timezone` column exists:**
```sql
ALTER TABLE user_preferences
  ADD COLUMN IF NOT EXISTS timezone TEXT NOT NULL DEFAULT 'UTC';
```

**Step 4 — Update Cloud Brain API:**
- Remove all 10+ individual typed quick-log endpoints (`quick_log_routes.py` and all
  per-type typed endpoints)
- Implement unified ingest endpoints (`/ingest`, `/ingest/session`, `/ingest/bulk`,
  `DELETE /api/v1/events/{event_id}`)
- Implement `local_date` computation in the ingest service (parse UTC offset from
  `recorded_at` string before PostgreSQL normalization)
- Rewrite analytics queries to use `daily_summaries` with `$user_local_date` parameter
- Implement Today tab summary, timeline (paginated), and goals-progress endpoints
- Implement Coach tab context endpoints
- Implement trends correlation endpoint
- Implement background aggregation (FastAPI BackgroundTasks + APScheduler — see Section 9)
- Add `GET /api/v1/ingest/status/{task_id}` for bulk sync polling

**Step 5 — Update Flutter app:**
- Replace all typed quick-log API calls with unified `POST /api/v1/ingest` calls
- Replace `POST /api/v1/quick-log/batch` with `POST /api/v1/ingest/session` for
  multi-metric logs (runs, sleep, meals)
- Replace Apple Health sync call with `POST /api/v1/ingest/bulk`
- Generate and attach `idempotency_key` (UUID v4, generated on the Flutter side before
  any network call) to every manual event and session submission
- Add pagination support to the Today timeline (cursor-based)
- Analytics providers require no Flutter changes (same API interface, same response shape)
- Add `DELETE /api/v1/events/{event_id}` call on swipe-to-delete in Today timeline

**Step 6 — User account deletion (GDPR/CCPA):**
All health tables reference `users(id) ON DELETE CASCADE`. Deleting the `users` row
cascades to `health_events`, `activity_sessions`, and `daily_summaries`. This ensures
complete data deletion on account removal. Cloud Brain's account deletion endpoint must
delete the user record (not just mark it inactive) to trigger the cascade.

---

## 8. Performance at Scale

### Index Strategy

The two most critical indexes:
- `daily_summaries (user_id, metric_type, date DESC)` — serves all trend queries
- `daily_summaries (user_id, date DESC)` — serves all today/dashboard queries

Both fit comfortably in PostgreSQL's buffer cache for typical user datasets.
At 1 million users, the working set for active users (those querying within 30 days)
is a fraction of the total table — the index + hot data pages for recent rows stay
in memory.

### Partitioning Strategy

At 1 million users × 20 active metrics/user/day × 365 days = ~7.3 billion rows/year
in `daily_summaries` (realistic estimate; not all users log all 35+ metrics daily).
Even at the theoretical upper bound (100 metrics/user/day), the table would be ~36.5B
rows/year.

**Phase 1 (current, up to ~100K users): no partitioning.** The indexes above are
sufficient. PostgreSQL handles billions of rows efficiently with proper indexing.

**Phase 2 (100K–1M users): add monthly range partitioning on `daily_summaries.date`.**
This enables archiving months older than 12 months to cold storage and keeps partition
sizes manageable:

```sql
-- Convert to range-partitioned table (requires table rebuild or pg_partman)
-- Partition key: date (already in the UNIQUE constraint — satisfies PostgreSQL requirement)
-- One partition per month; pg_partman auto-creates future partitions
```

**Phase 3 (1M+ users): migrate to TimescaleDB.** This is the purpose-built solution
for this workload and requires zero schema changes:

```sql
SELECT create_hypertable('health_events', 'recorded_at', chunk_time_interval => INTERVAL '1 week');
SELECT create_hypertable('daily_summaries', 'date', chunk_time_interval => INTERVAL '1 month');
```

TimescaleDB continuous aggregates can replace the manual `daily_summaries` recomputation
entirely, making the APScheduler background worker redundant at that scale.

**Do not implement composite hash+range partitioning in PostgreSQL.** This requires
manually managing 192 partitions (16 hash × 12 monthly), provides no benefit over
TimescaleDB hypertables, and creates significant operational overhead. Skip directly
to TimescaleDB when partitioning is needed.

---

## 9. Background Worker Specification

### 9.1 Synchronous Aggregation (single events)

For `POST /api/v1/ingest` (single manual event):
- Aggregation runs synchronously before returning `201`.
- The response includes the updated `daily_total` for the affected metric.
- P99 latency must remain under 200ms. If the aggregation query exceeds this
  threshold under load, switch to async aggregation with a follow-up poll endpoint.

### 9.2 Asynchronous Aggregation (bulk device sync)

For `POST /api/v1/ingest/bulk`:
- All events are inserted in a single database transaction.
- Cloud Brain returns `202 Accepted` immediately.
- A **FastAPI `BackgroundTasks` task** is enqueued to run aggregation for all
  affected `(user_id, local_date, metric_type)` combinations from the batch.
- Task status is tracked in a lightweight in-memory dict (suitable for development;
  replace with Redis at scale). `GET /api/v1/ingest/status/{task_id}` returns
  `{ "status": "processing" | "complete" | "failed", "affected_dates": [...] }`.

### 9.3 Stale-Row Recomputation (APScheduler)

For aggregation failures and corrected events:
- An **APScheduler `AsyncIOScheduler`** runs inside the FastAPI process.
- Job: every 5 minutes, query `SELECT * FROM daily_summaries WHERE is_stale = true
  LIMIT 1000 ORDER BY computed_at ASC` and recompute each.
- On success: set `is_stale = false, computed_at = now()`.
- On failure: leave `is_stale = true`, log the error to Sentry.
- **Alerting:** If any row remains stale for more than 30 minutes, Sentry captures
  a warning-level event. If stale for more than 2 hours, it captures an error.

### 9.4 Future: Celery Migration

When the application scales beyond a single Cloud Brain instance (horizontal scaling),
FastAPI `BackgroundTasks` are not suitable (tasks run in-process and do not survive
restarts). At that point, replace with **Celery + Redis**:
- `celery_app.py` with Redis broker
- `tasks/aggregation.py` wrapping the same aggregation logic
- APScheduler replaced by Celery Beat

The aggregation logic is isolated in `app/services/aggregation_service.py` from the
start, making this migration a router-layer change with no logic changes.

---

## 10. Error Handling

- **Unknown `metric_type` on ingest:** Accept and store the event. The server-side
  service role inserts a placeholder row into `metric_definitions` with `is_active = false`
  for review. Never silently drop data from unknown metric types.
- **Out-of-range value:** Return `422 Unprocessable Entity`. Do not store the event.
  Validation runs before the database transaction begins.
- **Aggregation failure:** Mark the affected `daily_summaries` row with `is_stale = true`.
  APScheduler retries stale rows every 5 minutes. Raw events in `health_events` are
  always preserved regardless of aggregation outcome.
- **Duplicate manual event (idempotency_key match):** Return `200 OK` with the original
  event's data. No duplicate is inserted. This is treated as success, not a conflict.
- **Duplicate device point_in_time event (unique index conflict):** Return `200 OK`.
  The client should treat this as success (event already recorded).
- **Device daily aggregate re-sync:** Silently upsert — no error. Client receives `201`
  with the updated (or unchanged) daily total.
- **Bulk ingest validation failure:** Return `422` with a list of invalid events
  (index + reason). No events are inserted. The client should fix and retry.
- **Bulk ingest database failure:** Return `500`. All inserts are rolled back. No partial
  data is committed. The client may retry the full batch safely (idempotent).
- **Delete non-owned event:** Return `404`. Do not reveal whether the event exists for
  a different user (avoid enumeration).
- **Delete device-sourced event:** Return `422` with explanation. Users cannot delete
  device readings — they must re-sync from the device with corrected data.

---

## 11. What Each Tab Uses

| Tab | Primary Tables | Use |
|-----|---------------|-----|
| Today | `daily_summaries` (today) + `health_events` (today, paginated) | Current day totals + raw log timeline |
| Data | `daily_summaries` (7D/30D/90D) | Trend charts and tile values |
| Coach | `daily_summaries` + `health_events` + `activity_sessions` | AI context — structured summaries + raw history |
| Progress | `daily_summaries` + `user_goals` | Goal progress computation |
| Trends | `daily_summaries` (self-join) | Correlation analysis between any two metrics |
| Settings | `users` + `user_preferences` | Profile and preferences only |

---

## 12. Summary

**Before:** 7+ tables, manual sync required for each metric, Today tab and Data tab
disconnected, adding a new integration breaks things, no audit trail.

**After:** 3 health tables (`health_events`, `daily_summaries`, `metric_definitions`) +
1 session table (`activity_sessions`), all tabs read from the same data, new integrations
require zero schema changes, full audit trail preserved, timezone-correct daily buckets
via server-computed `local_date`, idempotent ingest for both manual and device sources,
soft-delete for user corrections, scalable to 1M+ users via indexing then TimescaleDB,
background aggregation via FastAPI BackgroundTasks + APScheduler with Celery upgrade path.
