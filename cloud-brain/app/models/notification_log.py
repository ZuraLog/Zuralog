"""Notification log model — persisted push notification history.

Each row represents a push notification that was sent to a user.
Records are used to power the in-app notification centre (``GET /notifications``)
and to support read-state tracking.

Types:
    insight             — AI-generated health insight card notification.
    anomaly             — Unusual data point alert.
    streak              — Streak milestone or at-risk warning.
    achievement         — Achievement unlocked.
    reminder            — Scheduled reminder or goal nudge.
    briefing            — Daily or weekly summary briefing.
    integration_alert   — Integration error or token expiry warning.
"""

import uuid

from sqlalchemy import DateTime, String, Text
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from app.database import Base

# ---------------------------------------------------------------------------
# Valid notification type values
# ---------------------------------------------------------------------------
NOTIFICATION_TYPES: tuple[str, ...] = (
    "insight",
    "anomaly",
    "streak",
    "achievement",
    "reminder",
    "briefing",
    "integration_alert",
)


class NotificationLog(Base):
    """Persisted record of a push notification sent to a user.

    Notification logs back the in-app notification centre. Every push
    notification sent via ``PushService.send_and_persist`` creates one row.
    The client uses these records to display a chronological notification
    history and to track which notifications have been read.

    Attributes:
        id: UUID primary key (auto-generated).
        user_id: Owner's user ID (indexed for fast per-user queries).
        title: Notification title text.
        body: Notification body text.
        type: Notification category — one of ``NOTIFICATION_TYPES``.
        deep_link: Optional URI for in-app tap navigation
            (e.g. ``zuralog://insights/abc123``). ``None`` if the
            notification has no specific destination.
        sent_at: Server-side timestamp when the notification was sent (UTC).
            Indexed to support date-range queries and chronological ordering.
        read_at: Timestamp when the user opened the notification. ``None``
            until the client sends a ``PATCH /notifications/{id}`` request.
    """

    __tablename__ = "notification_logs"

    id: Mapped[str] = mapped_column(
        String,
        primary_key=True,
        default=lambda: str(uuid.uuid4()),
    )
    user_id: Mapped[str] = mapped_column(
        String,
        index=True,
        nullable=False,
    )
    title: Mapped[str] = mapped_column(
        String,
        nullable=False,
    )
    body: Mapped[str] = mapped_column(
        Text,
        nullable=False,
    )
    type: Mapped[str] = mapped_column(
        String,
        nullable=False,
        comment=f"One of: {', '.join(NOTIFICATION_TYPES)}",
    )
    deep_link: Mapped[str | None] = mapped_column(
        String,
        nullable=True,
        comment="URI for tap navigation, e.g. zuralog://insights/abc123",
    )
    sent_at: Mapped[str] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        index=True,
        server_default=func.now(),
    )
    read_at: Mapped[str | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        comment="Set when the client marks this notification as read",
    )
