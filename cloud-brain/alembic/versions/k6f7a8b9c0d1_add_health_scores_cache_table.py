"""add health_scores cache table

Revision ID: k6f7a8b9c0d1
Revises: j5e6f7a8b9c0
Create Date: 2026-03-07 00:00:00.000000
"""

from alembic import op
import sqlalchemy as sa

revision = "k6f7a8b9c0d1"
down_revision = "j5e6f7a8b9c0"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "health_scores",
        sa.Column("id", sa.Integer(), nullable=False, autoincrement=True),
        sa.Column("user_id", sa.String(), nullable=False),
        sa.Column("score_date", sa.String(length=10), nullable=False),
        sa.Column("score", sa.Integer(), nullable=False),
        sa.Column("sub_scores_json", sa.String(), nullable=False, server_default="{}"),
        sa.Column("commentary", sa.String(), nullable=False, server_default=""),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "score_date", name="uq_health_scores_user_date"),
    )
    op.create_index("ix_health_scores_user_date", "health_scores", ["user_id", "score_date"])
    op.create_index(op.f("ix_health_scores_user_id"), "health_scores", ["user_id"])


def downgrade() -> None:
    op.drop_index(op.f("ix_health_scores_user_id"), table_name="health_scores")
    op.drop_index("ix_health_scores_user_date", table_name="health_scores")
    op.drop_table("health_scores")
