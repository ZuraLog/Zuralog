"""Drop legacy health tables.

Revision ID: v7w8x9y0z1a2
Revises: u6v7w8x9y0z1
Create Date: 2026-03-22

These tables belong to the old per-metric schema and are being replaced by the
new unified health data architecture, which uses four canonical tables:

  - health_events        (raw event stream, replaces quick_logs and all per-type tables)
  - daily_summaries      (replaces daily_health_metrics)
  - metric_definitions   (metadata catalog for all metric types)
  - activity_sessions    (replaces unified_activities)

Tables dropped:
  - quick_logs
  - daily_health_metrics
  - sleep_records
  - weight_measurements
  - nutrition_entries
  - blood_pressure_records
  - unified_activities
  - cycle_tracking
  - environment_metrics

This is a development environment with no production users. There is no data to
preserve. The downgrade function is intentionally a no-op.
"""

from typing import Sequence, Union

from alembic import op

revision: str = "v7w8x9y0z1a2"
down_revision: Union[str, Sequence[str], None] = "u6v7w8x9y0z1"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.execute("DROP TABLE IF EXISTS quick_logs CASCADE")
    op.execute("DROP TABLE IF EXISTS daily_health_metrics CASCADE")
    op.execute("DROP TABLE IF EXISTS sleep_records CASCADE")
    op.execute("DROP TABLE IF EXISTS weight_measurements CASCADE")
    op.execute("DROP TABLE IF EXISTS nutrition_entries CASCADE")
    op.execute("DROP TABLE IF EXISTS blood_pressure_records CASCADE")
    op.execute("DROP TABLE IF EXISTS unified_activities CASCADE")
    op.execute("DROP TABLE IF EXISTS cycle_tracking CASCADE")
    op.execute("DROP TABLE IF EXISTS environment_metrics CASCADE")


def downgrade() -> None:
    # No-op: this is a development environment with no production data.
    # The dropped tables are superseded by the new unified health data schema
    # and will not be recreated.
    pass
