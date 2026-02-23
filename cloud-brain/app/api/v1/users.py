"""
Zuralog Cloud Brain — User Preferences API.

Endpoints for reading and updating user profile preferences
such as coaching persona and subscription tier.
"""

import logging

from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.services.auth_service import AuthService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/users", tags=["users"])
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
    credentials: HTTPAuthorizationCredentials = Depends(security),
    auth_service: AuthService = Depends(_get_auth_service),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Get the current user's AI preferences.

    Args:
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
    body: UpdatePreferencesRequest,
    credentials: HTTPAuthorizationCredentials = Depends(security),
    auth_service: AuthService = Depends(_get_auth_service),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Update the current user's AI preferences.

    Args:
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
