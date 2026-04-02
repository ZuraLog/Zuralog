"""add_model_tier_to_usage_logs

Revision ID: 521365e98be1
Revises: c4d5e6f7a8b9
Create Date: 2026-04-02 15:02:01.438868

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "521365e98be1"
down_revision: Union[str, None] = "c4d5e6f7a8b9"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("usage_logs", sa.Column("model_tier", sa.String(), nullable=True))


def downgrade() -> None:
    op.drop_column("usage_logs", "model_tier")
