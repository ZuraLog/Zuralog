"""add_user_preferences_table

Revision ID: f1e2d3c4b5a6
Revises: a1b2c3d4e5f6
Create Date: 2026-03-04 00:00:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "f1e2d3c4b5a6"
down_revision: Union[str, Sequence[str], None] = "a1b2c3d4e5f6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # No-op: user_preferences is created idempotently by g2b3c4d5e6f7
    # (which uses CREATE TABLE IF NOT EXISTS). This branch was superseded
    # before it was ever merged into the main migration chain.
    pass


def downgrade() -> None:
    pass
