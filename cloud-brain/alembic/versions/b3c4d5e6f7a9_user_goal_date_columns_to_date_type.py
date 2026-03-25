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
    # Use raw SQL to check current column type before altering (idempotent)
    op.execute("""
        DO $$
        BEGIN
            -- Only alter start_date if it is not already a date type
            IF EXISTS (
                SELECT 1 FROM information_schema.columns
                WHERE table_name = 'user_goals' AND column_name = 'start_date'
                AND data_type NOT IN ('date')
            ) THEN
                UPDATE user_goals SET start_date = NULL WHERE start_date = '' OR start_date IS NULL;
                ALTER TABLE user_goals ALTER COLUMN start_date DROP DEFAULT;
                ALTER TABLE user_goals
                    ALTER COLUMN start_date TYPE DATE USING start_date::date;
            END IF;
            -- Only alter deadline if it is not already a date type
            IF EXISTS (
                SELECT 1 FROM information_schema.columns
                WHERE table_name = 'user_goals' AND column_name = 'deadline'
                AND data_type NOT IN ('date')
            ) THEN
                UPDATE user_goals SET deadline = NULL WHERE deadline = '' OR deadline IS NULL;
                ALTER TABLE user_goals ALTER COLUMN deadline DROP DEFAULT;
                ALTER TABLE user_goals
                    ALTER COLUMN deadline TYPE DATE USING deadline::date;
            END IF;
        END $$;
    """)


def downgrade() -> None:
    op.alter_column("user_goals", "start_date", type_=sa.String(), postgresql_using="start_date::text")
    op.alter_column("user_goals", "deadline", type_=sa.String(), nullable=True, postgresql_using="deadline::text")
