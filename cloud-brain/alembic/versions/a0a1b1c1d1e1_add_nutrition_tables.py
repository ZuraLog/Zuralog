"""add nutrition tables

Phase 2A: Nutrition feature — meals, meal_foods, food_cache,
nutrition_daily_summaries.

Revision ID: a0a1b1c1d1e1
Revises: z2a3b4c5d6e7
Create Date: 2026-04-16

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "a0a1b1c1d1e1"
down_revision: Union[str, Sequence[str], None] = "z2a3b4c5d6e7"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ------------------------------------------------------------------
    # 0. Enable pg_trgm (needed for GIN trigram index on food_cache)
    # ------------------------------------------------------------------
    op.execute("CREATE EXTENSION IF NOT EXISTS pg_trgm")

    # ------------------------------------------------------------------
    # 1. meals
    # ------------------------------------------------------------------
    op.create_table(
        "meals",
        sa.Column("id", sa.dialects.postgresql.UUID(), server_default=sa.text("gen_random_uuid()"), nullable=False),
        sa.Column("user_id", sa.String(), nullable=False),
        sa.Column("meal_type", sa.String(20), nullable=False),
        sa.Column("name", sa.String(200), nullable=True),
        sa.Column("logged_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint("id"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
    )

    # ------------------------------------------------------------------
    # 2. meal_foods
    # ------------------------------------------------------------------
    op.create_table(
        "meal_foods",
        sa.Column("id", sa.dialects.postgresql.UUID(), server_default=sa.text("gen_random_uuid()"), nullable=False),
        sa.Column("meal_id", sa.dialects.postgresql.UUID(), nullable=False),
        sa.Column("food_name", sa.String(200), nullable=False),
        sa.Column("food_database_id", sa.String(100), nullable=True),
        sa.Column("portion_amount", sa.Numeric(10, 2), nullable=False),
        sa.Column("portion_unit", sa.String(20), nullable=False),
        sa.Column("calories", sa.Numeric(10, 2), nullable=False),
        sa.Column("protein_g", sa.Numeric(10, 2), nullable=False),
        sa.Column("carbs_g", sa.Numeric(10, 2), nullable=False),
        sa.Column("fat_g", sa.Numeric(10, 2), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.ForeignKeyConstraint(["meal_id"], ["meals.id"], ondelete="CASCADE"),
    )

    # ------------------------------------------------------------------
    # 3. food_cache
    # ------------------------------------------------------------------
    op.create_table(
        "food_cache",
        sa.Column("id", sa.dialects.postgresql.UUID(), server_default=sa.text("gen_random_uuid()"), nullable=False),
        sa.Column("external_id", sa.String(100), nullable=False, unique=True),
        sa.Column("name", sa.String(200), nullable=False),
        sa.Column("brand", sa.String(200), nullable=True),
        sa.Column("serving_size", sa.Numeric(10, 2), nullable=False),
        sa.Column("serving_unit", sa.String(20), nullable=False),
        sa.Column("calories_per_serving", sa.Numeric(10, 2), nullable=False),
        sa.Column("protein_per_serving", sa.Numeric(10, 2), nullable=False),
        sa.Column("carbs_per_serving", sa.Numeric(10, 2), nullable=False),
        sa.Column("fat_per_serving", sa.Numeric(10, 2), nullable=False),
        sa.Column("metadata", sa.dialects.postgresql.JSONB(), nullable=True),
        sa.Column("fetched_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )

    # ------------------------------------------------------------------
    # 4. nutrition_daily_summaries
    # ------------------------------------------------------------------
    op.create_table(
        "nutrition_daily_summaries",
        sa.Column("id", sa.dialects.postgresql.UUID(), server_default=sa.text("gen_random_uuid()"), nullable=False),
        sa.Column("user_id", sa.String(), nullable=False),
        sa.Column("date", sa.Date(), nullable=False),
        sa.Column("total_calories", sa.Numeric(10, 2), server_default=sa.text("0"), nullable=False),
        sa.Column("total_protein_g", sa.Numeric(10, 2), server_default=sa.text("0"), nullable=False),
        sa.Column("total_carbs_g", sa.Numeric(10, 2), server_default=sa.text("0"), nullable=False),
        sa.Column("total_fat_g", sa.Numeric(10, 2), server_default=sa.text("0"), nullable=False),
        sa.Column("meal_count", sa.Integer(), server_default=sa.text("0"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
    )

    # ------------------------------------------------------------------
    # 5. Indexes
    # ------------------------------------------------------------------

    # meals: composite index on user + logged_at for date-range queries
    op.create_index(
        "ix_meals_user_date",
        "meals",
        ["user_id", "logged_at"],
    )

    # meals: partial index for active (non-deleted) meals per user
    op.create_index(
        "ix_meals_user_active",
        "meals",
        ["user_id"],
        postgresql_where=sa.text("deleted_at IS NULL"),
    )

    # meal_foods: look up foods by meal
    op.create_index(
        "ix_meal_foods_meal_id",
        "meal_foods",
        ["meal_id"],
    )

    # food_cache: GIN trigram index for fuzzy name search
    op.create_index(
        "ix_food_cache_name_gin",
        "food_cache",
        ["name"],
        postgresql_using="gin",
        postgresql_ops={"name": "gin_trgm_ops"},
    )

    # food_cache: index for cache eviction by age
    op.create_index(
        "ix_food_cache_fetched_at",
        "food_cache",
        ["fetched_at"],
    )

    # nutrition_daily_summaries: one summary per user per day
    op.create_index(
        "uix_nutrition_summary_user_date",
        "nutrition_daily_summaries",
        ["user_id", "date"],
        unique=True,
    )


def downgrade() -> None:
    # Drop indexes first (some are automatically dropped with tables, but
    # being explicit keeps the downgrade deterministic).
    op.drop_index("uix_nutrition_summary_user_date", table_name="nutrition_daily_summaries")
    op.drop_index("ix_food_cache_fetched_at", table_name="food_cache")
    op.drop_index("ix_food_cache_name_gin", table_name="food_cache")
    op.drop_index("ix_meal_foods_meal_id", table_name="meal_foods")
    op.drop_index("ix_meals_user_active", table_name="meals")
    op.drop_index("ix_meals_user_date", table_name="meals")

    # Drop tables in reverse dependency order
    op.drop_table("nutrition_daily_summaries")
    op.drop_table("food_cache")
    op.drop_table("meal_foods")
    op.drop_table("meals")
