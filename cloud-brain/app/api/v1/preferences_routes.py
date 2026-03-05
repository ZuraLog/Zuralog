"""
Zuralog Cloud Brain — User Preferences API Router.

Provides GET / PUT / PATCH endpoints for reading and updating the
``user_preferences`` row for the authenticated user.

On first GET the row is created with all default values (lazy init).
PUT performs a full replace; PATCH performs a partial update — only
fields that are explicitly provided in the request body are written.
"""

import logging
import uuid

import sentry_sdk
from fastapi import APIRouter, Depends, HTTPException, Request, status
from pydantic import BaseModel, Field, field_validator
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.deps import get_authenticated_user_id
from app.database import get_db
from app.models.user_preferences import (
    CoachPersona,
    ProactivityLevel,
    Theme,
    UnitsSystem,
    UserPreferences,
)


def _make_default_prefs(user_id: str) -> UserPreferences:
    """Construct a UserPreferences instance with all Python-side defaults.

    SQLAlchemy does not apply ``column(default=...)`` values at constructor
    time — they are only applied at INSERT.  This helper passes all defaults
    explicitly so the in-memory object is valid before the DB round-trip.

    Args:
        user_id: The owning user's ID.

    Returns:
        A fully initialised UserPreferences instance (not yet persisted).
    """
    return UserPreferences(
        id=str(uuid.uuid4()),
        user_id=user_id,
        coach_persona=CoachPersona.BALANCED.value,
        proactivity_level=ProactivityLevel.MEDIUM.value,
        theme=Theme.DARK.value,
        haptic_enabled=True,
        tooltips_enabled=True,
        onboarding_complete=False,
        morning_briefing_enabled=False,
        checkin_reminder_enabled=False,
        quiet_hours_enabled=False,
        units_system=UnitsSystem.METRIC.value,
    )


from app.services.cache_service import CacheService, cached

logger = logging.getLogger(__name__)


async def _set_sentry_module() -> None:
    """Tag the current Sentry scope with the preferences module name."""
    sentry_sdk.set_tag("api.module", "preferences")


router = APIRouter(
    prefix="/preferences",
    tags=["preferences"],
    dependencies=[Depends(_set_sentry_module)],
)

# ---------------------------------------------------------------------------
# Pydantic schemas
# ---------------------------------------------------------------------------

_VALID_PERSONAS = {p.value for p in CoachPersona}
_VALID_PROACTIVITY = {p.value for p in ProactivityLevel}
_VALID_THEMES = {t.value for t in Theme}
_VALID_UNITS = {u.value for u in UnitsSystem}


class PreferencesUpdate(BaseModel):
    """Request body for PUT and PATCH preference endpoints.

    All fields are Optional — PATCH applies only those that are not None,
    PUT writes all fields (defaulting omitted ones to their initial defaults).

    Attributes:
        coach_persona: AI coaching style.
        proactivity_level: How often the coach proactively surfaces insights.
        dashboard_layout: Card order and visibility config (arbitrary JSON).
        notification_settings: Per-notification toggle map (arbitrary JSON).
        theme: Colour theme preference.
        haptic_enabled: Enable haptic feedback.
        tooltips_enabled: Show onboarding tooltips.
        onboarding_complete: Mark onboarding flow as done.
        morning_briefing_enabled: Enable daily morning briefing push.
        morning_briefing_time: Local time string for briefing (HH:MM or HH:MM:SS).
        checkin_reminder_enabled: Enable daily check-in reminder push.
        checkin_reminder_time: Local time string for reminder (HH:MM or HH:MM:SS).
        quiet_hours_enabled: Suppress pushes during quiet hours.
        quiet_hours_start: Start of quiet window (HH:MM or HH:MM:SS).
        quiet_hours_end: End of quiet window (HH:MM or HH:MM:SS).
        goals: Array of goal objects.
        units_system: Measurement system preference.
    """

    coach_persona: str | None = Field(
        default=None,
        description="AI coaching style: tough_love | balanced | gentle",
    )
    proactivity_level: str | None = Field(
        default=None,
        description="Coach proactivity: low | medium | high",
    )
    dashboard_layout: dict | None = Field(
        default=None,
        description="Card order and visibility config for the dashboard",
    )
    notification_settings: dict | None = Field(
        default=None,
        description="Per-notification-type toggle map",
    )
    theme: str | None = Field(
        default=None,
        description="Colour theme: dark | light | system",
    )
    haptic_enabled: bool | None = Field(default=None)
    tooltips_enabled: bool | None = Field(default=None)
    onboarding_complete: bool | None = Field(default=None)
    morning_briefing_enabled: bool | None = Field(default=None)
    morning_briefing_time: str | None = Field(
        default=None,
        description="Local time for morning briefing (HH:MM or HH:MM:SS)",
    )
    checkin_reminder_enabled: bool | None = Field(default=None)
    checkin_reminder_time: str | None = Field(
        default=None,
        description="Local time for check-in reminder (HH:MM or HH:MM:SS)",
    )
    quiet_hours_enabled: bool | None = Field(default=None)
    quiet_hours_start: str | None = Field(
        default=None,
        description="Start of quiet hours window (HH:MM or HH:MM:SS)",
    )
    quiet_hours_end: str | None = Field(
        default=None,
        description="End of quiet hours window (HH:MM or HH:MM:SS)",
    )
    goals: list | None = Field(
        default=None,
        description="Array of goal objects {metric, target, period}",
    )
    units_system: str | None = Field(
        default=None,
        description="Measurement system: metric | imperial",
    )

    @field_validator("coach_persona")
    @classmethod
    def validate_coach_persona(cls, v: str | None) -> str | None:
        """Validate coach_persona is a recognised enum value.

        Args:
            v: The incoming value.

        Returns:
            The validated string or None.

        Raises:
            ValueError: If the value is not a valid CoachPersona.
        """
        if v is not None and v not in _VALID_PERSONAS:
            raise ValueError(f"coach_persona must be one of: {', '.join(sorted(_VALID_PERSONAS))}")
        return v

    @field_validator("proactivity_level")
    @classmethod
    def validate_proactivity_level(cls, v: str | None) -> str | None:
        """Validate proactivity_level is a recognised enum value.

        Args:
            v: The incoming value.

        Returns:
            The validated string or None.

        Raises:
            ValueError: If the value is not a valid ProactivityLevel.
        """
        if v is not None and v not in _VALID_PROACTIVITY:
            raise ValueError(f"proactivity_level must be one of: {', '.join(sorted(_VALID_PROACTIVITY))}")
        return v

    @field_validator("theme")
    @classmethod
    def validate_theme(cls, v: str | None) -> str | None:
        """Validate theme is a recognised enum value.

        Args:
            v: The incoming value.

        Returns:
            The validated string or None.

        Raises:
            ValueError: If the value is not a valid Theme.
        """
        if v is not None and v not in _VALID_THEMES:
            raise ValueError(f"theme must be one of: {', '.join(sorted(_VALID_THEMES))}")
        return v

    @field_validator("units_system")
    @classmethod
    def validate_units_system(cls, v: str | None) -> str | None:
        """Validate units_system is a recognised enum value.

        Args:
            v: The incoming value.

        Returns:
            The validated string or None.

        Raises:
            ValueError: If the value is not a valid UnitsSystem.
        """
        if v is not None and v not in _VALID_UNITS:
            raise ValueError(f"units_system must be one of: {', '.join(sorted(_VALID_UNITS))}")
        return v


