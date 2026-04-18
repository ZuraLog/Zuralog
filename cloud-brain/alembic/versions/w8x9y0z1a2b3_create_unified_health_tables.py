"""Create unified health tables.

Revision ID: w8x9y0z1a2b3
Revises: v7w8x9y0z1a2
Create Date: 2026-03-22

Creates the four canonical tables for the unified health data architecture:

  - activity_sessions    (workout / activity session tracking)
  - metric_definitions   (metadata catalog for all metric types)
  - health_events        (raw event stream, replaces all per-type tables)
  - daily_summaries      (pre-aggregated daily rollups)

Also:
  - Enables RLS on all four tables with per-user SELECT policies.
  - Seeds metric_definitions with 38 initial rows.
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "w8x9y0z1a2b3"
down_revision: Union[str, Sequence[str], None] = "v7w8x9y0z1a2"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ------------------------------------------------------------------
    # 1. activity_sessions
    # ------------------------------------------------------------------
    op.create_table(
        "activity_sessions",
        sa.Column("id", sa.dialects.postgresql.UUID(), server_default=sa.text("gen_random_uuid()"), nullable=False),
        sa.Column("user_id", sa.String(), nullable=False),
        sa.Column("activity_type", sa.Text(), nullable=False),
        sa.Column("source", sa.Text(), nullable=False),
        sa.Column("started_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("ended_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("metadata", sa.dialects.postgresql.JSONB(), nullable=True),
        sa.Column("idempotency_key", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
    )

    op.create_index(
        "idx_activity_sessions_idempotency",
        "activity_sessions",
        ["user_id", "idempotency_key"],
        unique=True,
        postgresql_where=sa.text("idempotency_key IS NOT NULL"),
    )
    op.create_index(
        "idx_activity_sessions_user_type_time",
        "activity_sessions",
        ["user_id", "activity_type", sa.text("started_at DESC")],
    )

    # ------------------------------------------------------------------
    # 2. metric_definitions
    # ------------------------------------------------------------------
    op.create_table(
        "metric_definitions",
        sa.Column("metric_type", sa.Text(), nullable=False),
        sa.Column("display_name", sa.Text(), nullable=False),
        sa.Column("unit", sa.Text(), nullable=False),
        sa.Column("category", sa.Text(), nullable=False),
        sa.Column("aggregation_fn", sa.Text(), nullable=False),
        sa.Column("data_type", sa.Text(), nullable=False),
        sa.Column("min_value", sa.Float(precision=53), nullable=True),
        sa.Column("max_value", sa.Float(precision=53), nullable=True),
        sa.Column("is_active", sa.Boolean(), server_default=sa.text("true"), nullable=False),
        sa.Column("display_order", sa.Integer(), server_default=sa.text("0"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.PrimaryKeyConstraint("metric_type"),
    )

    # ------------------------------------------------------------------
    # 3. health_events (references activity_sessions)
    # ------------------------------------------------------------------
    op.create_table(
        "health_events",
        sa.Column("id", sa.dialects.postgresql.UUID(), server_default=sa.text("gen_random_uuid()"), nullable=False),
        sa.Column("user_id", sa.String(), nullable=False),
        sa.Column("metric_type", sa.Text(), nullable=False),
        sa.Column("value", sa.Float(precision=53), nullable=False),
        sa.Column("unit", sa.Text(), nullable=False),
        sa.Column("source", sa.Text(), nullable=False),
        sa.Column("recorded_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("local_date", sa.Date(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("granularity", sa.Text(), server_default=sa.text("'point_in_time'"), nullable=False),
        sa.Column("session_id", sa.dialects.postgresql.UUID(), nullable=True),
        sa.Column("idempotency_key", sa.Text(), nullable=True),
        sa.Column("metadata", sa.dialects.postgresql.JSONB(), nullable=True),
        sa.PrimaryKeyConstraint("id"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["session_id"], ["activity_sessions.id"], ondelete="SET NULL"),
    )

    op.create_index(
        "idx_health_events_device_point_dedup",
        "health_events",
        ["user_id", "source", "metric_type", "recorded_at"],
        unique=True,
        postgresql_where=sa.text("source != 'manual' AND granularity = 'point_in_time'"),
    )
    op.create_index(
        "idx_health_events_device_daily_dedup",
        "health_events",
        ["user_id", "source", "metric_type", "local_date"],
        unique=True,
        postgresql_where=sa.text("granularity = 'daily_aggregate'"),
    )
    op.create_index(
        "idx_health_events_idempotency",
        "health_events",
        ["user_id", "idempotency_key"],
        unique=True,
        postgresql_where=sa.text("idempotency_key IS NOT NULL"),
    )
    op.create_index(
        "idx_health_events_user_metric_time",
        "health_events",
        ["user_id", "metric_type", sa.text("recorded_at DESC")],
        postgresql_where=sa.text("deleted_at IS NULL"),
    )
    op.create_index(
        "idx_health_events_user_local_date",
        "health_events",
        ["user_id", sa.text("local_date DESC")],
        postgresql_where=sa.text("deleted_at IS NULL"),
    )
    op.create_index(
        "idx_health_events_session",
        "health_events",
        ["session_id"],
        postgresql_where=sa.text("session_id IS NOT NULL AND deleted_at IS NULL"),
    )

    # ------------------------------------------------------------------
    # 4. daily_summaries
    # ------------------------------------------------------------------
    op.create_table(
        "daily_summaries",
        sa.Column("id", sa.dialects.postgresql.UUID(), server_default=sa.text("gen_random_uuid()"), nullable=False),
        sa.Column("user_id", sa.String(), nullable=False),
        sa.Column("date", sa.Date(), nullable=False),
        sa.Column("metric_type", sa.Text(), nullable=False),
        sa.Column("value", sa.Float(precision=53), nullable=False),
        sa.Column("unit", sa.Text(), nullable=False),
        sa.Column("event_count", sa.Integer(), server_default=sa.text("1"), nullable=False),
        sa.Column("is_stale", sa.Boolean(), server_default=sa.text("false"), nullable=False),
        sa.Column("computed_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.UniqueConstraint("user_id", "date", "metric_type", name="uq_daily_summaries_user_date_metric"),
    )

    op.create_index(
        "idx_daily_summaries_user_metric_date",
        "daily_summaries",
        ["user_id", "metric_type", sa.text("date DESC")],
    )
    op.create_index(
        "idx_daily_summaries_user_date",
        "daily_summaries",
        ["user_id", sa.text("date DESC")],
    )
    op.create_index(
        "idx_daily_summaries_stale",
        "daily_summaries",
        ["is_stale"],
        postgresql_where=sa.text("is_stale = true"),
    )

    # ------------------------------------------------------------------
    # 5. RLS Policies
    # ------------------------------------------------------------------
    # RLS policies reference auth.uid(), which only exists on Supabase.
    # On plain Postgres (local dev) the auth schema is absent, so we guard
    # the policy creation and only enable RLS on the tables. This mirrors
    # the pattern used by every other RLS migration in this directory.
    _has_auth = (
        op.get_bind()
        .execute(sa.text("SELECT EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'auth')"))
        .scalar()
    )

    op.execute("ALTER TABLE activity_sessions ENABLE ROW LEVEL SECURITY")
    op.execute("ALTER TABLE metric_definitions ENABLE ROW LEVEL SECURITY")
    op.execute("ALTER TABLE health_events ENABLE ROW LEVEL SECURITY")
    op.execute("ALTER TABLE daily_summaries ENABLE ROW LEVEL SECURITY")

    op.execute(
        'CREATE POLICY "metric definitions are publicly readable" '
        "ON metric_definitions FOR SELECT USING (true)"
    )

    if _has_auth:
        op.execute(
            'CREATE POLICY "users can read their own sessions" '
            "ON activity_sessions FOR SELECT USING (user_id = auth.uid())"
        )
        op.execute(
            'CREATE POLICY "users can read their own events" '
            "ON health_events FOR SELECT USING (user_id = auth.uid())"
        )
        op.execute(
            'CREATE POLICY "users can read their own summaries" '
            "ON daily_summaries FOR SELECT USING (user_id = auth.uid())"
        )

    # ------------------------------------------------------------------
    # 6. Seed metric_definitions (38 rows)
    # ------------------------------------------------------------------
    op.execute("""
        INSERT INTO metric_definitions
            (metric_type, display_name, unit, category, aggregation_fn, data_type, min_value, max_value, display_order)
        VALUES
            ('steps',                   'Steps',                'steps',     'activity',    'sum',    'integer',  0,    100000,  1),
            ('active_calories',         'Active Calories',      'kcal',      'activity',    'sum',    'float',    0,    10000,   2),
            ('distance',                'Distance',             'm',         'activity',    'sum',    'float',    0,    500000,  3),
            ('exercise_minutes',        'Exercise Minutes',     'min',       'activity',    'sum',    'integer',  0,    1440,    4),
            ('walking_speed',           'Walking Speed',        'm/s',       'activity',    'avg',    'float',    0,    10,      5),
            ('running_pace',            'Running Pace',         's/km',      'activity',    'avg',    'float',    60,   1800,    6),
            ('floors_climbed',          'Floors Climbed',       'floors',    'activity',    'sum',    'integer',  0,    500,     7),
            ('sleep_duration',          'Sleep Duration',       'min',       'sleep',       'latest', 'duration', 0,    1440,    1),
            ('deep_sleep_minutes',      'Deep Sleep',           'min',       'sleep',       'latest', 'duration', 0,    720,     2),
            ('rem_sleep_minutes',       'REM Sleep',            'min',       'sleep',       'latest', 'duration', 0,    720,     3),
            ('sleep_efficiency',        'Sleep Efficiency',     '%',         'sleep',       'latest', 'float',    0,    100,     4),
            ('sleep_quality',           'Sleep Quality',        'score',     'sleep',       'latest', 'score',    0,    100,     5),
            ('resting_heart_rate',      'Resting Heart Rate',   'bpm',       'heart',       'avg',    'float',    20,   220,     1),
            ('hrv_ms',                  'HRV',                  'ms',        'heart',       'avg',    'float',    0,    300,     2),
            ('vo2_max',                 'VO2 Max',              'mL/kg/min', 'heart',       'latest', 'float',    10,   90,      3),
            ('respiratory_rate',        'Respiratory Rate',     'brpm',      'heart',       'avg',    'float',    5,    60,      4),
            ('heart_rate_avg',          'Avg Heart Rate',       'bpm',       'heart',       'avg',    'float',    20,   220,     5),
            ('weight_kg',               'Weight',               'kg',        'body',        'latest', 'float',    20,   500,     1),
            ('body_fat_percentage',     'Body Fat',             '%',         'body',        'latest', 'float',    1,    70,      2),
            ('body_temperature',        'Body Temperature',     '°C',       'body',        'avg',    'float',    34,   42,      3),
            ('wrist_temperature',       'Wrist Temperature',    '°C',       'body',        'avg',    'float',    30,   42,      4),
            ('muscle_mass_kg',          'Muscle Mass',          'kg',        'body',        'latest', 'float',    5,    200,     5),
            ('blood_pressure_systolic', 'Blood Pressure (Sys)', 'mmHg',      'vitals',      'avg',    'integer',  50,   250,     1),
            ('blood_pressure_diastolic','Blood Pressure (Dia)', 'mmHg',      'vitals',      'avg',    'integer',  30,   150,     2),
            ('spo2',                    'Blood Oxygen',         '%',         'vitals',      'avg',    'float',    70,   100,     3),
            ('blood_glucose',           'Blood Glucose',        'mmol/L',    'vitals',      'avg',    'float',    1,    30,      4),
            ('calories',                'Calories',             'kcal',      'nutrition',   'sum',    'integer',  0,    20000,   1),
            ('protein_grams',           'Protein',              'g',         'nutrition',   'sum',    'float',    0,    1000,    2),
            ('carbs_grams',             'Carbs',                'g',         'nutrition',   'sum',    'float',    0,    2000,    3),
            ('fat_grams',               'Fat',                  'g',         'nutrition',   'sum',    'float',    0,    1000,    4),
            ('water_ml',                'Water',                'mL',        'nutrition',   'sum',    'float',    0,    20000,   5),
            ('mood',                    'Mood',                 '/10',       'wellness',    'avg',    'score',    0,    10,      1),
            ('energy',                  'Energy',               '/10',       'wellness',    'avg',    'score',    0,    10,      2),
            ('stress',                  'Stress',               '/100',      'wellness',    'avg',    'score',    0,    100,     3),
            ('mindful_minutes',         'Mindful Minutes',      'min',       'wellness',    'sum',    'integer',  0,    1440,    4),
            ('cycle_day',               'Cycle Day',            'day',       'cycle',       'latest', 'integer',  1,    40,      1),
            ('noise_exposure',          'Noise Exposure',       'dB',        'environment', 'avg',    'float',    0,    200,     1),
            ('uv_index',                'UV Index',             'UV',        'environment', 'avg',    'float',    0,    20,      2)
        ON CONFLICT DO NOTHING
    """)


def downgrade() -> None:
    op.drop_table("daily_summaries")
    op.drop_table("health_events")
    op.drop_table("metric_definitions")
    op.drop_table("activity_sessions")
