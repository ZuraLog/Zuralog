# Unified Data Pipeline — Design Spec

**Date:** 2026-03-26
**Status:** Approved
**Scope:** Backend architecture (Cloud Brain), with minor Flutter touch-points

---

## Problem

Zuralog has two disconnected data pipelines:

- **Pipeline A (newer):** Manual logs and Apple Health / Health Connect data flow through `health_events` → `daily_summaries`. All 5 app tabs read from `daily_summaries`.
- **Pipeline B (older):** Strava, Fitbit, Oura, Withings, and Polar write to separate typed tables (`unified_activities`, `sleep_records`, `weight_measurements`, `nutrition_entries`, `daily_health_metrics`). No app tab reads from these tables.

Result: data from Pipeline B integrations is fetched and stored but invisible to the entire application. Users who rely on Strava, Fitbit, or Oura see incomplete or empty dashboards, broken trends, and inaccurate coaching.

## Solution

Unify into one universal pipeline. Every data source — no matter what it is — produces `health_events`. The existing aggregation service crunches those into `daily_summaries`. All tabs continue reading from `daily_summaries` as they already do.

Drop the old typed tables entirely (we are in development with no real users). Rebuild from a clean slate and reseed test data.

---

## Architecture

### The Universal Pipeline

```
Any Source (Strava, Fitbit, Apple Health, manual log, future integration #51)
    │
    ▼
Integration Adapter (one per source — translates API data → health_events format)
    │
    ▼
health_events (single raw event store — the source of truth)
    │
    ▼
Aggregation Service (computes daily totals with smart deduplication)
    │
    ▼
daily_summaries (derived read cache — all 5 tabs read from here)
```

### Core Principle

Adding a new integration means writing **one adapter function** that converts the integration's API response into `health_events` format. No schema changes. No new tables. No migrations. The aggregation service, the dedup logic, and all 5 app tabs are completely unaware that a new integration was added.

---

## Schema

### health_events (enhanced)

The existing table with targeted additions. This is the source of truth for all health data.

| Column | Type | Purpose |
|--------|------|---------|
| `id` | UUID, PK | Unique event identifier |
| `user_id` | VARCHAR, indexed | Owner |
| `metric_type` | VARCHAR(100) | What was measured (e.g., `steps`, `sleep_duration`, `active_calories`) |
| `value` | FLOAT | The numeric measurement |
| `unit` | VARCHAR(50) | Unit of measurement |
| `source` | VARCHAR(50) | Which integration produced this (`strava`, `fitbit`, `apple_health`, `manual`, etc.) |
| `recorded_at` | TIMESTAMPTZ | When the measurement was taken (UTC) |
| `local_date` | DATE | The user's calendar date for this event |
| `granularity` | VARCHAR(30) | `daily_aggregate`, `point_in_time`, or `session` |
| `session_id` | UUID, nullable | Groups events from the same activity session (e.g., a single run produces events for distance, calories, duration) |
| `idempotency_key` | VARCHAR, nullable | Prevents duplicate ingestion of the same raw data. Unique constraint: partial unique index on `(user_id, source, idempotency_key) WHERE idempotency_key IS NOT NULL`. Rows with NULL idempotency keys are unconstrained. |
| `metadata` | JSONB | Source-specific context (activity type, heart rate zones, workout name, etc.) |
| `deleted_at` | TIMESTAMPTZ, nullable | Soft delete timestamp |
| `is_primary` | BOOLEAN, default TRUE | Set by the aggregation service. FALSE means a higher-priority source provided the same data for this date+metric. Tabs filter by `is_primary = TRUE`. |
| `superseded_by` | UUID, nullable FK | Points to the event that superseded this one. NULL if this event is primary. |
| `created_at` | TIMESTAMPTZ | Row creation time |
| `updated_at` | TIMESTAMPTZ | Updated whenever `is_primary` or `superseded_by` changes |

**Key indexes:**
- `(user_id, local_date, metric_type)` — the aggregation query path
- `(user_id, source, idempotency_key) WHERE idempotency_key IS NOT NULL` — partial unique index for duplicate ingestion prevention
- `(user_id, local_date, metric_type, source)` — dedup lookups during aggregation
- `(session_id)` — grouping events from the same activity

