"""Add supplement_taken and symptom metric definitions.

Revision ID: y0z1a2b3c4d5
Revises: x9y0z1a2b3c4
Create Date: 2026-03-22
"""
from alembic import op

revision = "y0z1a2b3c4d5"
down_revision = "x9y0z1a2b3c4"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("""
        INSERT INTO metric_definitions
            (metric_type, display_name, unit, category, aggregation_fn, data_type, min_value, max_value, display_order)
        VALUES
            ('supplement_taken', 'Supplement Taken', 'dose', 'wellness', 'sum', 'integer', 0, 100, 5),
            ('symptom',          'Symptom',          'severity', 'wellness', 'avg', 'score', 0, 3, 6)
        ON CONFLICT DO NOTHING
    """)


def downgrade() -> None:
    op.execute("DELETE FROM metric_definitions WHERE metric_type IN ('supplement_taken', 'symptom')")
