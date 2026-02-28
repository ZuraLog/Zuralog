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
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.schemas import UpdateProfileRequest, UserProfileResponse
from app.database import get_db
from app.models.user import User
from app.services.auth_service import AuthService

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


class UpdatePreferencesRequest(BaseModel):
    """Request body for updating user preferences.

    Attributes:
        coach_persona: The coaching style preference.
    """

    coach_persona: str | None = None


def _get_auth_service(request: Request) -> AuthService:
    """Retrieve the shared AuthService from app state.

    Args:
        request: The incoming FastAPI request.

    Returns:
        The shared AuthService instance.
    """
    return request.app.state.auth_service


@router.get("/me/preferences")
async def get_preferences(
    request: Request,
    credentials: HTTPAuthorizationCredentials = Depends(security),
    auth_service: AuthService = Depends(_get_auth_service),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Get the current user's AI preferences.

    Args:
        request: The incoming FastAPI request (used to set state for Sentry).
        credentials: Bearer token from the Authorization header.
        auth_service: Injected auth service for token validation.
        db: Injected async database session.

    Returns:
        A dict with coach_persona, subscription_tier, and is_premium fields.

    Raises:
        HTTPException: 404 if the user is not found in the database.
    """
    user = await auth_service.get_user(credentials.credentials)
    user_id = user.get("id", "unknown")
    request.state.user_id = user_id
    sentry_sdk.set_user({"id": user_id})

    result = await db.execute(
        text("SELECT coach_persona, subscription_tier FROM users WHERE id = :uid"),
        {"uid": user_id},
    )
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

    return {"message": "Preferences updated", "coach_persona": body.coach_persona}


@router.get("/me/profile", response_model=UserProfileResponse)
async def get_profile(
    request: Request,
    credentials: HTTPAuthorizationCredentials = Depends(security),
    auth_service: AuthService = Depends(_get_auth_service),
    db: AsyncSession = Depends(get_db),
) -> UserProfileResponse:
    """Get the current user's profile.

    Args:
        request: The incoming FastAPI request (used to set state for Sentry).
        credentials: Bearer token from the Authorization header.
        auth_service: Injected auth service for token validation.
        db: Injected async database session.

    Returns:
        UserProfileResponse with all profile fields.

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
        setattr(db_user, field, value)

    await db.commit()
    await db.refresh(db_user)

    return UserProfileResponse.model_validate(db_user)
