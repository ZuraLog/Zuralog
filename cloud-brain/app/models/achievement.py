"""
Zuralog Cloud Brain — Achievement Model.

SQLAlchemy ORM model for user achievements. Achievements are milestones
unlocked by reaching specific goals (e.g. a 7-day streak, connecting 3
integrations). A locked achievement has ``unlocked_at=None``; once
unlocked the timestamp is set and never cleared.

Models:
    - Achievement: A single achievement definition instance per user.
"""

import uuid
from datetime import datetime

from sqlalchemy import DateTime, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from app.database import Base


class Achievement(Base):
    """A user achievement — locked until the qualifying condition is met.

    Achievement definitions live in the ``AchievementTracker`` registry.
    Each user gets one row per achievement key; the row is created as
    locked (``unlocked_at=None``) and updated in-place on unlock.

    Attributes:
        id: UUID primary key (auto-generated).
        user_id: Owner's user ID (indexed for fast lookups).
        achievement_key: Stable string key matching a registry entry
            (e.g. ``"streak_7"``, ``"first_integration"``).
        unlocked_at: UTC timestamp when the achievement was unlocked,
            or ``None`` if still locked.
        created_at: Row creation timestamp (server-side default).
    """

    __tablename__ = "achievements"
    __table_args__ = (
        UniqueConstraint("user_id", "achievement_key", name="uq_achievement_user_key"),
    )

    id: Mapped[str] = mapped_column(
        String,
        primary_key=True,
        default=lambda: str(uuid.uuid4()),
    )
    user_id: Mapped[str] = mapped_column(
        String,
        index=True,
    )
    achievement_key: Mapped[str] = mapped_column(String)
    unlocked_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        default=None,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )
