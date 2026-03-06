"""add_phase2_tables

Creates tables required for Phase 2 backend features:
  - achievements
  - user_streaks
  - journal_entries
  - quick_logs
  - emergency_health_cards

Revision ID: b2c3d4e5f6a7
Revises: c3d4e5f6a7b8
Create Date: 2026-03-04 00:00:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "b2c3d4e5f6a7"
down_revision: Union[str, Sequence[str], None] = "c3d4e5f6a7b8"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # No-op: all tables here are created idempotently by g2b3c4d5e6f7.
    # This orphaned branch was superseded before being merged.
    return

    """Create Phase 2 tables: achievements, user_streaks, journal_entries, quick_logs, emergency_health_cards."""

    # ------------------------------------------------------------------
    # achievements
    # ------------------------------------------------------------------
    op.create_table(
        "achievements",
        sa.Column("id", sa.String(), nullable=False),
        sa.Column("user_id", sa.String(), nullable=False),
        sa.Column("achievement_key", sa.String(), nullable=False),
        sa.Column(
            "unlocked_at",
            sa.DateTime(timezone=True),
            nullable=True,
            comment="UTC timestamp when achievement was unlocked; NULL while locked",
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "achievement_key", name="uq_achievement_user_key"),
    )
    op.create_index(
        "ix_achievements_user_id",
        "achievements",
        ["user_id"],
        unique=False,
    )

    # ------------------------------------------------------------------
    # user_streaks
    # ------------------------------------------------------------------
    op.create_table(
        "user_streaks",
        sa.Column("id", sa.String(), nullable=False),
        sa.Column("user_id", sa.String(), nullable=False),
        sa.Column(
            "streak_type",
            sa.String(),
            nullable=False,
            comment="engagement | steps | workouts | checkin",
        ),
        sa.Column(
            "current_count",
            sa.Integer(),
            nullable=False,
            server_default="0",
            comment="Current consecutive-day streak length",
        ),
        sa.Column(
            "longest_count",
            sa.Integer(),
            nullable=False,
            server_default="0",
            comment="All-time longest streak achieved by this user",
        ),
        sa.Column(
            "last_activity_date",
            sa.String(),
            nullable=True,
            comment="Most-recent active day as YYYY-MM-DD string",
        ),
        sa.Column(
            "freeze_count",
            sa.Integer(),
            nullable=False,
            server_default="0",
            comment="Accumulated freeze tokens (maximum 2)",
        ),
        sa.Column(
            "freeze_used_this_week",
            sa.Boolean(),
            nullable=False,
            server_default="false",
            comment="Whether the free weekly freeze has been used; reset every Monday",
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "streak_type", name="uq_user_streak_user_type"),
    )
    op.create_index(
        "ix_user_streaks_user_id",
        "user_streaks",
        ["user_id"],
        unique=False,
    )

    # ------------------------------------------------------------------
    # journal_entries
    # ------------------------------------------------------------------
    op.create_table(
        "journal_entries",
        sa.Column("id", sa.String(), nullable=False),
        sa.Column("user_id", sa.String(), nullable=False),
        sa.Column(
            "date",
            sa.String(),
            nullable=False,
            comment="Calendar date in YYYY-MM-DD format",
        ),
        sa.Column(
            "mood",
            sa.Integer(),
            nullable=True,
            comment="Subjective mood rating 1–10",
        ),
        sa.Column(
            "energy",
            sa.Integer(),
            nullable=True,
            comment="Subjective energy rating 1–10",
        ),
        sa.Column(
            "stress",
            sa.Integer(),
            nullable=True,
            comment="Subjective stress rating 1–10",
        ),
        sa.Column(
            "sleep_quality",
            sa.Integer(),
            nullable=True,
            comment="Subjective sleep quality rating 1–10",
        ),
        sa.Column(
            "notes",
            sa.Text(),
            nullable=True,
            comment="Free-text journal notes",
        ),
        sa.Column(
            "tags",
            sa.JSON(),
            nullable=False,
            server_default="[]",
            comment="Array of tag strings",
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "date", name="uq_journal_entries_user_date"),
    )
    op.create_index(
        "ix_journal_entries_user_id",
        "journal_entries",
        ["user_id"],
        unique=False,
    )
    op.create_index(
        "ix_journal_entries_date",
        "journal_entries",
        ["date"],
        unique=False,
    )

    # ------------------------------------------------------------------
    # quick_logs
    # ------------------------------------------------------------------
    op.create_table(
        "quick_logs",
        sa.Column("id", sa.String(), nullable=False),
        sa.Column(
            "user_id",
            sa.String(),
            nullable=False,
            comment="Supabase UID of the owning user",
        ),
        sa.Column(
            "metric_type",
            sa.String(),
            nullable=False,
            comment="water | mood | energy | stress | sleep_quality | pain | notes",
        ),
        sa.Column(
            "value",
            sa.Float(),
            nullable=True,
            comment="Numeric measurement value",
        ),
        sa.Column(
            "text_value",
            sa.Text(),
            nullable=True,
            comment="Free-text content for notes or descriptive metrics",
        ),
        sa.Column(
            "tags",
            sa.JSON(),
            nullable=False,
            server_default="[]",
            comment="Array of tag strings",
        ),
        sa.Column(
            "logged_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
            comment="When the metric was recorded",
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_quick_logs_user_id",
        "quick_logs",
        ["user_id"],
        unique=False,
    )
    op.create_index(
        "ix_quick_logs_logged_at",
        "quick_logs",
        ["logged_at"],
        unique=False,
    )

    # ------------------------------------------------------------------
    # emergency_health_cards
    # ------------------------------------------------------------------
    op.create_table(
        "emergency_health_cards",
        sa.Column(
            "user_id",
            sa.String(),
            nullable=False,
            comment="Supabase UID — one row per user",
        ),
        sa.Column(
            "blood_type",
            sa.String(),
            nullable=True,
            comment="ABO/Rh blood type, e.g. 'O+'",
        ),
        sa.Column(
            "allergies",
            sa.JSON(),
            nullable=False,
            server_default="[]",
            comment="Array of allergy description strings",
        ),
        sa.Column(
            "medications",
            sa.JSON(),
            nullable=False,
            server_default="[]",
            comment="Array of current medication strings",
        ),
        sa.Column(
            "conditions",
            sa.JSON(),
            nullable=False,
            server_default="[]",
            comment="Array of medical condition strings",
        ),
        sa.Column(
            "emergency_contacts",
            sa.JSON(),
            nullable=False,
            server_default="[]",
            comment="Array of contact dicts: {name, relationship, phone}",
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=True,
            comment="Server-managed last-update timestamp",
        ),
        sa.PrimaryKeyConstraint("user_id"),
    )


def downgrade() -> None:
    """Drop Phase 2 tables in reverse creation order."""
    op.drop_table("emergency_health_cards")

    op.drop_index("ix_quick_logs_logged_at", table_name="quick_logs")
    op.drop_index("ix_quick_logs_user_id", table_name="quick_logs")
    op.drop_table("quick_logs")

    op.drop_index("ix_journal_entries_date", table_name="journal_entries")
    op.drop_index("ix_journal_entries_user_id", table_name="journal_entries")
    op.drop_table("journal_entries")

    op.drop_index("ix_user_streaks_user_id", table_name="user_streaks")
    op.drop_table("user_streaks")

    op.drop_index("ix_achievements_user_id", table_name="achievements")
    op.drop_table("achievements")
