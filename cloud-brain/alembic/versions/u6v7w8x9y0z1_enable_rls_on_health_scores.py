"""Enable RLS on health_scores table.

Revision ID: u6v7w8x9y0z1
Revises: t5u6v7w8x9y0
Create Date: 2026-03-18

Security fix: health_scores had RLS disabled, allowing any authenticated
user to read or modify any other user's health scores via PostgREST.

Policies created:
  1. service_role_bypass — full access for the backend service role.
  2. health_scores_select_own — users can read their own rows.
  3. health_scores_insert_own — users can insert their own rows.
  4. health_scores_update_own — users can update their own rows.
  No DELETE policy — deletion is handled by service role only.
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "u6v7w8x9y0z1"
down_revision: Union[str, Sequence[str], None] = "t5u6v7w8x9y0"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ------------------------------------------------------------------
    # Step 1: Enable RLS on health_scores (safe on any Postgres)
    # ------------------------------------------------------------------
    op.execute("ALTER TABLE health_scores ENABLE ROW LEVEL SECURITY")

    # ------------------------------------------------------------------
    # Steps 2-5: Create policies — only when the auth schema is present.
    # On plain Postgres (no Supabase), auth.uid() doesn't exist and the
    # CREATE POLICY calls would fail. The guard makes the migration safe
    # to run in any environment.
    # ------------------------------------------------------------------
    _has_auth = (
        op.get_bind().execute(sa.text("SELECT EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'auth')")).scalar()
    )

    if _has_auth:
        # ------------------------------------------------------------------
        # Step 2: Service-role bypass — the backend uses service_role to
        # manage health scores on behalf of users. Without this policy the
        # backend would be blocked by RLS too.
        # ------------------------------------------------------------------
        op.execute("""
            DO $$
            BEGIN
                IF NOT EXISTS (
                    SELECT 1 FROM pg_policies
                    WHERE schemaname = 'public'
                      AND tablename  = 'health_scores'
                      AND policyname = 'service_role_bypass'
                ) THEN
                    CREATE POLICY service_role_bypass ON health_scores
                        FOR ALL
                        TO service_role
                        USING (true)
                        WITH CHECK (true);
                END IF;
            END $$
        """)

        # ------------------------------------------------------------------
        # Step 3: SELECT — users can read only their own health scores
        # ------------------------------------------------------------------
        op.execute("""
            DO $$
            BEGIN
                IF NOT EXISTS (
                    SELECT 1 FROM pg_policies
                    WHERE schemaname = 'public'
                      AND tablename  = 'health_scores'
                      AND policyname = 'health_scores_select_own'
                ) THEN
                    CREATE POLICY health_scores_select_own ON health_scores
                        FOR SELECT
                        USING (auth.uid()::text = user_id);
                END IF;
            END $$
        """)

        # ------------------------------------------------------------------
        # Step 4: INSERT — users can insert only their own rows
        # ------------------------------------------------------------------
        op.execute("""
            DO $$
            BEGIN
                IF NOT EXISTS (
                    SELECT 1 FROM pg_policies
                    WHERE schemaname = 'public'
                      AND tablename  = 'health_scores'
                      AND policyname = 'health_scores_insert_own'
                ) THEN
                    CREATE POLICY health_scores_insert_own ON health_scores
                        FOR INSERT
                        WITH CHECK (auth.uid()::text = user_id);
                END IF;
            END $$
        """)

        # ------------------------------------------------------------------
        # Step 5: UPDATE — users can update only their own rows
        # ------------------------------------------------------------------
        op.execute("""
            DO $$
            BEGIN
                IF NOT EXISTS (
                    SELECT 1 FROM pg_policies
                    WHERE schemaname = 'public'
                      AND tablename  = 'health_scores'
                      AND policyname = 'health_scores_update_own'
                ) THEN
                    CREATE POLICY health_scores_update_own ON health_scores
                        FOR UPDATE
                        USING (auth.uid()::text = user_id)
                        WITH CHECK (auth.uid()::text = user_id);
                END IF;
            END $$
        """)


def downgrade() -> None:
    op.execute("DROP POLICY IF EXISTS health_scores_update_own ON health_scores")
    op.execute("DROP POLICY IF EXISTS health_scores_insert_own ON health_scores")
    op.execute("DROP POLICY IF EXISTS health_scores_select_own ON health_scores")
    op.execute("DROP POLICY IF EXISTS service_role_bypass ON health_scores")
    op.execute("ALTER TABLE health_scores DISABLE ROW LEVEL SECURITY")
