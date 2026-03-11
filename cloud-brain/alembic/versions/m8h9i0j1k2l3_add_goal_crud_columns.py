"""add goal CRUD columns to user_goals

Revision ID: m8h9i0j1k2l3
Revises: l7g8h9i0j1k2
Create Date: 2026-03-11

Adds 8 new columns to user_goals that the Flutter client needs for
full goals CRUD (list, create, edit, delete). Also drops the unique
constraint on (user_id, metric) so users can have multiple goals of
the same type.

  New columns:
    - type: VARCHAR NOT NULL DEFAULT 'custom'
    - title: VARCHAR NOT NULL DEFAULT ''
    - current_value: DOUBLE PRECISION NOT NULL DEFAULT 0.0
    - unit: VARCHAR NOT NULL DEFAULT ''
    - start_date: VARCHAR NOT NULL DEFAULT ''
    - deadline: VARCHAR (nullable)
    - is_completed: BOOLEAN NOT NULL DEFAULT false
    - ai_commentary: VARCHAR (nullable)

  Dropped constraint:
    - uq_user_goal_user_metric (one-goal-per-metric restriction)

  Backfill:
    - title = metric for existing rows
    - start_date = created_at formatted as YYYY-MM-DD
"""

from alembic import op


revision = "m8h9i0j1k2l3"
down_revision = "l7g8h9i0j1k2"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # ADD COLUMN with a constant DEFAULT is metadata-only on PostgreSQL 11+.
    # No table rewrite, no lock escalation.
    op.execute("ALTER TABLE user_goals ADD COLUMN IF NOT EXISTS type VARCHAR NOT NULL DEFAULT 'custom'")
    op.execute("ALTER TABLE user_goals ADD COLUMN IF NOT EXISTS title VARCHAR NOT NULL DEFAULT ''")
    op.execute("ALTER TABLE user_goals ADD COLUMN IF NOT EXISTS current_value DOUBLE PRECISION NOT NULL DEFAULT 0.0")
    op.execute("ALTER TABLE user_goals ADD COLUMN IF NOT EXISTS unit VARCHAR NOT NULL DEFAULT ''")
    op.execute("ALTER TABLE user_goals ADD COLUMN IF NOT EXISTS start_date VARCHAR NOT NULL DEFAULT ''")
    op.execute("ALTER TABLE user_goals ADD COLUMN IF NOT EXISTS deadline VARCHAR")
    op.execute("ALTER TABLE user_goals ADD COLUMN IF NOT EXISTS is_completed BOOLEAN NOT NULL DEFAULT false")
    op.execute("ALTER TABLE user_goals ADD COLUMN IF NOT EXISTS ai_commentary VARCHAR")

    # Drop the one-goal-per-metric unique constraint so users can
    # have multiple goals of the same type.
    op.execute("ALTER TABLE user_goals DROP CONSTRAINT IF EXISTS uq_user_goal_user_metric")

    # Backfill existing rows with sensible values.
    op.execute("UPDATE user_goals SET title = metric WHERE title = ''")
    op.execute("UPDATE user_goals SET start_date = TO_CHAR(created_at, 'YYYY-MM-DD') WHERE start_date = ''")


def downgrade() -> None:
    op.drop_column("user_goals", "ai_commentary")
    op.drop_column("user_goals", "is_completed")
    op.drop_column("user_goals", "deadline")
    op.drop_column("user_goals", "start_date")
    op.drop_column("user_goals", "unit")
    op.drop_column("user_goals", "current_value")
    op.drop_column("user_goals", "title")
    op.drop_column("user_goals", "type")
    # Re-add the unique constraint dropped during upgrade.
    op.create_unique_constraint("uq_user_goal_user_metric", "user_goals", ["user_id", "metric"])
