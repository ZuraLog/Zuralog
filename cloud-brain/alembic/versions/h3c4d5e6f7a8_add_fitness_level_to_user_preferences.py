"""add fitness_level to user_preferences

Revision ID: h3c4d5e6f7a8
Revises: g2b3c4d5e6f7
Create Date: 2026-03-06

Adds the fitness_level column to user_preferences to persist the self-assessed
fitness level selected during onboarding Step 5.

Valid values: 'beginner', 'active', 'athletic'. Nullable — column is empty for
users who skipped Step 5 or onboarded before this migration.
"""

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic
revision = "h3c4d5e6f7a8"
down_revision = "g2b3c4d5e6f7"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "user_preferences",
        sa.Column(
            "fitness_level",
            sa.String(),
            nullable=True,
            comment="beginner | active | athletic — set during onboarding",
        ),
    )


def downgrade() -> None:
    op.drop_column("user_preferences", "fitness_level")
