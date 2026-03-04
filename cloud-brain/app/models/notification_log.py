"""
Zuralog Cloud Brain — NotificationLog Model.

Persists every push notification sent to users, enabling an in-app
notification centre with read/unread state and deep-link navigation.

One row per push sent. The ``read_at`` column is null until the user
taps the notification or opens the notification centre.
"""

import enum
import uuid
from datetime import datetime

from sqlalchemy import DateTime, Index, String, Text
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from app.database import Base


class NotificationType(str, enum.Enum):
    """Semantic category of a push notification.

    Attributes:
        INSIGHT: AI-generated insight card push.
        ANOMALY: Anomaly detection alert.
        STREAK: Streak milestone reached.
        ACHIEVEMENT: Achievement unlocked.
        REMINDER: Smart reminder (gap, goal, pattern).
        BRIEFING: Morning briefing push.
        INTEGRATION_ALERT: Integration stale or requires re-auth.
    """

    INSIGHT = "insight"
    ANOMALY = "anomaly"
    STREAK = "streak"
    ACHIEVEMENT = "achievement"
    REMINDER = "reminder"
    BRIEFING = "briefing"
    INTEGRATION_ALERT = "integration_alert"


class NotificationLog(Base):
    """Persisted record of every push notification sent to a user.

    Attributes:
        id: UUID primary key (auto-generated).
        user_id: Owner's user ID — indexed for fast per-user queries.
            Not a FK; Supabase Auth manages user identity.
        title: Short notification title text (≤ 64 chars recommended).
        body: Full notification body text.
        type: NotificationType value stored as string.
        deep_link: Optional URI for client-side tap navigation, e.g.
            ``"zuralog://insight/abc123"``. Null for generic pushes.
        sent_at: When the push was dispatched (server default = now).
            Indexed for feed ordering.
        read_at: When the user read/opened the notification. Null if unread.
        created_at: Row creation timestamp (server default = now).
    """

    __tablename__ = "notification_logs"
    __table_args__ = (
        # Per-user feed ordered by most recent first.
        Index("ix_notification_logs_user_sent", "user_id", "sent_at"),
    )

    id: Mapped[str] = mapped_column(
        String,
        primary_key=True,
        default=lambda: str(uuid.uuid4()),
    )
    user_id: Mapped[str] = mapped_column(
        String,
        index=True,
        nullable=False,
        comment="Supabase Auth user UID — not a FK by design",
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
        comment="NotificationType enum value stored as string",
    )
    deep_link: Mapped[str | None] = mapped_column(
        String,
        nullable=True,
        comment="URI for client-side tap navigation, e.g. zuralog://insight/abc123",
    )
    sent_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        index=True,
        nullable=False,
    )
    read_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    # ------------------------------------------------------------------
    # Computed properties
    # ------------------------------------------------------------------

    @property
    def is_read(self) -> bool:
        """Whether the notification has been read.

        Returns:
            True if ``read_at`` is not None.
        """
        return self.read_at is not None

    # ------------------------------------------------------------------
    # Serialisation
    # ------------------------------------------------------------------

    def to_dict(self) -> dict:
        """Serialize the notification log to a plain dictionary.

        Timestamps are ISO-8601 strings; None values are preserved as null.

        Returns:
            A JSON-serialisable dictionary of all fields.
        """
        return {
            "id": self.id,
            "user_id": self.user_id,
            "title": self.title,
            "body": self.body,
            "type": self.type,
            "deep_link": self.deep_link,
            "sent_at": self.sent_at.isoformat() if self.sent_at else None,
            "read_at": self.read_at.isoformat() if self.read_at else None,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "is_read": self.is_read,
        }
