"""Add fiber_g, sodium_mg, and sugar_g columns to meal_foods table.

Revision ID: 897ba7021291
Revises: aa1b2c3d4e5f, e3f4a5b6c7d8
Create Date: 2026-04-23

Extends the meal_foods table with optional nullable numeric fields to track
additional micronutrients for each food item:
  - fiber_g: Dietary fiber in grams
  - sodium_mg: Sodium in milligrams
  - sugar_g: Total sugar in grams

All columns default to 0 for existing rows.
"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "897ba7021291"
down_revision = ("aa1b2c3d4e5f", "e3f4a5b6c7d8")
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Add three new nullable numeric columns with default value of 0
    op.add_column(
        "meal_foods",
        sa.Column(
            "fiber_g",
            sa.Numeric(10, 2, asdecimal=False),
            nullable=True,
            server_default=sa.text("0"),
        ),
    )
    op.add_column(
        "meal_foods",
        sa.Column(
            "sodium_mg",
            sa.Numeric(10, 2, asdecimal=False),
            nullable=True,
            server_default=sa.text("0"),
        ),
    )
    op.add_column(
        "meal_foods",
        sa.Column(
            "sugar_g",
            sa.Numeric(10, 2, asdecimal=False),
            nullable=True,
            server_default=sa.text("0"),
        ),
    )


def downgrade() -> None:
    # Drop the three columns in reverse order
    op.drop_column("meal_foods", "sugar_g")
    op.drop_column("meal_foods", "sodium_mg")
    op.drop_column("meal_foods", "fiber_g")
