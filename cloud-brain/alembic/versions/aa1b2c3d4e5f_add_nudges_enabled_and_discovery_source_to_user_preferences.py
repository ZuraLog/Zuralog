"""add nudges_enabled and discovery_source to user_preferences

Revision ID: aa1b2c3d4e5f
Revises: 7de9ed24e305
Create Date: 2026-04-22

Adds two columns to user_preferences:
- nudges_enabled (BOOLEAN NOT NULL DEFAULT false): controls real-time nudge
  notifications, off by default.
- discovery_source (VARCHAR NULL): records how the user found ZuraLog, set
  once during onboarding and never overwritten.
"""

from alembic import op

# revision identifiers, used by Alembic
revision = "aa1b2c3d4e5f"
down_revision = "7de9ed24e305"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Use IF NOT EXISTS so re-running is safe if columns were added manually.
    op.execute(
        "ALTER TABLE user_preferences "
        "ADD COLUMN IF NOT EXISTS nudges_enabled BOOLEAN NOT NULL DEFAULT false"
    )
    op.execute(
        "ALTER TABLE user_preferences "
        "ADD COLUMN IF NOT EXISTS discovery_source VARCHAR NULL"
    )


def downgrade() -> None:
    op.drop_column("user_preferences", "discovery_source")
    op.drop_column("user_preferences", "nudges_enabled")
