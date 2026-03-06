"""add archived and deleted_at to conversations

Revision ID: i4d5e6f7a8b9
Revises: h3c4d5e6f7a8
Create Date: 2026-03-06

Adds soft-delete and archive support to the conversations table:
- archived (Boolean, default false) — hides conversation from default list
- deleted_at (DateTime, nullable) — soft-delete timestamp
"""

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic
revision = "i4d5e6f7a8b9"
down_revision = "h3c4d5e6f7a8"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "conversations",
        sa.Column(
            "archived",
            sa.Boolean(),
            nullable=False,
            server_default="false",
            comment="True when the user has archived this conversation",
        ),
    )
    op.add_column(
        "conversations",
        sa.Column(
            "deleted_at",
            sa.DateTime(timezone=True),
            nullable=True,
            comment="Soft-delete timestamp; non-null means deleted",
        ),
    )


def downgrade() -> None:
    op.drop_column("conversations", "deleted_at")
    op.drop_column("conversations", "archived")
