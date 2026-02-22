"""fix_users_schema

Revision ID: 191778be138d
Revises: 1dce1fca3cc9
Create Date: 2026-02-22 16:45:13.786862

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '191778be138d'
down_revision: Union[str, Sequence[str], None] = '1dce1fca3cc9'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Replace is_premium boolean with subscription_tier string and add new columns."""
    op.drop_column("users", "is_premium")
    op.add_column("users", sa.Column("subscription_tier", sa.String(), nullable=False, server_default="free"))
    op.add_column("users", sa.Column("subscription_expires_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("users", sa.Column("revenuecat_customer_id", sa.String(), nullable=True))
    op.create_index(op.f("ix_users_revenuecat_customer_id"), "users", ["revenuecat_customer_id"], unique=False)


def downgrade() -> None:
    """Revert to is_premium boolean."""
    op.drop_index(op.f("ix_users_revenuecat_customer_id"), table_name="users")
    op.drop_column("users", "revenuecat_customer_id")
    op.drop_column("users", "subscription_expires_at")
    op.drop_column("users", "subscription_tier")
    op.add_column("users", sa.Column("is_premium", sa.Boolean(), nullable=False, server_default="false"))
