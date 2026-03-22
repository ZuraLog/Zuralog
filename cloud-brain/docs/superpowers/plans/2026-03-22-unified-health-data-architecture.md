# Unified Health Data Architecture — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace 7+ fragmented health data tables with a unified event-sourcing + CQRS architecture (`health_events` → `daily_summaries`) so every app tab reads from one consistent data layer.

**Architecture:** All writes go to `health_events` (append-only for manual/point-in-time, upsert for device daily aggregates). An aggregation service recomputes `daily_summaries` after each write. All read endpoints query `daily_summaries`. Raw events are preserved forever.

**Tech Stack:** FastAPI, SQLAlchemy 2.0 async, asyncpg, Alembic, Celery (existing), Supabase PostgreSQL, Flutter/Riverpod/Dio.

**Spec:** `cloud-brain/docs/superpowers/specs/2026-03-22-unified-health-data-architecture-design.md`

---

## File Map

**New files — Cloud Brain:**
- `app/models/health_event.py` — SQLAlchemy model for `health_events`
- `app/models/activity_session.py` — SQLAlchemy model for `activity_sessions`
- `app/models/daily_summary.py` — SQLAlchemy model for `daily_summaries`
- `app/models/metric_definition.py` — SQLAlchemy model for `metric_definitions`
- `app/services/aggregation_service.py` — Pure aggregation logic (sum/avg/latest)
- `app/services/ingest_service.py` — `local_date` computation, validation, write orchestration
- `app/api/v1/ingest_routes.py` — POST /ingest, /ingest/session, /ingest/bulk, DELETE /events/{id}
- `app/api/v1/today_routes.py` — GET /today/summary, /today/timeline, /today/goals-progress
- `app/api/v1/coach_routes.py` — GET /coach/context, /coach/events
- `app/tasks/aggregation_tasks.py` — Celery tasks for bulk + stale-row aggregation
- `alembic/versions/<hash>_drop_legacy_health_tables.py`
- `alembic/versions/<hash>_create_unified_health_tables.py`
- `alembic/versions/<hash>_add_timezone_to_user_preferences.py`
- `tests/services/test_aggregation_service.py`
- `tests/services/test_ingest_service.py`
- `tests/api/test_ingest_routes.py`
- `tests/api/test_today_routes.py`
- `tests/api/test_coach_routes.py`
- `tests/tasks/test_aggregation_tasks.py`

**Modified files — Cloud Brain:**
- `app/main.py` — register new routers; remove quick_log_router; add trends correlation route
- `app/api/v1/analytics.py` — rewrite queries to use `daily_summaries` with `$user_local_date`
- `app/api/v1/trends_routes.py` — implement correlation endpoint
- `app/models/__init__.py` — export new models
- `celery_app.py` (or equivalent) — add Celery Beat schedule for stale-row job

**Modified files — Flutter:**
- `zuralog/lib/features/today/data/today_repository.dart` — replace `submitQuickLog` with unified ingest; add `submitSession`, `bulkIngest`, `deleteEvent`, `getTodaySummary`, `getTodayTimeline`
- `zuralog/lib/features/today/domain/today_models.dart` — add `TodaySummary`, `TodayEvent`, `TodayTimeline` models
- `zuralog/lib/features/today/providers/today_providers.dart` — wire new providers
- `zuralog/lib/core/utils/idempotency_key.dart` — UUID v4 generator helper (new)

---

## Phase 1: Database Migrations

### Task 1: Drop legacy health tables

**Files:**
- Create: `alembic/versions/<hash>_drop_legacy_health_tables.py`

- [ ] **Step 1: Write the migration**

```python
"""Drop legacy health tables.

Revision ID: drop_legacy_health_001
Revises: (set to current head)
Create Date: 2026-03-22
"""
from alembic import op

revision = "drop_legacy_health_001"
down_revision = None  # set to actual current head
branch_labels = None
depends_on = None


def upgrade() -> None:
    for table in [
        "quick_logs",
        "daily_health_metrics",
        "sleep_records",
        "weight_measurements",
        "nutrition_entries",
        "blood_pressure_records",
        "unified_activities",
        "cycle_tracking",
        "environment_metrics",
    ]:
        op.execute(f"DROP TABLE IF EXISTS {table} CASCADE")


def downgrade() -> None:
    pass  # No downgrade — dev-only, no production data to protect
```

- [ ] **Step 2: Run migration and verify**

```bash
cd cloud-brain
alembic upgrade head
```

Expected: `Running upgrade ... -> drop_legacy_health_001` with no errors.

- [ ] **Step 3: Verify tables are gone**

```bash
alembic current
```

Expected: shows `drop_legacy_health_001 (head)`.

- [ ] **Step 4: Commit**

```bash
git add alembic/versions/
git commit -m "db: drop legacy health tables (quick_logs, daily_health_metrics, sleep_records, etc.)"
```

---

### Task 2: Create unified health tables + RLS

**Files:**
- Create: `alembic/versions/<hash>_create_unified_health_tables.py`

- [ ] **Step 1: Write the migration**

```python
"""Create unified health tables.

Revision ID: create_unified_health_001
Revises: drop_legacy_health_001
Create Date: 2026-03-22
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "create_unified_health_001"
down_revision = "drop_legacy_health_001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # 1. activity_sessions (no FK dependencies)
    op.create_table(
        "activity_sessions",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("activity_type", sa.Text, nullable=False),
        sa.Column("source", sa.Text, nullable=False),
        sa.Column("started_at", sa.TIMESTAMP(timezone=True), nullable=False),
        sa.Column("ended_at", sa.TIMESTAMP(timezone=True), nullable=True),
        sa.Column("notes", sa.Text, nullable=True),
        sa.Column("metadata", postgresql.JSONB, nullable=True),
        sa.Column("idempotency_key", sa.Text, nullable=True),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
    )
    op.create_index("idx_activity_sessions_user_type_time", "activity_sessions", ["user_id", "activity_type", sa.text("started_at DESC")])
    op.create_index("idx_activity_sessions_idempotency", "activity_sessions", ["user_id", "idempotency_key"], unique=True, postgresql_where=sa.text("idempotency_key IS NOT NULL"))

    # 2. metric_definitions
    op.create_table(
        "metric_definitions",
        sa.Column("metric_type", sa.Text, primary_key=True),
        sa.Column("display_name", sa.Text, nullable=False),
        sa.Column("unit", sa.Text, nullable=False),
        sa.Column("category", sa.Text, nullable=False),
        sa.Column("aggregation_fn", sa.Text, nullable=False),
        sa.Column("data_type", sa.Text, nullable=False),
        sa.Column("min_value", sa.Float(precision=53), nullable=True),
        sa.Column("max_value", sa.Float(precision=53), nullable=True),
        sa.Column("is_active", sa.Boolean, nullable=False, server_default=sa.text("true")),
        sa.Column("display_order", sa.Integer, nullable=False, server_default=sa.text("0")),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()")),
    )

    # 3. health_events (references activity_sessions)
    op.create_table(
        "health_events",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("metric_type", sa.Text, nullable=False),
        sa.Column("value", sa.Float(precision=53), nullable=False),
        sa.Column("unit", sa.Text, nullable=False),
        sa.Column("source", sa.Text, nullable=False),
        sa.Column("recorded_at", sa.TIMESTAMP(timezone=True), nullable=False),
        sa.Column("local_date", sa.Date, nullable=False),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True), nullable=True),
        sa.Column("deleted_at", sa.TIMESTAMP(timezone=True), nullable=True),
        sa.Column("granularity", sa.Text, nullable=False, server_default=sa.text("'point_in_time'")),
        sa.Column("session_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("idempotency_key", sa.Text, nullable=True),
        sa.Column("metadata", postgresql.JSONB, nullable=True),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["session_id"], ["activity_sessions.id"], ondelete="SET NULL"),
    )
    op.create_index("idx_health_events_device_point_dedup", "health_events",
        ["user_id", "source", "metric_type", "recorded_at"], unique=True,
        postgresql_where=sa.text("source != 'manual' AND granularity = 'point_in_time'"))
    op.create_index("idx_health_events_device_daily_dedup", "health_events",
        ["user_id", "source", "metric_type", "local_date"], unique=True,
        postgresql_where=sa.text("granularity = 'daily_aggregate'"))
    op.create_index("idx_health_events_idempotency", "health_events",
        ["user_id", "idempotency_key"], unique=True,
        postgresql_where=sa.text("idempotency_key IS NOT NULL"))
    op.create_index("idx_health_events_user_metric_time", "health_events",
        ["user_id", "metric_type", sa.text("recorded_at DESC")],
        postgresql_where=sa.text("deleted_at IS NULL"))
    op.create_index("idx_health_events_user_local_date", "health_events",
        ["user_id", sa.text("local_date DESC")],
        postgresql_where=sa.text("deleted_at IS NULL"))
    op.create_index("idx_health_events_session", "health_events", ["session_id"],
        postgresql_where=sa.text("session_id IS NOT NULL AND deleted_at IS NULL"))

    # 4. daily_summaries
    op.create_table(
        "daily_summaries",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("date", sa.Date, nullable=False),
        sa.Column("metric_type", sa.Text, nullable=False),
        sa.Column("value", sa.Float(precision=53), nullable=False),
        sa.Column("unit", sa.Text, nullable=False),
        sa.Column("event_count", sa.Integer, nullable=False, server_default=sa.text("1")),
        sa.Column("is_stale", sa.Boolean, nullable=False, server_default=sa.text("false")),
        sa.Column("computed_at", sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.UniqueConstraint("user_id", "date", "metric_type", name="uq_daily_summaries_user_date_metric"),
    )
    op.create_index("idx_daily_summaries_user_metric_date", "daily_summaries",
        ["user_id", "metric_type", sa.text("date DESC")])
    op.create_index("idx_daily_summaries_user_date", "daily_summaries",
        ["user_id", sa.text("date DESC")])
    op.create_index("idx_daily_summaries_stale", "daily_summaries", ["is_stale"],
        postgresql_where=sa.text("is_stale = true"))

    # 5. RLS — enable immediately, in the same migration
    op.execute("ALTER TABLE activity_sessions ENABLE ROW LEVEL SECURITY")
    op.execute("""
        CREATE POLICY "users can read their own sessions"
        ON activity_sessions FOR SELECT USING (user_id = auth.uid())
    """)
    op.execute("ALTER TABLE metric_definitions ENABLE ROW LEVEL SECURITY")
    op.execute("""
        CREATE POLICY "metric definitions are publicly readable"
        ON metric_definitions FOR SELECT USING (true)
    """)
    op.execute("ALTER TABLE health_events ENABLE ROW LEVEL SECURITY")
    op.execute("""
        CREATE POLICY "users can read their own events"
        ON health_events FOR SELECT USING (user_id = auth.uid())
    """)
    op.execute("ALTER TABLE daily_summaries ENABLE ROW LEVEL SECURITY")
    op.execute("""
        CREATE POLICY "users can read their own summaries"
        ON daily_summaries FOR SELECT USING (user_id = auth.uid())
    """)

    # 6. Seed metric_definitions
    op.execute("""
        INSERT INTO metric_definitions
            (metric_type, display_name, unit, category, aggregation_fn, data_type, min_value, max_value, display_order)
        VALUES
            ('steps','Steps','steps','activity','sum','integer',0,100000,1),
            ('active_calories','Active Calories','kcal','activity','sum','float',0,10000,2),
            ('distance','Distance','m','activity','sum','float',0,500000,3),
            ('exercise_minutes','Exercise Minutes','min','activity','sum','integer',0,1440,4),
            ('walking_speed','Walking Speed','m/s','activity','avg','float',0,10,5),
            ('running_pace','Running Pace','s/km','activity','avg','float',60,1800,6),
            ('floors_climbed','Floors Climbed','floors','activity','sum','integer',0,500,7),
            ('sleep_duration','Sleep Duration','min','sleep','latest','duration',0,1440,1),
            ('deep_sleep_minutes','Deep Sleep','min','sleep','latest','duration',0,720,2),
            ('rem_sleep_minutes','REM Sleep','min','sleep','latest','duration',0,720,3),
            ('sleep_efficiency','Sleep Efficiency','%','sleep','latest','float',0,100,4),
            ('sleep_quality','Sleep Quality','score','sleep','latest','score',0,100,5),
            ('resting_heart_rate','Resting Heart Rate','bpm','heart','avg','float',20,220,1),
            ('hrv_ms','HRV','ms','heart','avg','float',0,300,2),
            ('vo2_max','VO2 Max','mL/kg/min','heart','latest','float',10,90,3),
            ('respiratory_rate','Respiratory Rate','brpm','heart','avg','float',5,60,4),
            ('heart_rate_avg','Avg Heart Rate','bpm','heart','avg','float',20,220,5),
            ('weight_kg','Weight','kg','body','latest','float',20,500,1),
            ('body_fat_percentage','Body Fat','%','body','latest','float',1,70,2),
            ('body_temperature','Body Temperature','°C','body','avg','float',34,42,3),
            ('wrist_temperature','Wrist Temperature','°C','body','avg','float',30,42,4),
            ('muscle_mass_kg','Muscle Mass','kg','body','latest','float',5,200,5),
            ('blood_pressure_systolic','Blood Pressure (Sys)','mmHg','vitals','avg','integer',50,250,1),
            ('blood_pressure_diastolic','Blood Pressure (Dia)','mmHg','vitals','avg','integer',30,150,2),
            ('spo2','Blood Oxygen','%','vitals','avg','float',70,100,3),
            ('blood_glucose','Blood Glucose','mmol/L','vitals','avg','float',1,30,4),
            ('calories','Calories','kcal','nutrition','sum','integer',0,20000,1),
            ('protein_grams','Protein','g','nutrition','sum','float',0,1000,2),
            ('carbs_grams','Carbs','g','nutrition','sum','float',0,2000,3),
            ('fat_grams','Fat','g','nutrition','sum','float',0,1000,4),
            ('water_ml','Water','mL','nutrition','sum','float',0,20000,5),
            ('mood','Mood','/10','wellness','avg','score',0,10,1),
            ('energy','Energy','/10','wellness','avg','score',0,10,2),
            ('stress','Stress','/100','wellness','avg','score',0,100,3),
            ('mindful_minutes','Mindful Minutes','min','wellness','sum','integer',0,1440,4),
            ('cycle_day','Cycle Day','day','cycle','latest','integer',1,40,1),
            ('noise_exposure','Noise Exposure','dB','environment','avg','float',0,200,1),
            ('uv_index','UV Index','UV','environment','avg','float',0,20,2)
        ON CONFLICT (metric_type) DO NOTHING
    """)


def downgrade() -> None:
    for table in ["daily_summaries", "health_events", "metric_definitions", "activity_sessions"]:
        op.execute(f"DROP TABLE IF EXISTS {table} CASCADE")
```

