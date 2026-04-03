"""Add summary columns to conversations and token/summarized columns to messages.

Revision ID: h00d00000003
Revises: g00d00000002
Create Date: 2026-04-03

The episodic memory system (rolling conversation summarisation) needs three
columns on conversations and two on messages that were added to the ORM models
but never migrated. The missing columns cause an immediate 1011 WebSocket
crash on every chat connection.
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op  # type: ignore[attr-defined]


revision: str = "h00d00000003"
down_revision: Union[str, Sequence[str], None] = "g00d00000002"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # --- conversations ---
    op.add_column(
        "conversations",
        sa.Column(
            "summary",
            sa.Text(),
            nullable=True,
            comment="Rolling LLM-generated summary of older messages",
        ),
    )
    op.add_column(
        "conversations",
        sa.Column(
            "summary_updated_at",
            sa.DateTime(timezone=True),
            nullable=True,
            comment="When the summary was last generated",
        ),
    )
    op.add_column(
        "conversations",
        sa.Column(
            "summary_token_count",
            sa.Integer(),
            nullable=False,
            server_default="0",
            comment="Token count of the current summary (for budget tracking)",
        ),
    )

    # --- messages ---
    op.add_column(
        "messages",
        sa.Column(
            "token_count",
            sa.Integer(),
            nullable=True,
            comment="Token count of this message's content (cl100k_base)",
        ),
    )
    op.add_column(
        "messages",
        sa.Column(
            "is_summarized",
            sa.Boolean(),
            nullable=False,
            server_default="false",
            comment="True once this message has been included in a rolling summary",
        ),
    )


def downgrade() -> None:
    op.drop_column("messages", "is_summarized")
    op.drop_column("messages", "token_count")
    op.drop_column("conversations", "summary_token_count")
    op.drop_column("conversations", "summary_updated_at")
    op.drop_column("conversations", "summary")
