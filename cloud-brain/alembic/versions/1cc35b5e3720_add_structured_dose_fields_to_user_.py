"""Add structured dose fields to user_supplements.

Revision ID: 1cc35b5e3720
Revises: ab1234567890
Create Date: 2026-04-27
"""
import sqlalchemy as sa
from alembic import op

revision = "1cc35b5e3720"
down_revision = "ab1234567890"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "user_supplements",
        sa.Column("dose_amount", sa.Numeric(8, 2), nullable=True,
                  comment="Numeric dose quantity e.g. 5000"),
    )
    op.add_column(
        "user_supplements",
        sa.Column("dose_unit", sa.String(20), nullable=True,
                  comment="Unit of dose e.g. IU, mg, mcg, g, ml"),
    )
    op.add_column(
        "user_supplements",
        sa.Column("form", sa.String(20), nullable=True,
                  comment="Physical form e.g. capsule, softgel, tablet"),
    )


def downgrade() -> None:
    op.drop_column("user_supplements", "form")
    op.drop_column("user_supplements", "dose_unit")
    op.drop_column("user_supplements", "dose_amount")
