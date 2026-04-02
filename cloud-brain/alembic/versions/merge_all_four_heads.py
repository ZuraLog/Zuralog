"""Merge all four heads into a single linear chain.

Revision ID: f00d00000001
Revises: 521365e98be1, 1d8d00104ded, d4e5f6a7b8c9, i4d5e6f7a8b9
Create Date: 2026-04-02

Alembic requires a single head to run `upgrade head`. This merge
migration combines the four divergent branches so Railway deploys
succeed again.
"""
from typing import Sequence, Union

from alembic import op  # noqa: F401


revision: str = "f00d00000001"
down_revision: Union[str, Sequence[str], None] = (
    "521365e98be1",
    "1d8d00104ded",
    "d4e5f6a7b8c9",
    "i4d5e6f7a8b9",
)
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """No-op merge — all schema changes are in the parent branches."""


def downgrade() -> None:
    """No-op merge — nothing to undo."""
