"""Add query-optimized index on daily_summaries (user_id, metric_type, date).

Revision ID: a2b3c4d5e6f7
Revises: z1a2b3c4d5e6
Create Date: 2026-03-25
"""
import sqlalchemy as sa
from alembic import op

revision = "a2b3c4d5e6f7"
down_revision = "z1a2b3c4d5e6"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_index(
        "ix_daily_summaries_user_metric_date",
        "daily_summaries",
        ["user_id", "metric_type", "date"],
    )


def downgrade() -> None:
    op.drop_index("ix_daily_summaries_user_metric_date", table_name="daily_summaries")
