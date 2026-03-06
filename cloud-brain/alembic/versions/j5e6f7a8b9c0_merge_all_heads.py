"""merge all heads into single trunk

Revision ID: j5e6f7a8b9c0
Revises: 1d8d00104ded, i4d5e6f7a8b9, d4e5f6a7b8c9
Create Date: 2026-03-06

No-op merge that unifies three dangling heads into a single trunk:
  - 1d8d00104ded: merge of attachments + phase2 core tables
  - i4d5e6f7a8b9: add archived/deleted_at to conversations
  - d4e5f6a7b8c9: notification_logs and reports (orphaned branch)
"""

from typing import Sequence, Union

from alembic import op

revision: str = "j5e6f7a8b9c0"
down_revision: Union[str, Sequence[str], None] = (
    "1d8d00104ded",
    "i4d5e6f7a8b9",
    "d4e5f6a7b8c9",
)
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass
