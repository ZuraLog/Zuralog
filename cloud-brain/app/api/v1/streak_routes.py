"""
Zuralog Cloud Brain — Streak API.

Endpoints:
  GET  /api/v1/streaks                      — All streaks for the current user.
  POST /api/v1/streaks/{streak_type}/freeze — Consume a freeze token for a streak.

All endpoints are auth-guarded via ``get_authenticated_user_id``.
Streaks are tracked per type: ``engagement``, ``steps``, ``workouts``, ``checkin``.
"""

import logging

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, ConfigDict
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.deps import get_authenticated_user_id
from app.database import get_db
from app.models.user_streak import UserStreak
from app.services.streak_tracker import StreakTracker, _VALID_STREAK_TYPES

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/streaks", tags=["streaks"])

# ---------------------------------------------------------------------------
# Pydantic schemas
# ---------------------------------------------------------------------------


class StreakResponse(BaseModel):
    """A single user streak record.

    Attributes:
        id: UUID primary key.
        user_id: Owner's user ID.
        streak_type: Activity category (``engagement``, ``steps``, ``workouts``, ``checkin``).
        current_count: Current consecutive-day streak length.
        longest_count: All-time longest streak for this type.
        last_activity_date: Most-recent active day as YYYY-MM-DD, or ``None``.
        freeze_count: Accumulated freeze tokens (0–2).
        freeze_used_this_week: Whether the free weekly freeze has been used.
    """

    id: str
    user_id: str
    streak_type: str
    current_count: int
    longest_count: int
    last_activity_date: str | None
    freeze_count: int
    freeze_used_this_week: bool

    model_config = ConfigDict(from_attributes=True)


class FreezeResponse(BaseModel):
    """Response for a successful freeze token consumption.

    Attributes:
        success: Always ``True`` when the freeze was applied.
        streak_type: The streak type the freeze was applied to.
        message: Human-readable confirmation message.
    """

    success: bool
    streak_type: str
    message: str


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _streak_to_response(streak: UserStreak) -> dict:
    """Serialise a UserStreak ORM object to a response dict.

    Args:
        streak: The ORM instance to serialise.

    Returns:
        Dict suitable for the StreakResponse schema.
    """
    return {
        "id": streak.id,
        "user_id": streak.user_id,
        "streak_type": streak.streak_type,
        "current_count": streak.current_count,
        "longest_count": streak.longest_count,
        "last_activity_date": streak.last_activity_date,
        "freeze_count": streak.freeze_count,
        "freeze_used_this_week": streak.freeze_used_this_week,
    }


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------


@router.get("", summary="List all streaks for the current user", response_model=list[StreakResponse])
async def list_streaks(
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> list[dict]:
    """Return all streak rows for the authenticated user.

    Returns one entry per streak type that has been initialised (i.e. at
    least one activity has been recorded). Types with no activity are
    omitted — the client should treat a missing type as ``current_count=0``.

    Args:
        user_id: Authenticated user ID (injected by dependency).
        db: Async database session.

    Returns:
        List of ``StreakResponse`` objects (may be empty).
    """
    tracker = StreakTracker()
    streaks = await tracker.get_all_streaks(user_id=user_id, db=db)

    logger.info(
        "list_streaks: user='%s' found %d streak(s)",
        user_id,
        len(streaks),
    )

    return [_streak_to_response(s) for s in streaks]


@router.post(
    "/{streak_type}/freeze",
    summary="Consume a freeze token to preserve a streak",
    response_model=FreezeResponse,
)
async def use_streak_freeze(
    streak_type: str,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Consume a freeze token to keep a streak alive through a missed day.

    A freeze can only be applied if:
    - ``streak_type`` is one of ``engagement``, ``steps``, ``workouts``, ``checkin``.
    - The user has at least 1 accumulated freeze token (``freeze_count > 0``).
    - The free weekly freeze has not already been used this week.

    Args:
        streak_type: The streak type path parameter (must be a valid type).
        user_id: Authenticated user ID (injected by dependency).
        db: Async database session.

    Returns:
        ``FreezeResponse`` confirming the freeze was applied.

    Raises:
        HTTPException: 400 if ``streak_type`` is invalid.
        HTTPException: 409 if no freeze tokens are available or weekly limit is reached.
    """
    if streak_type not in _VALID_STREAK_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                f"Invalid streak_type '{streak_type}'. "
                f"Must be one of: {', '.join(sorted(_VALID_STREAK_TYPES))}."
            ),
        )

    tracker = StreakTracker()
    applied = await tracker.use_freeze(user_id=user_id, streak_type=streak_type, db=db)

    if not applied:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=(
                "No freeze tokens available or the weekly freeze limit has already been used. "
                "Earn freeze tokens by maintaining your streak."
            ),
        )

    logger.info(
        "use_streak_freeze: freeze applied for user='%s' streak_type='%s'",
        user_id,
        streak_type,
    )

    return {
        "success": True,
        "streak_type": streak_type,
        "message": f"Freeze token applied to your '{streak_type}' streak. Keep it going!",
    }
