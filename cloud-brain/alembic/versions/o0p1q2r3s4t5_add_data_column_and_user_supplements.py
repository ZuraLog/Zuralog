"""Add data JSONB column, composite indexes, user_supplements, and RLS.

DB subagent recommendations:
- Single JSONB data column on quick_logs (not child tables)
- Composite indexes: (user_id, logged_at DESC) and (user_id, metric_type, logged_at DESC)
- New user_supplements table with soft-delete (is_active) and sort_order
- CRITICAL FIX: Enable RLS on quick_logs (was never enabled — security gap)
- Enable RLS on user_supplements

Revision ID: o0p1q2r3s4t5
Revises: n9i0j1k2l3m4
Create Date: 2026-03-16
"""

from typing import Sequence, Union
import sqlalchemy as sa
from alembic import op

revision: str = "o0p1q2r3s4t5"
down_revision: Union[str, Sequence[str], None] = "n9i0j1k2l3m4"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Add JSONB data column to quick_logs
    #    PostgreSQL 11+: no table rewrite, brief catalog lock only.
    op.execute("""
        ALTER TABLE quick_logs
            ADD COLUMN IF NOT EXISTS data JSONB NOT NULL DEFAULT '{}'
    """)

    # 2. Add missing updated_at column to quick_logs
    op.execute("""
        ALTER TABLE quick_logs
            ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE
    """)

    # 3. Replace single-column indexes with composite indexes
    op.execute("DROP INDEX IF EXISTS ix_quick_logs_user_id")
    op.execute("DROP INDEX IF EXISTS ix_quick_logs_logged_at")

    op.execute("""
        CREATE INDEX IF NOT EXISTS ix_quick_logs_user_logged
            ON quick_logs (user_id, logged_at DESC)
    """)
    op.execute("""
        CREATE INDEX IF NOT EXISTS ix_quick_logs_user_type_logged
            ON quick_logs (user_id, metric_type, logged_at DESC)
    """)

    # 4. Create user_supplements table
    op.create_table(
        "user_supplements",
        sa.Column("id", sa.String(), nullable=False),
        sa.Column("user_id", sa.String(), nullable=False),
        sa.Column("name", sa.String(200), nullable=False),
        sa.Column("dose", sa.String(100), nullable=True),
        sa.Column("timing", sa.String(50), nullable=True),
        sa.Column(
            "sort_order",
            sa.SmallInteger(),
            nullable=False,
            server_default="0",
        ),
        sa.Column(
            "is_active",
            sa.Boolean(),
            nullable=False,
            server_default="true",
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_user_supplements_user_id",
        "user_supplements",
        ["user_id"],
    )

    # 5. Enable RLS on quick_logs (CRITICAL — was never enabled)
    op.execute("ALTER TABLE quick_logs ENABLE ROW LEVEL SECURITY")

    # 6. Enable RLS on user_supplements
    op.execute("ALTER TABLE user_supplements ENABLE ROW LEVEL SECURITY")

    # 7. RLS policies — only created if auth schema exists (Supabase).
    #    Plain Postgres test environments skip policy creation.
    op.execute("""
        DO $$ BEGIN
            IF EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'auth') THEN

                IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'quick_logs' AND policyname = 'quick_logs_select_own') THEN
                    EXECUTE 'CREATE POLICY quick_logs_select_own ON quick_logs FOR SELECT USING (auth.uid()::text = user_id)';
                END IF;

                IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'quick_logs' AND policyname = 'quick_logs_insert_own') THEN
                    EXECUTE 'CREATE POLICY quick_logs_insert_own ON quick_logs FOR INSERT WITH CHECK (auth.uid()::text = user_id)';
                END IF;

                IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'quick_logs' AND policyname = 'quick_logs_update_own') THEN
                    EXECUTE 'CREATE POLICY quick_logs_update_own ON quick_logs FOR UPDATE USING (auth.uid()::text = user_id) WITH CHECK (auth.uid()::text = user_id)';
                END IF;

                IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'quick_logs' AND policyname = 'quick_logs_delete_own') THEN
                    EXECUTE 'CREATE POLICY quick_logs_delete_own ON quick_logs FOR DELETE USING (auth.uid()::text = user_id)';
                END IF;

                IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'quick_logs' AND policyname = 'quick_logs_service_role_all') THEN
                    EXECUTE 'CREATE POLICY quick_logs_service_role_all ON quick_logs FOR ALL TO service_role USING (true) WITH CHECK (true)';
                END IF;

                IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'user_supplements' AND policyname = 'user_supplements_select_own') THEN
                    EXECUTE 'CREATE POLICY user_supplements_select_own ON user_supplements FOR SELECT USING (auth.uid()::text = user_id)';
                END IF;

                IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'user_supplements' AND policyname = 'user_supplements_insert_own') THEN
                    EXECUTE 'CREATE POLICY user_supplements_insert_own ON user_supplements FOR INSERT WITH CHECK (auth.uid()::text = user_id)';
                END IF;

                IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'user_supplements' AND policyname = 'user_supplements_update_own') THEN
                    EXECUTE 'CREATE POLICY user_supplements_update_own ON user_supplements FOR UPDATE USING (auth.uid()::text = user_id) WITH CHECK (auth.uid()::text = user_id)';
                END IF;

                IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'user_supplements' AND policyname = 'user_supplements_delete_own') THEN
                    EXECUTE 'CREATE POLICY user_supplements_delete_own ON user_supplements FOR DELETE USING (auth.uid()::text = user_id)';
                END IF;

                IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'user_supplements' AND policyname = 'user_supplements_service_role_all') THEN
                    EXECUTE 'CREATE POLICY user_supplements_service_role_all ON user_supplements FOR ALL TO service_role USING (true) WITH CHECK (true)';
                END IF;

            END IF;
        END $$
    """)


def downgrade() -> None:
    op.execute("DROP POLICY IF EXISTS user_supplements_service_role_all ON user_supplements")
    op.execute("DROP POLICY IF EXISTS user_supplements_delete_own ON user_supplements")
    op.execute("DROP POLICY IF EXISTS user_supplements_update_own ON user_supplements")
    op.execute("DROP POLICY IF EXISTS user_supplements_insert_own ON user_supplements")
    op.execute("DROP POLICY IF EXISTS user_supplements_select_own ON user_supplements")

    op.execute("DROP POLICY IF EXISTS quick_logs_service_role_all ON quick_logs")
    op.execute("DROP POLICY IF EXISTS quick_logs_delete_own ON quick_logs")
    op.execute("DROP POLICY IF EXISTS quick_logs_update_own ON quick_logs")
    op.execute("DROP POLICY IF EXISTS quick_logs_insert_own ON quick_logs")
    op.execute("DROP POLICY IF EXISTS quick_logs_select_own ON quick_logs")

    op.execute("ALTER TABLE user_supplements DISABLE ROW LEVEL SECURITY")
    op.execute("ALTER TABLE quick_logs DISABLE ROW LEVEL SECURITY")

    op.drop_table("user_supplements")

    op.execute("DROP INDEX IF EXISTS ix_quick_logs_user_type_logged")
    op.execute("DROP INDEX IF EXISTS ix_quick_logs_user_logged")
    op.execute("CREATE INDEX ix_quick_logs_user_id ON quick_logs (user_id)")
    op.execute("CREATE INDEX ix_quick_logs_logged_at ON quick_logs (logged_at)")

    op.execute("ALTER TABLE quick_logs DROP COLUMN IF EXISTS updated_at")
    op.execute("ALTER TABLE quick_logs DROP COLUMN IF EXISTS data")
