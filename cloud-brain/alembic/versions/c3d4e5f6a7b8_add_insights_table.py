"""add_insights_table

Creates the ``insights`` table for AI-generated daily health insight cards.
Each row is a prioritised card surfaced to the user's dashboard after
health data ingest.

Revision ID: c3d4e5f6a7b8
Revises: f1e2d3c4b5a6
Create Date: 2026-03-04 00:00:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


# revision identifiers, used by Alembic.
revision: str = 'c3d4e5f6a7b8'
down_revision: Union[str, Sequence[str], None] = 'f1e2d3c4b5a6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # No-op: insights is created idempotently by g2b3c4d5e6f7.
    # This orphaned branch was superseded before being merged.
    pass


def downgrade() -> None:
    pass
