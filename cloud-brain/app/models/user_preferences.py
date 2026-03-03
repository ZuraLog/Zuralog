"""
Zuralog Cloud Brain — User Preferences Model.

Stores all user-configurable preferences for the Zuralog app:
coaching persona, proactivity level, dashboard layout, notification
toggles, theme, haptic/tooltip state, onboarding, and scheduling times.

The row is auto-created with sensible defaults on first access via the
GET endpoint (upsert behaviour). There is exactly one row per user.
"""

import enum
import uuid
from datetime import time
from typing import Any

from sqlalchemy import Boolean, DateTime, JSON, String, Time
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from app.database import Base


class CoachPersona(str, enum.Enum):
    """AI coach personality style."""

    TOUGH_LOVE = "tough_love"
    BALANCED = "balanced"
    GENTLE = "gentle"


class ProactivityLevel(str, enum.Enum):
    """How proactively the AI coach surfaces suggestions."""

    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"


class AppTheme(str, enum.Enum):
    """App colour-theme preference."""

    DARK = "dark"
    LIGHT = "light"
    SYSTEM = "system"


def _default_notification_settings() -> dict[str, Any]:
    """Return default notification toggle dict matching mvp-features.md §10."""
    return {
        "morning_briefing": True,
        "smart_reminders": True,
        "smart_reminder_frequency": "medium",
        "smart_reminders_pattern": True,
        "smart_reminders_gap": True,
        "smart_reminders_goal": True,
        "smart_reminders_celebration": True,
        "streak_reminders": True,
        "achievement_notifications": True,
        "anomaly_alerts": True,
        "integration_alerts": True,
        "wellness_checkin_reminder": True,
    }


def _default_dashboard_layout() -> list[dict[str, Any]]:
    """Return default dashboard card order and visibility."""
    return [
        {"id": "activity", "visible": True, "color": None},
        {"id": "sleep", "visible": True, "color": None},
        {"id": "heart", "visible": True, "color": None},
        {"id": "body", "visible": True, "color": None},
        {"id": "nutrition", "visible": True, "color": None},
        {"id": "vitals", "visible": True, "color": None},
        {"id": "cycle", "visible": False, "color": None},
        {"id": "wellness", "visible": True, "color": None},
        {"id": "mobility", "visible": False, "color": None},
        {"id": "environment", "visible": False, "color": None},
    ]


class UserPreferences(Base):
    """Per-user configurable preferences for the Zuralog app.

    One row per user (enforced by unique constraint on user_id).
    Populated with sensible defaults on first GET.

    Attributes:
        id: UUID primary key (auto-generated).
        user_id: Owner's Supabase UID (unique — one row per user).
        coach_persona: AI coaching style. One of: 'tough_love', 'balanced', 'gentle'.
        proactivity_level: How proactively the AI surfaces suggestions.
        dashboard_layout: JSON array of {id, visible, color} card objects.
        notification_settings: JSON object with all notification toggles.
        theme: App colour scheme. One of: 'dark', 'light', 'system'.
        haptic_enabled: Whether haptic feedback is active.
        tooltips_enabled: Whether onboarding tooltip bubbles are shown.
        onboarding_complete: True once the user finished the welcome flow.
        morning_briefing_time: Local time the daily briefing push is sent.
        checkin_reminder_time: Local time of the wellness check-in reminder.
        quiet_hours_start: Start of the user's quiet hours window (no pushes).
        quiet_hours_end: End of the quiet hours window.
        goals: JSON array of goal type strings.
        created_at: Row creation timestamp.
        updated_at: Last modification timestamp.
    """

    __tablename__ = "user_preferences"

    id: Mapped[str] = mapped_column(
        String,
        primary_key=True,
        default=lambda: str(uuid.uuid4()),
    )
    user_id: Mapped[str] = mapped_column(
        String,
        unique=True,
        index=True,
        nullable=False,
        comment="Supabase UID — one row per user",
    )

    # Coach settings (stored as plain strings for simplicity with SQLite in tests)
    coach_persona: Mapped[str] = mapped_column(
        String,
        default=CoachPersona.BALANCED.value,
        server_default=CoachPersona.BALANCED.value,
        nullable=False,
        comment="tough_love | balanced | gentle",
    )
    proactivity_level: Mapped[str] = mapped_column(
        String,
        default=ProactivityLevel.MEDIUM.value,
        server_default=ProactivityLevel.MEDIUM.value,
        nullable=False,
        comment="low | medium | high",
    )

    # Dashboard layout (JSON — card order + visibility + color overrides)
    dashboard_layout: Mapped[list[dict[str, Any]]] = mapped_column(
        JSON,
        default=_default_dashboard_layout,
        server_default="[]",
        nullable=False,
        comment="Ordered list of category cards with visibility and color overrides",
    )

    # Notification settings (JSON — all toggles from mvp-features.md §10)
    notification_settings: Mapped[dict[str, Any]] = mapped_column(
        JSON,
        default=_default_notification_settings,
        server_default="{}",
        nullable=False,
        comment="All notification toggle keys from mvp-features.md Section 10",
    )

    # Appearance
    theme: Mapped[str] = mapped_column(
        String,
        default=AppTheme.DARK.value,
        server_default=AppTheme.DARK.value,
        nullable=False,
        comment="dark | light | system",
    )
    haptic_enabled: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
        server_default="true",
        nullable=False,
    )
    tooltips_enabled: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
        server_default="true",
        nullable=False,
    )
    onboarding_complete: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        server_default="false",
        nullable=False,
    )

    # Notification scheduling
    morning_briefing_time: Mapped[time | None] = mapped_column(
        Time(timezone=False),
        nullable=True,
        comment="Local clock time for the morning briefing push (e.g. 07:00:00)",
    )
    checkin_reminder_time: Mapped[time | None] = mapped_column(
        Time(timezone=False),
        nullable=True,
        comment="Local clock time for the wellness check-in reminder",
    )
    quiet_hours_start: Mapped[time | None] = mapped_column(
        Time(timezone=False),
        nullable=True,
        comment="Start of quiet hours — no push notifications in this window",
    )
    quiet_hours_end: Mapped[time | None] = mapped_column(
        Time(timezone=False),
        nullable=True,
        comment="End of quiet hours",
    )

    # High-level goal types (not numeric UserGoal records)
    goals: Mapped[list[str]] = mapped_column(
        JSON,
        default=list,
        server_default="[]",
        nullable=False,
        comment="Goal type strings: weight_loss, sleep, fitness, stress, nutrition, longevity",
    )

    # Timestamps
    created_at: Mapped[str] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
    updated_at: Mapped[str | None] = mapped_column(
        DateTime(timezone=True),
        onupdate=func.now(),
        nullable=True,
    )
