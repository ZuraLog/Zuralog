"""Add muscle_logs table.

Revision ID: ab1234567890
Revises: b1c2d3e4f5a6
Create Date: 2026-04-24
"""
from alembic import op
import sqlalchemy as sa

revision = "ab1234567890"
down_revision = "b1c2d3e4f5a6"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "muscle_logs",
        sa.Column("id", sa.String(36), nullable=False),
        sa.Column("user_id", sa.String(255), nullable=False),
        sa.Column("log_date", sa.Date(), nullable=False),
        sa.Column("muscle_group", sa.String(50), nullable=False),
        sa.Column("state", sa.String(20), nullable=False),
        sa.Column("logged_at_time", sa.Time(), nullable=False),
        sa.Column(
            "created_at",
            sa.TIMESTAMP(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column(
            "updated_at",
            sa.TIMESTAMP(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.UniqueConstraint(
            "user_id", "log_date", "muscle_group",
            name="uq_muscle_logs_user_date_muscle",
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_muscle_logs_user_date", "muscle_logs", ["user_id", "log_date"])


def downgrade() -> None:
    op.drop_index("ix_muscle_logs_user_date", table_name="muscle_logs")
    op.drop_table("muscle_logs")
