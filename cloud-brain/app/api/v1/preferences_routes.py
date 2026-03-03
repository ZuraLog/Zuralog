"""
Zuralog Cloud Brain — User Preferences API.

Endpoints:
  GET  /api/v1/preferences  — Return current user's preferences, auto-creating
                              with defaults on first call (upsert behaviour).
  PUT  /api/v1/preferences  — Full replacement of all preference fields.
  PATCH /api/v1/preferences — Partial update (only provided fields are changed).

All endpoints are auth-guarded; users can only access their own preferences.
"""

import logging
from datetime import time
from typing import Any

import sentry_sdk
from fastapi import APIRouter, Depends, HTTPException, Request, status
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.deps import get_authenticated_user_id
from app.database import get_db
from app.models.user_preferences import UserPreferences
from app.services.cache_service import CacheService, cached

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/preferences", tags=["preferences"])

# ---------------------------------------------------------------------------
# Valid enum values
# ---------------------------------------------------------------------------

_VALID_PERSONAS = {"tough_love", "balanced", "gentle"}
_VALID_PROACTIVITY = {"low", "medium", "high"}
_VALID_THEMES = {"dark", "light", "system"}

# ---------------------------------------------------------------------------
# Default values applied on first-access creation
# ---------------------------------------------------------------------------

_DEFAULT_NOTIFICATION_SETTINGS: dict[str, Any] = {
    "morning_briefing_enabled": True,
    "smart_reminders_enabled": True,
    "reminder_frequency": 2,
    "streak_reminders": True,
    "achievement_notifications": True,
    "anomaly_alerts": True,
    "integration_alerts": True,
    "wellness_checkin_reminder": False,
}

# ---------------------------------------------------------------------------
# Pydantic schemas
# ---------------------------------------------------------------------------


class PreferencesResponse(BaseModel):
    """Full preferences payload returned to the client.

    All nullable fields are omitted when None (exclude_none on serialise).
    """

    coach_persona: str
    proactivity_level: str
    dashboard_layout: Any = None
    notification_settings: dict[str, Any] | None = None
    theme: str
    haptic_enabled: bool
    tooltips_enabled: bool
    onboarding_complete: bool
    morning_briefing_time: str | None = None
    checkin_reminder_time: str | None = None
    quiet_hours_start: str | None = None
    quiet_hours_end: str | None = None
    goals: list[str] | None = None

    model_config = {"from_attributes": True}


class PreferencesUpdateRequest(BaseModel):
    """Body for PUT (full replacement) — all optional with defaults."""

    coach_persona: str | None = Field(None, description="tough_love | balanced | gentle")
    proactivity_level: str | None = Field(None, description="low | medium | high")
    dashboard_layout: Any | None = None
    notification_settings: dict[str, Any] | None = None
    theme: str | None = Field(None, description="dark | light | system")
    haptic_enabled: bool | None = None
    tooltips_enabled: bool | None = None
    onboarding_complete: bool | None = None
    morning_briefing_time: str | None = Field(None, description="HH:MM (24-hour)")
    checkin_reminder_time: str | None = Field(None, description="HH:MM (24-hour)")
    quiet_hours_start: str | None = Field(None, description="HH:MM (24-hour)")
    quiet_hours_end: str | None = Field(None, description="HH:MM (24-hour)")
    goals: list[str] | None = None


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _parse_time(value: str | None) -> time | None:
    """Parse an 'HH:MM' string to a :class:`datetime.time`.

    Args:
        value: Time string in 24-hour ``HH:MM`` format, or ``None``.

    Returns:
        :class:`datetime.time` or ``None``.

    Raises:
        HTTPException: 422 if the string cannot be parsed.
    """
    if value is None:
        return None
    try:
        parts = value.strip().split(":")
        return time(int(parts[0]), int(parts[1]))
    except (ValueError, IndexError):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Invalid time format '{value}'. Expected HH:MM.",
        )


def _time_str(t: time | None) -> str | None:
    """Format a :class:`datetime.time` as ``HH:MM``, or ``None``."""
    return t.strftime("%H:%M") if t else None


def _prefs_to_response(prefs: UserPreferences) -> dict[str, Any]:
    """Convert a ``UserPreferences`` ORM object to a serialisable dict."""
    return {
        "coach_persona": prefs.coach_persona,
        "proactivity_level": prefs.proactivity_level,
        "dashboard_layout": prefs.dashboard_layout,
        "notification_settings": prefs.notification_settings,
        "theme": prefs.theme,
        "haptic_enabled": prefs.haptic_enabled,
        "tooltips_enabled": prefs.tooltips_enabled,
        "onboarding_complete": prefs.onboarding_complete,
        "morning_briefing_time": _time_str(prefs.morning_briefing_time),
        "checkin_reminder_time": _time_str(prefs.checkin_reminder_time),
        "quiet_hours_start": _time_str(prefs.quiet_hours_start),
        "quiet_hours_end": _time_str(prefs.quiet_hours_end),
        "goals": prefs.goals,
    }


def _validate_update(body: PreferencesUpdateRequest) -> None:
    """Validate enum-valued fields in the update body.

    Args:
        body: Incoming update request.

    Raises:
        HTTPException: 400 if any enum field contains an invalid value.
    """
    if body.coach_persona and body.coach_persona not in _VALID_PERSONAS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"coach_persona must be one of: {sorted(_VALID_PERSONAS)}",
        )
    if body.proactivity_level and body.proactivity_level not in _VALID_PROACTIVITY:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"proactivity_level must be one of: {sorted(_VALID_PROACTIVITY)}",
        )
    if body.theme and body.theme not in _VALID_THEMES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"theme must be one of: {sorted(_VALID_THEMES)}",
        )


async def _get_or_create_prefs(user_id: str, db: AsyncSession) -> UserPreferences:
    """Fetch or auto-create the user's preferences row with defaults.

    Args:
        user_id: Authenticated user's ID.
        db: Async database session.

    Returns:
        The existing or newly-created :class:`UserPreferences` instance.
    """
    result = await db.execute(
        select(UserPreferences).where(UserPreferences.user_id == user_id)
    )
    prefs = result.scalar_one_or_none()

    if prefs is None:
        prefs = UserPreferences(
            user_id=user_id,
            notification_settings=_DEFAULT_NOTIFICATION_SETTINGS,
        )
        db.add(prefs)
        await db.commit()
        await db.refresh(prefs)
        logger.info("Created default preferences for user %s", user_id)

    return prefs


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------


@router.get("", summary="Get user preferences")
@cached(prefix="preferences", ttl=300, key_params=["user_id"])
async def get_preferences(
    request: Request,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> dict[str, Any]:
    """Return the current user's preferences, creating defaults on first call.

    Args:
        request: Incoming FastAPI request (used for Sentry context).
        user_id: Authenticated user ID (injected by dependency).
        db: Async database session.

    Returns:
        Full preferences dict.
    """
    request.state.user_id = user_id
    sentry_sdk.set_user({"id": user_id})

    prefs = await _get_or_create_prefs(user_id, db)
    return _prefs_to_response(prefs)


@router.put("", summary="Replace user preferences (full update)")
async def put_preferences(
    request: Request,
    body: PreferencesUpdateRequest,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> dict[str, Any]:
    """Full replacement of the user's preferences.

    Any field omitted from the request body is left at its current value
    (or default if not yet set). Equivalent to PATCH for convenience.

    Args:
        request: Incoming FastAPI request.
        body: Preference fields to update.
        user_id: Authenticated user ID.
        db: Async database session.

    Returns:
        Updated preferences dict.
    """
    request.state.user_id = user_id
    sentry_sdk.set_user({"id": user_id})
    _validate_update(body)

    prefs = await _get_or_create_prefs(user_id, db)
    _apply_update(prefs, body)
    await db.commit()
    await db.refresh(prefs)

    # Invalidate cache
    cache: CacheService | None = getattr(request.app.state, "cache_service", None)
    if cache:
        await cache.delete(CacheService.make_key("preferences", user_id))

    return _prefs_to_response(prefs)


@router.patch("", summary="Partially update user preferences")
async def patch_preferences(
    request: Request,
    body: PreferencesUpdateRequest,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> dict[str, Any]:
    """Partially update the user's preferences.

    Only fields present (non-None) in the body are changed. This is the
    primary endpoint for incremental Flutter settings updates.

    Args:
        request: Incoming FastAPI request.
        body: Partial preference update payload.
        user_id: Authenticated user ID.
        db: Async database session.

    Returns:
        Full updated preferences dict.
    """
    request.state.user_id = user_id
    sentry_sdk.set_user({"id": user_id})
    _validate_update(body)

    prefs = await _get_or_create_prefs(user_id, db)
    _apply_update(prefs, body, partial=True)
    await db.commit()
    await db.refresh(prefs)

    # Invalidate cache
    cache: CacheService | None = getattr(request.app.state, "cache_service", None)
    if cache:
        await cache.delete(CacheService.make_key("preferences", user_id))

    return _prefs_to_response(prefs)


# ---------------------------------------------------------------------------
# Internal update helper
# ---------------------------------------------------------------------------


def _apply_update(
    prefs: UserPreferences,
    body: PreferencesUpdateRequest,
    partial: bool = False,
) -> None:
    """Apply update body fields onto the ORM instance.

    Args:
        prefs: The ORM instance to mutate.
        body: Incoming update payload.
        partial: When True, skip fields that are None in the body.
    """
    updates = body.model_dump(exclude_none=True) if partial else body.model_dump()

    field_map = {
        "coach_persona": "coach_persona",
        "proactivity_level": "proactivity_level",
        "dashboard_layout": "dashboard_layout",
        "notification_settings": "notification_settings",
        "theme": "theme",
        "haptic_enabled": "haptic_enabled",
        "tooltips_enabled": "tooltips_enabled",
        "onboarding_complete": "onboarding_complete",
        "goals": "goals",
    }

    for body_field, model_field in field_map.items():
        if body_field in updates:
            setattr(prefs, model_field, updates[body_field])

    # Time fields require parsing from HH:MM strings
    for body_field, model_field in [
        ("morning_briefing_time", "morning_briefing_time"),
        ("checkin_reminder_time", "checkin_reminder_time"),
        ("quiet_hours_start", "quiet_hours_start"),
        ("quiet_hours_end", "quiet_hours_end"),
    ]:
        if body_field in updates:
            setattr(prefs, model_field, _parse_time(updates[body_field]))
