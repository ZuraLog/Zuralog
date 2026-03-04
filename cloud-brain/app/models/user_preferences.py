"""
Zuralog Cloud Brain — UserPreferences Model.

Stores all per-user application preferences: AI coach persona,
notification settings, dashboard layout, theme, and health goals.
One row per user, with cascade-delete tied to the parent users row.
"""

import enum
import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, JSON, String, Time, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from app.database import Base


class CoachPersona(str, enum.Enum):
    """AI coach personality styles.

    Attributes:
        TOUGH_LOVE: Direct, challenging coaching style.
        BALANCED: Balanced encouragement and accountability.
        GENTLE: Supportive, low-pressure coaching style.
    """

    TOUGH_LOVE = "tough_love"
    BALANCED = "balanced"
    GENTLE = "gentle"


class ProactivityLevel(str, enum.Enum):
    """How proactively the AI coach surfaces insights.

    Attributes:
        LOW: Only surface critical alerts.
        MEDIUM: Balanced — daily summaries and notable trends.
        HIGH: Frequent nudges and pattern commentary.
    """

    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"


class Theme(str, enum.Enum):
    """Application colour theme preference.

    Attributes:
        DARK: Always use dark mode (default).
        LIGHT: Always use light mode.
        SYSTEM: Follow the device system setting.
    """

    DARK = "dark"
    LIGHT = "light"
    SYSTEM = "system"


class UnitsSystem(str, enum.Enum):
    """Measurement units system preference.

    Attributes:
        METRIC: SI units (kg, km, °C).
        IMPERIAL: Imperial units (lbs, miles, °F).
    """

    METRIC = "metric"
    IMPERIAL = "imperial"


