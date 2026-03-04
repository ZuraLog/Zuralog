"""add_notification_logs_and_reports

Creates the notification_logs and reports tables introduced in Phase 2.
- notification_logs: persisted push notification feed with read/unread state.
- reports: generated weekly and monthly health reports (one row per user/period).

Revision ID: f1a2b3c4d5e7
Revises: e1a2b3c4d5e6
Create Date: 2026-03-04 00:00:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "f1a2b3c4d5e7"
down_revision: Union[str, Sequence[str], None] = "e1a2b3c4d5e6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Create notification_logs and reports tables."""

    # ------------------------------------------------------------------
    # notification_logs
    # ------------------------------------------------------------------
    op.create_table(
        "notification_logs",
        sa.Column("id", sa.String(), nullable=False),
        sa.Column(
            "user_id",
            sa.String(),
            nullable=False,
            comment="Supabase Auth user UID — not a FK by design",
        ),
        sa.Column("title", sa.String(), nullable=False),
        sa.Column("body", sa.Text(), nullable=False),
        sa.Column(
            "type",
            sa.String(),
            nullable=False,
            comment="NotificationType enum value stored as string",
        ),
        sa.Column(
            "deep_link",
            sa.String(),
            nullable=True,
            comment="URI for client-side tap navigation, e.g. zuralog://insight/abc123",
        ),
        sa.Column(
            "sent_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column("read_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_notification_logs_user_id",
        "notification_logs",
        ["user_id"],
    )
    op.create_index(
        "ix_notification_logs_sent_at",
        "notification_logs",
        ["sent_at"],
    )
    op.create_index(
        "ix_notification_logs_user_sent",
        "notification_logs",
        ["user_id", "sent_at"],
    )

    # ------------------------------------------------------------------
    # reports
    # ------------------------------------------------------------------
    op.create_table(
        "reports",
        sa.Column("id", sa.String(), nullable=False),
        sa.Column(
            "user_id",
            sa.String(),
            nullable=False,
            comment="Supabase Auth user UID — not a FK by design",
        ),
        sa.Column(
            "type",
            sa.String(),
            nullable=False,
            comment="ReportType enum value: weekly | monthly",
        ),
        sa.Column(
            "period_start",
            sa.Date(),
            nullable=False,
            comment="First day of the reporting period (inclusive)",
        ),
        sa.Column(
            "period_end",
            sa.Date(),
            nullable=False,
            comment="Last day of the reporting period (inclusive)",
        ),
        sa.Column(
            "data",
            sa.JSON(),
            nullable=False,
            comment="Serialized WeeklyReport or MonthlyReport as JSON",
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "user_id",
            "type",
            "period_start",
            name="uq_report_user_type_period",
        ),
    )
    op.create_index(
        "ix_reports_user_id",
        "reports",
        ["user_id"],
    )


def downgrade() -> None:
    """Drop notification_logs and reports tables."""
    op.drop_index("ix_reports_user_id", table_name="reports")
    op.drop_table("reports")

    op.drop_index("ix_notification_logs_user_sent", table_name="notification_logs")
    op.drop_index("ix_notification_logs_sent_at", table_name="notification_logs")
    op.drop_index("ix_notification_logs_user_id", table_name="notification_logs")
    op.drop_table("notification_logs")
