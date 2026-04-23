"""Add weight_kg column to users table.

Revision ID: c0d1e2f3a4b5
Revises: 897ba7021291
Create Date: 2026-04-23
"""
from alembic import op
import sqlalchemy as sa

revision = "c0d1e2f3a4b5"
down_revision = "897ba7021291"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column("weight_kg", sa.Numeric(precision=5, scale=1), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("users", "weight_kg")
