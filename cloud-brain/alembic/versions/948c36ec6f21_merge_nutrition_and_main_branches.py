"""merge_nutrition_and_main_branches

Revision ID: 948c36ec6f21
Revises: b0b1c1d1e1f1, j00d00000005
Create Date: 2026-04-16 21:32:12.822296

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '948c36ec6f21'
down_revision: Union[str, Sequence[str], None] = ('b0b1c1d1e1f1', 'j00d00000005')
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    pass


def downgrade() -> None:
    """Downgrade schema."""
    pass
