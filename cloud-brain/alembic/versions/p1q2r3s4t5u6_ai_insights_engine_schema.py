"""AI Insights Engine schema changes.

Revision ID: p1q2r3s4t5u6
Revises: o0p1q2r3s4t5
Create Date: 2026-03-18

Changes:
  1. Add generation_date DATE column to insights (user's local timezone date, for date-lock).
  2. Add signal_type VARCHAR(100) column to insights (raw signal type from detector).
  3. Add timezone VARCHAR(50) column to user_preferences (IANA timezone, default UTC).
  4. Backfill generation_date from existing date / created_at columns.
  5. Drop old uq_insights_user_type_day / uq_insights_user_type_date constraint.
  6. Add new unique constraint: (user_id, signal_type, generation_date).
  7. Add composite index on (user_id, generation_date) for date-lock queries.

Migration notes:
  - generation_date is nullable — legacy rows with NULL signal_type won't conflict on the
    new unique constraint (PostgreSQL treats each NULL as distinct in UNIQUE constraints).
  - The old `date` column is preserved for rollback safety. Drop it in a future migration.
  - insight_tasks.py references the old constraint by name; it must be updated in the same
    deployment (handled in Chunk 6).
  - TODO: drop `date` column in next release once new pipeline is confirmed working.
"""

import sqlalchemy as sa
from alembic import op

revision = "p1q2r3s4t5u6"
down_revision = "o0p1q2r3s4t5"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # ------------------------------------------------------------------
    # Step 1: Add generation_date (DATE) to insights
    # ------------------------------------------------------------------
    op.execute("""
        ALTER TABLE insights
            ADD COLUMN IF NOT EXISTS generation_date DATE
    """)

    # ------------------------------------------------------------------
    # Step 2: Add signal_type (VARCHAR(100)) to insights
    # ------------------------------------------------------------------
    op.execute("""
        ALTER TABLE insights
            ADD COLUMN IF NOT EXISTS signal_type VARCHAR(100)
    """)

    # ------------------------------------------------------------------
    # Step 3: Add timezone (VARCHAR(50)) to user_preferences
    # ------------------------------------------------------------------
    op.execute("""
        ALTER TABLE user_preferences
            ADD COLUMN IF NOT EXISTS timezone VARCHAR(50) NOT NULL DEFAULT 'UTC'
    """)

    # ------------------------------------------------------------------
    # Step 4: Backfill generation_date from existing date / created_at
    # This must happen before adding the unique constraint.
    # Rows with NULL generation_date are fine (NULLs are distinct in UNIQUE),
    # but backfilling makes the date-lock logic work for any still-active
    # legacy insight rows.
    # ------------------------------------------------------------------
    op.execute("""
        UPDATE insights
        SET generation_date = COALESCE(date, DATE(created_at AT TIME ZONE 'UTC'))
        WHERE generation_date IS NULL
    """)

    # ------------------------------------------------------------------
    # Step 5: Drop old unique constraints (either name variant)
    # ------------------------------------------------------------------
    op.execute("""
        ALTER TABLE insights DROP CONSTRAINT IF EXISTS uq_insights_user_type_day
    """)
    op.execute("""
        ALTER TABLE insights DROP CONSTRAINT IF EXISTS uq_insights_user_type_date
    """)

    # ------------------------------------------------------------------
    # Step 6: Add new unique constraint on (user_id, signal_type, generation_date)
    # NULLs treated as distinct — legacy rows with NULL signal_type won't conflict.
    # ------------------------------------------------------------------
    op.execute("""
        DO $$
        BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM pg_constraint
                WHERE conrelid = 'public.insights'::regclass
                  AND conname = 'uq_insights_user_signal_date'
                  AND contype = 'u'
            ) THEN
                ALTER TABLE insights
                    ADD CONSTRAINT uq_insights_user_signal_date
                    UNIQUE (user_id, signal_type, generation_date);
            END IF;
        END $$
    """)

    # ------------------------------------------------------------------
    # Step 7: Composite index on (user_id, generation_date) for date-lock queries.
    # The date-lock check runs on every insight generation call:
    #   SELECT COUNT(*) FROM insights WHERE user_id=? AND generation_date=? AND dismissed_at IS NULL
    # At 1M users this index is critical. Using regular CREATE INDEX (not CONCURRENTLY)
    # because the table is pre-launch and has no significant data.
    # FUTURE: use CONCURRENTLY for any new indexes added post-launch.
    # ------------------------------------------------------------------
    op.execute("""
        CREATE INDEX IF NOT EXISTS ix_insights_user_generation_date
            ON insights (user_id, generation_date)
    """)


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS ix_insights_user_generation_date")
    op.execute("""
        ALTER TABLE insights DROP CONSTRAINT IF EXISTS uq_insights_user_signal_date
    """)
    # Re-add old constraint (date column still exists)
    op.execute("""
        DO $$
        BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM pg_constraint
                WHERE conrelid = 'public.insights'::regclass
                  AND conname IN ('uq_insights_user_type_date', 'uq_insights_user_type_day')
                  AND contype = 'u'
            ) THEN
                ALTER TABLE insights
                    ADD CONSTRAINT uq_insights_user_type_date
                    UNIQUE (user_id, type, date);
            END IF;
        END $$
    """)
    op.execute("ALTER TABLE user_preferences DROP COLUMN IF EXISTS timezone")
    op.execute("ALTER TABLE insights DROP COLUMN IF EXISTS signal_type")
    op.execute("ALTER TABLE insights DROP COLUMN IF EXISTS generation_date")
