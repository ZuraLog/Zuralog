"""Enable RLS on journal_entries table.

Revision ID: s4t5u6v7w8x9
Revises: r3s4t5u6v7w8
Create Date: 2026-03-18

Security fix: journal_entries had RLS disabled, allowing any authenticated
user to read or modify any other user's journal entries via PostgREST.

Policies created:
  1. service_role_bypass — full access for the backend service role.
  2. journal_entries_select_own — users can read their own rows.
  3. journal_entries_insert_own — users can insert their own rows.
  4. journal_entries_update_own — users can update their own rows.
  No DELETE policy — deletion is handled by service role only.
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "s4t5u6v7w8x9"
down_revision: Union[str, Sequence[str], None] = "r3s4t5u6v7w8"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ------------------------------------------------------------------
    # Step 1: Enable RLS on journal_entries (safe on any Postgres)
    # ------------------------------------------------------------------
    op.execute("ALTER TABLE journal_entries ENABLE ROW LEVEL SECURITY")

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
        # manage journal entries on behalf of users. Without this policy the
        # backend would be blocked by RLS too.
        # ------------------------------------------------------------------
        op.execute("""
            DO $$
            BEGIN
                IF NOT EXISTS (
                    SELECT 1 FROM pg_policies
                    WHERE schemaname = 'public'
                      AND tablename  = 'journal_entries'
                      AND policyname = 'service_role_bypass'
                ) THEN
                    CREATE POLICY service_role_bypass ON journal_entries
                        FOR ALL
                        TO service_role
                        USING (true)
                        WITH CHECK (true);
                END IF;
            END $$
        """)

        # ------------------------------------------------------------------
        # Step 3: SELECT — users can read only their own journal entries
        # ------------------------------------------------------------------
        op.execute("""
            DO $$
            BEGIN
                IF NOT EXISTS (
                    SELECT 1 FROM pg_policies
                    WHERE schemaname = 'public'
                      AND tablename  = 'journal_entries'
                      AND policyname = 'journal_entries_select_own'
                ) THEN
                    CREATE POLICY journal_entries_select_own ON journal_entries
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
                      AND tablename  = 'journal_entries'
                      AND policyname = 'journal_entries_insert_own'
                ) THEN
                    CREATE POLICY journal_entries_insert_own ON journal_entries
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
                      AND tablename  = 'journal_entries'
                      AND policyname = 'journal_entries_update_own'
                ) THEN
                    CREATE POLICY journal_entries_update_own ON journal_entries
                        FOR UPDATE
                        USING (auth.uid()::text = user_id)
                        WITH CHECK (auth.uid()::text = user_id);
                END IF;
            END $$
        """)


def downgrade() -> None:
    op.execute("DROP POLICY IF EXISTS journal_entries_update_own ON journal_entries")
    op.execute("DROP POLICY IF EXISTS journal_entries_insert_own ON journal_entries")
    op.execute("DROP POLICY IF EXISTS journal_entries_select_own ON journal_entries")
    op.execute("DROP POLICY IF EXISTS service_role_bypass ON journal_entries")
    op.execute("ALTER TABLE journal_entries DISABLE ROW LEVEL SECURITY")
