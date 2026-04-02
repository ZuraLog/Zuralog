"""add_model_tier_to_usage_logs

Revision ID: 521365e98be1
Revises: c4d5e6f7a8b9
Create Date: 2026-04-02 15:02:01.438868

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "521365e98be1"
down_revision: Union[str, None] = "c4d5e6f7a8b9"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Create the table if it doesn't exist — it was missing from the
    # migration that was supposed to create it.
    op.execute("""
        CREATE TABLE IF NOT EXISTS usage_logs (
            id VARCHAR NOT NULL PRIMARY KEY,
            user_id VARCHAR NOT NULL,
            model VARCHAR NOT NULL DEFAULT '',
            input_tokens INTEGER NOT NULL DEFAULT 0,
            output_tokens INTEGER NOT NULL DEFAULT 0,
            created_at TIMESTAMPTZ NOT NULL DEFAULT now()
        )
    """)
    op.execute("CREATE INDEX IF NOT EXISTS ix_usage_logs_user_id ON usage_logs (user_id)")
    op.add_column("usage_logs", sa.Column("model_tier", sa.String(), nullable=True))


def downgrade() -> None:
    op.drop_column("usage_logs", "model_tier")
