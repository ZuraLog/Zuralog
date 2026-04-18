"""Add light_sleep_minutes and awake_during_sleep_minutes metric definitions

Revision ID: e3f4a5b6c7d8
Revises: d2e3f4a5b6c7
Create Date: 2026-04-18
"""
from alembic import op

revision = 'e3f4a5b6c7d8'
down_revision = 'd2e3f4a5b6c7'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("""
        INSERT INTO metric_definitions
            (metric_type, display_name, unit, category,
             aggregation_fn, data_type, is_active, display_order)
        VALUES
            ('light_sleep_minutes',
             'Light Sleep', 'min', 'sleep',
             'latest', 'duration', true, 55),
            ('awake_during_sleep_minutes',
             'Awake During Sleep', 'min', 'sleep',
             'latest', 'duration', true, 56)
        ON CONFLICT (metric_type) DO NOTHING;
    """)


def downgrade() -> None:
    op.execute("""
        DELETE FROM metric_definitions
        WHERE metric_type IN (
            'light_sleep_minutes',
            'awake_during_sleep_minutes'
        );
    """)
