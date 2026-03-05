"""merge_attachments_and_phase2

Revision ID: 1d8d00104ded
Revises: b3c4d5e6f7a8, g2b3c4d5e6f7
Create Date: 2026-03-04 19:52:06.439238

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '1d8d00104ded'
down_revision: Union[str, Sequence[str], None] = ('b3c4d5e6f7a8', 'g2b3c4d5e6f7')
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    pass


def downgrade() -> None:
    """Downgrade schema."""
    pass
