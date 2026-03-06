"""add attachments jsonb column to messages

Adds an optional JSONB `attachments` column to the messages table
for storing file attachment metadata (images, voice notes).

Revision ID: b3c4d5e6f7a8
Revises: a1b2c3d4e5f6
Create Date: 2026-02-28 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import JSONB

# revision identifiers, used by Alembic.
revision: str = "b3c4d5e6f7a8"
down_revision: Union[str, None] = "a1b2c3d4e5f6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Use IF NOT EXISTS to be idempotent — the column may already exist in the DB.
    op.execute(
        "ALTER TABLE messages ADD COLUMN IF NOT EXISTS attachments JSONB"
    )


def downgrade() -> None:
    op.drop_column("messages", "attachments")
