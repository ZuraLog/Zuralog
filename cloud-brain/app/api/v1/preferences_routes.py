"""
Zuralog Cloud Brain — User Preferences API.

Endpoints:
  GET   /api/v1/preferences  — Return current user's preferences, auto-creating
                               with defaults on first call (upsert behaviour).
  PUT   /api/v1/preferences  — Full replacement of all preference fields.
  PATCH /api/v1/preferences  — Partial update (only provided fields are changed).

All endpoints are auth-guarded via ``get_current_user``; users can only access
their own preferences row.
"""

import datetime
import logging
import re
from typing import Any

import sentry_sdk
from fastapi import APIRouter, Depends, HTTPException, Request, status
from pydantic import BaseModel, ConfigDict, Field, model_validator
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.database import get_db
from app.models.user import User
from app.models.user_preferences import UserPreferences

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/preferences", tags=["preferences"])

# ---------------------------------------------------------------------------
# Valid enum values — enforced at the route layer (not by the DB)
# ---------------------------------------------------------------------------

_VALID_PERSONAS: frozenset[str] = frozenset({"tough_love", "balanced", "gentle"})
_VALID_PROACTIVITY: frozenset[str] = frozenset({"low", "medium", "high"})
_VALID_RESPONSE_LENGTHS: frozenset[str] = frozenset({"concise", "detailed"})
_VALID_THEMES: frozenset[str] = frozenset({"dark", "light", "system"})
_VALID_FITNESS_LEVELS: frozenset[str] = frozenset({"beginner", "active", "athletic"})

# HH:MM in 24-hour format
_TIME_RE = re.compile(r"^(?:[01]\d|2[0-3]):[0-5]\d$")

# ---------------------------------------------------------------------------
# Pydantic schemas
# ---------------------------------------------------------------------------


class PreferencesResponse(BaseModel):
    """Full preferences payload returned to the client."""

    user_id: str
    coach_persona: str
    proactivity_level: str
    response_length: str = "concise"
    suggested_prompts_enabled: bool = True
    voice_input_enabled: bool = True
    dashboard_layout: dict | None = None
    notification_settings: dict | None = None
    theme: str
    haptic_enabled: bool
    tooltips_enabled: bool
    onboarding_complete: bool
    morning_briefing_enabled: bool = True
    morning_briefing_time: str | datetime.time | None = None
    checkin_reminder_enabled: bool = False
    checkin_reminder_time: str | datetime.time | None = None
    quiet_hours_enabled: bool = False
    quiet_hours_start: str | datetime.time | None = None
    quiet_hours_end: str | datetime.time | None = None
    goals: list | None = None
    units_system: str = "metric"
    fitness_level: str | None = None
    wellness_checkin_card_visible: bool = True
    data_maturity_banner_dismissed: bool = False
    analytics_opt_out: bool = False

    model_config = ConfigDict(from_attributes=True)

    @model_validator(mode="after")
    def _serialize_times(self) -> "PreferencesResponse":
        """Convert datetime.time fields to HH:MM strings for the client."""
        time_fields = (
            "morning_briefing_time",
            "checkin_reminder_time",
            "quiet_hours_start",
            "quiet_hours_end",
        )
        for field in time_fields:
            val = getattr(self, field)
            if isinstance(val, datetime.time):
                setattr(self, field, val.strftime("%H:%M"))
        return self


class PreferencesUpdate(BaseModel):
    """Body for PATCH — all fields optional; only provided fields are changed."""

    coach_persona: str | None = Field(None, description="tough_love | balanced | gentle")
    proactivity_level: str | None = Field(None, description="low | medium | high")
    response_length: str | None = Field(None, description="concise | detailed")
    suggested_prompts_enabled: bool | None = None
    voice_input_enabled: bool | None = None
    dashboard_layout: dict | None = None
    notification_settings: dict | None = None
    theme: str | None = Field(None, description="dark | light | system")
    haptic_enabled: bool | None = None
    tooltips_enabled: bool | None = None
    onboarding_complete: bool | None = None
    morning_briefing_enabled: bool | None = None
    morning_briefing_time: str | None = Field(None, description="HH:MM (24-hour)")
    checkin_reminder_enabled: bool | None = None
    checkin_reminder_time: str | None = Field(None, description="HH:MM (24-hour)")
    quiet_hours_enabled: bool | None = None
    quiet_hours_start: str | None = Field(None, description="HH:MM (24-hour)")
    quiet_hours_end: str | None = Field(None, description="HH:MM (24-hour)")
    goals: list | None = None
    units_system: str | None = Field(None, description="metric | imperial")
    fitness_level: str | None = Field(None, description="beginner | active | athletic")
    wellness_checkin_card_visible: bool | None = None
    data_maturity_banner_dismissed: bool | None = None
    analytics_opt_out: bool | None = None


