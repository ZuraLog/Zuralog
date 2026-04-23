"""
Zuralog Cloud Brain — Streak Tracker Service.

Manages per-user activity streaks across four types:
    ``engagement``, ``steps``, ``workouts``, ``checkin``.

Streak mechanics:
- Activity on a date increments the streak if the previous activity was
  the prior day, or starts a fresh streak of 1 if no prior activity exists.
- A gap of more than 1 day resets the current streak to 1 (new start).
- Freeze tokens preserve a streak through one missed day.
  - Max 2 tokens accumulated at any time.
  - 1 free freeze per week (Monday reset).
  - ``use_freeze()`` is called by the user explicitly; it applies the
    freeze retroactively so the streak survives the missed day.

Milestone celebrations are returned by ``record_activity()`` for:
    7, 14, 30, 60, 90, 180, 365 days.

Classes:
    - StreakTracker: Stateless service for streak management.
"""

import logging
import uuid
from datetime import date, timedelta
from typing import Any

from sqlalchemy import select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user_streak import UserStreak

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

_VALID_STREAK_TYPES = frozenset({"engagement", "steps", "workouts", "checkin", "nutrition_goals"})
_MILESTONE_DAYS = frozenset({7, 14, 30, 60, 90, 180, 365})
_MAX_FREEZE_TOKENS = 2


