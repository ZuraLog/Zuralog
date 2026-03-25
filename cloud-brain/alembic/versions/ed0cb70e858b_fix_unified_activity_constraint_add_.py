"""fix_unified_activity_constraint_add_user_id

Revision ID: ed0cb70e858b
Revises: y0z1a2b3c4d5
Create Date: 2026-03-25 11:07:12.236958

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'ed0cb70e858b'
down_revision: Union[str, Sequence[str], None] = 'y0z1a2b3c4d5'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.drop_constraint("uq_activity_source_original", "unified_activities", type_="unique")
    op.create_unique_constraint(
        "uq_activity_user_source_original",
        "unified_activities",
        ["user_id", "source", "original_id"],
    )


def downgrade() -> None:
    op.drop_constraint("uq_activity_user_source_original", "unified_activities", type_="unique")
    op.create_unique_constraint(
        "uq_activity_source_original",
        "unified_activities",
        ["source", "original_id"],
    )
