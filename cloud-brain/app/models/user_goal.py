"""
Zuralog Cloud Brain — User Goal Model.

SQLAlchemy ORM model for user-defined health and fitness goals.
Goals provide essential context for the analytics engine — raw metric
values like "8 000 steps" are meaningless without knowing whether the
user's target is 5 000 or 15 000.

Models:
    - GoalPeriod: Enum of supported goal time horizons.
    - UserGoal: A single measurable target a user wants to achieve.
"""

import uuid
from datetime import date, datetime
from enum import Enum

from sqlalchemy import Boolean, Date, DateTime, Float, String, UniqueConstraint
from sqlalchemy import Enum as SAEnum
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from app.database import Base


class GoalPeriod(str, Enum):
    """Supported time horizons for a user goal.

    Used by the analytics engine to bucket and evaluate progress
    over the correct window.

    Members:
        DAILY: Goal resets every day (e.g. 10 000 steps/day).
        WEEKLY: Goal resets every week (e.g. 3 workouts/week).
        LONG_TERM: Open-ended target without a recurring reset
            (e.g. reach 75 kg body weight).
    """

    DAILY = "daily"
    WEEKLY = "weekly"
    LONG_TERM = "long_term"


class UserGoal(Base):
    """A user-defined health or fitness goal for a specific metric.

    Each goal ties a ``metric`` (e.g. ``'steps'``, ``'calories_consumed'``,
    ``'weight_kg'``, ``'workouts'``) to a numeric ``target_value`` within
    a given ``period``.  The analytics engine compares actual data against
    active goals to generate progress reports and recommendations.

    Users may have multiple goals (including multiple goals of the same
    type/metric).

    Attributes:
        id: UUID primary key (auto-generated).
        user_id: Owner's user ID (indexed for fast lookups).
        metric: The health/fitness metric being targeted
            (e.g. 'steps', 'calories_consumed', 'weight_kg', 'workouts').
        target_value: The numeric target the user aims to hit.
        period: Time horizon for the goal (daily, weekly, or long-term).
        is_active: Whether the goal is currently active (default ``True``).
        created_at: Row creation timestamp (server-side default).
        type: Goal type slug used by the Flutter client
            (e.g. 'step_count', 'weight_target', 'custom').
        title: Short user-facing goal title.
        current_value: Latest recorded progress toward the goal.
        unit: Measurement unit label (e.g. 'steps', 'kg', 'hrs').
        start_date: ISO-8601 date when the goal was started.
        deadline: Optional ISO-8601 deadline date.
        is_completed: Whether the goal has been achieved.
        ai_commentary: Optional AI-generated motivational text.
    """

    __tablename__ = "user_goals"
    __table_args__ = (
        UniqueConstraint("user_id", "metric", name="uq_user_goals_user_metric"),
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
    metric: Mapped[str] = mapped_column(String)
    target_value: Mapped[float] = mapped_column(Float)
    period: Mapped[GoalPeriod] = mapped_column(SAEnum(GoalPeriod))
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )

    # ── CRUD columns (added for Flutter Goals screen) ─────────────────────
    type: Mapped[str] = mapped_column(String, default="custom")
    title: Mapped[str] = mapped_column(String, default="")
    current_value: Mapped[float] = mapped_column(Float, default=0.0)
    unit: Mapped[str] = mapped_column(String, default="")
    start_date: Mapped[date | None] = mapped_column(Date, nullable=True, default=None)
    deadline: Mapped[date | None] = mapped_column(Date, nullable=True, default=None)
    is_completed: Mapped[bool] = mapped_column(Boolean, default=False)
    ai_commentary: Mapped[str | None] = mapped_column(String, nullable=True, default=None)
