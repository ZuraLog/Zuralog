"""Add memory_enabled to user_preferences.

The SQLAlchemy model has had this column since the memory feature was
built, but no migration ever created it in the database. This closes
the gap so the chat endpoint and preferences routes can read/write it
without throwing UndefinedColumnError.

Revision ID: b1c2d3e4f5a6
Revises: f8a9b2c3d4e5
Create Date: 2026-04-24
"""
from alembic import op
import sqlalchemy as sa

revision = "b1c2d3e4f5a6"
down_revision = "f8a9b2c3d4e5"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "user_preferences",
        sa.Column(
            "memory_enabled",
            sa.Boolean(),
            nullable=False,
            server_default="true",
        ),
    )


def downgrade() -> None:
    op.drop_column("user_preferences", "memory_enabled")
