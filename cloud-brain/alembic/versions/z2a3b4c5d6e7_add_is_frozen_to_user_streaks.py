"""add is_frozen to user_streaks

Revision ID: z2a3b4c5d6e7
Revises: y0z1a2b3c4d5
Create Date: 2026-03-25
"""
from alembic import op
import sqlalchemy as sa

revision = "z2a3b4c5d6e7"
down_revision = "y0z1a2b3c4d5"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        "ALTER TABLE user_streaks ADD COLUMN IF NOT EXISTS is_frozen BOOLEAN DEFAULT FALSE NOT NULL"
    )


def downgrade() -> None:
    op.drop_column("user_streaks", "is_frozen")
