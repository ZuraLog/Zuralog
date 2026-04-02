"""Drop one-entry-per-day unique constraint on journal_entries.

Revision ID: g00d00000002
Revises: f00d00000001
Create Date: 2026-04-02

Users should be able to write multiple journal entries per day.
The unique constraint on (user_id, date) prevented this.
"""
from typing import Sequence, Union

from alembic import op  # noqa: F401


revision: str = "g00d00000002"
down_revision: Union[str, Sequence[str], None] = "f00d00000001"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Drop the unique constraint and index that enforce one entry per day."""
    op.execute("ALTER TABLE journal_entries DROP CONSTRAINT IF EXISTS uq_journal_entries_user_date")
    op.execute("DROP INDEX IF EXISTS ix_journal_entries_user_date")


def downgrade() -> None:
    """Re-add the one-entry-per-day constraint."""
    op.execute("""
        CREATE UNIQUE INDEX IF NOT EXISTS ix_journal_entries_user_date
        ON journal_entries (user_id, date)
    """)
