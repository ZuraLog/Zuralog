"""Create user_memories table and rename walking_speed to walking_speed_mps.

Revision ID: i00d00000004
Revises: h00d00000003
Create Date: 2026-04-03

Two unrelated fixes bundled into one migration to keep the chain linear:

1. user_memories — the pgvector-backed long-term memory store used by the
   AI coach. The table is queried via raw SQL in pgvector_memory_store.py
   and was never created, causing UndefinedTableError on every memory
   read/write operation.

2. walking_speed → walking_speed_mps — the ORM model uses walking_speed_mps
   but the DB column was created as walking_speed. SQLAlchemy generates
   SELECT / INSERT using the model attribute name, so every Apple Health
   metrics query crashed with UndefinedColumnError.
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op  # type: ignore[attr-defined]


revision: str = "i00d00000004"
down_revision: Union[str, Sequence[str], None] = "h00d00000003"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Enable pgvector (idempotent — safe to run on already-enabled DBs).
    op.execute("CREATE EXTENSION IF NOT EXISTS vector")

    # 2. Create user_memories with a 1536-dim vector column (text-embedding-3-small).
    op.create_table(
        "user_memories",
        sa.Column("id", sa.String(), nullable=False),
        sa.Column("user_id", sa.String(), nullable=False),
        sa.Column("content", sa.Text(), nullable=False),
        sa.Column("category", sa.String(), nullable=False),
        sa.Column(
            "embedding",
            sa.Text(),  # stored as text; pgvector casts on INSERT/SELECT
            nullable=True,
            comment="1536-dim vector embedding (text-embedding-3-small)",
        ),
        sa.Column("source_conversation_id", sa.String(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("id"),
    )

    # Change embedding column type to vector(1536) now that the extension exists.
    op.execute(
        "ALTER TABLE user_memories ALTER COLUMN embedding TYPE vector(1536) "
        "USING embedding::vector(1536)"
    )

    op.create_index("ix_user_memories_user_id", "user_memories", ["user_id"])

    # 3. Rename walking_speed → walking_speed_mps to match the ORM model.
    # Conditional: the daily_health_metrics table is dropped in a later
    # migration (v7w8x9y0z1a2). On DBs that skipped directly to the
    # post-drop state, the table/column no longer exists and this rename
    # becomes a no-op.
    op.execute("""
        DO $$ BEGIN
            IF EXISTS (
                SELECT 1 FROM information_schema.columns
                WHERE table_name = 'daily_health_metrics'
                  AND column_name = 'walking_speed'
            ) THEN
                ALTER TABLE daily_health_metrics
                    RENAME COLUMN walking_speed TO walking_speed_mps;
            END IF;
        END $$;
    """)


def downgrade() -> None:
    op.alter_column(
        "daily_health_metrics",
        "walking_speed_mps",
        new_column_name="walking_speed",
    )
    op.drop_index("ix_user_memories_user_id", table_name="user_memories")
    op.drop_table("user_memories")
    op.execute("DROP EXTENSION IF EXISTS vector")
