"""
Zuralog Cloud Brain — User Streak Model.

Tracks engagement streaks across multiple metric categories for each user.
Each row represents a single streak type for a single user. The freeze
mechanic lets users preserve a streak through a missed day — up to one
freeze per week, accumulated to a maximum of 2.

Models:
    - StreakType: Enum of supported streak categories.
    - UserStreak: A single streak record for one user and type.
"""

import enum
import uuid
from datetime import date, datetime

from sqlalchemy import Boolean, Date, DateTime, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from app.database import Base


class StreakType(str, enum.Enum):
    """Categories of streaks tracked by the platform.

    Members:
        ENGAGEMENT: Any data logged or coaching chat — the primary streak.
        STEPS: Daily step goal met.
        WORKOUTS: Workout logged.
        CHECKIN: Wellness check-in (journal entry) logged.
    """

    ENGAGEMENT = "engagement"
    STEPS = "steps"
    WORKOUTS = "workouts"
    CHECKIN = "checkin"


class UserStreak(Base):
    """A streak record tracking consistency for one user and one streak type.

    Freeze mechanic:
        - One freeze is auto-granted per week (weekly reset task).
        - Freezes accumulate up to a maximum of 2.
        - When a streak would break (gap > 1 day), a freeze is consumed
          automatically if available and not yet used this week.
        - ``freeze_count`` = tokens available.
        - ``freeze_used_today`` = transient daily guard (not currently used
          in automatic logic but available for manual use).
        - ``freeze_used_this_week`` = prevents using more than one freeze
          per week automatically.

    Attributes:
        id: UUID primary key (auto-generated).
        user_id: Owner's user ID (indexed for fast per-user queries).
        streak_type: The type of activity being tracked.
        current_count: Current consecutive-day count.
        longest_count: All-time personal best streak count.
        last_activity_date: The most recent date an activity was recorded.
        freeze_count: Number of available freeze tokens (max 2).
        freeze_used_today: Whether a freeze was applied today (daily guard).
        freeze_used_this_week: Whether a freeze was applied this week.
        week_freeze_reset_date: The Monday when the weekly freeze was last reset.
        created_at: Row creation timestamp.
        updated_at: Timestamp of last update.
    """

    __tablename__ = "user_streaks"
    __table_args__ = (UniqueConstraint("user_id", "streak_type", name="uq_user_streak_user_type"),)

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
    streak_type: Mapped[str] = mapped_column(
        String,
        nullable=False,
        comment="StreakType enum value",
    )
    current_count: Mapped[int] = mapped_column(
        Integer,
        default=0,
        server_default="0",
        nullable=False,
    )
    longest_count: Mapped[int] = mapped_column(
        Integer,
        default=0,
        server_default="0",
        nullable=False,
    )
    last_activity_date: Mapped[date | None] = mapped_column(
        Date,
        nullable=True,
    )
    freeze_count: Mapped[int] = mapped_column(
        Integer,
        default=1,
        server_default="1",
        nullable=False,
        comment="Available freeze tokens. New users start with 1 (first-week freebie).",
    )
    freeze_used_today: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        server_default="false",
        nullable=False,
    )
    freeze_used_this_week: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        server_default="false",
        nullable=False,
    )
    week_freeze_reset_date: Mapped[date | None] = mapped_column(
        Date,
        nullable=True,
        comment="The Monday on which the weekly freeze was last reset.",
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )
    updated_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        onupdate=func.now(),
        nullable=True,
    )