- [ ] **Step 2: Run migration**

```bash
alembic upgrade head
```

Expected: `Running upgrade drop_legacy_health_001 -> create_unified_health_001` with no errors.

- [ ] **Step 3: Spot-check in psql**

```bash
psql $DATABASE_URL -c "\dt health_events daily_summaries metric_definitions activity_sessions"
psql $DATABASE_URL -c "SELECT count(*) FROM metric_definitions"
```

Expected: 4 tables exist, `count = 35` metric definitions seeded.

- [ ] **Step 4: Commit**

```bash
git add alembic/versions/
git commit -m "db: create health_events, activity_sessions, daily_summaries, metric_definitions with RLS"
```

---

### Task 3: Ensure `timezone` column exists in `user_preferences`

**Note:** The column may already exist if migration `p1q2r3s4t5u6_ai_insights_engine_schema.py`
was applied. The migration below uses `ADD COLUMN IF NOT EXISTS` — safe to run either way.

**Files:**
- Create: `alembic/versions/<hash>_ensure_timezone_in_user_preferences.py`

- [ ] **Step 1: Check whether the column already exists**

```bash
psql $DATABASE_URL -c "\d user_preferences" | grep timezone
```

If the column exists, skip to Step 3 (no migration needed — just commit a note).

- [ ] **Step 2: Write the migration (only if column is missing)**

```python
"""Ensure timezone column exists in user_preferences.

Revision ID: ensure_timezone_pref_001
Revises: create_unified_health_001
"""
from alembic import op
import sqlalchemy as sa

revision = "ensure_timezone_pref_001"
down_revision = "create_unified_health_001"

def upgrade() -> None:
    # IF NOT EXISTS: safe to run even if a previous migration already added this column.
    op.execute(
        "ALTER TABLE user_preferences ADD COLUMN IF NOT EXISTS timezone TEXT NOT NULL DEFAULT 'UTC'"
    )

def downgrade() -> None:
    # Intentionally a no-op — removing timezone would break existing timezone logic.
    pass
```

- [ ] **Step 3: Run + verify**

```bash
alembic upgrade head
psql $DATABASE_URL -c "\d user_preferences" | grep timezone
```

Expected: `timezone | text | not null | default 'UTC'`

- [ ] **Step 4: Commit**

```bash
git add alembic/versions/
git commit -m "db: ensure timezone column exists in user_preferences"
```

---

### Task 3b: Data migration — update `user_goals` and `user_streaks` metric slugs

The old `quick_logs` used metric names like `"water"`, `"steps_count"`, `"sleep"`. The new
schema uses canonical slugs like `"water_ml"`, `"steps"`, `"sleep_duration"`. The
`user_goals` and `user_streaks` tables still reference old names. A query like
`JOIN user_goals ON ds.metric_type = ug.metric_type` will return zero rows until fixed.

**Files:**
- Create: `alembic/versions/<hash>_migrate_metric_slugs.py`

- [ ] **Step 1: Audit current metric values in user_goals and user_streaks**

```bash
psql $DATABASE_URL -c "SELECT DISTINCT metric FROM user_goals ORDER BY metric"
psql $DATABASE_URL -c "SELECT DISTINCT metric_type FROM user_streaks ORDER BY metric_type"
```

Record the distinct values. Map each old slug to the new canonical slug from `metric_definitions`.

- [ ] **Step 2: Write the migration**

```python
"""Migrate metric slugs in user_goals and user_streaks to canonical names.

Revision ID: migrate_metric_slugs_001
Revises: ensure_timezone_pref_001
"""
from alembic import op

revision = "migrate_metric_slugs_001"
down_revision = "ensure_timezone_pref_001"

# Add more mappings based on the audit in Step 1.
SLUG_MAP = {
    "water":        "water_ml",
    "steps_count":  "steps",
    "sleep":        "sleep_duration",
    "weight":       "weight_kg",
    "mood":         "mood",       # already correct
    "energy":       "energy",     # already correct
    "stress":       "stress",     # already correct
    "run":          "exercise_minutes",
}

def upgrade() -> None:
    for old, new in SLUG_MAP.items():
        op.execute(
            f"UPDATE user_goals SET metric = '{new}' WHERE metric = '{old}'"
        )
        op.execute(
            f"UPDATE user_streaks SET metric_type = '{new}' WHERE metric_type = '{old}'"
        )

def downgrade() -> None:
    for old, new in SLUG_MAP.items():
        op.execute(
            f"UPDATE user_goals SET metric = '{old}' WHERE metric = '{new}'"
        )
        op.execute(
            f"UPDATE user_streaks SET metric_type = '{old}' WHERE metric_type = '{new}'"
        )
```

**Important:** Run the audit (Step 1) first and update `SLUG_MAP` to cover all values found.
Do not assume the list above is complete.

- [ ] **Step 3: Run + verify**

```bash
alembic upgrade head
psql $DATABASE_URL -c "SELECT DISTINCT metric FROM user_goals ORDER BY metric"
```

Expected: only canonical slugs that exist in `metric_definitions`.

- [ ] **Step 4: Commit**

```bash
git add alembic/versions/
git commit -m "db: migrate user_goals and user_streaks to canonical metric_type slugs"
```

---

## Phase 2: SQLAlchemy Models

### Task 4: Create the four new ORM models

**Files:**
- Create: `app/models/metric_definition.py`
- Create: `app/models/activity_session.py`
- Create: `app/models/health_event.py`
- Create: `app/models/daily_summary.py`
- Modify: `app/models/__init__.py`

- [ ] **Step 1: Write failing test for MetricDefinition model**

`tests/test_models_new.py`:
```python
"""Tests for new unified health data ORM models."""
import uuid
from datetime import date, datetime, timezone

from app.models.metric_definition import MetricDefinition
from app.models.activity_session import ActivitySession
from app.models.health_event import HealthEvent
from app.models.daily_summary import DailySummary


def test_metric_definition_instantiation():
    md = MetricDefinition(
        metric_type="steps",
        display_name="Steps",
        unit="steps",
        category="activity",
        aggregation_fn="sum",
        data_type="integer",
    )
    assert md.metric_type == "steps"
    assert md.is_active is True


def test_health_event_instantiation():
    event = HealthEvent(
        user_id=uuid.uuid4(),
        metric_type="water_ml",
        value=250.0,
        unit="mL",
        source="manual",
        recorded_at=datetime.now(tz=timezone.utc),
        local_date=date.today(),
        granularity="point_in_time",
    )
    assert event.value == 250.0
    assert event.deleted_at is None
    assert event.updated_at is None


def test_daily_summary_instantiation():
    ds = DailySummary(
        user_id=uuid.uuid4(),
        date=date.today(),
        metric_type="steps",
        value=8500.0,
        unit="steps",
    )
    assert ds.is_stale is False
    assert ds.event_count == 1
```

- [ ] **Step 2: Run test to verify it fails**

```bash
pytest tests/test_models_new.py -v
```

Expected: `ImportError` — models don't exist yet.

- [ ] **Step 3: Create `app/models/metric_definition.py`**

```python
"""MetricDefinition ORM model — metric registry."""
import uuid
from datetime import datetime

import sqlalchemy as sa
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from app.database import Base


class MetricDefinition(Base):
    __tablename__ = "metric_definitions"

    metric_type: Mapped[str] = mapped_column(sa.Text, primary_key=True)
    display_name: Mapped[str] = mapped_column(sa.Text, nullable=False)
    unit: Mapped[str] = mapped_column(sa.Text, nullable=False)
    category: Mapped[str] = mapped_column(sa.Text, nullable=False)
    aggregation_fn: Mapped[str] = mapped_column(sa.Text, nullable=False)
    data_type: Mapped[str] = mapped_column(sa.Text, nullable=False)
    min_value: Mapped[float | None] = mapped_column(sa.Float(precision=53), nullable=True)
    max_value: Mapped[float | None] = mapped_column(sa.Float(precision=53), nullable=True)
    is_active: Mapped[bool] = mapped_column(sa.Boolean, nullable=False, default=True)
    display_order: Mapped[int] = mapped_column(sa.Integer, nullable=False, default=0)
    created_at: Mapped[datetime] = mapped_column(
        sa.TIMESTAMP(timezone=True), nullable=False, server_default=func.now()
    )
```

- [ ] **Step 4: Create `app/models/activity_session.py`**

```python
"""ActivitySession ORM model — session containers for grouped health events."""
import uuid
from datetime import datetime

import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from app.database import Base


class ActivitySession(Base):
    __tablename__ = "activity_sessions"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False, index=True)
    activity_type: Mapped[str] = mapped_column(sa.Text, nullable=False)
    source: Mapped[str] = mapped_column(sa.Text, nullable=False)
    started_at: Mapped[datetime] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=False)
    ended_at: Mapped[datetime | None] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=True)
    notes: Mapped[str | None] = mapped_column(sa.Text, nullable=True)
    metadata_: Mapped[dict | None] = mapped_column("metadata", JSONB, nullable=True)
    idempotency_key: Mapped[str | None] = mapped_column(sa.Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        sa.TIMESTAMP(timezone=True), nullable=False, server_default=func.now()
    )
```

- [ ] **Step 5: Create `app/models/health_event.py`**

