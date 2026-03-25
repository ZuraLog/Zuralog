"""add_partial_index_conversations_active

Revision ID: a24f71417efe
Revises: y0z1a2b3c4d5
Create Date: 2026-03-25 11:28:34.768379

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'a24f71417efe'
down_revision: Union[str, Sequence[str], None] = 'y0z1a2b3c4d5'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.execute(
        "CREATE INDEX IF NOT EXISTS ix_conversations_active "
        "ON conversations(user_id) WHERE deleted_at IS NULL"
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute("DROP INDEX IF EXISTS ix_conversations_active")