class PreferencesCreate(BaseModel):
    """Body for PUT (full replacement) — all fields optional; unset fields use defaults."""

    coach_persona: str | None = Field(None, description="tough_love | balanced | gentle")
    proactivity_level: str | None = Field(None, description="low | medium | high")
    response_length: str | None = Field(None, description="concise | detailed")
    suggested_prompts_enabled: bool | None = None
    voice_input_enabled: bool | None = None
    dashboard_layout: dict | None = None
    notification_settings: dict | None = None
    theme: str | None = Field(None, description="dark | light | system")
    haptic_enabled: bool | None = None
    tooltips_enabled: bool | None = None
    onboarding_complete: bool | None = None
    morning_briefing_enabled: bool | None = None
    morning_briefing_time: str | None = Field(None, description="HH:MM (24-hour)")
    checkin_reminder_enabled: bool | None = None
    checkin_reminder_time: str | None = Field(None, description="HH:MM (24-hour)")
    quiet_hours_enabled: bool | None = None
    quiet_hours_start: str | None = Field(None, description="HH:MM (24-hour)")
    quiet_hours_end: str | None = Field(None, description="HH:MM (24-hour)")
    goals: list | None = None
    units_system: str | None = Field(None, description="metric | imperial")
    fitness_level: str | None = Field(None, description="beginner | active | athletic")
    wellness_checkin_card_visible: bool | None = None
    data_maturity_banner_dismissed: bool | None = None
    analytics_opt_out: bool | None = None


# ---------------------------------------------------------------------------
# Validation helpers
# ---------------------------------------------------------------------------


def _validate_time_fields(data: dict[str, Any]) -> None:
    """Validate HH:MM format for all time string fields.

    Args:
        data: Dict of field names to values (non-None only).

    Raises:
        HTTPException: 422 if any time string does not match HH:MM.
    """
    time_fields = (
        "morning_briefing_time",
        "checkin_reminder_time",
        "quiet_hours_start",
        "quiet_hours_end",
    )
    for field in time_fields:
        value = data.get(field)
        if value is not None and not _TIME_RE.match(value):
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"Invalid time format for '{field}': '{value}'. Expected HH:MM.",
            )


def _validate_enums(data: dict[str, Any]) -> None:
    """Validate enum-valued fields.

    Args:
        data: Dict of field names to values (non-None only).

    Raises:
        HTTPException: 400 if any enum field contains an invalid value.
    """
    if "coach_persona" in data and data["coach_persona"] not in _VALID_PERSONAS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"coach_persona must be one of: {sorted(_VALID_PERSONAS)}",
        )
    if "proactivity_level" in data and data["proactivity_level"] not in _VALID_PROACTIVITY:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"proactivity_level must be one of: {sorted(_VALID_PROACTIVITY)}",
        )
    if "theme" in data and data["theme"] not in _VALID_THEMES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"theme must be one of: {sorted(_VALID_THEMES)}",
        )
    if "fitness_level" in data:
        # Treat empty string as "not provided" — remove it from the update dict
        if data["fitness_level"] == "":
            del data["fitness_level"]
        elif data["fitness_level"] not in _VALID_FITNESS_LEVELS:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"fitness_level must be one of: {sorted(_VALID_FITNESS_LEVELS)}",
            )
    if "response_length" in data and data["response_length"] not in _VALID_RESPONSE_LENGTHS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"response_length must be one of: {sorted(_VALID_RESPONSE_LENGTHS)}",
        )


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------


