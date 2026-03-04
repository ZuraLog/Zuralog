"""
Zuralog Cloud Brain — Streak API Routes.

Provides endpoints for reading a user's streaks and manually
consuming a freeze token to preserve a streak through a missed day.

Endpoints:
    GET  /api/v1/streaks                        — All streak types with counts
    POST /api/v1/streaks/{streak_type}/freeze   — Manually trigger a freeze
"""

import logging

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.deps import get_authenticated_user_id
from app.database import get_db
from app.models.user_streak import StreakType, UserStreak
from app.services.streak_tracker import StreakTracker

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/streaks",
    tags=["streaks"],
)

_tracker = StreakTracker()


def _serialize_streak(streak: UserStreak) -> dict:
    """Convert a UserStreak ORM row to a JSON-serialisable dict.

    Args:
        streak: The :class:`UserStreak` instance to serialise.

    Returns:
        Dict with all relevant streak fields.
    """
    return {
        "id": streak.id,
        "streak_type": streak.streak_type,
        "current_count": streak.current_count,
        "longest_count": streak.longest_count,
        "last_activity_date": streak.last_activity_date.isoformat() if streak.last_activity_date else None,
        "freeze_count": streak.freeze_count,
        "freeze_used_this_week": streak.freeze_used_this_week,
    }


@router.get("")
async def get_streaks(
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Return all streak records for the authenticated user.

    Only streak types that have been activated (at least one activity
    recorded) are returned. The client should render zero-state UI for
    any streak types absent from the response.

    Args:
        user_id: Authenticated user ID from JWT (injected by dependency).
        db: Injected async database session.

    Returns:
        Dict with a ``streaks`` list of streak objects.
    """
    streaks = await _tracker.get_streaks(user_id, db)
    return {"streaks": [_serialize_streak(s) for s in streaks]}


@router.post("/{streak_type}/freeze")
async def use_freeze(
    streak_type: str,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Manually consume a freeze token for the given streak type.

    A freeze prevents a streak from breaking through one missed day.
    Each user is limited to one freeze per week, accumulated up to 2.

    Args:
        streak_type: The streak category (``engagement``, ``steps``,
            ``workouts``, or ``checkin``).
        user_id: Authenticated user ID from JWT (injected by dependency).
        db: Injected async database session.

    Returns:
        Dict with the updated streak and a confirmation message.

    Raises:
        HTTPException: 400 if the streak_type string is invalid.
        HTTPException: 422 if no freeze tokens are available or the
            weekly limit has been reached.
    """
    # Validate streak_type
    try:
        streak_type_enum = StreakType(streak_type)
    except ValueError:
        valid = [t.value for t in StreakType]
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid streak_type '{streak_type}'. Must be one of: {valid}",
        )

    try:
        streak = await _tracker.use_freeze(user_id, streak_type_enum, db)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(exc),
        )

    return {
        "message": "Freeze applied",
        "streak": _serialize_streak(streak),
    }
