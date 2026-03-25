"""add height_cm and avatar_url to users

Revision ID: a3b4c5d6e7f8
Revises: z2a3b4c5d6e7
Create Date: 2026-03-25

Adds two nullable columns to the users table:
  - height_cm: FLOAT — user's height in centimetres, used for health calculations
  - avatar_url: VARCHAR — URL pointing to the user's profile photo in Supabase Storage

Both columns are nullable with no default. On PostgreSQL 11+, adding a nullable
column with no default is a metadata-only operation — no table rewrite, no lock
escalation, zero downtime at any table size.
"""

from alembic import op  # type: ignore[reportAttributeAccessIssue]


revision = "a3b4c5d6e7f8"
down_revision = "7de9ed24e305"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS height_cm FLOAT")
    op.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar_url VARCHAR")


def downgrade() -> None:
    op.drop_column("users", "avatar_url")
    op.drop_column("users", "height_cm")
