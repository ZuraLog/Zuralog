"""
Zuralog Cloud Brain — User Streak Model.

SQLAlchemy ORM model for per-user, per-type activity streaks.
Streak types are: engagement, steps, workouts, checkin.

Streak tokens allow users to preserve a streak through one missed day
per week (free reset on Monday) up to a maximum of 2 accumulated tokens.

Models:
    - UserStreak: A single streak counter for one user + streak type.
"""

import uuid
from datetime import date, datetime, timezone

from sqlalchemy import Boolean, Date, DateTime, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from app.database import Base


class UserStreak(Base):
    """A streak counter for a user's recurring health activity.

    One row exists per ``(user_id, streak_type)`` pair. The row is created
    on first activity and updated in-place on every subsequent call.

    Attributes:
        id: UUID primary key (auto-generated).
        user_id: Owner's user ID (indexed for fast lookups).
        streak_type: Activity category being tracked.
            One of: ``engagement``, ``steps``, ``workouts``, ``checkin``.
        current_count: Current consecutive-day streak length.
        longest_count: All-time longest streak achieved by this user.
        last_activity_date: Most-recent active day as ``YYYY-MM-DD`` string,
            or ``None`` if no activity has been recorded yet.
        freeze_count: Accumulated freeze tokens (maximum 2).
        freeze_used_this_week: Whether the free weekly freeze has been
            used in the current week (reset every Monday).
    """

    __tablename__ = "user_streaks"
    __table_args__ = (
        UniqueConstraint("user_id", "streak_type", name="uq_user_streak_user_type"),
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
    streak_type: Mapped[str] = mapped_column(String)
    current_count: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    longest_count: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    last_activity_date: Mapped[date | None] = mapped_column(
        Date,
        nullable=True,
        default=None,
    )
    freeze_count: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    freeze_used_this_week: Mapped[bool] = mapped_column(
        Boolean, default=False, server_default="false"
    )
    is_frozen: Mapped[bool] = mapped_column(
        Boolean, default=False, server_default="false"
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        default=lambda: datetime.now(timezone.utc),
    )
