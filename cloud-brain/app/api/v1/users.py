"""
Zuralog Cloud Brain — User Preferences API.

Endpoints for reading and updating user profile preferences
such as coaching persona, subscription tier, and onboarding profile fields.
"""

import logging

import sentry_sdk
from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel
from collections.abc import Sequence
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.schemas import ChangeEmailRequest, MessageResponse, UpdateProfileRequest, UserProfileResponse
from app.database import get_db
from app.models.user import User
from app.services.auth_service import AuthService
from app.api.deps import _get_auth_service, get_authenticated_user_id, get_current_user
from app.limiter import limiter
from app.services.cache_service import CacheService, cached

logger = logging.getLogger(__name__)


async def _set_sentry_module() -> None:
    sentry_sdk.set_tag("api.module", "users")


router = APIRouter(
    prefix="/users",
    tags=["users"],
    dependencies=[Depends(_set_sentry_module)],
)
security = HTTPBearer()

VALID_PERSONAS = {"tough_love", "balanced", "gentle"}

_PROFILE_WRITABLE_FIELDS: frozenset[str] = frozenset({
    "display_name",
    "nickname",
    "birthday",
    "gender",
    "height_cm",
    "onboarding_complete",
})


class UpdatePreferencesRequest(BaseModel):
    """Request body for updating user preferences.

    Attributes:
        coach_persona: The coaching style preference.
    """

    coach_persona: str | None = None


@router.get("/me/preferences")
@cached(prefix="users.preferences", ttl=900, key_params=["user_id"])
async def get_preferences(
    request: Request,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Get the current user's AI preferences.

    Args:
        request: The incoming FastAPI request (used to set state for Sentry).
        user_id: Authenticated user ID from JWT (injected by dependency).
        db: Injected async database session.

    Returns:
        A dict with coach_persona, subscription_tier, and is_premium fields.

    Raises:
        HTTPException: 404 if the user is not found in the database.
    """
    request.state.user_id = user_id
    sentry_sdk.set_user({"id": user_id})

    result = await db.execute(select(User.coach_persona, User.subscription_tier).where(User.id == user_id))
    row = result.mappings().first()

    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    return {
        "coach_persona": row["coach_persona"],
        "subscription_tier": row["subscription_tier"],
        "is_premium": row["subscription_tier"] != "free",
    }


@router.patch("/me/preferences")
async def update_preferences(
    request: Request,
    body: UpdatePreferencesRequest,
    credentials: HTTPAuthorizationCredentials = Depends(security),
    auth_service: AuthService = Depends(_get_auth_service),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Update the current user's AI preferences.

    Args:
        request: The incoming FastAPI request (used to set state for Sentry).
        body: The request body containing fields to update.
        credentials: Bearer token from the Authorization header.
        auth_service: Injected auth service for token validation.
        db: Injected async database session.

    Returns:
        A confirmation dict with the updated persona.

    Raises:
        HTTPException: 400 if the persona is invalid or no fields provided.
    """
    user = await auth_service.get_user(credentials.credentials)
    user_id = user.get("id", "unknown")
    request.state.user_id = user_id
    sentry_sdk.set_user({"id": user_id})

    if body.coach_persona and body.coach_persona not in VALID_PERSONAS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid persona. Must be one of: {', '.join(sorted(VALID_PERSONAS))}",
        )

    if not body.coach_persona:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="No fields to update")

    await db.execute(
        text("UPDATE users SET coach_persona = :persona WHERE id = :uid"),
        {"persona": body.coach_persona, "uid": user_id},
    )
    await db.commit()

    # Invalidate cached preferences
    cache = getattr(request.app.state, "cache_service", None)
    if cache:
        await cache.delete(CacheService.make_key("users.preferences", user_id))

    return {"message": "Preferences updated", "coach_persona": body.coach_persona}


@router.get("/me/profile", response_model=UserProfileResponse)
@cached(prefix="users.profile", ttl=900, key_params=["user_id"])
async def get_profile(
    request: Request,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> UserProfileResponse:
    """Get the current user's profile.

    Args:
        request: The incoming FastAPI request (used to set state for Sentry).
        user_id: Authenticated user ID from JWT (injected by dependency).
        db: Injected async database session.

    Returns:
        UserProfileResponse with all profile fields.

    Raises:
        HTTPException: 404 if the user is not found in the database.
    """
    request.state.user_id = user_id
    sentry_sdk.set_user({"id": user_id})

    result = await db.execute(select(User).where(User.id == user_id))
    db_user = result.scalars().first()

    if db_user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    return UserProfileResponse.model_validate(db_user)


@router.patch("/me/profile", response_model=UserProfileResponse)
async def update_profile(
    request: Request,
    body: UpdateProfileRequest,
    credentials: HTTPAuthorizationCredentials = Depends(security),
    auth_service: AuthService = Depends(_get_auth_service),
    db: AsyncSession = Depends(get_db),
) -> UserProfileResponse:
    """Update the current user's profile.

    Only fields with non-None values in the request body are applied.

    Args:
        request: The incoming FastAPI request (used to set state for Sentry).
        body: Partial profile update payload.
        credentials: Bearer token from the Authorization header.
        auth_service: Injected auth service for token validation.
        db: Injected async database session.

    Returns:
        UserProfileResponse reflecting the updated state.

    Raises:
        HTTPException: 404 if the user is not found in the database.
    """
    user = await auth_service.get_user(credentials.credentials)
    user_id = user.get("id")
    if not user_id:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
    request.state.user_id = user_id
    sentry_sdk.set_user({"id": user_id})

    result = await db.execute(select(User).where(User.id == user_id))
    db_user = result.scalars().first()

    if db_user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    update_data = body.model_dump(exclude_none=True)
    if not update_data:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="No fields to update")
    for field, value in update_data.items():
        if field not in _PROFILE_WRITABLE_FIELDS:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Field '{field}' cannot be updated",
            )
        setattr(db_user, field, value)

    await db.commit()
    await db.refresh(db_user)

    # Invalidate cached profile
    cache = getattr(request.app.state, "cache_service", None)
    if cache:
        await cache.delete(CacheService.make_key("users.profile", user_id))

    return UserProfileResponse.model_validate(db_user)


