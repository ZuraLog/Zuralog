"""
Zuralog Cloud Brain — User Preferences API.

Endpoints for reading and updating user profile preferences
such as coaching persona, subscription tier, and onboarding profile fields.
"""

import logging

import filetype
import sentry_sdk
from fastapi import APIRouter, Depends, HTTPException, Request, UploadFile, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel
from collections.abc import Sequence
from sqlalchemy import select, text, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.schemas import AvatarUploadResponse, ChangeEmailRequest, ChangePasswordRequest, MessageResponse, UpdateProfileRequest, UserProfileResponse
from app.config import settings
from app.database import get_db
from app.models.user import User
from app.services.auth_service import AuthService
from app.services.storage_service import StorageService
from app.api.deps import _get_auth_service, get_authenticated_user_id, get_current_user
from app.limiter import limiter
from app.services.cache_service import CacheService, cached

logger = logging.getLogger(__name__)

_AVATAR_MAX_BYTES = 5 * 1024 * 1024  # 5 MB
_ALLOWED_MIME_TYPES: frozenset[str] = frozenset({"image/jpeg", "image/png", "image/webp"})
_MIME_TO_EXT: dict[str, str] = {"image/jpeg": "jpg", "image/png": "png", "image/webp": "webp"}


def _get_storage_service(request: Request) -> StorageService:
    """FastAPI dependency that retrieves the shared StorageService from app state."""
    return request.app.state.storage_service


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


@router.post("/me/password", response_model=MessageResponse)
@limiter.limit("3/hour")
async def change_password(
    request: Request,
    body: ChangePasswordRequest,
    credentials: HTTPAuthorizationCredentials = Depends(security),
    user_id: str = Depends(get_authenticated_user_id),
    auth_service: AuthService = Depends(_get_auth_service),
    db: AsyncSession = Depends(get_db),
) -> MessageResponse:
    """Change the current user's password.

    Verifies the current password by re-authenticating before applying the
    change. Social login users (Google/Apple) have no Supabase password and
    will always receive a 401 — the Flutter client handles the UX for that.

    Args:
        request: The incoming FastAPI request (required by the rate limiter).
        body: Request body containing current_password and new_password.
        credentials: Bearer token from the Authorization header.
        user_id: Authenticated user ID from JWT (injected by dependency).
        auth_service: Injected auth service for Supabase calls.
        db: Injected async database session.

    Returns:
        MessageResponse confirming the password was changed.

    Raises:
        HTTPException: 401 if the current password is wrong (or the user is
            a social login user with no password set).
        HTTPException: 400 if Supabase rejects the new password.
        HTTPException: 404 if the user row is not found in the local database.
        HTTPException: 429 if the rate limit is exceeded.
    """
    sentry_sdk.set_user({"id": user_id})

    # Look up the user's email — needed to re-authenticate for verification.
    result = await db.execute(select(User.email).where(User.id == user_id))
    email = result.scalar_one_or_none()
    if email is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found.")

    # Verify the current password by attempting a fresh sign-in.
    try:
        await auth_service.sign_in(email, body.current_password)
    except HTTPException as exc:
        if exc.status_code == status.HTTP_401_UNAUTHORIZED:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Current password is incorrect.",
            )
        raise  # propagate 503/504/502 as-is

    # Apply the new password using the user's own token (not the service key).
    await auth_service.update_user_password(
        access_token=credentials.credentials,
        new_password=body.new_password,
    )

    # Invalidate cached profile in case any derived data changes.
    cache = getattr(request.app.state, "cache_service", None)
    if cache:
        await cache.delete(CacheService.make_key("users.profile", user_id))

    return MessageResponse(message="Password updated successfully.")


@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
@limiter.limit("3/day")
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


@router.post("/me/avatar", response_model=AvatarUploadResponse)
@limiter.limit("10/hour")
async def upload_avatar(
    request: Request,
    file: UploadFile,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
    storage: StorageService = Depends(_get_storage_service),
) -> AvatarUploadResponse:
    """Upload or replace the current user's profile picture.

    Validates the file size (max 5 MB) and actual MIME type via magic bytes
    before uploading to Supabase Storage. The uploaded image always overwrites
    the previous one at a deterministic path so the bucket never grows unbounded.

    Args:
        request: The incoming FastAPI request (required by the rate limiter).
        file: The image file uploaded by the client (multipart/form-data).
        user_id: Authenticated user ID from JWT (injected by dependency).
        db: Injected async database session.
        storage: Injected storage service for Supabase bucket uploads.

    Returns:
        AvatarUploadResponse containing the public URL of the uploaded image.

    Raises:
        HTTPException: 413 if the file exceeds 5 MB.
        HTTPException: 415 if the file is not a JPEG, PNG, or WebP image.
        HTTPException: 500 if a valid public URL could not be constructed.
        HTTPException: 429 if the rate limit is exceeded.
    """
    sentry_sdk.set_user({"id": user_id})

    # Read up to 5 MB + 1 byte so we can detect oversized files without
    # buffering the entire upload into memory first.
    data = await file.read(_AVATAR_MAX_BYTES + 1)
    if len(data) > _AVATAR_MAX_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="File too large. Maximum size is 5 MB.",
        )

    # Validate the actual file type from magic bytes — never trust the
    # Content-Type header, which clients can set to anything.
    kind = filetype.guess(data)
    mime_type = kind.mime if kind else None
    if mime_type not in _ALLOWED_MIME_TYPES:
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail="Unsupported file type. Upload a JPEG, PNG, or WebP image.",
        )

    ext = _MIME_TO_EXT[mime_type]
    storage_path = f"{user_id}/avatar.{ext}"

    # Remove any avatar files stored under the other two possible extensions so
    # the bucket never accumulates stale files when a user switches format
    # (e.g. uploads a PNG after previously uploading a JPEG).
    stale_exts = {"jpg", "png", "webp"} - {ext}
    for stale_ext in stale_exts:
        try:
            await storage.delete_file(
                bucket=settings.avatar_bucket,
                paths=[f"{user_id}/avatar.{stale_ext}"],
            )
        except Exception:
            pass  # file didn't exist or already deleted — not an error

    # Upload to the configured avatars bucket, overwriting any existing file.
    await storage.upload_file(
        bucket=settings.avatar_bucket,
        path=storage_path,
        content=data,
        content_type=mime_type,
        upsert=True,
    )

    # Build the public URL from the Supabase project URL — never hardcode a domain.
    base_url = settings.supabase_url.strip().rstrip("/")
    avatar_url = f"{base_url}/storage/v1/object/public/{settings.avatar_bucket}/{storage_path}"

    if not avatar_url.startswith("https://"):
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to build a valid avatar URL.",
        )

    # Persist the URL on the user's profile row.
    await db.execute(update(User).where(User.id == user_id).values(avatar_url=avatar_url))
    await db.commit()

    # Invalidate the cached profile so the new avatar_url is immediately visible.
    cache = getattr(request.app.state, "cache_service", None)
    if cache:
        await cache.delete(CacheService.make_key("users.profile", user_id))

    return AvatarUploadResponse(avatar_url=avatar_url)