### event_details (new)

Stores rich payloads that don't belong in the events table — GPS tracks, sleep stage breakdowns, heart rate time series, lap splits. Kept separate so the events table stays lean for aggregation queries.

| Column | Type | Purpose |
|--------|------|---------|
| `id` | UUID, PK | Unique identifier |
| `event_id` | UUID, FK → health_events | The parent event this detail belongs to |
| `detail_type` | VARCHAR(50) | What kind of detail (`gps_track`, `sleep_stages`, `heart_rate_series`, `lap_splits`, `route_summary`) |
| `data` | JSONB | The actual payload |
| `created_at` | TIMESTAMPTZ | Row creation time |

**Key index:** `(event_id)` — lookup by parent event.

**Size limit:** Maximum 1 MB per `data` payload. Adapters must validate payload size before saving. For GPS tracks exceeding 1 MB (very long activities with high-frequency sampling), the adapter should downsample the coordinate array to fit within the limit. Future optimization: move oversized payloads to object storage (S3/R2) and store a reference URL in the JSONB instead.

**RLS:** Row-level security must be enabled on this table. Policy: a user can only read `event_details` rows where the parent `health_event.user_id` matches the authenticated user. This matches the RLS pattern already applied to all other tables in the project.

**Example payloads:**

GPS track:
```json
{
  "detail_type": "gps_track",
  "data": {
    "format": "geojson",
    "points_count": 1842,
    "track": { "type": "LineString", "coordinates": [[lng, lat, alt], ...] }
  }
}
```

Sleep stages:
```json
{
  "detail_type": "sleep_stages",
  "data": {
    "stages": [
      { "stage": "light", "start": "2026-03-25T23:15:00Z", "end": "2026-03-26T00:30:00Z" },
      { "stage": "deep", "start": "2026-03-26T00:30:00Z", "end": "2026-03-26T01:45:00Z" }
    ]
  }
}
```

### daily_summaries (unchanged)

No schema changes. Continues to serve as the derived read cache for all 5 tabs. The only change is in how the aggregation service populates it (smart dedup logic — see below).

### Tables to drop

These typed tables are removed entirely. Their responsibilities are absorbed by `health_events` + `event_details`. Note: a migration (`v7w8x9y0z1a2_drop_legacy_health_tables.py`) may already exist in the codebase — check its state before creating a duplicate. If it has already been applied, Phase 1 skips this step.

- `unified_activities`
- `sleep_records`
- `nutrition_entries`
- `weight_measurements`
- `daily_health_metrics`

The old ingest endpoint (`POST /api/v1/health/ingest`) that wrote to these tables is also removed. All ingestion goes through the existing `POST /api/v1/ingest/bulk` and `POST /api/v1/ingest` endpoints.

---

## Smart Deduplication

Deduplication happens at aggregation time, not at ingest. Events are always saved as-is. The aggregation service decides which events count.

### Source Priority

Source priority is **per metric category**, not a single flat list. Different sources excel at different types of data.

**Sleep metrics** (`sleep_duration`, `sleep_quality`, `deep_sleep_minutes`, `rem_sleep_minutes`):
```
oura > fitbit > polar > withings > apple_health > health_connect > manual
```

**Exercise metrics** (`active_calories`, `exercise_minutes`, `distance`):
```
strava > garmin > polar > fitbit > oura > apple_health > health_connect > manual
```

**Body metrics** (`weight_kg`, `body_fat_percentage`):
```
withings > fitbit > garmin > oura > apple_health > health_connect > manual
```

**Heart metrics** (`resting_heart_rate`, `hrv_ms`, `heart_rate_avg`):
```
oura > polar > garmin > fitbit > apple_health > health_connect > manual
```

**Default** (all other metrics — `steps`, `calories`, `water_ml`, `mood`, `energy`, `stress`, etc.):
```
oura > fitbit > garmin > polar > withings > strava > apple_health > health_connect > manual
```

Sources not yet implemented (garmin) are included for future-proofing. They have no effect until an adapter is registered.

Manual is always last because if a user has an integration providing a metric, the integration's value is almost always more accurate than a manual estimate. However, if manual is the ONLY source for a metric on a given day, it is primary by default.

