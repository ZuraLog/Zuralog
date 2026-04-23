"""Add onboarding profile fields to user_preferences.

Adds nine nullable columns that carry every onboarding answer from the
mobile app into the AI's system prompt:

- focus_area            (main health focus)
- primary_goal          (narrative goal, up to 200 chars)
- tone                  (direct / warm / minimal / thorough)
- dietary_restrictions  (JSON array; empty array means "no restrictions")
- injuries              (JSON array; empty array means "none")
- sleep_pattern         (great / hard_to_fall_asleep / wake_up_a_lot / short_hours)
- health_frustration    (short free text, up to 120 chars)
- profile_catchup_status        (not_shown / in_progress / completed / dismissed)
- profile_catchup_dismissed_at  (timestamp for the 7-day re-offer window)

Also merges the two existing alembic heads into a single head so future
migrations run cleanly.

Revision ID: f8a9b2c3d4e5
Revises: 5e1ce400db6c, c0d1e2f3a4b5
Create Date: 2026-04-23
"""
from alembic import op
import sqlalchemy as sa

revision = "f8a9b2c3d4e5"
down_revision = ("5e1ce400db6c", "c0d1e2f3a4b5")
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "user_preferences",
        sa.Column("focus_area", sa.String(), nullable=True),
    )
    op.add_column(
        "user_preferences",
        sa.Column("primary_goal", sa.String(length=200), nullable=True),
    )
    op.add_column(
        "user_preferences",
        sa.Column("tone", sa.String(), nullable=True),
    )
    op.add_column(
        "user_preferences",
        sa.Column("dietary_restrictions", sa.JSON(), nullable=True),
    )
    op.add_column(
        "user_preferences",
        sa.Column("injuries", sa.JSON(), nullable=True),
    )
    op.add_column(
        "user_preferences",
        sa.Column("sleep_pattern", sa.String(), nullable=True),
    )
    op.add_column(
        "user_preferences",
        sa.Column("health_frustration", sa.String(length=120), nullable=True),
    )
    op.add_column(
        "user_preferences",
        sa.Column(
            "profile_catchup_status",
            sa.String(),
            nullable=False,
            server_default="not_shown",
        ),
    )
    op.add_column(
        "user_preferences",
        sa.Column(
            "profile_catchup_dismissed_at",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
    )


def downgrade() -> None:
    op.drop_column("user_preferences", "profile_catchup_dismissed_at")
    op.drop_column("user_preferences", "profile_catchup_status")
    op.drop_column("user_preferences", "health_frustration")
    op.drop_column("user_preferences", "sleep_pattern")
    op.drop_column("user_preferences", "injuries")
    op.drop_column("user_preferences", "dietary_restrictions")
    op.drop_column("user_preferences", "tone")
    op.drop_column("user_preferences", "primary_goal")
    op.drop_column("user_preferences", "focus_area")