```python
"""HealthEvent ORM model — source of truth for all health data."""
import uuid
from datetime import date, datetime

import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from app.database import Base


class HealthEvent(Base):
    __tablename__ = "health_events"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False, index=True)
    metric_type: Mapped[str] = mapped_column(sa.Text, nullable=False)
    value: Mapped[float] = mapped_column(sa.Float(precision=53), nullable=False)
    unit: Mapped[str] = mapped_column(sa.Text, nullable=False)
    source: Mapped[str] = mapped_column(sa.Text, nullable=False)
    recorded_at: Mapped[datetime] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=False)
    local_date: Mapped[date] = mapped_column(sa.Date, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        sa.TIMESTAMP(timezone=True), nullable=False, server_default=func.now()
    )
    updated_at: Mapped[datetime | None] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=True)
    deleted_at: Mapped[datetime | None] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=True)
    granularity: Mapped[str] = mapped_column(sa.Text, nullable=False, default="point_in_time")
    session_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    idempotency_key: Mapped[str | None] = mapped_column(sa.Text, nullable=True)
    metadata_: Mapped[dict | None] = mapped_column("metadata", JSONB, nullable=True)
```

- [ ] **Step 6: Create `app/models/daily_summary.py`**

```python
"""DailySummary ORM model — pre-aggregated read cache."""
import uuid
from datetime import date, datetime

import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from app.database import Base


class DailySummary(Base):
    __tablename__ = "daily_summaries"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    date: Mapped[date] = mapped_column(sa.Date, nullable=False)
    metric_type: Mapped[str] = mapped_column(sa.Text, nullable=False)
    value: Mapped[float] = mapped_column(sa.Float(precision=53), nullable=False)
    unit: Mapped[str] = mapped_column(sa.Text, nullable=False)
    event_count: Mapped[int] = mapped_column(sa.Integer, nullable=False, default=1)
    is_stale: Mapped[bool] = mapped_column(sa.Boolean, nullable=False, default=False)
    computed_at: Mapped[datetime] = mapped_column(
        sa.TIMESTAMP(timezone=True), nullable=False, server_default=func.now()
    )
```

- [ ] **Step 7: Update `app/models/__init__.py`** to export the four new models.

- [ ] **Step 8: Run tests**

```bash
pytest tests/test_models_new.py -v
```

Expected: all 3 tests PASS.

- [ ] **Step 9: Commit**

```bash
git add app/models/
git commit -m "feat(models): add HealthEvent, ActivitySession, DailySummary, MetricDefinition ORM models"
```

---

## Phase 3: Core Services

### Task 5: Aggregation service (sum / avg / latest)

**Files:**
- Create: `app/services/aggregation_service.py`
- Create: `tests/services/test_aggregation_service.py`

- [ ] **Step 1: Write failing tests**

```python
"""Tests for the pure aggregation logic."""
from datetime import date, datetime, timezone
from app.services.aggregation_service import aggregate_events, AggregationResult


def _event(value: float, recorded_at: datetime | None = None):
    return {"value": value, "recorded_at": recorded_at or datetime.now(tz=timezone.utc)}


def test_sum_aggregation():
    events = [_event(250.0), _event(300.0), _event(200.0)]
    result = aggregate_events(events, fn="sum", unit="mL")
    assert result.value == 750.0
    assert result.event_count == 3


def test_avg_aggregation():
    events = [_event(58.0), _event(62.0), _event(60.0)]
    result = aggregate_events(events, fn="avg", unit="bpm")
    assert result.value == 60.0


def test_latest_aggregation():
    t1 = datetime(2026, 3, 22, 8, 0, tzinfo=timezone.utc)
    t2 = datetime(2026, 3, 22, 20, 0, tzinfo=timezone.utc)
    events = [_event(70.0, t1), _event(71.5, t2)]
    result = aggregate_events(events, fn="latest", unit="kg")
    assert result.value == 71.5


def test_single_event_latest():
    events = [_event(65.0)]
    result = aggregate_events(events, fn="latest", unit="kg")
    assert result.value == 65.0


def test_empty_events_returns_none():
    result = aggregate_events([], fn="sum", unit="steps")
    assert result is None


def test_sum_single_event():
    result = aggregate_events([_event(10000.0)], fn="sum", unit="steps")
    assert result.value == 10000.0
    assert result.event_count == 1
```

- [ ] **Step 2: Run to verify failure**

```bash
pytest tests/services/test_aggregation_service.py -v
```

Expected: `ImportError`.

- [ ] **Step 3: Implement**

```python
"""Pure aggregation logic for daily_summaries recomputation.

No database access. Takes a list of event dicts (value, recorded_at) and
returns an aggregated result using the rule from metric_definitions.
"""
from dataclasses import dataclass
from datetime import datetime


@dataclass
class AggregationResult:
    value: float
    event_count: int
    unit: str


def aggregate_events(
    events: list[dict],   # each: {"value": float, "recorded_at": datetime}
    fn: str,              # "sum" | "avg" | "latest"
    unit: str,
) -> AggregationResult | None:
    """Compute the aggregated daily value from a list of health events.

    Returns None if events is empty (caller should not upsert daily_summaries
    for an empty event set — this means all events were deleted).
    """
    if not events:
        return None

    values = [e["value"] for e in events]

    if fn == "sum":
        return AggregationResult(value=sum(values), event_count=len(events), unit=unit)

    if fn == "avg":
        return AggregationResult(value=sum(values) / len(values), event_count=len(events), unit=unit)

    if fn == "latest":
        latest = max(events, key=lambda e: (e["recorded_at"], e.get("created_at", datetime.min)))
        return AggregationResult(value=latest["value"], event_count=len(events), unit=unit)

    raise ValueError(f"Unknown aggregation_fn: {fn!r}. Must be 'sum', 'avg', or 'latest'.")
```

- [ ] **Step 4: Run tests**

```bash
pytest tests/services/test_aggregation_service.py -v
```

Expected: all 6 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add app/services/aggregation_service.py tests/services/test_aggregation_service.py
git commit -m "feat(services): add AggregationService with sum/avg/latest logic (pure, no DB)"
```

---

### Task 6: Ingest service — `local_date` computation + validation

**Files:**
- Create: `app/services/ingest_service.py`
- Create: `tests/services/test_ingest_service.py`

- [ ] **Step 1: Write failing tests**

```python
"""Tests for ingest service: local_date extraction and value validation."""
from datetime import date
import pytest
from app.services.ingest_service import compute_local_date, validate_metric_value


def test_local_date_negative_offset():
    # 23:45 at -05:00 → local date is still the same day
    result = compute_local_date("2026-03-22T23:45:00-05:00")
    assert result == date(2026, 3, 22)


def test_local_date_crosses_midnight_positive():
    # 00:15 at +05:00 means UTC is previous day; local date is the +05:00 day
    result = compute_local_date("2026-03-23T00:15:00+05:00")
    assert result == date(2026, 3, 23)


def test_local_date_utc():
    result = compute_local_date("2026-03-22T12:00:00+00:00")
    assert result == date(2026, 3, 22)


def test_local_date_midnight_negative_offset():
    # 00:30 at -05:00 → local date is the same as submitted
    result = compute_local_date("2026-03-22T00:30:00-05:00")
    assert result == date(2026, 3, 22)


def test_compute_local_date_requires_offset():
    # No offset → raises ValueError
    with pytest.raises(ValueError, match="UTC offset"):
        compute_local_date("2026-03-22T12:00:00")


def test_validate_metric_value_in_range():
    # Should not raise
    validate_metric_value(metric_type="steps", value=5000.0, min_value=0, max_value=100000)


def test_validate_metric_value_out_of_range():
    with pytest.raises(ValueError, match="out of range"):
        validate_metric_value(metric_type="steps", value=-1.0, min_value=0, max_value=100000)


def test_validate_metric_value_no_bounds():
    # min_value=None, max_value=None → always passes
    validate_metric_value(metric_type="unknown_metric", value=999.0, min_value=None, max_value=None)
```

- [ ] **Step 2: Run to verify failure**

```bash
pytest tests/services/test_ingest_service.py -v
```

Expected: `ImportError`.

- [ ] **Step 3: Implement**

```python
"""Ingest service helpers: local_date computation and value validation."""
from datetime import date, datetime, timezone, timedelta


def compute_local_date(recorded_at_str: str) -> date:
    """Extract the user's local date from an ISO 8601 string with UTC offset.

    The offset must be present in the string (e.g. '+05:00', '-05:00', 'Z').
    This is the canonical way to determine local_date — it is computed from
    the client-supplied offset before PostgreSQL normalises the value to UTC.

    Raises:
        ValueError: if the string has no UTC offset.
    """
    try:
        dt = datetime.fromisoformat(recorded_at_str)
    except ValueError as exc:
        raise ValueError(f"Invalid ISO 8601 timestamp: {recorded_at_str!r}") from exc

    if dt.tzinfo is None or dt.utcoffset() is None:
        raise ValueError(
            f"recorded_at must include a UTC offset (e.g. '+05:00'). "
            f"Got: {recorded_at_str!r}"
        )

    # dt is already in the local timezone implied by the offset.
    # Extract the date directly — it IS the user's local date.
    return dt.date()


def validate_metric_value(
    metric_type: str,
    value: float,
    min_value: float | None,
    max_value: float | None,
) -> None:
    """Raise ValueError if value is outside the defined bounds for this metric.

    min_value=None and max_value=None mean no validation — the metric is
    unbounded or not yet defined.
    """
    if min_value is not None and value < min_value:
        raise ValueError(
            f"{metric_type} value {value} is out of range (min={min_value})"
        )
    if max_value is not None and value > max_value:
        raise ValueError(
            f"{metric_type} value {value} is out of range (max={max_value})"
        )
```

- [ ] **Step 4: Run tests**

```bash
pytest tests/services/test_ingest_service.py -v
```

Expected: all 8 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add app/services/ingest_service.py tests/services/test_ingest_service.py
git commit -m "feat(services): add ingest service with local_date computation and value validation"
```

---

## Phase 4: Ingest API Routes

### Task 7: `POST /api/v1/ingest` — single event

**Files:**
- Create: `app/api/v1/ingest_routes.py`
- Create: `tests/api/test_ingest_routes.py`

- [ ] **Step 1: Write failing tests**

`tests/api/test_ingest_routes.py`:
```python
"""Tests for unified ingest endpoints."""
import uuid
from datetime import date, datetime, timezone
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi.testclient import TestClient

from app.api.deps import get_authenticated_user_id
from app.database import get_db
from app.main import app

TEST_USER_ID = str(uuid.uuid4())
AUTH_HEADER = {"Authorization": "Bearer test-token"}


@pytest.fixture
def client(mock_db, mock_auth):
    return TestClient(app)


@pytest.fixture
def mock_auth():
    app.dependency_overrides[get_authenticated_user_id] = lambda: TEST_USER_ID
    yield
    app.dependency_overrides.pop(get_authenticated_user_id, None)


@pytest.fixture
def mock_db():
    db = AsyncMock()
    db.execute = AsyncMock()
    db.commit = AsyncMock()
    db.refresh = AsyncMock()
    # Mock metric_definitions lookup to return steps (sum, 0, 100000)
    metric_row = SimpleNamespace(
        metric_type="steps", unit="steps", aggregation_fn="sum",
        min_value=0.0, max_value=100000.0, is_active=True
    )
    db.execute.return_value.scalar_one_or_none = MagicMock(return_value=metric_row)
    db.execute.return_value.fetchall = MagicMock(return_value=[])
    app.dependency_overrides[get_db] = lambda: db
    yield db
    app.dependency_overrides.pop(get_db, None)


def test_single_ingest_returns_201(client):
    payload = {
        "metric_type": "steps",
        "value": 5000,
        "unit": "steps",
        "source": "manual",
        "recorded_at": "2026-03-22T14:30:00+05:00",
        "idempotency_key": str(uuid.uuid4()),
    }
    resp = client.post("/api/v1/ingest", json=payload, headers=AUTH_HEADER)
    assert resp.status_code == 201
    data = resp.json()
    assert "event_id" in data
    assert data["date"] == "2026-03-22"


def test_single_ingest_missing_offset_returns_422(client):
    payload = {
        "metric_type": "steps",
        "value": 5000,
        "unit": "steps",
        "source": "manual",
        "recorded_at": "2026-03-22T14:30:00",  # no offset
    }
    resp = client.post("/api/v1/ingest", json=payload, headers=AUTH_HEADER)
    assert resp.status_code == 422


def test_single_ingest_no_auth_returns_401():
    payload = {
        "metric_type": "steps", "value": 5000, "unit": "steps",
        "source": "manual", "recorded_at": "2026-03-22T14:30:00+00:00",
    }
    resp = TestClient(app).post("/api/v1/ingest", json=payload)
    assert resp.status_code in (401, 403)
```

