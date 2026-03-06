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
    """Create the insights table."""
    op.create_table(
        'insights',
        sa.Column('id', sa.String(), nullable=False),
        sa.Column('user_id', sa.String(), nullable=False),
        sa.Column('type', sa.String(), nullable=False),
        sa.Column('title', sa.String(), nullable=False),
        sa.Column('body', sa.String(), nullable=False),
        sa.Column(
            'data',
            sa.JSON(),
            nullable=False,
            server_default='{}',
            comment='Chart data, source metrics, numeric deltas',
        ),
        sa.Column(
            'reasoning',
            sa.String(),
            nullable=True,
            comment='Optional LLM explanation of why this insight was generated',
        ),
        sa.Column(
            'priority',
            sa.Integer(),
            nullable=False,
            server_default='5',
            comment='1 = highest priority, 10 = lowest',
        ),
        sa.Column(
            'created_at',
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text('now()'),
        ),
        sa.Column(
            'read_at',
            sa.DateTime(timezone=True),
            nullable=True,
            comment='Set when the client sends PATCH action=read',
        ),
        sa.Column(
            'dismissed_at',
            sa.DateTime(timezone=True),
            nullable=True,
            comment='Set when the client sends PATCH action=dismiss',
        ),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index(
        'ix_insights_user_id',
        'insights',
        ['user_id'],
        unique=False,
    )


def downgrade() -> None:
    """Drop the insights table and its index."""
    op.drop_index('ix_insights_user_id', table_name='insights')
    op.drop_table('insights')
