"""Change UserGoal start_date and deadline from String to Date type.

Revision ID: b3c4d5e6f7a9
Revises: a2b3c4d5e6f7
Create Date: 2026-03-25
"""
import sqlalchemy as sa
from alembic import op

revision = "b3c4d5e6f7a9"
down_revision = "a2b3c4d5e6f7"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Clean empty strings before type change
    op.execute("UPDATE user_goals SET start_date = NULL WHERE start_date = '' OR start_date IS NULL")
    op.execute("UPDATE user_goals SET deadline = NULL WHERE deadline = '' OR deadline IS NULL")
    op.alter_column("user_goals", "start_date", type_=sa.Date(), postgresql_using="start_date::date")
    op.alter_column("user_goals", "deadline", type_=sa.Date(), nullable=True, postgresql_using="deadline::date")


def downgrade() -> None:
    op.alter_column("user_goals", "start_date", type_=sa.String(), postgresql_using="start_date::text")
    op.alter_column("user_goals", "deadline", type_=sa.String(), nullable=True, postgresql_using="deadline::text")
