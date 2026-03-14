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
    # Step 1: Add updated_at column
    # ------------------------------------------------------------------
    op.add_column(
        "insights",
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=True,
            comment="Set on upsert when an existing insight is refreshed",
        ),
    )

    # ------------------------------------------------------------------
    # Step 2: Delete existing duplicate rows (keep newest per user/type/day)
    # ------------------------------------------------------------------
    op.execute("""
        DELETE FROM insights
        WHERE id IN (
            SELECT id
            FROM (
                SELECT
                    id,
                    ROW_NUMBER() OVER (
                        PARTITION BY user_id, type, created_at::date
                        ORDER BY created_at DESC
                    ) AS rn
                FROM insights
            ) ranked
            WHERE rn > 1
        )
    """)

    # ------------------------------------------------------------------
    # Step 3: Create unique index CONCURRENTLY (must run outside a transaction)
    # ------------------------------------------------------------------
    op.execute("COMMIT")
    op.execute("""
        CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS uq_insights_user_type_day
            ON insights (user_id, type, (created_at::date))
    """)

    # ------------------------------------------------------------------
    # Step 4: Enable RLS and add per-user policies (conditional on auth schema)
    # ------------------------------------------------------------------
    op.execute("ALTER TABLE insights ENABLE ROW LEVEL SECURITY")
    op.execute("""
        DO $$ BEGIN
            IF EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'auth') THEN
                EXECUTE '
                    CREATE POLICY insights_select_own ON insights
                        FOR SELECT
                        USING (auth.uid()::text = user_id)
                ';
                EXECUTE '
                    CREATE POLICY insights_update_own ON insights
                        FOR UPDATE
                        USING (auth.uid()::text = user_id)
                        WITH CHECK (auth.uid()::text = user_id)
                ';
            END IF;
        END $$
    """)


def downgrade() -> None:
    op.execute("DROP POLICY IF EXISTS insights_select_own ON insights")
    op.execute("DROP POLICY IF EXISTS insights_update_own ON insights")
    op.execute("ALTER TABLE insights DISABLE ROW LEVEL SECURITY")
    op.execute("DROP INDEX CONCURRENTLY IF EXISTS uq_insights_user_type_day")
    op.drop_column("insights", "updated_at")
