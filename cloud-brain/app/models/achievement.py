"""
Zuralog Cloud Brain — Achievement Model.

Tracks per-user achievement unlock state. Each row represents one
achievement for one user. Unlocked achievements have a non-null
``unlocked_at`` timestamp; locked achievements have ``unlocked_at=None``.

The ``ACHIEVEMENT_REGISTRY`` dict is the single source of truth for all
achievement keys, display metadata, and categories. No achievement may be
stored in the DB unless its key appears in this registry.
"""

import uuid
from datetime import datetime

from sqlalchemy import DateTime, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from app.database import Base


# ---------------------------------------------------------------------------
# Achievement registry — single source of truth for all achievement metadata
# ---------------------------------------------------------------------------

ACHIEVEMENT_REGISTRY: dict[str, dict] = {
    # Getting started
    "first_integration": {
        "title": "Connected!",
        "description": "Connected your first health app",
        "category": "getting_started",
        "icon": "link",
    },
    "first_chat": {
        "title": "First Conversation",
        "description": "Had your first coaching session",
        "category": "getting_started",
        "icon": "chat",
    },
    "first_insight": {
        "title": "First Insight",
        "description": "Received your first health insight",
        "category": "getting_started",
        "icon": "lightbulb",
    },
    # Consistency streaks
    "streak_7": {
        "title": "One Week Strong",
        "description": "7-day engagement streak",
        "category": "consistency",
        "icon": "fire",
    },
    "streak_30": {
        "title": "Monthly Dedication",
        "description": "30-day engagement streak",
        "category": "consistency",
        "icon": "fire",
    },
    "streak_90": {
        "title": "Iron Will",
        "description": "90-day engagement streak",
        "category": "consistency",
        "icon": "fire",
    },
    "streak_365": {
        "title": "Year of Health",
        "description": "365-day engagement streak",
        "category": "consistency",
        "icon": "trophy",
    },
    # Goals
    "first_goal": {
        "title": "Goal Setter",
        "description": "Created your first health goal",
        "category": "goals",
        "icon": "target",
    },
    "goals_5_complete": {
        "title": "Goal Crusher",
        "description": "Completed 5 health goals",
        "category": "goals",
        "icon": "check_circle",
    },
    "overachiever": {
        "title": "Overachiever",
        "description": "Exceeded a goal by 20%",
        "category": "goals",
        "icon": "rocket",
    },
    # Data
    "connected_3": {
        "title": "Data Rich",
        "description": "Connected 3 or more health apps",
        "category": "data",
        "icon": "network",
    },
    "data_rich_30": {
        "title": "30 Days of Data",
        "description": "30 days of continuous health data",
        "category": "data",
        "icon": "chart",
    },
    "full_picture_5_categories": {
        "title": "Full Picture",
        "description": "Tracking 5+ health categories",
        "category": "data",
        "icon": "dashboard",
    },
    # Coach
    "conversations_50": {
        "title": "Health Scholar",
        "description": "50 coaching conversations",
        "category": "coach",
        "icon": "school",
    },
    "insights_100": {
        "title": "Data Driven",
        "description": "100 health insights received",
        "category": "coach",
        "icon": "analytics",
    },
    "memories_20": {
        "title": "Well Known",
        "description": "AI has learned 20 things about you",
        "category": "coach",
        "icon": "brain",
    },
    # Health outcomes
    "improved_bedtime": {
        "title": "Sleep Champion",
        "description": "Improved average bedtime by 30+ minutes",
        "category": "health",
        "icon": "sleep",
    },
    "personal_best": {
        "title": "Personal Best",
        "description": "Set a new personal record",
        "category": "health",
        "icon": "star",
    },
    "anomaly_aware_10": {
        "title": "Self-Aware",
        "description": "Noticed and tracked 10 health anomalies",
        "category": "health",
        "icon": "radar",
    },
}


# ---------------------------------------------------------------------------
# ORM model
# ---------------------------------------------------------------------------


class Achievement(Base):
    """A single achievement row for one user.

    Locked achievements exist as rows with ``unlocked_at=None``.
    Unlocked achievements carry the timestamp of unlock.

    Attributes:
        id: UUID primary key (auto-generated).
        user_id: Owner's user ID (indexed for per-user queries).
        achievement_key: Registry key (e.g. ``"streak_7"``). Must exist
            in ``ACHIEVEMENT_REGISTRY``.
        unlocked_at: UTC timestamp when the achievement was unlocked.
            ``None`` means locked.
        created_at: Row creation timestamp (server-side default).
    """

    __tablename__ = "achievements"
    __table_args__ = (UniqueConstraint("user_id", "achievement_key", name="uq_achievement_user_key"),)

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
    achievement_key: Mapped[str] = mapped_column(
        String,
        nullable=False,
    )
    unlocked_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )
