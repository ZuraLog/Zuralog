"""add phase2 core tables

Creates all remaining Phase 2 tables:
- user_preferences: per-user settings and preferences
- achievements: achievement unlock state
- user_streaks: engagement/streak tracking with freeze mechanic
- journal_entries: daily wellness journal
- quick_logs: manual health data logging
- emergency_health_cards: user emergency health info
- insights: AI-generated insight cards

Revision ID: g2b3c4d5e6f7
Revises: f1a2b3c4d5e7
Create Date: 2026-03-04 12:00:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "g2b3c4d5e6f7"
down_revision: Union[str, Sequence[str], None] = "f1a2b3c4d5e7"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Create remaining Phase 2 tables."""

    # ------------------------------------------------------------------
    # user_preferences
    # ------------------------------------------------------------------
    op.create_table(
        "user_preferences",
        sa.Column("id", sa.String(), nullable=False),
        sa.Column(
            "user_id",
            sa.String(),
            nullable=False,
            comment="FK to users.id, deleted when user is deleted",
        ),
        sa.Column(
            "coach_persona",
            sa.String(),
            nullable=False,
            server_default="balanced",
            comment="tough_love | balanced | gentle",
        ),
        sa.Column(
            "proactivity_level",
            sa.String(),
            nullable=False,
            server_default="medium",
            comment="low | medium | high",
        ),
        sa.Column("dashboard_layout", sa.JSON(), nullable=True),
        sa.Column("notification_settings", sa.JSON(), nullable=True),
        sa.Column(
            "theme",
            sa.String(),
            nullable=False,
            server_default="dark",
            comment="dark | light | system",
        ),
        sa.Column(
            "haptic_enabled",
            sa.Boolean(),
            nullable=False,
            server_default="true",
        ),
        sa.Column(
            "tooltips_enabled",
            sa.Boolean(),
            nullable=False,
            server_default="true",
        ),
        sa.Column(
            "onboarding_complete",
            sa.Boolean(),
            nullable=False,
            server_default="false",
        ),
        sa.Column(
            "morning_briefing_enabled",
            sa.Boolean(),
            nullable=False,
            server_default="false",
        ),
        sa.Column("morning_briefing_time", sa.Time(), nullable=True),
        sa.Column(
            "checkin_reminder_enabled",
            sa.Boolean(),
            nullable=False,
            server_default="false",
        ),
        sa.Column("checkin_reminder_time", sa.Time(), nullable=True),
        sa.Column(
            "quiet_hours_enabled",
            sa.Boolean(),
            nullable=False,
            server_default="false",
        ),
        sa.Column("quiet_hours_start", sa.Time(), nullable=True),
        sa.Column("quiet_hours_end", sa.Time(), nullable=True),
        sa.Column("goals", sa.JSON(), nullable=True),
        sa.Column(
            "units_system",
            sa.String(),
            nullable=False,
            server_default="metric",
            comment="metric | imperial",
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_user_preferences_user_id", "user_preferences", ["user_id"])
    op.create_index("ix_user_preferences_user_id_unique", "user_preferences", ["user_id"], unique=True)

    # ------------------------------------------------------------------
    # achievements
    # ------------------------------------------------------------------
    op.create_table(
        "achievements",
        sa.Column("id", sa.String(), nullable=False),
        sa.Column("user_id", sa.String(), nullable=False),
        sa.Column("achievement_key", sa.String(), nullable=False),
        sa.Column("unlocked_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_achievements_user_id", "achievements", ["user_id"])
    op.create_index(
        "ix_achievements_user_key",
        "achievements",
        ["user_id", "achievement_key"],
        unique=True,
    )

    # ------------------------------------------------------------------
    # user_streaks
    # ------------------------------------------------------------------
    op.create_table(
        "user_streaks",
        sa.Column("id", sa.String(), nullable=False),
        sa.Column("user_id", sa.String(), nullable=False),
        sa.Column("streak_type", sa.String(), nullable=False),
        sa.Column("current_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("longest_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("last_activity_date", sa.Date(), nullable=True),
        sa.Column("freeze_count", sa.Integer(), nullable=False, server_default="1"),
        sa.Column(
            "freeze_used_today",
            sa.Boolean(),
            nullable=False,
            server_default="false",
        ),
        sa.Column(
            "freeze_used_this_week",
            sa.Boolean(),
            nullable=False,
            server_default="false",
        ),
        sa.Column("week_freeze_reset_date", sa.Date(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_user_streaks_user_id", "user_streaks", ["user_id"])
    op.create_index(
        "ix_user_streaks_user_type",
        "user_streaks",
        ["user_id", "streak_type"],
        unique=True,
    )

    # ------------------------------------------------------------------
    # journal_entries
    # ------------------------------------------------------------------
    op.create_table(
        "journal_entries",
        sa.Column("id", sa.String(), nullable=False),
        sa.Column("user_id", sa.String(), nullable=False),
        sa.Column("date", sa.Date(), nullable=False),
        sa.Column("mood", sa.Integer(), nullable=True),
        sa.Column("energy", sa.Integer(), nullable=True),
        sa.Column("stress", sa.Integer(), nullable=True),
        sa.Column("sleep_quality", sa.Integer(), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("tags", sa.JSON(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_journal_entries_user_id", "journal_entries", ["user_id"])
    op.create_index("ix_journal_entries_date", "journal_entries", ["date"])
    op.create_index(
        "ix_journal_entries_user_date",
        "journal_entries",
        ["user_id", "date"],
        unique=True,
    )

    # ------------------------------------------------------------------
    # quick_logs
    # ------------------------------------------------------------------
    op.create_table(
        "quick_logs",
        sa.Column("id", sa.String(), nullable=False),
        sa.Column("user_id", sa.String(), nullable=False),
        sa.Column("metric_type", sa.String(), nullable=False),
        sa.Column("value", sa.Float(), nullable=True),
        sa.Column("text_value", sa.String(), nullable=True),
        sa.Column("tags", sa.JSON(), nullable=True),
        sa.Column(
            "logged_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_quick_logs_user_id", "quick_logs", ["user_id"])
    op.create_index("ix_quick_logs_logged_at", "quick_logs", ["logged_at"])

    # ------------------------------------------------------------------
    # emergency_health_cards
    # ------------------------------------------------------------------
    op.create_table(
        "emergency_health_cards",
        sa.Column("id", sa.String(), nullable=False),
        sa.Column("user_id", sa.String(), nullable=False),
        sa.Column("blood_type", sa.String(), nullable=True),
        sa.Column("allergies", sa.JSON(), nullable=True),
        sa.Column("medications", sa.JSON(), nullable=True),
        sa.Column("conditions", sa.JSON(), nullable=True),
        sa.Column("emergency_contacts", sa.JSON(), nullable=True),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_emergency_health_cards_user_id",
        "emergency_health_cards",
        ["user_id"],
        unique=True,
    )

    # ------------------------------------------------------------------
    # insights
    # ------------------------------------------------------------------
    op.create_table(
        "insights",
        sa.Column("id", sa.String(), nullable=False),
        sa.Column("user_id", sa.String(), nullable=False),
        sa.Column("type", sa.String(), nullable=False),
        sa.Column("title", sa.String(), nullable=False),
        sa.Column("body", sa.Text(), nullable=False),
        sa.Column("data", sa.JSON(), nullable=True),
        sa.Column("reasoning", sa.Text(), nullable=True),
        sa.Column("priority", sa.Integer(), nullable=False, server_default="5"),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column("read_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("dismissed_at", sa.DateTime(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_insights_user_id", "insights", ["user_id"])
    op.create_index(
        "ix_insights_user_priority_created",
        "insights",
        ["user_id", "priority", "created_at"],
    )
    op.create_index(
        "ix_insights_user_type_created",
        "insights",
        ["user_id", "type", "created_at"],
    )


def downgrade() -> None:
    """Drop all Phase 2 tables."""
    op.drop_table("insights")
    op.drop_table("emergency_health_cards")
    op.drop_table("quick_logs")
    op.drop_table("journal_entries")
    op.drop_table("user_streaks")
    op.drop_table("achievements")
    op.drop_table("user_preferences")