The priority lists are stored as a configuration dict in the aggregation service, not hardcoded per-query. Adjusting rankings requires changing one file.

### Dedup Logic (runs during aggregation)

Deduplication and aggregation happen in two explicit, sequential steps within a single database transaction. This avoids the circular dependency of needing `is_primary` to aggregate while needing aggregation to set `is_primary`.

**Step 1 — Mark primary/non-primary flags:**

For each `(user_id, local_date, metric_type)` combination:

1. **Gather** all non-deleted events for this combination.
2. **Group by source.**
3. **Determine which events are duplicates vs. distinct activities:**
   - **For `daily_aggregate` granularity** (e.g., total steps, total calories): All sources reporting the same metric on the same day are considered duplicates by definition. A daily step count from Fitbit and a daily step count from Apple Health for the same day represent the same measurement, not two separate activities. The highest-priority source wins; all others are marked `is_primary = FALSE`.
   - **For `point_in_time` and `session` granularity** (e.g., individual workouts, weight readings): Compare events across sources using two checks:
     - **Time proximity:** Are the `recorded_at` timestamps within 2 hours of each other?
     - **Value similarity:** Is the relative difference within a threshold? Formula: `abs(a - b) / max(abs(a), abs(b)) <= threshold`. When both values are zero, they are considered equal. Default thresholds by metric category: exercise metrics 25%, body metrics 5%, heart metrics 15%, all others 20%. These are starting defaults that may be tuned based on real-world data.
     - If BOTH conditions are met → same activity. Higher-priority source keeps `is_primary = TRUE`; lower-priority source gets `is_primary = FALSE` and `superseded_by` set to the winning event's ID.
     - If either condition fails → different activities. Both stay `is_primary = TRUE`.

**Step 2 — Aggregate primary events into daily_summaries:**

4. **Query only `is_primary = TRUE` events** for this `(user_id, local_date, metric_type)`.
5. **Apply the existing aggregation rule** (sum, avg, or latest depending on metric type as defined in `metric_definitions`).
6. **Upsert** the result into `daily_summaries`.

Both steps run in the same transaction. If either fails, the entire operation rolls back.

### Edge Cases

- **User disconnects an integration:** All events from that source remain in `health_events` but the integration stops syncing new data. On next aggregation run, if those events were primary and a lower-priority source also has events for the same date+metric, the lower-priority source gets promoted to primary. No data loss.
- **User reconnects an integration:** New events flow in. Aggregation re-evaluates and the higher-priority source reclaims primary status.
- **Backfill:** When a user connects Strava for the first time and we pull 6 months of history, all events are saved, then aggregation runs across all affected dates. Dedup resolves everything in one pass. Backfill tasks run on a dedicated Celery queue with lower priority than real-time syncs, and process dates in batches of 30 to avoid overwhelming the database or starving other tasks.

---

## Integration Adapter Pattern

Each integration implements a simple contract: take the raw API response and return a list of `health_events` (and optionally `event_details`).

### Adapter Interface

```python
class IntegrationAdapter:
    """Base class for all integration adapters."""

    source_name: str  # e.g., "strava", "fitbit"

    def transform(self, raw_data: dict, user_id: str, user_tz: str) -> AdapterResult:
        """Convert raw API data into health_events + optional event_details."""
        raise NotImplementedError

@dataclass
class AdapterResult:
    events: list[HealthEventCreate]      # Events to save
    details: list[EventDetailCreate]     # Rich payloads (GPS, sleep stages, etc.)
```

### Example: Strava Adapter

A Strava activity webhook delivers a payload with activity type, distance, duration, calories, start time, and optionally a GPS stream. The adapter produces:

- One `health_event` per metric: `active_calories`, `distance`, `exercise_minutes`
- All events share a `session_id` linking them as one workout
- If GPS data is present, one `event_details` row with `detail_type = "gps_track"`

### Adding Integration #51

1. Write an adapter class that implements `transform()`
2. Register it in the adapter registry
3. Wire the webhook or sync task to call the adapter and save the results through the standard ingest path

No schema changes. No new tables. No changes to aggregation, dedup, or any tab.

