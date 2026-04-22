"""Create meal_templates table for saving reusable meal templates.

Revision ID: c3d4e5f6a7b8
Revises: b2c3d4e5f6a7
Create Date: 2026-04-23

Adds a new table to store meal templates — reusable sets of foods that users can
quickly log without entering individual food items each time. Each template tracks:
  - user_id: Reference to the user who created the template
  - name: Display name for the template (e.g., "My breakfast")
  - foods_json: JSON array of food items with nutritional information
  - created_at: Timestamp when the template was created

Indexes on user_id for efficient queries when fetching a user's templates.
"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "c3d4e5f6a7b8"
down_revision = "b2c3d4e5f6a7"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "meal_templates",
        sa.Column("id", sa.String(36), nullable=False),
        sa.Column("user_id", sa.String(255), nullable=False),
        sa.Column("name", sa.String(200), nullable=False),
        sa.Column("foods_json", sa.Text(), nullable=False),
        sa.Column(
            "created_at",
            sa.TIMESTAMP(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_meal_templates_user_id", "meal_templates", ["user_id"], unique=False)


def downgrade() -> None:
    op.drop_index("ix_meal_templates_user_id", table_name="meal_templates")
    op.drop_table("meal_templates")
