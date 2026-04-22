"""Create exercise_entries table for manual exercise calorie tracking.

Revision ID: b2c3d4e5f6a7
Revises: a1b2c3d4e5f6
Create Date: 2026-04-23

Adds a new table to store manually logged exercise burns that offset the daily
calorie budget. Each entry tracks:
  - user_id: Reference to the user who logged the exercise
  - date: The date the exercise was performed
  - activity_name: Name of the activity (e.g., "Morning run")
  - calories_burned: Estimated calories burned
  - source: Always "manual" for now (allows future integration with workout sessions)
  - session_id: Optional link to a workout session for future integration
  - created_at: Timestamp when the entry was created

Indexes on (user_id, date) for efficient queries of a user's exercises on a given day.
"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "b2c3d4e5f6a7"
down_revision = "a1b2c3d4e5f6"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "exercise_entries",
        sa.Column("id", sa.String(36), nullable=False),
        sa.Column("user_id", sa.String(255), nullable=False),
        sa.Column("date", sa.Date(), nullable=False),
        sa.Column("activity_name", sa.String(200), nullable=False),
        sa.Column("calories_burned", sa.Integer(), nullable=False),
        sa.Column("source", sa.String(20), nullable=False, server_default="manual"),
        sa.Column("session_id", sa.String(36), nullable=True),
        sa.Column(
            "created_at",
            sa.TIMESTAMP(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_exercise_entries_user_id", "exercise_entries", ["user_id"], unique=False)
    op.create_index("ix_exercise_entries_date", "exercise_entries", ["date"], unique=False)


def downgrade() -> None:
    op.drop_index("ix_exercise_entries_date", table_name="exercise_entries")
    op.drop_index("ix_exercise_entries_user_id", table_name="exercise_entries")
    op.drop_table("exercise_entries")
