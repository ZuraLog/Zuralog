"""Add expanded health metric columns to daily_health_metrics.

Adds all columns referenced by the DailyHealthMetrics ORM model under the
comment 'Expanded schema — all new columns added in migration
expand_health_metrics_schema'. That migration was referenced but never written,
causing UndefinedColumnError on every apple_health_read_metrics call that
queries daily_summary data (which selects all model columns).

Revision ID: j00d00000005
Revises: i00d00000004
Create Date: 2026-04-04
"""

from typing import Sequence, Union

from alembic import op  # type: ignore[attr-defined]


revision: str = "j00d00000005"
down_revision: Union[str, Sequence[str], None] = "i00d00000004"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

_COLUMNS = [
    "exercise_minutes",
    "running_pace_secs_per_km",
    "body_temperature_celsius",
    "wrist_temperature_celsius",
    "mindful_minutes",
    "blood_glucose_mmol",
    "water_ml",
    "mood_score",
    "energy_score",
    "stress_score",
    "skin_temperature_delta",
    "uv_exposure_index",
    "noise_exposure_db",
]


def upgrade() -> None:
    for col in _COLUMNS:
        op.execute(
            f"ALTER TABLE daily_health_metrics ADD COLUMN IF NOT EXISTS {col} FLOAT"
        )


def downgrade() -> None:
    for col in reversed(_COLUMNS):
        op.execute(
            f"ALTER TABLE daily_health_metrics DROP COLUMN IF EXISTS {col}"
        )
