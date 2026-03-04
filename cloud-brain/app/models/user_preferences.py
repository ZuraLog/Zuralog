"""
Zuralog Cloud Brain — User Preferences Model.

One row per user, auto-created with sensible defaults on first GET
(upsert behaviour). The primary key is ``user_id`` itself so there
is no separate surrogate key — lookups and upserts are single-column.

Fields cover coaching persona, proactivity, dashboard layout,
notification toggles, appearance, onboarding state, scheduling times,
and the user's high-level goal selection.
"""

import enum
import uuid

from sqlalchemy import Boolean, DateTime, JSON, String
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


class UserPreferences(Base):
    """Per-user configurable preferences for the Zuralog app.

    One row per user (user_id is the primary key).
    Populated with sensible defaults on first GET via the upsert helper.

    Attributes:
        user_id: Supabase UID — primary key, one row per user.
        coach_persona: AI coaching style. One of: 'tough_love', 'balanced', 'gentle'.
        proactivity_level: How proactively the AI surfaces suggestions.
            One of: 'low', 'medium', 'high'.
        dashboard_layout: JSON dict of card order and visibility settings.
        notification_settings: JSON dict with all notification toggles.
        theme: App colour scheme. One of: 'dark', 'light', 'system'.
        haptic_enabled: Whether haptic feedback is active.
        tooltips_enabled: Whether onboarding tooltip bubbles are shown.
        onboarding_complete: True once the user has finished the welcome flow.
        morning_briefing_time: HH:MM string for the daily briefing push.
        checkin_reminder_time: HH:MM string for the wellness check-in reminder.
        quiet_hours_start: HH:MM string for start of the quiet-hours window.
        quiet_hours_end: HH:MM string for end of the quiet-hours window.
        goals: JSON array of goal-type strings.
        updated_at: Timestamp of last modification (server-managed).
    """

    __tablename__ = "user_preferences"

    user_id: Mapped[str] = mapped_column(
        String,
        primary_key=True,
        default=lambda: str(uuid.uuid4()),
        comment="Supabase UID — one row per user",
    )

    # Coach settings
    coach_persona: Mapped[str] = mapped_column(
        String,
        default="balanced",
        server_default="balanced",
        nullable=False,
        comment="tough_love | balanced | gentle",
    )
    proactivity_level: Mapped[str] = mapped_column(
        String,
        default="medium",
        server_default="medium",
        nullable=False,
        comment="low | medium | high",
    )

    # Dashboard layout (JSON — card order + visibility + colour overrides)
    dashboard_layout: Mapped[dict] = mapped_column(
        JSON,
        default=dict,
        server_default="{}",
        nullable=False,
        comment="Card order and visibility settings",
    )

    # Notification settings (JSON — all toggles)
    notification_settings: Mapped[dict] = mapped_column(
        JSON,
        default=dict,
        server_default="{}",
        nullable=False,
        comment="All notification toggle keys",
    )

    # Appearance
    theme: Mapped[str] = mapped_column(
        String,
        default="system",
        server_default="system",
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

    # Notification scheduling — stored as HH:MM strings
    morning_briefing_time: Mapped[str | None] = mapped_column(
        String,
        nullable=True,
        comment="HH:MM — local clock time for the morning briefing push",
    )
    checkin_reminder_time: Mapped[str | None] = mapped_column(
        String,
        nullable=True,
        comment="HH:MM — local clock time for the wellness check-in reminder",
    )
    quiet_hours_start: Mapped[str | None] = mapped_column(
        String,
        nullable=True,
        comment="HH:MM — start of quiet hours (no push notifications)",
    )
    quiet_hours_end: Mapped[str | None] = mapped_column(
        String,
        nullable=True,
        comment="HH:MM — end of quiet hours",
    )

    # High-level goal types
    goals: Mapped[list] = mapped_column(
        JSON,
        default=list,
        server_default="[]",
        nullable=False,
        comment="Goal type strings: weight_loss, sleep, fitness, stress, nutrition, longevity",
    )

    # Timestamps
    updated_at: Mapped[str | None] = mapped_column(
        DateTime(timezone=True),
        onupdate=func.now(),
        nullable=True,
    )
