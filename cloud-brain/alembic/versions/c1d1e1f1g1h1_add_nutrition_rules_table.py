"""add nutrition_rules table

Revision ID: c1d1e1f1g1h1
Revises: 948c36ec6f21
Create Date: 2026-04-17
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "c1d1e1f1g1h1"
down_revision: Union[str, Sequence[str], None] = "948c36ec6f21"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "nutrition_rules",
        sa.Column("id", sa.dialects.postgresql.UUID(), server_default=sa.text("gen_random_uuid()"), nullable=False),
        sa.Column("user_id", sa.String(), nullable=False),
        sa.Column("rule_text", sa.String(500), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
    )
    op.create_index("ix_nutrition_rules_user_id", "nutrition_rules", ["user_id"])


def downgrade() -> None:
    op.drop_index("ix_nutrition_rules_user_id", table_name="nutrition_rules")
    op.drop_table("nutrition_rules")
