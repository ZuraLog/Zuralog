"""
Zuralog Cloud Brain — Achievement API.

Endpoints:
  GET /api/v1/achievements        — All achievements (locked + unlocked) for the current user.
  GET /api/v1/achievements/recent — Last 5 recently unlocked achievements.

All endpoints are auth-guarded via ``get_authenticated_user_id``.
Locked achievements (``unlocked_at=None``) are included in the full list
so the mobile client can render a "trophy case" with greyed-out cards.
"""

import logging
from typing import Any

import sentry_sdk
from fastapi import APIRouter, Depends
from pydantic import BaseModel, ConfigDict

from app.api.v1.deps import get_authenticated_user_id
from app.database import async_session
from app.services.achievement_tracker import AchievementTracker

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/achievements", tags=["achievements"])

# ---------------------------------------------------------------------------
# Pydantic schemas
# ---------------------------------------------------------------------------


class AchievementResponse(BaseModel):
    """A single achievement definition with locked/unlocked state.

    Attributes:
        key: Stable achievement identifier (e.g. ``"streak_7"``).
        name: Human-readable display name.
        description: Short description of the unlock condition.
        category: Category group name (e.g. ``"Consistency"``).
        unlocked_at: ISO-8601 timestamp when unlocked, or ``None`` if locked.
        is_unlocked: Convenience bool derived from ``unlocked_at``.
    """

    key: str
    name: str
    description: str
    category: str
    unlocked_at: str | None
    is_unlocked: bool

    model_config = ConfigDict(from_attributes=True)


class AchievementListResponse(BaseModel):
    """Envelope for the GET /achievements response.

    Attributes:
        achievements: Full list of achievement definitions with state.
        total: Total number of achievements in the registry.
        unlocked_count: Number of achievements the user has unlocked.
    """

    achievements: list[AchievementResponse]
    total: int
    unlocked_count: int


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------


@router.get("", summary="List all achievements (locked and unlocked)", response_model=AchievementListResponse)
async def list_achievements(
    user_id: str = Depends(get_authenticated_user_id),
) -> dict[str, Any]:
    """Return all achievement definitions with the user's locked/unlocked state.

    Merges the full achievement registry with the user's database rows so that
    locked achievements are also included. Clients should render locked
    achievements with a dimmed visual state.

    Args:
        user_id: Authenticated user ID (injected by dependency).

    Returns:
        ``{ achievements, total, unlocked_count }`` envelope.
    """
    sentry_sdk.set_user({"id": user_id})

    tracker = AchievementTracker()

    async with async_session() as db:
        achievements = await tracker.get_all(user_id=user_id, db=db)

    unlocked_count = sum(1 for a in achievements if a["is_unlocked"])

    logger.info(
        "list_achievements: user='%s' total=%d unlocked=%d",
        user_id,
        len(achievements),
        unlocked_count,
    )

    return {
        "achievements": achievements,
        "total": len(achievements),
        "unlocked_count": unlocked_count,
    }


@router.get("/recent", summary="List recently unlocked achievements", response_model=list[AchievementResponse])
async def list_recent_achievements(
    user_id: str = Depends(get_authenticated_user_id),
) -> list[dict[str, Any]]:
    """Return the last 5 achievements the user unlocked, newest first.

    Filters the full achievement list to those with a non-null
    ``unlocked_at`` timestamp, then sorts descending and returns up to 5.

    Args:
        user_id: Authenticated user ID (injected by dependency).

    Returns:
        List of up to 5 ``AchievementResponse`` objects sorted newest-first.
    """
    sentry_sdk.set_user({"id": user_id})

    tracker = AchievementTracker()

    async with async_session() as db:
        achievements = await tracker.get_all(user_id=user_id, db=db)

    # Filter to unlocked only, sort newest first, take top 5.
    unlocked = [a for a in achievements if a["is_unlocked"] and a["unlocked_at"] is not None]
    unlocked.sort(key=lambda a: a["unlocked_at"], reverse=True)
    recent = unlocked[:5]

    logger.info(
        "list_recent_achievements: user='%s' returning %d recent",
        user_id,
        len(recent),
    )

    return recent
