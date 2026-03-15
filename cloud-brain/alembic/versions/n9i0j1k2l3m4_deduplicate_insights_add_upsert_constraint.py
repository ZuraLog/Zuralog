"""Deduplicate insights table and add unique upsert constraint.

Revision ID: n9i0j1k2l3m4
Revises: m8h9i0j1k2l3
Create Date: 2026-03-14

Fixes the duplicate-insight bug by:
  1. Adding an updated_at column so upserts can record when a card was refreshed.
  2. Deleting existing duplicate rows (keeps the newest per user/type/day).
  3. Adding a UNIQUE INDEX on (user_id, type, created_at::date) so future
     upserts via ON CONFLICT DO UPDATE are possible and duplicates are
     structurally impossible.
  4. Enabling Row Level Security and adding per-user SELECT/UPDATE policies
     (conditional on the auth schema existing — safe for both Supabase and
     plain Postgres test environments).
"""

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision = "n9i0j1k2l3m4"
down_revision = "m8h9i0j1k2l3"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # ------------------------------------------------------------------
    # Step 1: Add updated_at column (idempotent — already exists in prod)
    # ------------------------------------------------------------------
    op.execute("""
        ALTER TABLE insights
            ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE
    """)

    # ------------------------------------------------------------------
    # Step 2: Delete existing duplicate rows (keep newest per user/type/day)
    # Idempotent: deleting 0 rows is fine if no duplicates exist.
    # ------------------------------------------------------------------
    op.execute("""
        DELETE FROM insights
        WHERE id IN (
            SELECT id
            FROM (
                SELECT
                    id,
                    ROW_NUMBER() OVER (
                        PARTITION BY user_id, type, DATE(created_at)
                        ORDER BY created_at DESC
                    ) AS rn
                FROM insights
            ) ranked
            WHERE rn > 1
        )
    """)

    # ------------------------------------------------------------------
    # Step 3: Ensure unique constraint on (user_id, type, date).
    # Production already has uq_insights_user_type_date (applied via Supabase MCP).
    # This step is a no-op if either constraint already exists.
    # ------------------------------------------------------------------
    op.execute("""
        DO $$
        BEGIN
            -- Add date column if missing (may already exist in prod)
            IF NOT EXISTS (
                SELECT 1 FROM information_schema.columns
                WHERE table_name = 'insights' AND column_name = 'date'
            ) THEN
                ALTER TABLE insights ADD COLUMN date DATE;
                UPDATE insights SET date = DATE(created_at);
            END IF;

            -- Add constraint only if neither variant already exists
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

    # ------------------------------------------------------------------
    # Step 4: Enable RLS and add per-user policies (idempotent)
    # ------------------------------------------------------------------
    op.execute("ALTER TABLE insights ENABLE ROW LEVEL SECURITY")
    op.execute("""
        DO $$ BEGIN
            IF EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'auth') THEN
                IF NOT EXISTS (
                    SELECT 1 FROM pg_policies
                    WHERE tablename = 'insights' AND policyname = 'insights_service_role_all'
                ) THEN
                    EXECUTE '
                        CREATE POLICY insights_service_role_all ON insights
                            FOR ALL TO service_role
                            USING (true) WITH CHECK (true)
                    ';
                END IF;
                IF NOT EXISTS (
                    SELECT 1 FROM pg_policies
                    WHERE tablename = 'insights' AND policyname = 'insights_select_own'
                ) THEN
                    EXECUTE '
                        CREATE POLICY insights_select_own ON insights
                            FOR SELECT USING (auth.uid()::text = user_id)
                    ';
                END IF;
                IF NOT EXISTS (
                    SELECT 1 FROM pg_policies
                    WHERE tablename = 'insights' AND policyname = 'insights_update_own'
                ) THEN
                    EXECUTE '
                        CREATE POLICY insights_update_own ON insights
                            FOR UPDATE
                            USING (auth.uid()::text = user_id)
                            WITH CHECK (auth.uid()::text = user_id)
                    ';
                END IF;
            END IF;
        END $$
    """)


def downgrade() -> None:
    op.execute("DROP POLICY IF EXISTS insights_service_role_all ON insights")
    op.execute("DROP POLICY IF EXISTS insights_select_own ON insights")
    op.execute("DROP POLICY IF EXISTS insights_update_own ON insights")
    op.execute("ALTER TABLE insights DISABLE ROW LEVEL SECURITY")
    op.execute("ALTER TABLE insights DROP CONSTRAINT IF EXISTS uq_insights_user_type_date")
    op.execute("ALTER TABLE insights DROP CONSTRAINT IF EXISTS uq_insights_user_type_day")
    op.execute("ALTER TABLE insights DROP COLUMN IF EXISTS date")
    op.execute("ALTER TABLE insights DROP COLUMN IF EXISTS updated_at")