class UserPreferences(Base):
    """Per-user application preferences.

    One row per user. Created lazily on first GET request with
    all-default values. Updated via PUT (full replace) or PATCH
    (partial update).

    Attributes:
        id: UUID primary key (auto-generated).
        user_id: FK → users.id (unique, cascade delete, indexed).
        coach_persona: AI coaching style. Default ``balanced``.
        proactivity_level: Coach proactivity. Default ``medium``.
        dashboard_layout: JSON blob — card order and visibility config.
        notification_settings: JSON blob — all notification toggles.
        theme: App colour theme. Default ``dark``.
        haptic_enabled: Enable haptic feedback. Default ``True``.
        tooltips_enabled: Show onboarding tooltips. Default ``True``.
        onboarding_complete: User has finished onboarding flow. Default ``False``.
        morning_briefing_enabled: Daily morning summary push. Default ``False``.
        morning_briefing_time: Local time for morning briefing (nullable).
        checkin_reminder_enabled: Daily check-in reminder push. Default ``False``.
        checkin_reminder_time: Local time for check-in reminder (nullable).
        quiet_hours_enabled: Suppress all pushes during quiet hours. Default ``False``.
        quiet_hours_start: Start of quiet window (nullable).
        quiet_hours_end: End of quiet window (nullable).
        goals: JSON array of goal objects (nullable).
        units_system: Measurement system preference. Default ``metric``.
        created_at: Row creation timestamp (server-side default).
        updated_at: Last-update timestamp (client-side onupdate trigger).
    """

    __tablename__ = "user_preferences"
    __table_args__ = (UniqueConstraint("user_id", name="uq_user_preferences_user_id"),)

    id: Mapped[str] = mapped_column(
        String,
        primary_key=True,
        default=lambda: str(uuid.uuid4()),
    )
    user_id: Mapped[str] = mapped_column(
        String,
        ForeignKey("users.id", ondelete="CASCADE"),
        unique=True,
        index=True,
        nullable=False,
    )
    coach_persona: Mapped[str] = mapped_column(
        String,
        default=CoachPersona.BALANCED.value,
        nullable=False,
        comment="AI coaching style: tough_love | balanced | gentle",
    )
    proactivity_level: Mapped[str] = mapped_column(
        String,
        default=ProactivityLevel.MEDIUM.value,
        nullable=False,
        comment="Coach proactivity: low | medium | high",
    )
    dashboard_layout: Mapped[dict | None] = mapped_column(
        JSON,
        nullable=True,
        comment="Card order and visibility config for the dashboard",
    )
    notification_settings: Mapped[dict | None] = mapped_column(
        JSON,
        nullable=True,
        comment="Per-notification-type toggle map",
    )
    theme: Mapped[str] = mapped_column(
        String,
        default=Theme.DARK.value,
        nullable=False,
        comment="Colour theme: dark | light | system",
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
    morning_briefing_enabled: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        server_default="false",
        nullable=False,
    )
    morning_briefing_time: Mapped[datetime | None] = mapped_column(
        Time,
        nullable=True,
        comment="Local time for morning briefing push notification",
    )
    checkin_reminder_enabled: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        server_default="false",
        nullable=False,
    )
    checkin_reminder_time: Mapped[datetime | None] = mapped_column(
        Time,
        nullable=True,
        comment="Local time for daily check-in reminder",
    )
    quiet_hours_enabled: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        server_default="false",
        nullable=False,
    )
    quiet_hours_start: Mapped[datetime | None] = mapped_column(
        Time,
        nullable=True,
        comment="Start of quiet hours window (no pushes sent)",
    )
    quiet_hours_end: Mapped[datetime | None] = mapped_column(
        Time,
        nullable=True,
        comment="End of quiet hours window",
    )
    goals: Mapped[list | None] = mapped_column(
        JSON,
        nullable=True,
        comment="Array of user goal objects {metric, target, period}",
    )
    units_system: Mapped[str] = mapped_column(
        String,
        default=UnitsSystem.METRIC.value,
        nullable=False,
        comment="Measurement system: metric | imperial",
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
    updated_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        onupdate=func.now(),
        nullable=True,
    )

    def to_dict(self) -> dict:
        """Return a safe dict representation for API responses.

        Time fields are serialised to ``HH:MM:SS`` strings.
        Datetime fields are serialised to ISO-8601 strings.

        Returns:
            A JSON-safe dictionary of all preference fields.
        """

        def _fmt_time(t) -> str | None:
            """Format a time value to HH:MM:SS string, or None."""
            if t is None:
                return None
            # Handles both datetime.time and datetime.datetime objects.
            if hasattr(t, "strftime"):
                return t.strftime("%H:%M:%S")
            return str(t)

        def _fmt_dt(dt) -> str | None:
            """Format a datetime to ISO-8601 string, or None."""
            if dt is None:
                return None
            if hasattr(dt, "isoformat"):
                return dt.isoformat()
            return str(dt)

        return {
            "id": self.id,
            "user_id": self.user_id,
            "coach_persona": self.coach_persona,
            "proactivity_level": self.proactivity_level,
            "dashboard_layout": self.dashboard_layout,
            "notification_settings": self.notification_settings,
            "theme": self.theme,
            "haptic_enabled": self.haptic_enabled,
            "tooltips_enabled": self.tooltips_enabled,
            "onboarding_complete": self.onboarding_complete,
            "morning_briefing_enabled": self.morning_briefing_enabled,
            "morning_briefing_time": _fmt_time(self.morning_briefing_time),
            "checkin_reminder_enabled": self.checkin_reminder_enabled,
            "checkin_reminder_time": _fmt_time(self.checkin_reminder_time),
            "quiet_hours_enabled": self.quiet_hours_enabled,
            "quiet_hours_start": _fmt_time(self.quiet_hours_start),
            "quiet_hours_end": _fmt_time(self.quiet_hours_end),
            "goals": self.goals,
            "units_system": self.units_system,
            "created_at": _fmt_dt(self.created_at),
            "updated_at": _fmt_dt(self.updated_at),
        }
