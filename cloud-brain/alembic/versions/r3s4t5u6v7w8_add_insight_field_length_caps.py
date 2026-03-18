"""Add field length caps to insights table.

Revision ID: r3s4t5u6v7w8
Revises: q2r3s4t5u6v7
Create Date: 2026-03-18

Security hardening: constrains insights.title to VARCHAR(200),
insights.body to VARCHAR(2000), and insights.reasoning to VARCHAR(1000)
to prevent oversized LLM output from being stored.
"""

from typing import Sequence, Union

from alembic import op

revision: str = "r3s4t5u6v7w8"
down_revision: Union[str, Sequence[str], None] = "q2r3s4t5u6v7"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Truncate any existing oversized data before adding constraints.
    op.execute("""
        UPDATE insights
        SET title = LEFT(title, 200)
        WHERE LENGTH(title) > 200
    """)
    op.execute("""
        UPDATE insights
        SET body = LEFT(body, 2000)
        WHERE LENGTH(body) > 2000
    """)
    op.execute("""
        UPDATE insights
        SET reasoning = LEFT(reasoning, 1000)
        WHERE reasoning IS NOT NULL AND LENGTH(reasoning) > 1000
    """)

    op.execute("ALTER TABLE insights ALTER COLUMN title TYPE VARCHAR(200)")
    op.execute("ALTER TABLE insights ALTER COLUMN body TYPE VARCHAR(2000)")
    op.execute("ALTER TABLE insights ALTER COLUMN reasoning TYPE VARCHAR(1000)")


def downgrade() -> None:
    op.execute("ALTER TABLE insights ALTER COLUMN title TYPE VARCHAR")
    op.execute("ALTER TABLE insights ALTER COLUMN body TYPE TEXT")
    op.execute("ALTER TABLE insights ALTER COLUMN reasoning TYPE TEXT")
