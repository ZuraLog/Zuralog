"""fix_users_schema

Revision ID: 191778be138d
Revises: 1dce1fca3cc9
Create Date: 2026-02-22 16:45:13.786862

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "191778be138d"
down_revision: Union[str, Sequence[str], None] = "1dce1fca3cc9"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """No-op: all columns (subscription_tier, subscription_expires_at, revenuecat_customer_id)
    were already created in the initial_tables migration (1dce1fca3cc9). This migration was
    written against an older version of the schema and is now redundant."""
    pass


def downgrade() -> None:
    """No-op: nothing to revert."""
    pass
