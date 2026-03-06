"""add_user_preferences_table

Revision ID: f1e2d3c4b5a6
Revises: a1b2c3d4e5f6
Create Date: 2026-03-04 00:00:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "f1e2d3c4b5a6"
down_revision: Union[str, Sequence[str], None] = "a1b2c3d4e5f6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Create user_preferences table and supporting enum types."""
    # Enum types for PostgreSQL
    op.execute("CREATE TYPE IF NOT EXISTS coach_persona_enum AS ENUM ('tough_love', 'balanced', 'gentle')")
    op.execute("CREATE TYPE IF NOT EXISTS proactivity_level_enum AS ENUM ('low', 'medium', 'high')")
    op.execute("CREATE TYPE IF NOT EXISTS app_theme_enum AS ENUM ('dark', 'light', 'system')")

    op.create_table(
        "user_preferences",
        sa.Column("id", sa.String(), nullable=False),
        sa.Column(
            "user_id",
            sa.String(),
            nullable=False,
            comment="Supabase Auth UID — one row per user",
        ),
        sa.Column(
            "coach_persona",
            sa.String(),
            server_default="balanced",
            nullable=False,
        ),
        sa.Column(
            "proactivity_level",
            sa.String(),
            server_default="medium",
            nullable=False,
        ),
        sa.Column("dashboard_layout", sa.JSON(), nullable=True),
        sa.Column("notification_settings", sa.JSON(), nullable=True),
        sa.Column(
            "theme",
            sa.String(),
            server_default="dark",
            nullable=False,
        ),
        sa.Column(
            "haptic_enabled",
            sa.Boolean(),
            server_default="true",
            nullable=False,
        ),
        sa.Column(
            "tooltips_enabled",
            sa.Boolean(),
            server_default="true",
            nullable=False,
        ),
        sa.Column(
            "onboarding_complete",
            sa.Boolean(),
            server_default="false",
            nullable=False,
        ),
        sa.Column("morning_briefing_time", sa.Time(), nullable=True),
        sa.Column("checkin_reminder_time", sa.Time(), nullable=True),
        sa.Column("quiet_hours_start", sa.Time(), nullable=True),
        sa.Column("quiet_hours_end", sa.Time(), nullable=True),
        sa.Column("goals", sa.JSON(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", name="uq_user_preferences_user_id"),
    )
    op.create_index(
        "ix_user_preferences_user_id",
        "user_preferences",
        ["user_id"],
        unique=False,
    )


def downgrade() -> None:
    """Drop user_preferences table and enum types."""
    op.drop_index("ix_user_preferences_user_id", table_name="user_preferences")
    op.drop_table("user_preferences")
    op.execute("DROP TYPE IF EXISTS app_theme_enum")
    op.execute("DROP TYPE IF EXISTS proactivity_level_enum")
    op.execute("DROP TYPE IF EXISTS coach_persona_enum")