@router.post("/me/email", response_model=MessageResponse)
@limiter.limit("3/hour")
async def change_email(
    request: Request,
    body: ChangeEmailRequest,
    credentials: HTTPAuthorizationCredentials = Depends(security),
    user_id: str = Depends(get_authenticated_user_id),
    auth_service: AuthService = Depends(_get_auth_service),
) -> MessageResponse:
    """Request an email address change.

    Sends a confirmation link to the new address. The change is not
    applied until the user clicks the link.

    Args:
        request: The incoming FastAPI request (required by the rate limiter).
        body: Request body containing the new email address.
        credentials: Bearer token from the Authorization header.
        user_id: Authenticated user ID from JWT (injected by dependency).
        auth_service: Injected auth service for the Supabase call.

    Returns:
        MessageResponse instructing the user to check their new inbox.

    Raises:
        HTTPException: 401 if the token is invalid.
        HTTPException: 400 if Supabase rejects the email change request.
        HTTPException: 429 if the rate limit is exceeded.
    """
    sentry_sdk.set_user({"id": user_id})
    await auth_service.update_user_email(
        access_token=credentials.credentials,
        new_email=str(body.new_email),
    )

    # Invalidate cached profile so any email read from cache is refreshed
    cache = getattr(request.app.state, "cache_service", None)
    if cache:
        await cache.delete(CacheService.make_key("users.profile", user_id))

    return MessageResponse(message="Check your new inbox to confirm.")


@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
async def delete_account(
    request: Request,
    credentials: HTTPAuthorizationCredentials = Depends(security),
    auth_service: AuthService = Depends(_get_auth_service),
    db: AsyncSession = Depends(get_db),
) -> None:
    """Delete the current user's account and all associated data (GDPR Art. 17)."""
    user_data = await auth_service.get_user(credentials.credentials)
    user_id = user_data.get("id")
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token",
        )

    # Delete health data rows (FK CASCADE handles linked tables,
    # but explicit deletion is safer for tables without FK constraints yet)
    tables_to_clear = [
        "daily_health_metrics",
        "unified_activities",
        "sleep_records",
        "nutrition_entries",
        "weight_measurements",
        "user_goals",
        "daily_summaries",
    ]
    for table in tables_to_clear:
        await db.execute(
            text(f"DELETE FROM {table} WHERE user_id = :uid"),
            {"uid": user_id},
        )

    # Delete the user row (cascades to integrations, conversations, etc.)
    await db.execute(text("DELETE FROM users WHERE id = :uid"), {"uid": user_id})
    await db.commit()

    # Delete from Supabase Auth (best-effort — don't fail the whole request)
    try:
        await auth_service.admin_delete_user(user_id)
    except Exception:
        logger.warning(
            "Failed to delete user %s from Supabase Auth; local data deleted",
            user_id,
            exc_info=True,
        )

    # Invalidate all cache entries for this user
    cache = getattr(request.app.state, "cache_service", None)
    if cache:
        await cache.invalidate_pattern(f"cache:*{user_id}*")


@router.get("/me/export")
async def export_user_data(
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Export all user data as JSON (GDPR Art. 20 — data portability)."""
    from app.models.daily_metrics import DailyHealthMetrics
    from app.models.health_data import (
        NutritionEntry,
        SleepRecord,
        UnifiedActivity,
        WeightMeasurement,
    )
    from app.models.user_goal import UserGoal

    # Fetch user profile
    result = await db.execute(select(User).where(User.id == user_id))
    db_user = result.scalars().first()
    if db_user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="User not found"
        )

    def _rows_to_dicts(rows: Sequence, columns: list[str]) -> list[dict]:
        return [{col: str(getattr(row, col, "")) for col in columns} for row in rows]

    # Collect data from each health table
    async def _fetch(model, cols):
        r = await db.execute(select(model).where(model.user_id == user_id))
        return _rows_to_dicts(list(r.scalars().all()), cols)

    return {
        "user": {
            "id": db_user.id,
            "email": db_user.email,
            "display_name": db_user.display_name,
            "nickname": db_user.nickname,
            "created_at": str(db_user.created_at),
        },
        "daily_metrics": await _fetch(
            DailyHealthMetrics,
            ["date", "source", "steps", "active_calories", "resting_heart_rate"],
        ),
        "activities": await _fetch(
            UnifiedActivity,
            ["source", "original_id", "activity_type", "duration_seconds", "calories", "start_time"],
        ),
        "sleep": await _fetch(SleepRecord, ["source", "date", "hours", "quality_score"]),
        "nutrition": await _fetch(
            NutritionEntry, ["source", "date", "calories", "protein_grams", "carbs_grams", "fat_grams"]
        ),
        "weight": await _fetch(WeightMeasurement, ["source", "date", "weight_kg"]),
        "goals": await _fetch(
            UserGoal, ["metric", "target_value", "period", "is_active", "start_date", "deadline"]
        ),
    }