class StreakTracker:
    """Stateless service for streak management.

    All methods accept an ``AsyncSession`` — the tracker holds no state.
    Instantiate once and reuse freely.
    """

    async def record_activity(
        self,
        user_id: str,
        streak_type: str,
        activity_date: date,
        db: AsyncSession,
    ) -> UserStreak:
        """Record activity for a given date and update the streak accordingly.

        Behaviour:
        - If no streak row exists, creates one with ``current_count=1``.
        - If the previous activity was yesterday, increments ``current_count``.
        - If the previous activity was today (duplicate call), no change.
        - If the gap is greater than 1 day, resets ``current_count`` to 1.
        - Updates ``longest_count`` if the new count exceeds it.

        Args:
            user_id: The authenticated user's ID.
            streak_type: One of ``engagement``, ``steps``, ``workouts``,
                ``checkin``.
            activity_date: The calendar date of the activity.
            db: Async database session.

        Returns:
            The updated (or newly created) :class:`UserStreak` instance.
        """
        date_str = activity_date.isoformat()

        result = await db.execute(
            select(UserStreak).where(
                UserStreak.user_id == user_id,
                UserStreak.streak_type == streak_type,
            )
        )
        streak = result.scalar_one_or_none()

        if streak is None:
            streak = UserStreak(
                id=str(uuid.uuid4()),
                user_id=user_id,
                streak_type=streak_type,
                current_count=1,
                longest_count=1,
                last_activity_date=date_str,
                freeze_count=0,
                freeze_used_this_week=False,
            )
            db.add(streak)
            try:
                await db.commit()
                await db.refresh(streak)
            except IntegrityError:
                # Race: another request created the row concurrently.
                await db.rollback()
                result = await db.execute(
                    select(UserStreak).where(
                        UserStreak.user_id == user_id,
                        UserStreak.streak_type == streak_type,
                    )
                )
                streak = result.scalar_one()

            logger.info(
                "record_activity: created streak '%s' for user '%s' on %s",
                streak_type,
                user_id,
                date_str,
            )
            return streak

        # Streak row already exists — determine increment/reset behaviour.
        if streak.last_activity_date is None:
            delta_days = None
        else:
            last_date = date.fromisoformat(streak.last_activity_date)
            delta_days = (activity_date - last_date).days

        if delta_days == 0:
            # Duplicate call for same day — idempotent.
            logger.debug(
                "record_activity: duplicate activity on %s for user '%s' streak '%s' — no change",
                date_str,
                user_id,
                streak_type,
            )
            return streak

        if delta_days == 1:
            # Consecutive day — increment.
            streak.current_count += 1
        else:
            # Gap > 1 day — reset streak.
            logger.info(
                "record_activity: gap of %s days detected for user '%s' streak '%s' — resetting to 1",
                delta_days,
                user_id,
                streak_type,
            )
            streak.current_count = 1

        streak.last_activity_date = date_str
        streak.is_frozen = False

        if streak.current_count > streak.longest_count:
            streak.longest_count = streak.current_count

        await db.commit()
        await db.refresh(streak)

        milestone = self._check_milestone(streak.current_count)
        if milestone:
            logger.info(
                "record_activity: milestone %d days for user '%s' streak '%s'",
                streak.current_count,
                user_id,
                streak_type,
            )

        return streak

    async def use_freeze(
        self,
        user_id: str,
        streak_type: str,
        db: AsyncSession,
    ) -> bool:
        """Consume a freeze token to keep a streak alive through a missed day.

        A freeze token can only be used if:
        - At least 1 freeze token is accumulated (``freeze_count > 0``).
        - The weekly free freeze has not already been used this week.

        Using a freeze extends the streak by treating the most recent missed
        day as if it were active. The caller is responsible for ensuring this
        is called during the grace period (e.g. the day after a miss).

        Args:
            user_id: The authenticated user's ID.
            streak_type: The streak type to apply the freeze to.
            db: Async database session.

        Returns:
            ``True`` if the freeze was successfully applied, ``False`` if no
            freeze tokens are available or the weekly limit is exhausted.
        """
        result = await db.execute(
            select(UserStreak).where(
                UserStreak.user_id == user_id,
                UserStreak.streak_type == streak_type,
            )
        )
        streak = result.scalar_one_or_none()

        if streak is None:
            logger.warning(
                "use_freeze: no streak '%s' found for user '%s'",
                streak_type,
                user_id,
            )
            return False

        if streak.freeze_count <= 0:
            logger.debug(
                "use_freeze: no freeze tokens available for user '%s' streak '%s'",
                user_id,
                streak_type,
            )
            return False

        if streak.freeze_used_this_week:
            logger.debug(
                "use_freeze: weekly freeze already used for user '%s' streak '%s'",
                user_id,
                streak_type,
            )
            return False

        streak.freeze_count -= 1
        streak.freeze_used_this_week = True
        streak.is_frozen = True

        # Extend last_activity_date by 1 day to bridge the gap so that the
        # next record_activity call sees only a 1-day delta.
        if streak.last_activity_date:
            last = date.fromisoformat(streak.last_activity_date)
            streak.last_activity_date = (last + timedelta(days=1)).isoformat()

        await db.commit()
        await db.refresh(streak)

        logger.info(
            "use_freeze: freeze applied for user '%s' streak '%s' — remaining=%d",
            user_id,
            streak_type,
            streak.freeze_count,
        )
        return True

    async def reset_weekly_freeze_flags(self, db: AsyncSession) -> None:
        """Reset ``freeze_used_this_week`` to False for all users.

        Also awards a free freeze token (up to the cap of 2) to each streak
        row. Called by Celery Beat every Monday.

        Args:
            db: Async database session.
        """
        # Two-step update because SQLAlchemy async doesn't support UPDATE with
        # CASE expressions cleanly across all dialects via the ORM update() call.
        # We fetch all rows and update in Python for correctness.
        result = await db.execute(select(UserStreak))
        streaks = result.scalars().all()

        for streak in streaks:
            streak.freeze_used_this_week = False
            # Award 1 free token per week, capped at MAX_FREEZE_TOKENS.
            if streak.freeze_count < _MAX_FREEZE_TOKENS:
                streak.freeze_count = min(
                    streak.freeze_count + 1, _MAX_FREEZE_TOKENS
                )

        await db.commit()
        logger.info(
            "reset_weekly_freeze_flags: reset %d streak rows",
            len(streaks),
        )

    async def get_all_streaks(
        self,
        user_id: str,
        db: AsyncSession,
    ) -> list[UserStreak]:
        """Return all streak rows for a user.

        Args:
            user_id: The authenticated user's ID.
            db: Async database session.

        Returns:
            List of :class:`UserStreak` ORM instances (may be empty).
        """
        result = await db.execute(
            select(UserStreak).where(UserStreak.user_id == user_id)
        )
        return list(result.scalars().all())

    # ---------------------------------------------------------------------------
    # Internal helpers
    # ---------------------------------------------------------------------------

    def _check_milestone(self, count: int) -> bool:
        """Return True if ``count`` is a milestone day.

        Args:
            count: Current streak day count.

        Returns:
            ``True`` if this count is a celebrated milestone.
        """
        return count in _MILESTONE_DAYS

    def get_milestone_data(self, count: int) -> dict[str, Any] | None:
        """Return celebration data for a milestone count, or None.

        Args:
            count: Current streak day count.

        Returns:
            A dict with ``days`` and ``message`` if ``count`` is a
            milestone, otherwise ``None``.
        """
        if count not in _MILESTONE_DAYS:
            return None

        messages = {
            7: "One week strong! Keep it up!",
            14: "Two weeks and counting — you're building a habit!",
            30: "30-day streak! You're on fire!",
            60: "Two months of consistency — incredible dedication!",
            90: "90 days! A true lifestyle change.",
            180: "Half a year! You're an inspiration.",
            365: "365 days — a full year of commitment. Legendary!",
        }
        return {
            "days": count,
            "message": messages.get(count, f"{count}-day milestone reached!"),
        }