- [ ] **Step 2: Run to verify failure**

```bash
pytest tests/api/test_ingest_routes.py::test_single_ingest_returns_201 -v
```

Expected: 404 (route not registered yet).

- [ ] **Step 3: Implement `app/api/v1/ingest_routes.py`**

The file should contain:
- Pydantic schemas: `SingleIngestRequest`, `SingleIngestResponse`, `SessionIngestRequest`, `SessionIngestResponse`, `BulkIngestRequest`, `BulkIngestResponse`, `DeleteEventResponse`
- `POST /ingest` route: validates offset → computes local_date → checks idempotency → inserts HealthEvent → triggers synchronous aggregation → returns 201
- `POST /ingest/session` route (implemented in Task 8)
- `POST /ingest/bulk` route + `GET /ingest/status/{task_id}` (implemented in Task 9)
- `DELETE /events/{event_id}` route (implemented in Task 10)

```python
"""Unified health data ingest endpoints.

POST /api/v1/ingest            — single manual event
POST /api/v1/ingest/session    — session with multiple linked events
POST /api/v1/ingest/bulk       — bulk device sync (async aggregation)
DELETE /api/v1/events/{id}     — soft-delete a manual event (user correction)
GET /api/v1/ingest/status/{id} — bulk sync status poll
"""
from __future__ import annotations

import uuid
import logging
from datetime import date, datetime, timezone
from typing import Any

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Request
from pydantic import BaseModel, field_validator
from sqlalchemy import select, text
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_authenticated_user_id
from app.database import get_db
from app.limiter import limiter
from app.models.health_event import HealthEvent
from app.models.metric_definition import MetricDefinition
from app.models.daily_summary import DailySummary
from app.services.ingest_service import compute_local_date, validate_metric_value
from app.services.aggregation_service import aggregate_events

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/ingest", tags=["ingest"])


# ── Pydantic schemas ──────────────────────────────────────────────────────────

class SingleIngestRequest(BaseModel):
    metric_type: str
    value: float
    unit: str
    source: str
    recorded_at: str          # ISO 8601 with UTC offset — REQUIRED
    idempotency_key: str | None = None
    metadata: dict | None = None

    @field_validator("recorded_at")
    @classmethod
    def must_have_utc_offset(cls, v: str) -> str:
        from app.services.ingest_service import compute_local_date
        compute_local_date(v)   # raises ValueError if no offset
        return v


class SingleIngestResponse(BaseModel):
    event_id: str
    daily_total: float | None
    unit: str
    date: str


class MetricPayload(BaseModel):
    metric_type: str
    value: float
    unit: str
    idempotency_key: str | None = None
    metadata: dict | None = None


class SessionIngestRequest(BaseModel):
    activity_type: str
    source: str
    started_at: str
    ended_at: str | None = None
    idempotency_key: str | None = None
    metrics: list[MetricPayload]


class SessionIngestResponse(BaseModel):
    session_id: str
    event_ids: list[str]
    date: str


class BulkEventPayload(BaseModel):
    metric_type: str
    value: float
    unit: str
    recorded_at: str
    granularity: str = "point_in_time"
    idempotency_key: str | None = None
    metadata: dict | None = None

    @field_validator("recorded_at")
    @classmethod
    def must_have_offset(cls, v: str) -> str:
        from app.services.ingest_service import compute_local_date
        compute_local_date(v)
        return v


class BulkIngestRequest(BaseModel):
    source: str
    events: list[BulkEventPayload]


class BulkIngestResponse(BaseModel):
    task_id: str
    event_count: int
    status: str


class DeleteEventResponse(BaseModel):
    event_id: str
    deleted_at: str
    updated_daily_total: float | None


# ── Helpers ───────────────────────────────────────────────────────────────────

async def _get_metric_def(
    db: AsyncSession, metric_type: str
) -> MetricDefinition | None:
    row = await db.execute(
        select(MetricDefinition).where(MetricDefinition.metric_type == metric_type)
    )
    return row.scalar_one_or_none()


async def _recompute_daily_summary(
    db: AsyncSession,
    user_id: str,
    local_date: date,
    metric_type: str,
    unit: str,
    aggregation_fn: str,
) -> float | None:
    """Re-aggregate all non-deleted events and upsert daily_summaries."""
    rows = await db.execute(
        select(HealthEvent.value, HealthEvent.recorded_at, HealthEvent.created_at)
        .where(
            HealthEvent.user_id == uuid.UUID(str(user_id)),
            HealthEvent.local_date == local_date,
            HealthEvent.metric_type == metric_type,
            HealthEvent.deleted_at.is_(None),
        )
    )
    events = [
        {"value": r.value, "recorded_at": r.recorded_at, "created_at": r.created_at}
        for r in rows.fetchall()
    ]

    from app.services.aggregation_service import aggregate_events, AggregationResult
    result = aggregate_events(events, fn=aggregation_fn, unit=unit)

    if result is None:
        # All events deleted — remove the summary row
        await db.execute(
            text(
                "DELETE FROM daily_summaries "
                "WHERE user_id = :uid AND date = :d AND metric_type = :mt"
            ),
            {"uid": str(user_id), "d": str(local_date), "mt": metric_type},
        )
        return None

    stmt = pg_insert(DailySummary).values(
        user_id=uuid.UUID(str(user_id)),
        date=local_date,
        metric_type=metric_type,
        value=result.value,
        unit=result.unit,
        event_count=result.event_count,
        is_stale=False,
        computed_at=datetime.now(tz=timezone.utc),
    ).on_conflict_do_update(
        constraint="uq_daily_summaries_user_date_metric",
        set_={
            "value": result.value,
            "event_count": result.event_count,
            "is_stale": False,
            "computed_at": datetime.now(tz=timezone.utc),
        },
    )
    await db.execute(stmt)
    return result.value


# ── Routes ────────────────────────────────────────────────────────────────────

@limiter.limit("60/minute")
@router.post("", status_code=201, response_model=SingleIngestResponse)
async def ingest_single(
    request: Request,
    body: SingleIngestRequest,
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(get_authenticated_user_id),
) -> SingleIngestResponse:
    """Log a single manual health event synchronously."""
    local_date = compute_local_date(body.recorded_at)

    # Idempotency check
    if body.idempotency_key:
        existing = await db.execute(
            select(HealthEvent).where(
                HealthEvent.user_id == uuid.UUID(str(user_id)),
                HealthEvent.idempotency_key == body.idempotency_key,
            )
        )
        existing_event = existing.scalar_one_or_none()
        if existing_event:
            # Return original event data — idempotent success
            summary = await db.execute(
                select(DailySummary.value).where(
                    DailySummary.user_id == uuid.UUID(str(user_id)),
                    DailySummary.date == local_date,
                    DailySummary.metric_type == body.metric_type,
                )
            )
            daily_total = summary.scalar_one_or_none()
            return SingleIngestResponse(
                event_id=str(existing_event.id),
                daily_total=daily_total,
                unit=body.unit,
                date=str(local_date),
            )

    # Validate value range
    metric_def = await _get_metric_def(db, body.metric_type)
    if metric_def:
        try:
            validate_metric_value(
                body.metric_type, body.value,
                metric_def.min_value, metric_def.max_value,
            )
        except ValueError as exc:
            raise HTTPException(status_code=422, detail=str(exc))
    else:
        # Unknown metric: auto-insert placeholder, store event
        await db.execute(
            pg_insert(MetricDefinition)
            .values(
                metric_type=body.metric_type,
                display_name=body.metric_type,
                unit=body.unit,
                category="unknown",
                aggregation_fn="sum",
                data_type="float",
                is_active=False,
            )
            .on_conflict_do_nothing()
        )
        metric_def = MetricDefinition(
            metric_type=body.metric_type, unit=body.unit,
            aggregation_fn="sum", is_active=False,
        )

    event = HealthEvent(
        user_id=uuid.UUID(str(user_id)),
        metric_type=body.metric_type,
        value=body.value,
        unit=body.unit,
        source=body.source,
        recorded_at=datetime.fromisoformat(body.recorded_at),
        local_date=local_date,
        granularity="point_in_time",
        idempotency_key=body.idempotency_key,
        metadata_=body.metadata,
    )
    db.add(event)
    await db.flush()   # get the id

    # Synchronous aggregation
    daily_total = await _recompute_daily_summary(
        db, user_id, local_date,
        body.metric_type, metric_def.unit, metric_def.aggregation_fn,
    )
    await db.commit()

    return SingleIngestResponse(
        event_id=str(event.id),
        daily_total=daily_total,
        unit=body.unit,
        date=str(local_date),
    )
```

- [ ] **Step 4: Register the router in `app/main.py`**

Add after existing router imports:
```python
from app.api.v1.ingest_routes import router as ingest_router
```
And in the app setup block:
```python
app.include_router(ingest_router, prefix="/api/v1")
```

Also add a standalone delete route (outside the `/ingest` prefix):
```python
# In ingest_routes.py, add a separate router for event deletion
events_router = APIRouter(prefix="/events", tags=["events"])
# ... (see Task 11)
```

- [ ] **Step 5: Run tests**

```bash
pytest tests/api/test_ingest_routes.py -v
```

Expected: all 3 tests PASS.

- [ ] **Step 6: Commit**

```bash
git add app/api/v1/ingest_routes.py app/main.py tests/api/test_ingest_routes.py
git commit -m "feat(api): add POST /api/v1/ingest single event endpoint"
```

---

### Task 8: `POST /api/v1/ingest/session`

**Files:**
- Modify: `app/api/v1/ingest_routes.py`
- Modify: `tests/api/test_ingest_routes.py`

- [ ] **Step 1: Add test**

```python
def test_session_ingest_returns_201(client):
    payload = {
        "activity_type": "run",
        "source": "manual",
        "started_at": "2026-03-22T07:00:00+05:00",
        "ended_at": "2026-03-22T07:30:00+05:00",
        "idempotency_key": str(uuid.uuid4()),
        "metrics": [
            {"metric_type": "distance", "value": 5000, "unit": "m", "idempotency_key": str(uuid.uuid4())},
            {"metric_type": "exercise_minutes", "value": 30, "unit": "min", "idempotency_key": str(uuid.uuid4())},
        ]
    }
    resp = client.post("/api/v1/ingest/session", json=payload, headers=AUTH_HEADER)
    assert resp.status_code == 201
    data = resp.json()
    assert "session_id" in data
    assert len(data["event_ids"]) == 2
    assert data["date"] == "2026-03-22"


def test_session_idempotency(client, mock_db):
    """Submitting same session idempotency_key twice returns the same session_id."""
    idem = str(uuid.uuid4())
    existing_session_id = str(uuid.uuid4())
    # Simulate existing session
    from app.models.activity_session import ActivitySession
    mock_session = SimpleNamespace(id=uuid.UUID(existing_session_id))
    mock_db.execute.return_value.scalar_one_or_none = MagicMock(return_value=mock_session)

    payload = {
        "activity_type": "run", "source": "manual",
        "started_at": "2026-03-22T07:00:00+05:00",
        "idempotency_key": idem, "metrics": []
    }
    resp = client.post("/api/v1/ingest/session", json=payload, headers=AUTH_HEADER)
    assert resp.status_code == 200
    assert resp.json()["session_id"] == existing_session_id
```

- [ ] **Step 2: Run to verify failure**

```bash
pytest tests/api/test_ingest_routes.py::test_session_ingest_returns_201 -v
```

Expected: 404.

- [ ] **Step 3: Implement `POST /ingest/session` in `ingest_routes.py`**

