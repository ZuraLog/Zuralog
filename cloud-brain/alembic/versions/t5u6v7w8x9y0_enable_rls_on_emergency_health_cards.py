"""Enable RLS on emergency_health_cards table.

Revision ID: t5u6v7w8x9y0
Revises: s4t5u6v7w8x9
Create Date: 2026-03-18

Security fix: emergency_health_cards had RLS disabled, allowing any authenticated
user to read or modify any other user's emergency health cards via PostgREST.

Policies created:
  1. service_role_bypass — full access for the backend service role.
  2. emergency_health_cards_select_own — users can read their own rows.
  3. emergency_health_cards_insert_own — users can insert their own rows.
  4. emergency_health_cards_update_own — users can update their own rows.
  No DELETE policy — deletion is handled by service role only.
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "t5u6v7w8x9y0"
down_revision: Union[str, Sequence[str], None] = "s4t5u6v7w8x9"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ------------------------------------------------------------------
    # Step 1: Enable RLS on emergency_health_cards (safe on any Postgres)
    # ------------------------------------------------------------------
    op.execute("ALTER TABLE emergency_health_cards ENABLE ROW LEVEL SECURITY")

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
        # manage emergency health cards on behalf of users. Without this
        # policy the backend would be blocked by RLS too.
        # ------------------------------------------------------------------
        op.execute("""
            DO $$
            BEGIN
                IF NOT EXISTS (
                    SELECT 1 FROM pg_policies
                    WHERE schemaname = 'public'
                      AND tablename  = 'emergency_health_cards'
                      AND policyname = 'service_role_bypass'
                ) THEN
                    CREATE POLICY service_role_bypass ON emergency_health_cards
                        FOR ALL
                        TO service_role
                        USING (true)
                        WITH CHECK (true);
                END IF;
            END $$
        """)

        # ------------------------------------------------------------------
        # Step 3: SELECT — users can read only their own emergency health cards
        # ------------------------------------------------------------------
        op.execute("""
            DO $$
            BEGIN
                IF NOT EXISTS (
                    SELECT 1 FROM pg_policies
                    WHERE schemaname = 'public'
                      AND tablename  = 'emergency_health_cards'
                      AND policyname = 'emergency_health_cards_select_own'
                ) THEN
                    CREATE POLICY emergency_health_cards_select_own ON emergency_health_cards
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
                      AND tablename  = 'emergency_health_cards'
                      AND policyname = 'emergency_health_cards_insert_own'
                ) THEN
                    CREATE POLICY emergency_health_cards_insert_own ON emergency_health_cards
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
                      AND tablename  = 'emergency_health_cards'
                      AND policyname = 'emergency_health_cards_update_own'
                ) THEN
                    CREATE POLICY emergency_health_cards_update_own ON emergency_health_cards
                        FOR UPDATE
                        USING (auth.uid()::text = user_id)
                        WITH CHECK (auth.uid()::text = user_id);
                END IF;
            END $$
        """)


def downgrade() -> None:
    op.execute("DROP POLICY IF EXISTS emergency_health_cards_update_own ON emergency_health_cards")
    op.execute("DROP POLICY IF EXISTS emergency_health_cards_insert_own ON emergency_health_cards")
    op.execute("DROP POLICY IF EXISTS emergency_health_cards_select_own ON emergency_health_cards")
    op.execute("DROP POLICY IF EXISTS service_role_bypass ON emergency_health_cards")
    op.execute("ALTER TABLE emergency_health_cards DISABLE ROW LEVEL SECURITY")
