"""pre_phase2_enable_rls_on_all_tables

Enable Row Level Security on all user-owned tables and add per-user
isolation policies so that the Supabase service role can still read
every row while authenticated users can only see their own data.

Revision ID: e1a2b3c4d5e6
Revises: c8d60f5c8771
Create Date: 2026-03-04 00:00:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


# revision identifiers, used by Alembic.
revision: str = "e1a2b3c4d5e6"
down_revision: Union[str, Sequence[str], None] = "a1b2c3d4e5f6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

# Tables that carry a direct `user_id` column pointing at users.id.
_USER_ID_TABLES: tuple[str, ...] = (
    "integrations",
    "unified_activities",
    "sleep_records",
    "nutrition_entries",
    "user_goals",
    "user_devices",
    "daily_health_metrics",
    "blood_pressure_records",
    "weight_measurements",
    "conversations",
)


def upgrade() -> None:
    """Enable RLS on all user-owned tables and create isolation policies.

    Each policy uses ``auth.uid()::text`` so that Supabase Auth JWTs are
    compared against the stored string user IDs without a cast failure.

    Policy naming convention: ``{table}_user_isolation``.

    Special cases:
    - ``users`` table: policy compares against ``id`` (not ``user_id``).
    - ``messages`` table: joins via ``conversations`` to resolve the owner.
    """
    # ------------------------------------------------------------------
    # 1. Enable RLS
    # ------------------------------------------------------------------
    _rls_tables = (
        "users",
        "conversations",
        "messages",
        "integrations",
        "unified_activities",
        "sleep_records",
        "nutrition_entries",
        "user_goals",
        "user_devices",
        "daily_health_metrics",
        "blood_pressure_records",
        "weight_measurements",
    )
    for table in _rls_tables:
        op.execute(
            f"DO $$ BEGIN "
            f"IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='{table}') THEN "
            f"EXECUTE 'ALTER TABLE {table} ENABLE ROW LEVEL SECURITY'; "
            f"END IF; END $$"
        )

    # ------------------------------------------------------------------
    # 2–4. RLS policies use auth.uid() which only exists on Supabase.
    #      Skip policy creation on local Postgres (no auth schema).
    # ------------------------------------------------------------------
    _has_auth = op.get_bind().execute(
        sa.text(
            "SELECT EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'auth')"
        )
    ).scalar()

    if _has_auth:
        # 2. users table — PK is `id`, not `user_id`
        op.execute(
            """
            CREATE POLICY users_user_isolation ON users
                USING (auth.uid()::text = id)
                WITH CHECK (auth.uid()::text = id)
            """
        )

        # 3. tables with a direct `user_id` FK → users.id
        for table in _USER_ID_TABLES:
            op.execute(
                f"DO $$ BEGIN "
                f"IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='{table}') THEN "
                f"EXECUTE 'CREATE POLICY {table}_user_isolation ON {table} "
                f"USING (auth.uid()::text = user_id) "
                f"WITH CHECK (auth.uid()::text = user_id)'; "
                f"END IF; END $$"
            )

        # 4. messages table — no direct user_id; resolve via conversations
        op.execute(
            """
            CREATE POLICY messages_user_isolation ON messages
                USING (
                    EXISTS (
                        SELECT 1
                        FROM conversations c
                        WHERE c.id = messages.conversation_id
                          AND auth.uid()::text = c.user_id
                    )
                )
                WITH CHECK (
                    EXISTS (
                        SELECT 1
                        FROM conversations c
                        WHERE c.id = messages.conversation_id
                          AND auth.uid()::text = c.user_id
                    )
                )
            """
        )


def downgrade() -> None:
    """Drop all RLS policies and disable Row Level Security.

    Reverts every ``CREATE POLICY`` issued in ``upgrade``, then disables
    RLS on each table so the schema is back to its pre-Phase-2 state.
    """
    # Drop policies in reverse dependency order.
    op.execute("DROP POLICY IF EXISTS messages_user_isolation ON messages")

    for table in reversed(_USER_ID_TABLES):
        op.execute(f"DROP POLICY IF EXISTS {table}_user_isolation ON {table}")

    op.execute("DROP POLICY IF EXISTS users_user_isolation ON users")

    # Disable RLS.
    _rls_tables = (
        "users",
        "conversations",
        "messages",
        "integrations",
        "unified_activities",
        "sleep_records",
        "nutrition_entries",
        "user_goals",
        "user_devices",
        "daily_health_metrics",
        "blood_pressure_records",
        "weight_measurements",
    )
    for table in _rls_tables:
        op.execute(
            f"DO $$ BEGIN "
            f"IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='{table}') THEN "
            f"EXECUTE 'ALTER TABLE {table} DISABLE ROW LEVEL SECURITY'; "
            f"END IF; END $$"
        )