class PreferencesResponse(BaseModel):
    """API response schema for user preferences.

    Mirrors all UserPreferences columns with JSON-serializable types.
    Time fields are returned as ``HH:MM:SS`` strings; datetime fields
    as ISO-8601 strings.

    Attributes:
        id: Preferences row UUID.
        user_id: Owning user UUID.
        coach_persona: AI coaching style.
        proactivity_level: Coach proactivity level.
        dashboard_layout: Card order and visibility config.
        notification_settings: Per-notification toggle map.
        theme: Colour theme preference.
        haptic_enabled: Haptic feedback setting.
        tooltips_enabled: Tooltip visibility setting.
        onboarding_complete: Whether onboarding is done.
        morning_briefing_enabled: Morning briefing push toggle.
        morning_briefing_time: Time for morning briefing.
        checkin_reminder_enabled: Check-in reminder push toggle.
        checkin_reminder_time: Time for check-in reminder.
        quiet_hours_enabled: Quiet hours suppression toggle.
        quiet_hours_start: Start of quiet window.
        quiet_hours_end: End of quiet window.
        goals: Array of goal objects.
        units_system: Measurement system.
        created_at: Row creation ISO-8601 timestamp.
        updated_at: Last-update ISO-8601 timestamp.
    """

    model_config = {"from_attributes": True}

    id: str
    user_id: str
    coach_persona: str
    proactivity_level: str
    dashboard_layout: dict | None = None
    notification_settings: dict | None = None
    theme: str
    haptic_enabled: bool
    tooltips_enabled: bool
    onboarding_complete: bool
    morning_briefing_enabled: bool
    morning_briefing_time: str | None = None
    checkin_reminder_enabled: bool
    checkin_reminder_time: str | None = None
    quiet_hours_enabled: bool
    quiet_hours_start: str | None = None
    quiet_hours_end: str | None = None
    goals: list | None = None
    units_system: str
    created_at: str | None = None
    updated_at: str | None = None


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


_TIME_FIELDS = {
    "morning_briefing_time",
    "checkin_reminder_time",
    "quiet_hours_start",
    "quiet_hours_end",
}


def _parse_time(value: str | None) -> "datetime.time | None":
    """Parse a HH:MM or HH:MM:SS string into a ``datetime.time``.

    Returns ``None`` if the input is ``None``.
    """
    if value is None:
        return None
    import datetime

    parts = value.split(":")
    return datetime.time(int(parts[0]), int(parts[1]), int(parts[2]) if len(parts) > 2 else 0)


