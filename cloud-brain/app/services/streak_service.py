"""Streak business logic service — single source of truth for freeze operations."""

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.models.user_streak import UserStreak
from app.services.streak_tracker import StreakTracker


async def apply_streak_freeze(
    db: AsyncSession, user_id: str, streak_type: str
) -> dict:
    """Apply a streak freeze for the given user and streak type.

    Eligibility rules (all must pass):
    - Streak exists for this user + type
    - freeze_count > 0 (tokens available)
    - is_frozen is False (not already frozen)
    - freeze_used_this_week is False (weekly limit not reached)

    Raises ValueError with a code string on ineligibility.
    Returns a success dict on success.
    """
    result = await db.execute(
        select(UserStreak).where(
            UserStreak.user_id == user_id,
            UserStreak.streak_type == streak_type,
        )
    )
    streak = result.scalar_one_or_none()

    if streak is None:
        raise ValueError("streak_not_found")
    if streak.freeze_count <= 0:
        raise ValueError("no_tokens")
    if streak.is_frozen:
        raise ValueError("already_frozen")
    if streak.freeze_used_this_week:
        raise ValueError("weekly_limit_reached")

    tracker = StreakTracker()
    await tracker.use_freeze(user_id=user_id, streak_type=streak_type, db=db)

    # Ensure is_frozen is set (tracker may not set it — belt-and-suspenders)
    streak_result = await db.execute(
        select(UserStreak).where(
            UserStreak.user_id == user_id,
            UserStreak.streak_type == streak_type,
        )
    )
    updated_streak = streak_result.scalar_one_or_none()
    if updated_streak and not updated_streak.is_frozen:
        updated_streak.is_frozen = True
        await db.commit()

    return {
        "success": True,
        "streak_type": streak_type,
        "message": "Streak frozen successfully.",
        "freeze_tokens_remaining": max(0, (updated_streak.freeze_count if updated_streak else 0)),
    }


async def get_freeze_status(
    db: AsyncSession, user_id: str, streak_type: str
) -> dict:
    """Return the current freeze eligibility status for a streak."""
    result = await db.execute(
        select(UserStreak).where(
            UserStreak.user_id == user_id,
            UserStreak.streak_type == streak_type,
        )
    )
    streak = result.scalar_one_or_none()

    if streak is None:
        return {"is_frozen": False, "freeze_tokens_available": 0, "freeze_used_this_week": False}

    return {
        "is_frozen": streak.is_frozen,
        "freeze_tokens_available": streak.freeze_count,
        "freeze_used_this_week": streak.freeze_used_this_week,
    }