async def _get_or_create_prefs(user_id: str, db: AsyncSession) -> UserPreferences:
    """Fetch or auto-create the user's preferences row with defaults.

    This implements the upsert-on-first-access pattern: if no row exists for
    the user, a new one is created with all default values before returning.

    Args:
        user_id: Authenticated user's ID.
        db: Async database session.

    Returns:
        The existing or newly-created :class:`UserPreferences` instance.
    """
    result = await db.execute(select(UserPreferences).where(UserPreferences.user_id == user_id))
    prefs = result.scalar_one_or_none()

    if prefs is None:
        prefs = UserPreferences(user_id=user_id)
        db.add(prefs)
        await db.commit()
        await db.refresh(prefs)
        logger.info("Created default preferences for user %s", user_id)

    return prefs


_TIME_FIELDS: frozenset[str] = frozenset({
    "morning_briefing_time",
    "checkin_reminder_time",
    "quiet_hours_start",
    "quiet_hours_end",
})


def _parse_time(value: str) -> datetime.time:
    """Convert an HH:MM string to a datetime.time (already validated by _validate_time_fields)."""
    return datetime.datetime.strptime(value, "%H:%M").time()


def _apply_update(prefs: UserPreferences, data: dict[str, Any]) -> None:
    """Apply a dict of field values onto the ORM instance.

    Converts HH:MM strings to datetime.time for TIME columns before setting.

    Args:
        prefs: The :class:`UserPreferences` ORM instance to mutate.
        data: Field-name-to-value mapping (already filtered to non-None).
    """
    for field, value in data.items():
        if field in _TIME_FIELDS and isinstance(value, str):
            value = _parse_time(value)
        setattr(prefs, field, value)


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------


@router.get("", summary="Get user preferences", response_model=PreferencesResponse)
async def get_preferences(
    request: Request,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> PreferencesResponse:
    """Return the current user's preferences, creating defaults on first call.

    If no preferences row exists for the authenticated user it is created
    automatically with all default values (upsert on first access).

    Args:
        request: Incoming FastAPI request.
        current_user: Authenticated :class:`User` ORM instance.
        db: Async database session.

    Returns:
        The user's full :class:`PreferencesResponse`.
    """
    sentry_sdk.set_user({"id": current_user.id})

    prefs = await _get_or_create_prefs(current_user.id, db)
    return PreferencesResponse.model_validate(prefs)


@router.put("", summary="Replace user preferences (full update)", response_model=PreferencesResponse)
async def put_preferences(
    request: Request,
    body: PreferencesCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> PreferencesResponse:
    """Full replacement of the user's preferences.

    Any field omitted from the request body is left at its current value
    (or default if the row does not yet exist). Equivalent to PATCH for
    convenience — both endpoints apply only provided fields.

    Args:
        request: Incoming FastAPI request.
        body: Preference fields to update.
        current_user: Authenticated :class:`User` ORM instance.
        db: Async database session.

    Returns:
        Updated :class:`PreferencesResponse`.

    Raises:
        HTTPException: 400 for invalid enum values.
        HTTPException: 422 for malformed time strings.
    """
    sentry_sdk.set_user({"id": current_user.id})

    data = body.model_dump(exclude_none=True)
    _validate_enums(data)
    _validate_time_fields(data)

    prefs = await _get_or_create_prefs(current_user.id, db)
    _apply_update(prefs, data)
    await db.commit()
    await db.refresh(prefs)

    return PreferencesResponse.model_validate(prefs)


@router.patch("", summary="Partially update user preferences", response_model=PreferencesResponse)
async def patch_preferences(
    request: Request,
    body: PreferencesUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> PreferencesResponse:
    """Partially update the user's preferences.

    Only fields present (non-None) in the body are changed. This is the
    primary endpoint for incremental Flutter settings updates.

    Args:
        request: Incoming FastAPI request.
        body: Partial preference update payload.
        current_user: Authenticated :class:`User` ORM instance.
        db: Async database session.

    Returns:
        Full updated :class:`PreferencesResponse`.

    Raises:
        HTTPException: 400 for invalid enum values.
        HTTPException: 422 for malformed time strings.
    """
    sentry_sdk.set_user({"id": current_user.id})

    data = body.model_dump(exclude_none=True)
    _validate_enums(data)
    _validate_time_fields(data)

    prefs = await _get_or_create_prefs(current_user.id, db)
    _apply_update(prefs, data)
    await db.commit()
    await db.refresh(prefs)

    return PreferencesResponse.model_validate(prefs)