The route:
1. Checks if `idempotency_key` already exists in `activity_sessions` — if so returns 200 with original data.
2. Creates `ActivitySession` row.
3. For each metric in `metrics`, computes `local_date` from `started_at`, creates `HealthEvent` with `session_id`, validates value, runs aggregation.
4. Returns 201 with `session_id`, `event_ids`, `date`.

- [ ] **Step 4: Run tests**

```bash
pytest tests/api/test_ingest_routes.py -v
```

Expected: all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add app/api/v1/ingest_routes.py tests/api/test_ingest_routes.py
git commit -m "feat(api): add POST /api/v1/ingest/session for multi-metric grouped events"
```

---

### Task 9: `POST /api/v1/ingest/bulk`

**Files:**
- Modify: `app/api/v1/ingest_routes.py`
- Modify: `tests/api/test_ingest_routes.py`

- [ ] **Step 1: Add tests**

```python
def test_bulk_ingest_returns_202(client):
    payload = {
        "source": "apple_health",
        "events": [
            {"metric_type": "steps", "value": 10000, "unit": "steps",
             "recorded_at": "2026-03-22T23:59:00-05:00", "granularity": "daily_aggregate"},
            {"metric_type": "resting_heart_rate", "value": 58, "unit": "bpm",
             "recorded_at": "2026-03-22T06:30:00-05:00", "granularity": "point_in_time"},
        ]
    }
    resp = client.post("/api/v1/ingest/bulk", json=payload, headers=AUTH_HEADER)
    assert resp.status_code == 202
    data = resp.json()
    assert data["event_count"] == 2
    assert data["status"] == "processing"
    assert "task_id" in data


def test_bulk_ingest_validates_before_insert(client):
    payload = {
        "source": "apple_health",
        "events": [
            {"metric_type": "steps", "value": -999, "unit": "steps",
             "recorded_at": "2026-03-22T23:59:00-05:00", "granularity": "daily_aggregate"},
        ]
    }
    resp = client.post("/api/v1/ingest/bulk", json=payload, headers=AUTH_HEADER)
    assert resp.status_code == 422
    assert "out of range" in resp.json()["detail"][0]["msg"].lower()


def test_bulk_ingest_rejects_missing_offset(client):
    payload = {
        "source": "apple_health",
        "events": [
            {"metric_type": "steps", "value": 10000, "unit": "steps",
             "recorded_at": "2026-03-22T23:59:00"},  # no offset
        ]
    }
    resp = client.post("/api/v1/ingest/bulk", json=payload, headers=AUTH_HEADER)
    assert resp.status_code == 422
```

- [ ] **Step 2: Run to verify failure**

```bash
pytest tests/api/test_ingest_routes.py::test_bulk_ingest_returns_202 -v
```

Expected: 404.

- [ ] **Step 3: Implement `POST /ingest/bulk`**

The route:
1. Validates ALL events for offset presence and value ranges BEFORE any DB operations. Return 422 with list of failures if any are invalid.
2. Inside a single DB transaction: for each event, insert via `pg_insert` with `ON CONFLICT DO NOTHING` (point_in_time) or `ON CONFLICT DO UPDATE` (daily_aggregate).
3. After commit: enqueue a Celery task to run aggregation for all affected `(user_id, local_date, metric_type)` combos. Store the Celery task ID in the response.
4. Return 202 with `task_id` (the Celery task ID from step 3 — used by the status poll endpoint below).

Also add the status poll endpoint in the same router:
```python
@limiter.limit("120/minute")
@router.get("/status/{task_id}")
async def bulk_ingest_status(
    request: Request,
    task_id: str,
    user_id: str = Depends(get_authenticated_user_id),
) -> dict:
    """Poll the status of a bulk ingest aggregation task."""
    from celery.result import AsyncResult
    result = AsyncResult(task_id)
    status_map = {
        "PENDING": "processing",
        "STARTED": "processing",
        "SUCCESS": "complete",
        "FAILURE": "failed",
        "RETRY": "processing",
        "REVOKED": "failed",
    }
    return {
        "task_id": task_id,
        "status": status_map.get(result.state, "processing"),
        "detail": str(result.info) if result.state == "FAILURE" else None,
    }
```

Add a test for this endpoint in `tests/api/test_ingest_routes.py`:
```python
def test_bulk_status_returns_200(client):
    with patch("app.api.v1.ingest_routes.AsyncResult") as mock_result:
        mock_result.return_value.state = "SUCCESS"
        mock_result.return_value.info = None
        resp = client.get("/api/v1/ingest/status/some-task-id", headers=AUTH_HEADER)
    assert resp.status_code == 200
    assert resp.json()["status"] == "complete"
```

- [ ] **Step 4: Run tests**

```bash
pytest tests/api/test_ingest_routes.py -v
```

Expected: all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add app/api/v1/ingest_routes.py tests/api/test_ingest_routes.py
git commit -m "feat(api): add POST /api/v1/ingest/bulk transactional bulk device sync"
```

---

### Task 10: `DELETE /api/v1/events/{event_id}` (soft delete)

**Files:**
- Modify: `app/api/v1/ingest_routes.py`
- Modify: `app/main.py`
- Modify: `tests/api/test_ingest_routes.py`

- [ ] **Step 1: Add tests**

```python
def test_delete_manual_event_returns_200(client, mock_db):
    event_id = str(uuid.uuid4())
    mock_event = SimpleNamespace(
        id=uuid.UUID(event_id),
        user_id=uuid.UUID(TEST_USER_ID),
        source="manual",
        metric_type="water_ml",
        local_date=date(2026, 3, 22),
        deleted_at=None,
    )
    mock_db.execute.return_value.scalar_one_or_none = MagicMock(return_value=mock_event)

    resp = client.delete(f"/api/v1/events/{event_id}", headers=AUTH_HEADER)
    assert resp.status_code == 200
    data = resp.json()
    assert data["event_id"] == event_id


def test_delete_device_event_returns_422(client, mock_db):
    event_id = str(uuid.uuid4())
    mock_event = SimpleNamespace(
        id=uuid.UUID(event_id),
        user_id=uuid.UUID(TEST_USER_ID),
        source="apple_health",   # device source
        metric_type="steps",
        local_date=date(2026, 3, 22),
        deleted_at=None,
    )
    mock_db.execute.return_value.scalar_one_or_none = MagicMock(return_value=mock_event)

    resp = client.delete(f"/api/v1/events/{event_id}", headers=AUTH_HEADER)
    assert resp.status_code == 422


def test_delete_nonexistent_event_returns_404(client, mock_db):
    mock_db.execute.return_value.scalar_one_or_none = MagicMock(return_value=None)
    resp = client.delete(f"/api/v1/events/{uuid.uuid4()}", headers=AUTH_HEADER)
    assert resp.status_code == 404
```

- [ ] **Step 2: Run to verify failure**

```bash
pytest tests/api/test_ingest_routes.py::test_delete_manual_event_returns_200 -v
```

Expected: 404 (route not registered).

- [ ] **Step 3: Implement DELETE route in `ingest_routes.py`**

Add a separate `events_router = APIRouter(prefix="/events", tags=["events"])`.
The route:
1. Fetches the event by ID, verifies `user_id == auth user_id` (return 404 if not found or not owned — do not leak existence).
2. If `source != 'manual'`: return 422 with message "Device events cannot be deleted by users."
3. Sets `event.deleted_at = now()`.
4. Calls `_recompute_daily_summary` for the affected (user_id, local_date, metric_type).
5. Returns 200 with `event_id`, `deleted_at`, `updated_daily_total`.

Register `events_router` in `main.py`:
```python
from app.api.v1.ingest_routes import events_router
app.include_router(events_router, prefix="/api/v1")
```

- [ ] **Step 4: Run tests**

```bash
pytest tests/api/test_ingest_routes.py -v
```

Expected: all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add app/api/v1/ingest_routes.py app/main.py tests/api/test_ingest_routes.py
git commit -m "feat(api): add DELETE /api/v1/events/{id} soft-delete for user corrections"
```

---

## Phase 5: Analytics, Today, Coach, and Trends API Rewrites

### Task 11: Rewrite analytics endpoints to use `daily_summaries`

**Files:**
- Modify: `app/api/v1/analytics.py`
- Modify: `tests/test_analytics_api.py`

- [ ] **Step 1: Read existing `analytics.py`** to understand current query shapes, then replace each query.

The core change: every query that previously referenced `daily_health_metrics`, `quick_logs`, or any of the old tables now queries `daily_summaries`. The API response shape stays the same.

**Critical change in every query:** Replace `current_date` / `CURRENT_DATE` with a `user_local_date` parameter that is computed by reading `user_preferences.timezone` and converting `datetime.now(tz=utc)` to the user's local date.

Add a helper at the top of the module:

```python
async def _get_user_local_date(db: AsyncSession, user_id: str) -> date:
    """Return the user's current local date based on their IANA timezone preference."""
    import zoneinfo
    from datetime import datetime, timezone as tz

    row = await db.execute(
        select(text("timezone")).where(text("user_id = :uid")).select_from(text("user_preferences")),
        {"uid": user_id}
    )
    iana_tz = (row.scalar_one_or_none() or "UTC")
    try:
        user_tz = zoneinfo.ZoneInfo(iana_tz)
    except Exception:
        user_tz = zoneinfo.ZoneInfo("UTC")
    return datetime.now(tz=user_tz).date()
```

- [ ] **Step 2: Update tests in `tests/test_analytics_api.py`** to mock `daily_summaries` responses instead of old table responses.

- [ ] **Step 3: Run analytics tests**

```bash
pytest tests/test_analytics_api.py -v
```

Expected: all existing tests still pass (same response shape, new table source).

- [ ] **Step 4: Commit**

```bash
git add app/api/v1/analytics.py tests/test_analytics_api.py
git commit -m "feat(api): rewrite analytics endpoints to query daily_summaries with user local date"
```

---

### Task 12: Today tab endpoints

**Files:**
- Create: `app/api/v1/today_routes.py`
- Modify: `app/main.py`
- Create: `tests/api/test_today_routes.py`

- [ ] **Step 1: Write failing tests**

```python
"""Tests for Today tab endpoints."""
import uuid
from unittest.mock import AsyncMock, MagicMock
from types import SimpleNamespace
import pytest
from fastapi.testclient import TestClient
from app.api.deps import get_authenticated_user_id
from app.database import get_db
from app.main import app

TEST_USER_ID = str(uuid.uuid4())
AUTH_HEADER = {"Authorization": "Bearer test-token"}


@pytest.fixture
def client(mock_db, mock_auth):
    return TestClient(app)


@pytest.fixture
def mock_auth():
    app.dependency_overrides[get_authenticated_user_id] = lambda: TEST_USER_ID
    yield
    app.dependency_overrides.pop(get_authenticated_user_id, None)


@pytest.fixture
def mock_db():
    db = AsyncMock()
    db.execute = AsyncMock()
    # Return empty result by default
    db.execute.return_value.fetchall = MagicMock(return_value=[])
    db.execute.return_value.scalar_one_or_none = MagicMock(return_value=None)
    app.dependency_overrides[get_db] = lambda: db
    yield db
    app.dependency_overrides.pop(get_db, None)


def test_today_summary_returns_200(client):
    resp = client.get("/api/v1/today/summary", headers=AUTH_HEADER)
    assert resp.status_code == 200
    data = resp.json()
    assert "metrics" in data
    assert "date" in data


def test_today_timeline_returns_200_with_pagination(client):
    resp = client.get("/api/v1/today/timeline?limit=10", headers=AUTH_HEADER)
    assert resp.status_code == 200
    data = resp.json()
    assert "events" in data
    assert "next_cursor" in data


def test_today_timeline_limit_enforced(client):
    # limit > 200 should be capped or rejected
    resp = client.get("/api/v1/today/timeline?limit=500", headers=AUTH_HEADER)
    assert resp.status_code in (200, 422)


def test_today_goals_progress_returns_200(client):
    resp = client.get("/api/v1/today/goals-progress", headers=AUTH_HEADER)
    assert resp.status_code == 200
    assert isinstance(resp.json(), list)


def test_today_endpoints_require_auth():
    for path in ["/api/v1/today/summary", "/api/v1/today/timeline", "/api/v1/today/goals-progress"]:
        resp = TestClient(app).get(path)
        assert resp.status_code in (401, 403)
