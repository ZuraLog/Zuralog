"""merge_all_heads_round8

Revision ID: 7de9ed24e305
Revises: 360233678afc, a24f71417efe, b3c4d5e6f7a9, z2a3b4c5d6e7
Create Date: 2026-03-25 14:19:10.741240

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '7de9ed24e305'
down_revision: Union[str, Sequence[str], None] = ('360233678afc', 'a24f71417efe', 'b3c4d5e6f7a9', 'z2a3b4c5d6e7')
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    pass


def downgrade() -> None:
    """Downgrade schema."""
    pass
