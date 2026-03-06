"""notification_and_reports

Creates tables for the notification centre and report storage:
  - notification_logs  — Persisted push notification history for the in-app
                         notification centre (Task 1 / Phase 2).
  - reports            — Generated weekly/monthly health summary reports
                         (Task 5 / Phase 2).

Revision ID: d4e5f6a7b8c9
Revises: b2c3d4e5f6a7
Create Date: 2026-03-04 00:00:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "d4e5f6a7b8c9"
down_revision: Union[str, Sequence[str], None] = "b2c3d4e5f6a7"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # No-op: notification_logs and reports are created by f1a2b3c4d5e7.
    # This orphaned branch was superseded before being merged.
    return

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
            comment="Supabase UID of the notification recipient",
        ),
        sa.Column(
            "title",
            sa.String(),
            nullable=False,
            comment="Notification title text",
        ),
        sa.Column(
            "body",
            sa.Text(),
            nullable=False,
            comment="Notification body text",
        ),
        sa.Column(
            "type",
            sa.String(),
            nullable=False,
            comment="insight | anomaly | streak | achievement | reminder | briefing | integration_alert",
        ),
        sa.Column(
            "deep_link",
            sa.String(),
            nullable=True,
            comment="URI for in-app tap navigation, e.g. zuralog://insights/abc123",
        ),
        sa.Column(
            "sent_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
            comment="UTC timestamp when the notification was sent",
        ),
        sa.Column(
            "read_at",
            sa.DateTime(timezone=True),
            nullable=True,
            comment="UTC timestamp when the user marked the notification as read",
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_notification_logs_user_id",
        "notification_logs",
        ["user_id"],
        unique=False,
    )
    op.create_index(
        "ix_notification_logs_sent_at",
        "notification_logs",
        ["sent_at"],
        unique=False,
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
            comment="Supabase UID of the report owner",
        ),
        sa.Column(
            "type",
            sa.String(),
            nullable=False,
            comment="weekly | monthly",
        ),
        sa.Column(
            "period_start",
            sa.String(),
            nullable=False,
            comment="ISO date string (YYYY-MM-DD) — inclusive start of the report period",
        ),
        sa.Column(
            "period_end",
            sa.String(),
            nullable=False,
            comment="ISO date string (YYYY-MM-DD) — inclusive end of the report period",
        ),
        sa.Column(
            "data",
            sa.JSON(),
            nullable=False,
            server_default="{}",
            comment="Full report payload — aggregated metrics, highlights, deltas",
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
            comment="UTC timestamp when the report was generated",
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_reports_user_id",
        "reports",
        ["user_id"],
        unique=False,
    )


def downgrade() -> None:
    """Drop notification_logs and reports tables."""
    op.drop_index("ix_reports_user_id", table_name="reports")
    op.drop_table("reports")

    op.drop_index("ix_notification_logs_sent_at", table_name="notification_logs")
    op.drop_index("ix_notification_logs_user_id", table_name="notification_logs")
    op.drop_table("notification_logs")