```

- [ ] **Step 2: Run to verify failure**

```bash
pytest tests/api/test_today_routes.py -v
```

Expected: 404 for all Today routes.

- [ ] **Step 3: Implement `app/api/v1/today_routes.py`**

```python
"""Today tab endpoints."""
from datetime import date
import uuid
import logging

from fastapi import APIRouter, Depends, Query, Request
from pydantic import BaseModel
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_authenticated_user_id
from app.api.v1.analytics import _get_user_local_date
from app.database import get_db
from app.limiter import limiter
from app.models.daily_summary import DailySummary
from app.models.health_event import HealthEvent

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/today", tags=["today"])


class TodayMetric(BaseModel):
    metric_type: str
    value: float
    unit: str


class TodaySummaryResponse(BaseModel):
    date: str
    metrics: list[TodayMetric]


class TodayEventItem(BaseModel):
    event_id: str
    metric_type: str
    value: float
    unit: str
    source: str
    recorded_at: str


class TodayTimelineResponse(BaseModel):
    events: list[TodayEventItem]
    next_cursor: str | None


class GoalProgressItem(BaseModel):
    metric_type: str
    current_value: float
    target_value: float
    unit: str
    percentage: float


@limiter.limit("120/minute")
@router.get("/summary", response_model=TodaySummaryResponse)
async def today_summary(
    request: Request,
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(get_authenticated_user_id),
) -> TodaySummaryResponse:
    local_date = await _get_user_local_date(db, user_id)
    rows = await db.execute(
        select(DailySummary.metric_type, DailySummary.value, DailySummary.unit).where(
            DailySummary.user_id == uuid.UUID(str(user_id)),
            DailySummary.date == local_date,
        )
    )
    metrics = [
        TodayMetric(metric_type=r.metric_type, value=r.value, unit=r.unit)
        for r in rows.fetchall()
    ]
    return TodaySummaryResponse(date=str(local_date), metrics=metrics)


@limiter.limit("120/minute")
@router.get("/timeline", response_model=TodayTimelineResponse)
async def today_timeline(
    request: Request,
    limit: int = Query(default=50, ge=1, le=200),
    before: str | None = Query(default=None),
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(get_authenticated_user_id),
) -> TodayTimelineResponse:
    local_date = await _get_user_local_date(db, user_id)

    query = (
        select(HealthEvent)
        .where(
            HealthEvent.user_id == uuid.UUID(str(user_id)),
            HealthEvent.local_date == local_date,
            HealthEvent.deleted_at.is_(None),
        )
        .order_by(HealthEvent.recorded_at.desc())
        .limit(limit + 1)   # fetch one extra to determine if there's a next page
    )
    if before:
        query = query.where(HealthEvent.id < uuid.UUID(before))

    rows = await db.execute(query)
    events = rows.scalars().all()

    next_cursor = None
    if len(events) > limit:
        events = events[:limit]
        next_cursor = str(events[-1].id)

    return TodayTimelineResponse(
        events=[
            TodayEventItem(
                event_id=str(e.id),
                metric_type=e.metric_type,
                value=e.value,
                unit=e.unit,
                source=e.source,
                recorded_at=e.recorded_at.isoformat(),
            )
            for e in events
        ],
        next_cursor=next_cursor,
    )


@limiter.limit("60/minute")
@router.get("/goals-progress", response_model=list[GoalProgressItem])
async def today_goals_progress(
    request: Request,
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(get_authenticated_user_id),
) -> list[GoalProgressItem]:
    local_date = await _get_user_local_date(db, user_id)
    rows = await db.execute(
        text("""
            SELECT ds.metric_type, ds.value AS current_value, ug.target_value, ds.unit,
                   ROUND(CAST(ds.value / NULLIF(ug.target_value, 0) * 100 AS numeric), 1) AS percentage
            FROM daily_summaries ds
            JOIN user_goals ug ON ds.user_id = ug.user_id AND ds.metric_type = ug.metric_type
            WHERE ds.user_id = :uid AND ds.date = :d
        """),
        {"uid": str(user_id), "d": str(local_date)},
    )
    return [
        GoalProgressItem(
            metric_type=r.metric_type,
            current_value=r.current_value,
            target_value=r.target_value,
            unit=r.unit,
            percentage=float(r.percentage or 0),
        )
        for r in rows.fetchall()
    ]
```

- [ ] **Step 4: Register in `main.py`**

```python
from app.api.v1.today_routes import router as today_router
app.include_router(today_router, prefix="/api/v1")
```

- [ ] **Step 5: Run tests**

```bash
pytest tests/api/test_today_routes.py -v
```

Expected: all 5 tests PASS.

- [ ] **Step 6: Commit**

```bash
git add app/api/v1/today_routes.py app/main.py tests/api/test_today_routes.py
git commit -m "feat(api): add Today tab endpoints (summary, timeline, goals-progress)"
```

---

### Task 13: Coach context endpoints + Trends correlation

**Files:**
- Create: `app/api/v1/coach_routes.py`
- Modify: `app/api/v1/trends_routes.py`
- Modify: `app/main.py`
- Create: `tests/api/test_coach_routes.py`

- [ ] **Step 1: Write failing tests for coach context**

```python
"""Tests for Coach tab endpoints."""
def test_coach_context_returns_200(client):
    resp = client.get("/api/v1/coach/context?days=7", headers=AUTH_HEADER)
    assert resp.status_code == 200
    data = resp.json()
    assert "daily_summaries" in data
    assert "recent_events" in data
    assert "sessions" in data


def test_coach_context_requires_auth():
    resp = TestClient(app).get("/api/v1/coach/context")
    assert resp.status_code in (401, 403)


def test_trends_correlation_returns_200(client):
    resp = client.get(
        "/api/v1/trends/correlation?metric_a=sleep_duration&metric_b=mood&days=30",
        headers=AUTH_HEADER
    )
    assert resp.status_code == 200
    data = resp.json()
    assert "data_points" in data
    assert "correlation" in data
```

- [ ] **Step 2: Run to verify failure**

```bash
pytest tests/api/test_coach_routes.py -v
```

Expected: 404 for coach routes.

- [ ] **Step 3: Implement `app/api/v1/coach_routes.py`**

Routes `GET /coach/context` and `GET /coach/events`:
- `/coach/context?days=30`: queries `daily_summaries` for past N days (grouped by date), last 200 `health_events`, and `activity_sessions` for past N days. Returns structured JSON for AI context.
- `/coach/events?metric_type=&days=`: queries `health_events` filtered by metric + date range, limit 500.

- [ ] **Step 4: Implement `GET /trends/correlation` in `trends_routes.py`**

```python
@limiter.limit("30/minute")
@router.get("/correlation")
async def trends_correlation(
    request: Request,
    metric_a: str,
    metric_b: str,
    days: int = Query(default=90, ge=7, le=365),
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(get_authenticated_user_id),
) -> dict:
    from app.api.v1.analytics import _get_user_local_date
    local_date = await _get_user_local_date(db, user_id)
    start_date = local_date - timedelta(days=days)

    rows = await db.execute(
        text("""
            SELECT a.date, a.value AS metric_a_value, b.value AS metric_b_value
            FROM daily_summaries a
            JOIN daily_summaries b ON a.user_id = b.user_id AND a.date = b.date
            WHERE a.user_id = :uid
              AND a.metric_type = :ma
              AND b.metric_type = :mb
              AND a.date >= :start
            ORDER BY a.date
        """),
        {"uid": str(user_id), "ma": metric_a, "mb": metric_b, "start": str(start_date)},
    )
    data_points = [
        {"date": str(r.date), metric_a: r.metric_a_value, metric_b: r.metric_b_value}
        for r in rows.fetchall()
    ]

    correlation = None
    if len(data_points) >= 3:
        import statistics
        xs = [p[metric_a] for p in data_points]
        ys = [p[metric_b] for p in data_points]
        try:
            correlation = round(statistics.correlation(xs, ys), 3)
        except statistics.StatisticsError:
            correlation = None

    return {"data_points": data_points, "correlation": correlation, "metric_a": metric_a, "metric_b": metric_b}
```

- [ ] **Step 5: Register coach_router in `main.py`**

- [ ] **Step 6: Run tests**

```bash
pytest tests/api/test_coach_routes.py -v
```

Expected: all tests PASS.

- [ ] **Step 7: Commit**

```bash
git add app/api/v1/coach_routes.py app/api/v1/trends_routes.py app/main.py tests/api/test_coach_routes.py
git commit -m "feat(api): add Coach context endpoints and Trends correlation endpoint"
```

---

## Phase 6: Background Aggregation (Celery)

### Task 14: Celery aggregation task for bulk sync

**Files:**
- Create: `app/tasks/aggregation_tasks.py`
- Modify: `app/api/v1/ingest_routes.py` (wire the Celery task into bulk ingest)
- Create: `tests/tasks/test_aggregation_tasks.py`

- [ ] **Step 1: Write failing tests**

```python
"""Tests for aggregation Celery tasks."""
from unittest.mock import AsyncMock, patch, MagicMock
import uuid
from datetime import date

from app.tasks.aggregation_tasks import recompute_daily_summaries_for_batch


def test_recompute_task_is_a_celery_task():
    # Just verify it's decorated as a shared_task
    assert hasattr(recompute_daily_summaries_for_batch, "delay")


def test_recompute_task_accepts_batch_spec():
    # Dry-run: no real DB, just test the signature
    batch = [
        {"user_id": str(uuid.uuid4()), "local_date": "2026-03-22", "metric_type": "steps"},
    ]
    # Calling with apply() synchronously would require DB — just test it's callable
    assert callable(recompute_daily_summaries_for_batch)
```

- [ ] **Step 2: Run to verify failure**

```bash
pytest tests/tasks/test_aggregation_tasks.py -v
```

Expected: `ImportError`.

- [ ] **Step 3: Implement**

```python
"""Celery tasks for health data aggregation."""
import asyncio
import logging
from datetime import date, datetime, timezone

from celery import shared_task
from sqlalchemy import select, text
from sqlalchemy.dialects.postgresql import insert as pg_insert

from app.database import worker_async_session
from app.models.health_event import HealthEvent
from app.models.metric_definition import MetricDefinition
from app.models.daily_summary import DailySummary
from app.services.aggregation_service import aggregate_events

logger = logging.getLogger(__name__)


@shared_task(name="app.tasks.aggregation_tasks.recompute_daily_summaries_for_batch")
def recompute_daily_summaries_for_batch(
    batch: list[dict],   # [{"user_id": str, "local_date": "YYYY-MM-DD", "metric_type": str}]
) -> dict:
    """Recompute daily_summaries for all (user, date, metric) combos in batch.

    Called after bulk device sync completes. Each item in batch is one
    affected (user_id, local_date, metric_type) combination.
    """
    return asyncio.run(_recompute_batch(batch))


