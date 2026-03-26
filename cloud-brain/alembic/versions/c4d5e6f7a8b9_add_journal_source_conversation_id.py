"""Add source and conversation_id to journal_entries."""

from alembic import op  # type: ignore[reportAttributeAccessIssue]

revision = "c4d5e6f7a8b9"
down_revision = "b5c6d7e8f9a0"
branch_labels = None
depends_on = None


def upgrade():
    op.execute(
        "ALTER TABLE journal_entries "
        "ADD COLUMN IF NOT EXISTS source VARCHAR(20) NOT NULL DEFAULT 'diary'"
    )
    op.execute(
        "ALTER TABLE journal_entries "
        "ADD COLUMN IF NOT EXISTS conversation_id VARCHAR(64)"
    )
    op.execute(
        "CREATE INDEX IF NOT EXISTS ix_journal_entries_conversation_id "
        "ON journal_entries (conversation_id)"
    )


def downgrade():
    op.execute("DROP INDEX IF EXISTS ix_journal_entries_conversation_id")
    op.execute("ALTER TABLE journal_entries DROP COLUMN IF EXISTS conversation_id")
    op.execute("ALTER TABLE journal_entries DROP COLUMN IF EXISTS source")