def _apply_update(prefs: UserPreferences, data: dict) -> None:
    """Apply a mapping of field→value onto a UserPreferences instance.

    Skips the ``id`` and ``user_id`` keys to prevent accidental overwrites.
    Converts time-string fields to ``datetime.time`` objects.

    Args:
        prefs: The ORM instance to mutate.
        data: Mapping of field name → new value.
    """
    protected = {"id", "user_id"}
    for field, value in data.items():
        if field not in protected:
            if field in _TIME_FIELDS and isinstance(value, str):
                value = _parse_time(value)
            setattr(prefs, field, value)


def _prefs_to_response(prefs: UserPreferences) -> PreferencesResponse:
    """Convert a UserPreferences ORM instance to a PreferencesResponse.

    Delegates serialisation of time and datetime fields to
    ``UserPreferences.to_dict()`` and then constructs the Pydantic model.

    Args:
        prefs: The ORM instance to convert.

    Returns:
        A ``PreferencesResponse`` ready for JSON serialisation.
    """
    return PreferencesResponse(**prefs.to_dict())


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------


@router.get("", response_model=PreferencesResponse)
@cached(prefix="preferences.get", ttl=900, key_params=["user_id"])
async def get_preferences(
    request: Request,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> PreferencesResponse:
    """Return the authenticated user's preferences.

    If no preferences row exists yet (first access), one is created with
    all defaults and immediately returned. This makes the endpoint
    idempotent and removes the need for a separate initialisation call.

    Args:
        request: Incoming FastAPI request (used for cache access).
        user_id: Authenticated user ID extracted from the JWT.
        db: Injected async database session.

    Returns:
        PreferencesResponse with all current preference values.
    """
    request.state.user_id = user_id
    sentry_sdk.set_user({"id": user_id})

    result = await db.execute(select(UserPreferences).where(UserPreferences.user_id == user_id))
    prefs: UserPreferences | None = result.scalar_one_or_none()

    if prefs is None:
        prefs = _make_default_prefs(user_id)
        db.add(prefs)
        await db.commit()
        await db.refresh(prefs)
        logger.info("Created default preferences for user_id=%s", user_id)

    return _prefs_to_response(prefs)


@router.put("", response_model=PreferencesResponse)
async def replace_preferences(
    request: Request,
    body: PreferencesUpdate,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> PreferencesResponse:
    """Full-replace the authenticated user's preferences.

    All fields in ``PreferencesUpdate`` are written; omitted fields reset
    to their defaults. Creates the row if it does not exist yet.

    Args:
        request: Incoming FastAPI request (used for cache invalidation).
        body: Full preferences payload.
        user_id: Authenticated user ID extracted from the JWT.
        db: Injected async database session.

    Returns:
        PreferencesResponse reflecting the saved state.
    """
    request.state.user_id = user_id
    sentry_sdk.set_user({"id": user_id})

    result = await db.execute(select(UserPreferences).where(UserPreferences.user_id == user_id))
    prefs: UserPreferences | None = result.scalar_one_or_none()

    if prefs is None:
        prefs = _make_default_prefs(user_id)
        db.add(prefs)

    # For PUT, only apply fields that the caller explicitly included.
    # Pydantic model_dump() returns None for omitted Optional fields, which
    # would overwrite non-nullable DB columns.  Using model_fields_set ensures
    # we only touch what was actually sent.
    update_data = {k: v for k, v in body.model_dump().items() if k in body.model_fields_set}
    _apply_update(prefs, update_data)

    await db.commit()
    await db.refresh(prefs)

    await _invalidate_cache(request, user_id)
    return _prefs_to_response(prefs)


@router.patch("", response_model=PreferencesResponse)
async def partial_update_preferences(
    request: Request,
    body: PreferencesUpdate,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> PreferencesResponse:
    """Partial-update the authenticated user's preferences.

    Only fields that are explicitly provided (non-None) in the request
    body are written. All other fields remain unchanged.

    Args:
        request: Incoming FastAPI request (used for cache invalidation).
        body: Partial preferences payload.
        user_id: Authenticated user ID extracted from the JWT.
        db: Injected async database session.

    Returns:
        PreferencesResponse reflecting the merged state.

    Raises:
        HTTPException: 400 if no fields are provided.
    """
    request.state.user_id = user_id
    sentry_sdk.set_user({"id": user_id})

    # Only include fields that the caller explicitly set.
    update_data = body.model_dump(exclude_none=True)
    if not update_data:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No fields provided to update.",
        )

    result = await db.execute(select(UserPreferences).where(UserPreferences.user_id == user_id))
    prefs: UserPreferences | None = result.scalar_one_or_none()

    if prefs is None:
        # Lazy creation — apply patch on top of defaults.
        prefs = _make_default_prefs(user_id)
        db.add(prefs)

    _apply_update(prefs, update_data)

    await db.commit()
    await db.refresh(prefs)

    await _invalidate_cache(request, user_id)
    return _prefs_to_response(prefs)


async def _invalidate_cache(request: Request, user_id: str) -> None:
    """Delete the cached preferences entry for a user.

    Args:
        request: FastAPI request carrying ``app.state.cache_service``.
        user_id: The user whose cache entry should be evicted.
    """
    cache: CacheService | None = getattr(request.app.state, "cache_service", None)
    if cache:
        await cache.delete(CacheService.make_key("preferences.get", user_id))
