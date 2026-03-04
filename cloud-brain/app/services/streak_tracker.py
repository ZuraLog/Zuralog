"""
Zuralog Cloud Brain — Streak Tracker Service.

Manages streak records: recording daily activities, applying freeze tokens
to preserve broken streaks, returning milestone flags, and resetting weekly
freeze allocations via a scheduled Celery task.

Freeze mechanic summary:
    - Each user starts with 1 freeze token (first-week freebie).
    - The weekly Celery beat task increments freeze_count by 1 (max 2) and
      resets freeze_used_this_week=False for every user.
    - When a streak would break (gap > 1 day), an auto-freeze is applied if:
        (a) freeze_count > 0, AND
        (b) freeze_used_this_week is False.
    - Manual freeze via use_freeze() follows the same guards.

Usage:
    tracker = StreakTracker()
    streak = await tracker.record_activity(user_id, StreakType.ENGAGEMENT, db)
    milestones = await tracker.check_milestones(streak)
"""

import logging
from datetime import date, timedelta

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user_streak import StreakType, UserStreak

logger = logging.getLogger(__name__)

_MAX_FREEZE = 2


class StreakTracker:
    """Service for managing user streaks and freeze tokens.

    All methods are stateless; pass a session on each call.
    """

    MILESTONE_DAYS: list[int] = [7, 14, 30, 60, 90, 180, 365]

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    async def record_activity(
        self,
        user_id: str,
        streak_type: StreakType,
        session: AsyncSession,
    ) -> UserStreak:
        """Record an activity for a streak type and return the updated row.

        Rules:
            - No existing row → create with current_count=1.
            - Last activity was today → no change (idempotent).
            - Last activity was yesterday → increment current_count.
            - Gap > 1 day AND freeze available AND not used this week →
              auto-apply freeze, keep current_count unchanged.
            - Gap > 1 day AND no freeze → reset current_count to 1.

        Also updates ``longest_count`` if ``current_count`` exceeds it.

        Args:
            user_id: The user performing the activity.
            streak_type: Which streak category to update.
            session: Async database session.

        Returns:
            The updated (or newly created) :class:`UserStreak` row.
        """
        today = date.today()
        streak = await self._get_or_create(user_id, streak_type, session)

        last = streak.last_activity_date

        if last is None:
            # First ever activity
            streak.current_count = 1
            streak.last_activity_date = today
        elif last == today:
            # Already recorded today — idempotent
            return streak
        elif last == today - timedelta(days=1):
            # Consecutive day — increment
            streak.current_count += 1
            streak.last_activity_date = today
        else:
            # Gap detected
            gap = (today - last).days
            if gap > 1 and streak.freeze_count > 0 and not streak.freeze_used_this_week:
                # Auto-apply freeze: preserve streak
                streak.freeze_count -= 1
                streak.freeze_used_this_week = True
                streak.freeze_used_today = True
                streak.last_activity_date = today
                logger.info(
                    "Freeze auto-applied: user=%s type=%s gap=%d remaining=%d",
                    user_id,
                    streak_type.value,
                    gap,
                    streak.freeze_count,
                )
            else:
                # Break streak
                streak.current_count = 1
                streak.last_activity_date = today

        # Update personal best
        if streak.current_count > streak.longest_count:
            streak.longest_count = streak.current_count

        await session.commit()
        await session.refresh(streak)
        return streak

    async def use_freeze(
        self,
        user_id: str,
        streak_type: StreakType,
        session: AsyncSession,
    ) -> UserStreak:
        """Manually consume a freeze token for a streak type.

        Args:
            user_id: The user consuming the freeze.
            streak_type: Which streak category to apply the freeze to.
            session: Async database session.

        Returns:
            The updated :class:`UserStreak` row.

        Raises:
            ValueError: If no freeze tokens are available, or if a freeze
                has already been used this week.
        """
        streak = await self._get_or_create(user_id, streak_type, session)

        if streak.freeze_count <= 0:
            raise ValueError("No freeze tokens available")
        if streak.freeze_used_this_week:
            raise ValueError("Freeze already used this week")

        streak.freeze_count -= 1
        streak.freeze_used_this_week = True
        streak.freeze_used_today = True

        await session.commit()
        await session.refresh(streak)
        return streak

    async def get_streaks(
        self,
        user_id: str,
        session: AsyncSession,
    ) -> list[UserStreak]:
        """Return all streak rows for a user.

        Args:
            user_id: The user whose streaks to fetch.
            session: Async database session.

        Returns:
            List of :class:`UserStreak` rows (one per registered type).
            May be fewer than the total number of StreakType members if
            the user has never triggered certain streak types.
        """
        result = await session.execute(select(UserStreak).where(UserStreak.user_id == user_id))
        return list(result.scalars().all())

    async def check_milestones(self, streak: UserStreak) -> list[int]:
        """Return milestone day counts that the streak has just reached.

        Checks the current count against ``MILESTONE_DAYS`` and returns
        the subset of milestones that exactly equal the current count.
        This is intentionally exact (not >=) so callers only fire
        milestone events at the moment of crossing, not on every call.

        Args:
            streak: The :class:`UserStreak` row to evaluate.

        Returns:
            List of milestone integers hit at the current count.
            Empty list if no milestone was just reached.
        """
        return [m for m in self.MILESTONE_DAYS if streak.current_count == m]

    async def reset_weekly_freezes(self, session: AsyncSession) -> None:
        """Increment freeze_count by 1 (max 2) and reset weekly flags.

        Intended to be called by the Celery beat weekly task. Runs a
        single bulk UPDATE for efficiency.

        Args:
            session: Async database session.
        """
        # Increment freeze_count for users who haven't reached the cap
        await session.execute(
            update(UserStreak)
            .where(UserStreak.freeze_count < _MAX_FREEZE)
            .values(freeze_count=UserStreak.freeze_count + 1)
        )
        # Reset weekly flag for all users
        await session.execute(
            update(UserStreak).values(
                freeze_used_this_week=False,
                freeze_used_today=False,
            )
        )
        await session.commit()
        logger.info("Weekly streak freeze reset complete")

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    async def _get_or_create(
        self,
        user_id: str,
        streak_type: StreakType,
        session: AsyncSession,
    ) -> UserStreak:
        """Fetch or create a UserStreak row for the given user and type.

        New rows start with freeze_count=1 (first-week freebie).

        Args:
            user_id: The user ID.
            streak_type: The streak type.
            session: Async database session.

        Returns:
            Existing or newly created :class:`UserStreak` row.
        """
        result = await session.execute(
            select(UserStreak).where(
                UserStreak.user_id == user_id,
                UserStreak.streak_type == streak_type.value,
            )
        )
        existing = result.scalars().first()
        if existing is not None:
            return existing

        streak = UserStreak(
            user_id=user_id,
            streak_type=streak_type.value,
            current_count=0,
            longest_count=0,
            freeze_count=1,  # first-week freebie
        )
        session.add(streak)
        await session.flush()
        return streak
