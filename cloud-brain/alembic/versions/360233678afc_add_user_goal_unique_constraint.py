"""add_user_goal_unique_constraint

Revision ID: 360233678afc
Revises: ed0cb70e858b
Create Date: 2026-03-25 11:09:30.339067

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '360233678afc'
down_revision: Union[str, Sequence[str], None] = 'z1a2b3c4d5e6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.execute("""
        DO $$
        BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM pg_constraint WHERE conname = 'uq_user_goals_user_metric'
            ) THEN
                ALTER TABLE user_goals
                    ADD CONSTRAINT uq_user_goals_user_metric UNIQUE (user_id, metric);
            END IF;
        END $$;
    """)


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_constraint("uq_user_goals_user_metric", "user_goals", type_="unique")
