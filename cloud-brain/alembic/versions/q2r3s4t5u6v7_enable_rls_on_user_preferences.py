"""Enable RLS on user_preferences table.

Revision ID: q2r3s4t5u6v7
Revises: p1q2r3s4t5u6
Create Date: 2026-03-18

Security fix: user_preferences had RLS disabled, allowing any authenticated
user to read or overwrite any other user's preferences via PostgREST.

Policies created:
  1. service_role_bypass — full access for the backend service role.
  2. user_preferences_select_own — users can read their own row.
  3. user_preferences_insert_own — users can insert their own row.
  4. user_preferences_update_own — users can update their own row.
  No DELETE policy — deletion is handled by cascade or service role only.
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "q2r3s4t5u6v7"
down_revision: Union[str, Sequence[str], None] = "p1q2r3s4t5u6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ------------------------------------------------------------------
    # Step 1: Enable RLS on user_preferences (safe on any Postgres)
    # ------------------------------------------------------------------
    op.execute("ALTER TABLE user_preferences ENABLE ROW LEVEL SECURITY")

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
        # manage preferences on behalf of users. Without this policy the
        # backend would be blocked by RLS too.
        # ------------------------------------------------------------------
        op.execute("""
            DO $$
            BEGIN
                IF NOT EXISTS (
                    SELECT 1 FROM pg_policies
                    WHERE schemaname = 'public'
                      AND tablename  = 'user_preferences'
                      AND policyname = 'service_role_bypass'
                ) THEN
                    CREATE POLICY service_role_bypass ON user_preferences
                        FOR ALL
                        TO service_role
                        USING (true)
                        WITH CHECK (true);
                END IF;
            END $$
        """)

        # ------------------------------------------------------------------
        # Step 3: SELECT — users can read only their own preferences
        # ------------------------------------------------------------------
        op.execute("""
            DO $$
            BEGIN
                IF NOT EXISTS (
                    SELECT 1 FROM pg_policies
                    WHERE schemaname = 'public'
                      AND tablename  = 'user_preferences'
                      AND policyname = 'user_preferences_select_own'
                ) THEN
                    CREATE POLICY user_preferences_select_own ON user_preferences
                        FOR SELECT
                        USING (auth.uid()::text = user_id);
                END IF;
            END $$
        """)

        # ------------------------------------------------------------------
        # Step 4: INSERT — users can insert only their own row
        # ------------------------------------------------------------------
        op.execute("""
            DO $$
            BEGIN
                IF NOT EXISTS (
                    SELECT 1 FROM pg_policies
                    WHERE schemaname = 'public'
                      AND tablename  = 'user_preferences'
                      AND policyname = 'user_preferences_insert_own'
                ) THEN
                    CREATE POLICY user_preferences_insert_own ON user_preferences
                        FOR INSERT
                        WITH CHECK (auth.uid()::text = user_id);
                END IF;
            END $$
        """)

        # ------------------------------------------------------------------
        # Step 5: UPDATE — users can update only their own row
        # ------------------------------------------------------------------
        op.execute("""
            DO $$
            BEGIN
                IF NOT EXISTS (
                    SELECT 1 FROM pg_policies
                    WHERE schemaname = 'public'
                      AND tablename  = 'user_preferences'
                      AND policyname = 'user_preferences_update_own'
                ) THEN
                    CREATE POLICY user_preferences_update_own ON user_preferences
                        FOR UPDATE
                        USING (auth.uid()::text = user_id)
                        WITH CHECK (auth.uid()::text = user_id);
                END IF;
            END $$
        """)


def downgrade() -> None:
    op.execute("DROP POLICY IF EXISTS user_preferences_update_own ON user_preferences")
    op.execute("DROP POLICY IF EXISTS user_preferences_insert_own ON user_preferences")
    op.execute("DROP POLICY IF EXISTS user_preferences_select_own ON user_preferences")
    op.execute("DROP POLICY IF EXISTS service_role_bypass ON user_preferences")
    op.execute("ALTER TABLE user_preferences DISABLE ROW LEVEL SECURITY")
