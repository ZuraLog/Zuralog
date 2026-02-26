"""add_phase6_columns_to_daily_health_metrics

Adds body_fat_percentage, respiratory_rate, oxygen_saturation, and
heart_rate_avg columns to the daily_health_metrics table for Phase 6
new HealthKit data types.

Revision ID: a1b2c3d4e5f6
Revises: d09d4fac7796
Create Date: 2026-02-27 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'a1b2c3d4e5f6'
down_revision: Union[str, Sequence[str], None] = 'd09d4fac7796'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Add Phase 6 health metric columns."""
    op.add_column(
        'daily_health_metrics',
        sa.Column('body_fat_percentage', sa.Float(), nullable=True),
    )
    op.add_column(
        'daily_health_metrics',
        sa.Column('respiratory_rate', sa.Float(), nullable=True),
    )
    op.add_column(
        'daily_health_metrics',
        sa.Column('oxygen_saturation', sa.Float(), nullable=True),
    )
    op.add_column(
        'daily_health_metrics',
        sa.Column('heart_rate_avg', sa.Float(), nullable=True),
    )


def downgrade() -> None:
    """Remove Phase 6 health metric columns."""
    op.drop_column('daily_health_metrics', 'heart_rate_avg')
    op.drop_column('daily_health_metrics', 'oxygen_saturation')
    op.drop_column('daily_health_metrics', 'respiratory_rate')
    op.drop_column('daily_health_metrics', 'body_fat_percentage')