---

## Tab Interactions

### Today Tab
- **Quick logs** create `health_events` via `POST /api/v1/ingest` (unchanged)
- **Streaks** read from `user_streaks` (unchanged)
- **Health score** computed from `daily_summaries` (unchanged)
- **Impact:** None. Works exactly as it does today.

### Data Tab
- **Daily totals** read from `daily_summaries` (unchanged)
- **Per-source breakdown** can now query `health_events` filtered by `is_primary = TRUE`, grouped by `source` — shows which integration contributed what
- **Individual events** queryable from `health_events` with source badges
- **Impact:** Minor frontend enhancement opportunity (source badges, per-source filtering). Backend queries unchanged.

### Coach Tab
- **Context building** reads from `daily_summaries` + `health_events` via `HealthBriefBuilder` (unchanged)
- **Impact:** None structurally. The coach automatically sees richer data because all sources now feed into the tables it already reads.

### Progress Tab
- **Goals** check current values against `daily_summaries` (unchanged)
- **Achievements** and **streaks** have their own tables (unchanged)
- **Journals** are separate from health data (unchanged)
- **Impact:** None. Goals that depend on integration data (e.g., "run 3x/week" tracked via Strava) will now work correctly.

### Trends Tab
- Reads from `daily_summaries` via `HealthBriefBuilder` (unchanged)
- Pre-computed caching (separate project) will layer on top
- **Impact:** None structurally. More complete data produces better correlations.

### Settings & Profile
- **Impact:** None. User preferences, auth, profile pictures are unrelated to the health data pipeline.

---

## What Gets Removed

### Tables dropped
- `unified_activities`
- `sleep_records`
- `nutrition_entries`
- `weight_measurements`
- `daily_health_metrics`

### Endpoints removed
- `POST /api/v1/health/ingest` (legacy typed-table ingest)

### Services retired
- `DataNormalizer` (`cloud-brain/app/analytics/normalizer.py`) — its job is absorbed by integration adapters
- Any direct-write logic in sync services (`sync_scheduler.py`, `fitbit_sync.py`, etc.) that targets the typed tables

### Code removed
- ORM models for the dropped tables (`health_data.py`, `daily_metrics.py`)
- Old health ingest route file (`health_ingest.py`)

---

## Seed Data

Since we're starting from a clean slate, the seed script (`scripts/seed_demo_data.py`) is rewritten to:

1. **demo-full@zuralog.dev** — 30+ days of realistic health data across multiple sources (Apple Health, Strava, Fitbit, manual). Includes overlapping data from multiple sources to exercise the dedup logic. Includes event_details rows for GPS tracks and sleep stages.
2. **demo-empty@zuralog.dev** — Empty account with preferences set but no health data.

---

## Implementation Phases

### Phase 1: Schema & Core Pipeline
- Add `is_primary` and `superseded_by` columns to `health_events`
- Create `event_details` table
- Drop the 5 typed tables and their ORM models
- Remove the legacy ingest endpoint and `DataNormalizer`
- Update the aggregation service with smart dedup logic

### Phase 2a: Integration Adapters (core)
- Define the `IntegrationAdapter` base class and registry
- Rewrite Strava sync to use the adapter pattern → `health_events`
- Rewrite Fitbit sync to use the adapter pattern → `health_events`
- Rewrite Oura sync to use the adapter pattern → `health_events`

### Phase 2b: Integration Adapters (remaining)
- Rewrite Withings sync to use the adapter pattern → `health_events`
- Rewrite Polar sync to use the adapter pattern → `health_events`

### Phase 3: Seed & Verify
- Rewrite the seed script for the new schema
- Verify all 5 tabs display correct data with the demo-full account
- Verify smart dedup handles overlapping sources correctly

### Phase 4: Cleanup
- Remove dead code referencing the old typed tables
- Update documentation

---

## Out of Scope

- **Trends pre-computed caching** — separate project that builds on top of this work
- **New integration implementations** (Garmin, Whoop, etc.) — future work using the adapter pattern
- **Data Tab UI redesign** — optional enhancement, not required for this change
- **Documentation overhaul** — planned as a separate effort after this spec is implemented
