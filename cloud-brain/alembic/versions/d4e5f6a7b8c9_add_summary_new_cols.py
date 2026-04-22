"""Add fiber/sodium/sugar/exercise_calories to NutritionDailySummary.

Revision ID: d4e5f6a7b8c9
Revises: c3d4e5f6a7b8
Create Date: 2026-04-23

Extends the nutrition_daily_summaries table with four new non-nullable columns
to track additional nutrition metrics for each day:
  - total_fiber_g: Total dietary fiber in grams
  - total_sodium_mg: Total sodium in milligrams
  - total_sugar_g: Total sugar in grams
  - exercise_calories_burned: Total calories burned through exercise

All columns default to 0 for existing rows. Unlike meal_foods columns, these
are NOT nullable because the summary always has values (defaulting to 0).
"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "d4e5f6a7b8c9"
down_revision = "c3d4e5f6a7b8"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Add four new non-nullable numeric/integer columns with default value of 0
    op.add_column(
        "nutrition_daily_summaries",
        sa.Column(
            "total_fiber_g",
            sa.Numeric(10, 2, asdecimal=False),
            nullable=False,
            server_default=sa.text("0"),
        ),
    )
    op.add_column(
        "nutrition_daily_summaries",
        sa.Column(
            "total_sodium_mg",
            sa.Numeric(10, 2, asdecimal=False),
            nullable=False,
            server_default=sa.text("0"),
        ),
    )
    op.add_column(
        "nutrition_daily_summaries",
        sa.Column(
            "total_sugar_g",
            sa.Numeric(10, 2, asdecimal=False),
            nullable=False,
            server_default=sa.text("0"),
        ),
    )
    op.add_column(
        "nutrition_daily_summaries",
        sa.Column(
            "exercise_calories_burned",
            sa.Integer,
            nullable=False,
            server_default=sa.text("0"),
        ),
    )


def downgrade() -> None:
    # Drop the four columns in reverse order
    op.drop_column("nutrition_daily_summaries", "exercise_calories_burned")
    op.drop_column("nutrition_daily_summaries", "total_sugar_g")
    op.drop_column("nutrition_daily_summaries", "total_sodium_mg")
    op.drop_column("nutrition_daily_summaries", "total_fiber_g")