async def _recompute_batch(batch: list[dict]) -> dict:
    success = 0
    failures = []

    async with worker_async_session() as db:
        for item in batch:
            try:
                user_id = item["user_id"]
                local_date = date.fromisoformat(item["local_date"])
                metric_type = item["metric_type"]

                # Look up metric definition
                md_row = await db.execute(
                    select(MetricDefinition).where(MetricDefinition.metric_type == metric_type)
                )
                md = md_row.scalar_one_or_none()
                if not md:
                    continue  # Unknown metric — skip aggregation

                # Get all non-deleted events
                import uuid as _uuid
                events_result = await db.execute(
                    select(HealthEvent.value, HealthEvent.recorded_at, HealthEvent.created_at)
                    .where(
                        HealthEvent.user_id == _uuid.UUID(user_id),
                        HealthEvent.local_date == local_date,
                        HealthEvent.metric_type == metric_type,
                        HealthEvent.deleted_at.is_(None),
                    )
                )
                events = [
                    {"value": r.value, "recorded_at": r.recorded_at, "created_at": r.created_at}
                    for r in events_result.fetchall()
                ]

                result = aggregate_events(events, fn=md.aggregation_fn, unit=md.unit)
                if result is None:
                    await db.execute(
                        text("DELETE FROM daily_summaries WHERE user_id=:uid AND date=:d AND metric_type=:mt"),
                        {"uid": user_id, "d": str(local_date), "mt": metric_type},
                    )
                else:
                    stmt = pg_insert(DailySummary).values(
                        user_id=_uuid.UUID(user_id), date=local_date,
                        metric_type=metric_type, value=result.value,
                        unit=result.unit, event_count=result.event_count,
                        is_stale=False, computed_at=datetime.now(tz=timezone.utc),
                    ).on_conflict_do_update(
                        constraint="uq_daily_summaries_user_date_metric",
                        set_={"value": result.value, "event_count": result.event_count,
                              "is_stale": False, "computed_at": datetime.now(tz=timezone.utc)},
                    )
                    await db.execute(stmt)

                await db.commit()
                success += 1
            except Exception as exc:
                logger.exception("Aggregation failed for %s", item)
                failures.append({"item": item, "error": str(exc)})
                # Mark row stale for retry
                try:
                    await db.execute(
                        text("UPDATE daily_summaries SET is_stale=true "
                             "WHERE user_id=:uid AND date=:d AND metric_type=:mt"),
                        {"uid": item["user_id"], "d": item["local_date"], "mt": item["metric_type"]},
                    )
                    await db.commit()
                except Exception:
                    pass

    return {"success": success, "failures": failures}


@shared_task(name="app.tasks.aggregation_tasks.recompute_stale_summaries")
def recompute_stale_summaries() -> dict:
    """Celery Beat periodic job: recompute all daily_summaries rows with is_stale=true.

    Scheduled every 5 minutes via Celery Beat. Processes up to 1000 stale
    rows per run, oldest first.
    """
    return asyncio.run(_recompute_stale())


async def _recompute_stale() -> dict:
    async with worker_async_session() as db:
        stale_rows = await db.execute(
            text("""
                SELECT user_id::text, date::text, metric_type
                FROM daily_summaries
                WHERE is_stale = true
                ORDER BY computed_at ASC
                LIMIT 1000
            """)
        )
        batch = [
            {"user_id": r.user_id, "local_date": r.date, "metric_type": r.metric_type}
            for r in stale_rows.fetchall()
        ]

    if not batch:
        return {"processed": 0}

    return await _recompute_batch(batch)
