"""add food_corrections table

Revision ID: b0b1c1d1e1f1
Revises: a0a1b1c1d1e1
Create Date: 2026-04-16
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "b0b1c1d1e1f1"
down_revision: Union[str, Sequence[str], None] = "a0a1b1c1d1e1"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "food_corrections",
        sa.Column("id", sa.dialects.postgresql.UUID(), server_default=sa.text("gen_random_uuid()"), nullable=False),
        sa.Column("user_id", sa.String(), nullable=False),
        sa.Column("food_cache_id", sa.dialects.postgresql.UUID(), nullable=True),
        sa.Column("food_name", sa.String(200), nullable=False),
        sa.Column("original_calories", sa.Numeric(10, 2), nullable=False),
        sa.Column("corrected_calories", sa.Numeric(10, 2), nullable=False),
        sa.Column("original_protein_g", sa.Numeric(10, 2), nullable=False),
        sa.Column("corrected_protein_g", sa.Numeric(10, 2), nullable=False),
        sa.Column("original_carbs_g", sa.Numeric(10, 2), nullable=False),
        sa.Column("corrected_carbs_g", sa.Numeric(10, 2), nullable=False),
        sa.Column("original_fat_g", sa.Numeric(10, 2), nullable=False),
        sa.Column("corrected_fat_g", sa.Numeric(10, 2), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["food_cache_id"], ["food_cache.id"], ondelete="SET NULL"),
    )
    op.create_index("ix_food_corrections_food_name", "food_corrections", ["food_name"])
    op.create_index("ix_food_corrections_user_food", "food_corrections", ["user_id", "food_name"])


def downgrade() -> None:
    op.drop_index("ix_food_corrections_user_food", table_name="food_corrections")
    op.drop_index("ix_food_corrections_food_name", table_name="food_corrections")
    op.drop_table("food_corrections")
