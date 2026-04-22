"""
Zuralog Cloud Brain — User Preferences Model.

One row per user, keyed by ``id`` (surrogate PK) with ``user_id`` as a
unique foreign reference to auth.users.  Auto-created with sensible defaults
on first GET (upsert behaviour).

Fields cover coaching persona, proactivity, dashboard layout,
notification toggles, appearance, onboarding state, scheduling times,
and the user's high-level goal selection.
"""

import datetime
import enum
import uuid

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


class ResponseLength(str, enum.Enum):
    """AI coach response verbosity."""

    CONCISE = "concise"
    DETAILED = "detailed"


class AppTheme(str, enum.Enum):
    """App colour-theme preference."""

    DARK = "dark"
    LIGHT = "light"
    SYSTEM = "system"


class UserPreferences(Base):
    """Per-user configurable preferences for the Zuralog app.

    One row per user (id is the surrogate PK; user_id is a unique FK).
    Populated with sensible defaults on first GET via the upsert helper.

    Attributes:
        id: Surrogate primary key (varchar).
        user_id: Supabase UID — unique, one row per user.
        coach_persona: AI coaching style. One of: 'tough_love', 'balanced', 'gentle'.
        proactivity_level: How proactively the AI surfaces suggestions.
            One of: 'low', 'medium', 'high'.
        dashboard_layout: JSON dict of card order and visibility settings.
        notification_settings: JSON dict with all notification toggles.
        theme: App colour scheme. One of: 'dark', 'light', 'system'.
        haptic_enabled: Whether haptic feedback is active.
        tooltips_enabled: Whether onboarding tooltip bubbles are shown.
        onboarding_complete: True once the user has finished the welcome flow.
        morning_briefing_enabled: Whether the daily morning briefing is active.
        morning_briefing_time: HH:MM string for the daily briefing push.
        checkin_reminder_enabled: Whether the wellness check-in reminder is active.
        checkin_reminder_time: HH:MM string for the wellness check-in reminder.
        quiet_hours_enabled: Whether quiet hours are active.
        quiet_hours_start: HH:MM string for start of the quiet-hours window.
        quiet_hours_end: HH:MM string for end of the quiet-hours window.
        wellness_checkin_card_visible: Controls visibility of wellness check-in card on Today tab.
        data_maturity_banner_dismissed: True when user has permanently dismissed the data maturity banner.
        analytics_opt_out: True when user has opted out of anonymous product analytics.
        memory_enabled: True when the coach should build and use long-term memories.
        goals: JSON array of goal-type strings.
        units_system: 'metric' or 'imperial'.
        fitness_level: Self-assessed fitness level from onboarding.
            One of: 'beginner', 'active', 'athletic'. Nullable.
        response_length: AI coach response verbosity. One of: 'concise', 'detailed'.
        suggested_prompts_enabled: Whether suggested prompts are shown in the coach UI.
        voice_input_enabled: Whether voice input is active in the coach UI.
        created_at: Row creation timestamp (server-managed).
        updated_at: Timestamp of last modification (server-managed).
    """

    __tablename__ = "user_preferences"

    # Surrogate PK (matches the DB's id column)
    id: Mapped[str] = mapped_column(
        String,
        primary_key=True,
        default=lambda: str(uuid.uuid4()),
        comment="Surrogate primary key",
    )

    user_id: Mapped[str] = mapped_column(
        String,
        unique=True,
        nullable=False,
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
    response_length: Mapped[str] = mapped_column(
        String,
        default="concise",
        server_default="concise",
        nullable=False,
        comment="concise | detailed",
    )
    suggested_prompts_enabled: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
        server_default="true",
        nullable=False,
    )
    voice_input_enabled: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
        server_default="true",
        nullable=False,
    )

    # Dashboard layout (JSON — card order + visibility + colour overrides)
    dashboard_layout: Mapped[dict | None] = mapped_column(
        JSON,
        nullable=True,
        comment="Card order and visibility settings",
    )

    # Notification settings (JSON — all toggles)
    notification_settings: Mapped[dict | None] = mapped_column(
        JSON,
        nullable=True,
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

    # Morning briefing
    morning_briefing_enabled: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
        server_default="true",
        nullable=False,
    )

    # Notification scheduling — stored as TIME in the DB
    morning_briefing_time: Mapped[datetime.time | None] = mapped_column(
        Time,
        nullable=True,
        comment="Local clock time for the morning briefing push",
    )

    # Wellness check-in
    checkin_reminder_enabled: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        server_default="false",
        nullable=False,
    )
    checkin_reminder_time: Mapped[datetime.time | None] = mapped_column(
        Time,
        nullable=True,
        comment="Local clock time for the wellness check-in reminder",
    )

    # Quiet hours
    quiet_hours_enabled: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        server_default="false",
        nullable=False,
    )
    quiet_hours_start: Mapped[datetime.time | None] = mapped_column(
        Time,
        nullable=True,
        comment="Start of quiet hours (no push notifications)",
    )
    quiet_hours_end: Mapped[datetime.time | None] = mapped_column(
        Time,
        nullable=True,
        comment="End of quiet hours",
    )

    # Privacy & visibility
    wellness_checkin_card_visible: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
        server_default="true",
        nullable=False,
        comment="Controls visibility of wellness check-in card on Today tab",
    )
    data_maturity_banner_dismissed: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        server_default="false",
        nullable=False,
        comment="True when user has permanently dismissed the data maturity banner",
    )
    analytics_opt_out: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        server_default="false",
        nullable=False,
        comment="True when user has opted out of anonymous product analytics",
    )
    memory_enabled: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
        server_default="true",
        nullable=False,
    )

    # High-level goal types
    goals: Mapped[list | None] = mapped_column(
        JSON,
        nullable=True,
        comment="Goal type strings: weight_loss, sleep, fitness, stress, nutrition, longevity",
    )

    # Units
    units_system: Mapped[str] = mapped_column(
        String,
        default="metric",
        server_default="metric",
        nullable=False,
        comment="metric | imperial",
    )

    # Self-assessed fitness level (set during onboarding)
    fitness_level: Mapped[str | None] = mapped_column(
        String,
        nullable=True,
        comment="beginner | active | athletic — set during onboarding",
    )

    # Real-time nudges (notification-adjacent)
    nudges_enabled: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        server_default="false",
        nullable=False,
        comment="Whether real-time nudges are enabled",
    )

    # Onboarding attribution (set once)
    discovery_source: Mapped[str | None] = mapped_column(
        String,
        nullable=True,
        comment="How the user discovered ZuraLog (set once during onboarding)",
    )

    # Timezone for scheduling fan-out (e.g. 6 AM local)
    timezone: Mapped[str] = mapped_column(
        String(50),
        default="UTC",
        server_default="UTC",
        nullable=False,
        comment="IANA timezone name (e.g. America/New_York). Used for 6 AM fan-out scheduling.",
    )

    # Timestamps
    created_at: Mapped[datetime.datetime | None] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=True,
    )
    updated_at: Mapped[datetime.datetime | None] = mapped_column(
        DateTime(timezone=True),
        onupdate=func.now(),
        nullable=True,
    )