```

- [ ] **Step 4: Register Celery Beat schedule**

In `app/worker.py`, add to the existing `celery_app.conf.beat_schedule` dict (do NOT
reassign the whole dict — add the key to the existing assignment block at line ~99):

```python
# In app/worker.py, inside the existing celery_app.conf.beat_schedule = { ... } block:
"recompute-stale-summaries": {
    "task": "app.tasks.aggregation_tasks.recompute_stale_summaries",
    "schedule": 300.0,  # every 5 minutes
},
```

The variable is `celery_app` (not `app`) — `app` refers to the FastAPI application in
other modules. See `app/worker.py` line 67: `celery_app = Celery(...)` and line 99:
`celery_app.conf.beat_schedule = {`.

- [ ] **Step 5: Wire into bulk ingest**

In `ingest_routes.py`, replace the `POST /ingest/bulk` placeholder task enqueue with:
```python
from app.tasks.aggregation_tasks import recompute_daily_summaries_for_batch

# After all events are committed:
task = recompute_daily_summaries_for_batch.delay(affected_combos)
task_id = task.id
```

- [ ] **Step 6: Run tests**

```bash
pytest tests/tasks/test_aggregation_tasks.py -v
```

Expected: both tests PASS.

- [ ] **Step 7: Commit**

```bash
git add app/tasks/aggregation_tasks.py tests/tasks/test_aggregation_tasks.py app/api/v1/ingest_routes.py
git commit -m "feat(tasks): add Celery aggregation task for bulk sync and stale-row recomputation"
```

---

### Task 15: Remove `quick_log_router` from `main.py`

**Dependency: Must run AFTER Phase 7 (Flutter migration) is complete.** If `quick_log_router`
is unregistered before the Flutter app is updated, every Flutter `POST /quick-log` call will
receive a 404 and users will be unable to log data. Only proceed with this task after all
Flutter call sites have been migrated to `POST /api/v1/ingest` and the updated Flutter build
is deployed (or confirmed working in development).

**Files:**
- Modify: `app/main.py`

- [ ] **Step 1: Confirm all Flutter call sites are migrated**

```bash
cd zuralog && grep -r "quick-log\|quick_log" lib/ --include="*.dart"
```

Expected: no results. If any results remain, complete those Flutter migrations first.

- [ ] **Step 2: Remove the router registration**

In `app/main.py`, remove:
```python
# Remove these two lines:
from app.api.v1.quick_log_routes import router as quick_log_router
app.include_router(quick_log_router, prefix="/api/v1")
```

- [ ] **Step 3: Run smoke test**

```bash
pytest tests/ -k "not quick_log" --ignore=tests/api/test_quick_log_routes.py -x -q
```

Expected: all passing tests still pass. `test_quick_log_routes.py` will fail (route gone) — that's expected and acceptable.

- [ ] **Step 4: Commit**

```bash
git add app/main.py
git commit -m "chore: unregister quick_log router from main.py (Flutter migration pending)"
```

---

## Phase 7: Flutter App Updates

### Task 16: Idempotency key utility

**Files:**
- Create: `zuralog/lib/core/utils/idempotency_key.dart`

- [ ] **Step 1: Write the utility**

```dart
/// Generates a UUID v4 idempotency key for use with ingest endpoints.
///
/// The key must be generated BEFORE the network call and stored locally
/// (e.g. in the widget state or a Riverpod StateProvider) so that on
/// retry the same key is reused. Never regenerate the key on retry.
library;

import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Returns a new random UUID v4 string suitable as an idempotency key.
String generateIdempotencyKey() => _uuid.v4();
```

Ensure `uuid: ^4.0.0` is in `zuralog/pubspec.yaml` (it likely already is — check first with `grep uuid pubspec.yaml`).

- [ ] **Step 2: Verify the package is already present or add it**

```bash
cd zuralog && grep uuid pubspec.yaml
```

If missing: `flutter pub add uuid`.

- [ ] **Step 3: Commit**

```bash
git add zuralog/lib/core/utils/idempotency_key.dart zuralog/pubspec.yaml zuralog/pubspec.lock
git commit -m "feat(flutter): add idempotency key utility"
```

---

### Task 17: Update Today repository — replace `submitQuickLog` with unified ingest

**Files:**
- Modify: `zuralog/lib/features/today/domain/today_models.dart`
- Modify: `zuralog/lib/features/today/data/today_repository.dart`
- Modify: `zuralog/lib/features/today/providers/today_providers.dart`

- [ ] **Step 1: Add new domain models to `today_models.dart`**

```dart
/// Response from POST /api/v1/ingest
class IngestResult {
  const IngestResult({
    required this.eventId,
    this.dailyTotal,
    required this.unit,
    required this.date,
  });

  final String eventId;
  final double? dailyTotal;
  final String unit;
  final String date;

  factory IngestResult.fromJson(Map<String, dynamic> json) => IngestResult(
    eventId: json['event_id'] as String,
    dailyTotal: (json['daily_total'] as num?)?.toDouble(),
    unit: json['unit'] as String,
    date: json['date'] as String,
  );
}

/// A single raw health event from GET /api/v1/today/timeline
class TodayEvent {
  const TodayEvent({
    required this.eventId,
    required this.metricType,
    required this.value,
    required this.unit,
    required this.source,
    required this.recordedAt,
  });

  final String eventId;
  final String metricType;
  final double value;
  final String unit;
  final String source;
  final DateTime recordedAt;

  factory TodayEvent.fromJson(Map<String, dynamic> json) => TodayEvent(
    eventId: json['event_id'] as String,
    metricType: json['metric_type'] as String,
    value: (json['value'] as num).toDouble(),
    unit: json['unit'] as String,
    source: json['source'] as String,
    recordedAt: DateTime.parse(json['recorded_at'] as String),
  );
}

/// Paginated response from GET /api/v1/today/timeline
class TodayTimeline {
  const TodayTimeline({required this.events, this.nextCursor});
  final List<TodayEvent> events;
  final String? nextCursor;

  factory TodayTimeline.fromJson(Map<String, dynamic> json) => TodayTimeline(
    events: (json['events'] as List)
        .map((e) => TodayEvent.fromJson(e as Map<String, dynamic>))
        .toList(),
    nextCursor: json['next_cursor'] as String?,
  );
}
```

- [ ] **Step 2: Update `TodayRepositoryInterface` and `TodayRepository`**

Add to the interface:
```dart
/// Submit a single health event via POST /api/v1/ingest.
/// [recordedAt] must include a UTC offset — use DateTime.now() with tz.
Future<IngestResult> submitIngest({
  required String metricType,
  required double value,
  required String unit,
  required String source,
  required DateTime recordedAt,
  String? idempotencyKey,
  Map<String, dynamic>? metadata,
});

/// Fetch paginated raw event timeline for today.
Future<TodayTimeline> getTodayTimeline({int limit = 50, String? before});

/// Soft-delete a manual health event.
Future<void> deleteEvent(String eventId);
```

Implementation in `TodayRepository`:
```dart
@override
Future<IngestResult> submitIngest({
  required String metricType,
  required double value,
  required String unit,
  required String source,
  required DateTime recordedAt,
  String? idempotencyKey,
  Map<String, dynamic>? metadata,
}) async {
  // recordedAt must be timezone-aware — Flutter DateTime with tz offset
  // Format: "2026-03-22T14:30:00+05:00"
  final offset = recordedAt.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final hh = offset.inHours.abs().toString().padLeft(2, '0');
  final mm = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
  final recordedAtStr =
      '${recordedAt.toLocal().toIso8601String().split('.').first}$sign$hh:$mm';

  final resp = await _api.post('/api/v1/ingest', data: {
    'metric_type': metricType,
    'value': value,
    'unit': unit,
    'source': source,
    'recorded_at': recordedAtStr,
    if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
    if (metadata != null) 'metadata': metadata,
  });
  return IngestResult.fromJson(resp.data as Map<String, dynamic>);
}

@override
Future<TodayTimeline> getTodayTimeline({int limit = 50, String? before}) async {
  final resp = await _api.get('/api/v1/today/timeline', queryParameters: {
    'limit': limit,
    if (before != null) 'before': before,
  });
  return TodayTimeline.fromJson(resp.data as Map<String, dynamic>);
}

@override
Future<void> deleteEvent(String eventId) async {
  await _api.delete('/api/v1/events/$eventId');
}
```

- [ ] **Step 3: Update all call sites**

Grep for `submitQuickLog` across the Flutter codebase:
```bash
cd zuralog && grep -r "submitQuickLog" lib/ --include="*.dart" -l
```

For each call site, replace with `submitIngest(...)` and generate `idempotencyKey` via `generateIdempotencyKey()` before the call.

- [ ] **Step 4: Build Flutter to verify no compilation errors**

```bash
cd zuralog && flutter build apk --debug 2>&1 | tail -20
```

Expected: build succeeds.

- [ ] **Step 5: Commit**

```bash
git add zuralog/lib/features/today/
git commit -m "feat(flutter): replace submitQuickLog with unified ingest API calls"
```

---

### Task 17b: Flutter — `submitSession` and `bulkIngest` in Today repository

The plan's File Map promises `submitSession` and `bulkIngest` on `TodayRepositoryInterface`.
These are required to replace `POST /api/v1/quick-log/batch` (batch/session logging from UI)
and to provide a hook for the Apple Health sync (Task 17c).

**Files:**
- Modify: `zuralog/lib/features/today/domain/today_models.dart`
- Modify: `zuralog/lib/features/today/data/today_repository.dart`

- [ ] **Step 1: Add `SessionIngestResult`, `SessionMetricPayload`, `BulkEventPayload`, and `BulkIngestResult` models to `today_models.dart`**

```dart
/// A single metric payload within a session ingest request.
class SessionMetricPayload {
  const SessionMetricPayload({
    required this.metricType,
    required this.value,
    required this.unit,
    this.idempotencyKey,
    this.metadata,
  });
  final String metricType;
  final double value;
  final String unit;
  final String? idempotencyKey;
  final Map<String, dynamic>? metadata;

  Map<String, dynamic> toJson() => {
    'metric_type': metricType,
    'value': value,
    'unit': unit,
    if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
    if (metadata != null) 'metadata': metadata,
  };
}

/// A single event payload within a bulk ingest request.
class BulkEventPayload {
  const BulkEventPayload({
    required this.metricType,
    required this.value,
    required this.unit,
    required this.recordedAt,  // ISO 8601 string with UTC offset
    this.granularity = 'point_in_time',
    this.idempotencyKey,
  });
  final String metricType;
  final double value;
  final String unit;
  final String recordedAt;
  final String granularity;
  final String? idempotencyKey;

  Map<String, dynamic> toJson() => {
    'metric_type': metricType,
    'value': value,
    'unit': unit,
    'recorded_at': recordedAt,
    'granularity': granularity,
    if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
  };
}

/// Response from POST /api/v1/ingest/session
class SessionIngestResult {
  const SessionIngestResult({
    required this.sessionId,
    required this.eventIds,
    required this.date,
  });
  final String sessionId;
  final List<String> eventIds;
  final String date;

  factory SessionIngestResult.fromJson(Map<String, dynamic> json) =>
      SessionIngestResult(
        sessionId: json['session_id'] as String,
        eventIds: (json['event_ids'] as List).cast<String>(),
        date: json['date'] as String,
      );
}

/// Response from POST /api/v1/ingest/bulk
class BulkIngestResult {
  const BulkIngestResult({
    required this.taskId,
    required this.eventCount,
    required this.status,
  });
  final String taskId;
  final int eventCount;
  final String status;

  factory BulkIngestResult.fromJson(Map<String, dynamic> json) =>
      BulkIngestResult(
        taskId: json['task_id'] as String,
        eventCount: json['event_count'] as int,
        status: json['status'] as String,
      );
}
```

- [ ] **Step 2: Add `submitSession` and `bulkIngest` to the interface and implementation**

```dart
// Interface addition:
Future<SessionIngestResult> submitSession({
  required String activityType,
  required String source,
  required DateTime startedAt,
  DateTime? endedAt,
  required List<SessionMetricPayload> metrics,
  String? idempotencyKey,
});

Future<BulkIngestResult> bulkIngest({
  required String source,
  required List<BulkEventPayload> events,
});

// Implementation: POST to /api/v1/ingest/session and /api/v1/ingest/bulk respectively.
// Follow the same UTC offset serialization pattern as submitIngest (Task 17).
```

- [ ] **Step 3: Find all call sites for `POST /api/v1/quick-log/batch`**

```bash
cd zuralog && grep -r "quick-log/batch\|batch" lib/ --include="*.dart" -l
```

Replace each with the appropriate `submitSession(...)` call.

- [ ] **Step 4: Build to verify**

```bash
cd zuralog && flutter build apk --debug 2>&1 | tail -20
```

- [ ] **Step 5: Commit**

```bash
git add zuralog/lib/features/today/
git commit -m "feat(flutter): add submitSession and bulkIngest to TodayRepository"
```

---

### Task 17c: Flutter — migrate Apple Health sync to `POST /api/v1/ingest/bulk`

The Apple Health sync writes to `POST /api/v1/health/ingest` (the old device ingest endpoint).
After the old tables are dropped, this endpoint will fail. Migrate it to `POST /api/v1/ingest/bulk`.

**Files:**
- Modify: `zuralog/lib/features/health/data/health_sync_service.dart`
- Modify: `zuralog/lib/features/health/data/health_repository.dart`

- [ ] **Step 1: Read the current sync implementation**

```bash
# Find the Apple Health sync call:
grep -n "health/ingest\|healthIngest\|syncHealth" \
  zuralog/lib/features/health/data/health_sync_service.dart
```

Note the exact endpoint, request shape, and data types being sent.

- [ ] **Step 2: Map old fields to new bulk event format**

The old endpoint accepted a typed struct (steps, heart_rate, etc. as named fields).
The new `/ingest/bulk` accepts `[{metric_type, value, unit, recorded_at, granularity}]`.

Write the mapping logic:
```dart
// Old: { steps: 10000, date: "2026-03-22" }
// New bulk event: { metric_type: "steps", value: 10000, unit: "steps",
//                   recorded_at: "2026-03-22T23:59:00+00:00",
//                   granularity: "daily_aggregate" }
```

For daily aggregates from Apple Health: use `granularity: "daily_aggregate"` and
set `recorded_at` to `"$date T23:59:00$offsetStr"` (end of day in local time).

- [ ] **Step 3: Replace the sync call in `health_sync_service.dart`**

Use the `bulkIngest(...)` method from `TodayRepository` (or call `_api.post` directly
if `HealthSyncService` has its own API client).

- [ ] **Step 4: Build and verify**

```bash
cd zuralog && flutter build apk --debug 2>&1 | tail -20
```

- [ ] **Step 5: Commit**

```bash
git add zuralog/lib/features/health/
git commit -m "feat(flutter): migrate Apple Health sync to POST /api/v1/ingest/bulk"
```

---

### Task 18: Flutter — paginated Today timeline widget

**Files:**
- Modify the Today feed screen to load the timeline using `getTodayTimeline` with pagination (load-more on scroll).

- [ ] **Step 1: Identify the widget that renders today's log history**

```bash
cd zuralog && grep -r "getTodayLogSummary\|timeline\|quick.log" lib/features/today/ --include="*.dart" -l
```

- [ ] **Step 2: Replace the existing log history load with paginated timeline**

The pattern:
```dart
// Provider (in today_providers.dart)
final todayTimelineProvider = StateNotifierProvider<TodayTimelineNotifier, AsyncValue<TodayTimeline>>(
  (ref) => TodayTimelineNotifier(ref.watch(todayRepositoryProvider)),
);

class TodayTimelineNotifier extends StateNotifier<AsyncValue<TodayTimeline>> {
  TodayTimelineNotifier(this._repo) : super(const AsyncValue.loading()) {
    load();
  }
  final TodayRepositoryInterface _repo;
  String? _cursor;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final timeline = await _repo.getTodayTimeline(limit: 50);
      _cursor = timeline.nextCursor;
      state = AsyncValue.data(timeline);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> loadMore() async {
    if (_cursor == null) return;
    final current = state.valueOrNull;
    if (current == null) return;
    final more = await _repo.getTodayTimeline(limit: 50, before: _cursor);
    _cursor = more.nextCursor;
    state = AsyncValue.data(
      TodayTimeline(events: [...current.events, ...more.events], nextCursor: more.nextCursor),
    );
  }
}
```

- [ ] **Step 3: Build and run**

```bash
cd zuralog && flutter run --debug
```

Verify today's log timeline loads and paginates correctly.

- [ ] **Step 4: Commit**

```bash
git add zuralog/lib/features/today/
git commit -m "feat(flutter): add paginated Today timeline with load-more"
```

---

### Task 19: Flutter — swipe-to-delete on Today timeline events

**Files:**
- Modify the Today timeline list widget to wrap items in `Dismissible`.

- [ ] **Step 1: Add swipe-to-delete**

```dart
Dismissible(
  key: Key(event.eventId),
  direction: DismissDirection.endToStart,
  background: Container(
    color: Theme.of(context).colorScheme.error,
    alignment: Alignment.centerRight,
    padding: const EdgeInsets.only(right: 16),
    child: const Icon(Icons.delete, color: Colors.white),
  ),
  confirmDismiss: (_) async {
    // Show confirmation dialog — prevent accidental deletes
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete entry?'),
        content: Text('Remove ${event.metricType} log?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
  },
  onDismissed: (_) {
    ref.read(todayRepositoryProvider).deleteEvent(event.eventId);
    ref.read(todayTimelineProvider.notifier).load(); // refresh
  },
  child: EventListTile(event: event),
),
```

Note: Only `source == 'manual'` events should show the swipe affordance. Device-sourced events should be non-dismissible.

- [ ] **Step 2: Build and verify**

```bash
cd zuralog && flutter run --debug
```

- [ ] **Step 3: Commit**

```bash
git add zuralog/lib/features/today/
git commit -m "feat(flutter): add swipe-to-delete on Today timeline for manual events"
```

---

## Phase 8: Final Cleanup

### Task 20: Delete `quick_log_routes.py` and its tests

Only after all Flutter call sites are migrated to the new ingest endpoints.

- [ ] **Step 1: Verify no remaining call sites**

```bash
cd zuralog && grep -r "quick-log\|quick_log" lib/ --include="*.dart"
```

Expected: no results.

- [ ] **Step 2: Delete all quick_log files**

Multiple test files exist. Delete all of them:
```bash
cd cloud-brain
rm app/api/v1/quick_log_routes.py
# The test file exists in multiple locations — delete all:
rm -f tests/api/test_quick_log_routes.py
rm -f tests/test_quick_log_routes.py
```

- [ ] **Step 3: Remove any remaining imports and references**

```bash
grep -r "quick_log_routes\|quick_log_router\|QuickLog\|quick-log" app/ tests/ --include="*.py"
```

Fix any remaining references.

- [ ] **Step 4: Run full test suite**

```bash
pytest tests/ -x -q
```

Expected: all tests pass. No references to old tables.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "chore: remove quick_log_routes.py and its tests (replaced by unified ingest)"
```

---

### Task 21: Smoke test the full stack

- [ ] **Step 1: Start the local dev stack**

```bash
cd cloud-brain && uvicorn app.main:app --reload
```

- [ ] **Step 2: POST a manual event**

```bash
curl -X POST http://localhost:8000/api/v1/ingest \
  -H "Authorization: Bearer <your-test-token>" \
  -H "Content-Type: application/json" \
  -d '{"metric_type":"water_ml","value":250,"unit":"mL","source":"manual","recorded_at":"2026-03-22T14:30:00+05:00","idempotency_key":"smoke-test-001"}'
```

Expected: `{"event_id":"...","daily_total":250.0,"unit":"mL","date":"2026-03-22"}`

- [ ] **Step 3: Repeat the same POST (idempotency check)**

Run the same curl again. Expected: `200 OK` with same `event_id`.

- [ ] **Step 4: GET today summary**

```bash
curl http://localhost:8000/api/v1/today/summary \
  -H "Authorization: Bearer <your-test-token>"
```

Expected: response includes `water_ml` with `value: 250`.

- [ ] **Step 5: GET today timeline**

```bash
curl "http://localhost:8000/api/v1/today/timeline?limit=10" \
  -H "Authorization: Bearer <your-test-token>"
```

Expected: the water_ml event appears in `events`.

- [ ] **Step 6: DELETE the event**

```bash
curl -X DELETE "http://localhost:8000/api/v1/events/<event_id>" \
  -H "Authorization: Bearer <your-test-token>"
```

Expected: `200 OK` with `updated_daily_total: null` (no remaining events).

- [ ] **Step 7: Verify daily summary is gone**

Repeat Step 4. Expected: `metrics` is empty (or water_ml not present).

- [ ] **Step 8: Final commit**

```bash
git add .
git commit -m "chore: final smoke test complete — unified health data architecture live"
```

---

## Execution Order Summary

| Phase | Tasks | Dependency |
|-------|-------|------------|
| 1. DB Migrations | 1, 2, 3, 3b | Must complete before any model or API work |
| 2. ORM Models | 4 | Depends on Phase 1 |
| 3. Core Services | 5, 6 | Depends on Phase 2; no API dependencies |
| 4. Ingest API | 7, 8, 9, 10 | Depends on Phase 3 |
| 5. Analytics/Today/Coach | 11, 12, 13 | Depends on Phase 4 |
| 6. Background Worker | 14 | Depends on Phase 4 |
| 7. Flutter | 16, 17, 17b, 17c, 18, 19 | Depends on Phase 4 + 5 being deployed |
| 8. Cleanup | 15, 20, 21 | **After Phase 7 is complete** — Task 15 (remove quick_log router) must not run before Flutter is migrated |

Tasks within each phase can be worked in parallel if desired.
