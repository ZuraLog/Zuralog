"""
Zuralog Cloud Brain — Insight Model.

Persistent AI-generated insight cards surfaced in the mobile app feed.
Each Insight belongs to a single user, has a typed category, a priority
rank (1 = most urgent), and optional structured data for rendering charts
and supporting numbers.

Lifecycle:
    created  →  (optionally) read  →  (optionally) dismissed

Use the ``is_read`` / ``is_dismissed`` properties instead of comparing
timestamps directly.
"""

import enum
import uuid
from datetime import datetime

from sqlalchemy import DateTime, Index, Integer, String, Text
from sqlalchemy.dialects.postgresql import JSON
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from app.database import Base


class InsightType(str, enum.Enum):
    """Semantic category of an AI-generated insight card.

    Variants:
        SLEEP_ANALYSIS: Sleep quality recap and score.
        ACTIVITY_PROGRESS: Step / activity goal progress update.
        NUTRITION_SUMMARY: Daily macro and calorie summary.
        ANOMALY_ALERT: Detected outlier in health metrics.
        GOAL_NUDGE: Near-miss motivational push toward a goal.
        CORRELATION_DISCOVERY: Newly discovered cross-metric pattern.
        STREAK_MILESTONE: Consistency streak achievement.
        MORNING_BRIEFING: Time-of-day morning summary card.
        WELCOME: First-run onboarding insight.
        CORRELATION_SUGGESTION: Actionable hypothesis from correlation data.
    """

    SLEEP_ANALYSIS = "sleep_analysis"
    ACTIVITY_PROGRESS = "activity_progress"
    NUTRITION_SUMMARY = "nutrition_summary"
    ANOMALY_ALERT = "anomaly_alert"
    GOAL_NUDGE = "goal_nudge"
    CORRELATION_DISCOVERY = "correlation_discovery"
    STREAK_MILESTONE = "streak_milestone"
    MORNING_BRIEFING = "morning_briefing"
    WELCOME = "welcome"
    CORRELATION_SUGGESTION = "correlation_suggestion"


class Insight(Base):
    """A single AI-generated insight card for a user.

    Attributes:
        id: UUID primary key (auto-generated).
        user_id: Owner's user ID — indexed for fast per-user queries.
            Not a FK; Supabase Auth manages user identity.
        type: Insight category (``InsightType`` value stored as string).
        title: Short headline displayed in the card header.
        body: Full insight copy (1–3 sentences).
        data: Arbitrary JSON payload for charts, metric values, or
            source references rendered by the mobile client. Nullable.
        reasoning: Internal AI explanation for why this insight was
            generated (hidden from users; used for debugging / auditing).
            Nullable.
        priority: Integer rank where **1 = highest priority, 10 = lowest**.
            Used to order the insight feed. Defaults to 5.
        created_at: UTC timestamp of card creation (server default).
        read_at: UTC timestamp of first open by the user. ``None`` if unread.
        dismissed_at: UTC timestamp of dismissal. ``None`` if not dismissed.
    """

    __tablename__ = "insights"
    __table_args__ = (
        # Compound index: per-user feed ordered by priority then recency.
        Index("ix_insights_user_priority_created", "user_id", "priority", "created_at"),
        # Supports duplicate-prevention queries: same type + same day.
        Index("ix_insights_user_type_created", "user_id", "type", "created_at"),
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
    type: Mapped[str] = mapped_column(
        String,
        nullable=False,
        comment="InsightType enum value stored as string",
    )
    title: Mapped[str] = mapped_column(
        String,
        nullable=False,
    )
    body: Mapped[str] = mapped_column(
        Text,
        nullable=False,
    )
    data: Mapped[dict | None] = mapped_column(
        JSON,
        nullable=True,
        comment="Structured payload: charts, numbers, source references",
    )
    reasoning: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="Internal AI chain-of-thought — not shown to users",
    )
    priority: Mapped[int] = mapped_column(
        Integer,
        default=5,
        server_default="5",
        nullable=False,
        comment="1 = highest priority, 10 = lowest",
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
    read_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    dismissed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    # ------------------------------------------------------------------
    # Computed properties
    # ------------------------------------------------------------------

    @property
    def is_read(self) -> bool:
        """Whether the insight has been opened by the user.

        Returns:
            True if ``read_at`` is not None.
        """
        return self.read_at is not None

    @property
    def is_dismissed(self) -> bool:
        """Whether the insight has been dismissed by the user.

        Returns:
            True if ``dismissed_at`` is not None.
        """
        return self.dismissed_at is not None

    # ------------------------------------------------------------------
    # Serialisation
    # ------------------------------------------------------------------

    def to_dict(self) -> dict:
        """Serialize the insight to a plain dictionary.

        Timestamps are ISO-8601 strings; None values are preserved as null.
        ``is_read`` and ``is_dismissed`` are included as computed fields.

        Returns:
            A JSON-serialisable dictionary of all insight fields.
        """
        return {
            "id": self.id,
            "user_id": self.user_id,
            "type": self.type,
            "title": self.title,
            "body": self.body,
            "data": self.data,
            "reasoning": self.reasoning,
            "priority": self.priority,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "read_at": self.read_at.isoformat() if self.read_at else None,
            "dismissed_at": self.dismissed_at.isoformat() if self.dismissed_at else None,
            "is_read": self.is_read,
            "is_dismissed": self.is_dismissed,
        }
