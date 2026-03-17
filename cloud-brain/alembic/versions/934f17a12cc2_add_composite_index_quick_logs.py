"""add_composite_index_quick_logs

Revision ID: 934f17a12cc2
Revises: o0p1q2r3s4t5
Create Date: 2026-03-17 11:16:09.940533

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


# revision identifiers, used by Alembic.
revision: str = "934f17a12cc2"
down_revision: Union[str, Sequence[str], None] = "o0p1q2r3s4t5"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Composite index for snapshot/ring queries: filter by user, type, date.
    # if_not_exists=True makes this safe to re-run (e.g. if applied manually before).
    op.create_index(
        "ix_quick_logs_user_type_logged_at",
        "quick_logs",
        ["user_id", "metric_type", "logged_at"],
        unique=False,
        if_not_exists=True,
    )


def downgrade() -> None:
    op.drop_index(
        "ix_quick_logs_user_type_logged_at",
        table_name="quick_logs",
        if_exists=True,
    )
