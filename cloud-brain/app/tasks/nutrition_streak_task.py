"""
Zuralog Cloud Brain — Nutrition Streak Evaluation Task.

Evaluates whether a user has hit all of their active nutrition goals for a
given calendar date.  When every goal is satisfied the user's
``nutrition_goals`` streak is incremented (or started at 1).  If any goal
is missed the function returns ``None`` — the streak is NOT touched.

Metric → summary column mapping
--------------------------------
Each nutrition goal metric is either a *min* goal (user must hit at least the
target) or a *max* goal (user must stay at or below the target):

    nutrition.daily_calorie_limit  → total_calories   (max)
    nutrition.daily_protein_g      → total_protein_g  (min)
    nutrition.daily_carbs_g        → total_carbs_g    (max)
    nutrition.daily_fat_g          → total_fat_g      (max)
    nutrition.daily_fiber_g        → total_fiber_g    (min)
    nutrition.daily_sodium_mg      → total_sodium_mg  (max)
    nutrition.daily_sugar_g        → total_sugar_g    (max)

Public API
----------
    evaluate_nutrition_streak_for_user(db, user_id, activity_date) → UserStreak | None
"""

from __future__ import annotations

import logging
import uuid
from datetime import date
from typing import Any

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.nutrition_daily_summary import NutritionDailySummary
from app.models.user_goal import UserGoal
from app.models.user_streak import UserStreak

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

STREAK_TYPE = "nutrition_goals"

# Maps metric slug → (summary_attribute, is_min_goal).
# is_min_goal=True  → user must reach AT LEAST the target (e.g. protein).
# is_min_goal=False → user must stay AT OR BELOW the target (e.g. calories).
_METRIC_MAP: dict[str, tuple[str, bool]] = {
    "nutrition.daily_calorie_limit": ("total_calories", False),   # max
    "nutrition.daily_protein_g":     ("total_protein_g", True),   # min
    "nutrition.daily_carbs_g":       ("total_carbs_g", False),    # max
    "nutrition.daily_fat_g":         ("total_fat_g", False),      # max
    "nutrition.daily_fiber_g":       ("total_fiber_g", True),     # min
    "nutrition.daily_sodium_mg":     ("total_sodium_mg", False),  # max
    "nutrition.daily_sugar_g":       ("total_sugar_g", False),    # max
}


# ---------------------------------------------------------------------------
# Public entry point
# ---------------------------------------------------------------------------


async def evaluate_nutrition_streak_for_user(
    db: AsyncSession,
    user_id: str,
    activity_date: date,
) -> UserStreak | None:
    """Evaluate whether a user hit all nutrition goals for ``activity_date``.

    Fetches all active ``nutrition.*`` goals and the pre-computed daily
    summary, then checks each goal against the summary.  If every goal is
    met the function upserts the ``nutrition_goals`` streak row and returns
    it.  If any goal is missed — or there are no goals / no summary — the
    function returns ``None`` without touching the streak.

    Args:
        db: Active async database session.
        user_id: The authenticated user's ID.
        activity_date: The calendar date to evaluate.

    Returns:
        The updated :class:`UserStreak` if all goals were met, otherwise
        ``None``.
    """
    goals = await _fetch_nutrition_goals(db, user_id)
    if not goals:
        logger.debug(
            "evaluate_nutrition_streak: no active nutrition goals for user=%s on %s — skipping",
            user_id,
            activity_date,
        )
        return None

    summary = await _fetch_nutrition_summary(db, user_id, activity_date)
    if summary is None:
        logger.debug(
            "evaluate_nutrition_streak: no nutrition summary for user=%s on %s — skipping",
            user_id,
            activity_date,
        )
        return None

    all_met = _all_goals_met(goals, summary)
    if not all_met:
        logger.info(
            "evaluate_nutrition_streak: one or more goals NOT met for user=%s on %s — no streak update",
            user_id,
            activity_date,
        )
        return None

    streak = await _upsert_streak(db, user_id, activity_date)
    logger.info(
        "evaluate_nutrition_streak: all goals met for user=%s on %s — streak=%d",
        user_id,
        activity_date,
        streak.current_count,
    )
    return streak


# ---------------------------------------------------------------------------
# Internal helpers (extracted so tests can patch them cleanly)
# ---------------------------------------------------------------------------


async def _fetch_nutrition_goals(db: AsyncSession, user_id: str) -> list[Any]:
    """Return all active nutrition.* goals for the user."""
    result = await db.execute(
        select(UserGoal).where(
            UserGoal.user_id == user_id,
            UserGoal.is_active.is_(True),
            UserGoal.metric.like("nutrition.%"),
        )
    )
    return list(result.scalars().all())


async def _fetch_nutrition_summary(
    db: AsyncSession,
    user_id: str,
    activity_date: date,
) -> NutritionDailySummary | None:
    """Return the pre-computed daily nutrition summary for the user and date."""
    result = await db.execute(
        select(NutritionDailySummary).where(
            NutritionDailySummary.user_id == user_id,
            NutritionDailySummary.date == activity_date,
        )
    )
    return result.scalar_one_or_none()


def _all_goals_met(goals: list[Any], summary: Any) -> bool:
    """Return True only if every recognised nutrition goal is satisfied.

    Goals for unknown metric keys are silently skipped (future-proofing).

    Args:
        goals: List of :class:`UserGoal` ORM objects (or compatible mocks).
        summary: :class:`NutritionDailySummary` ORM object (or compatible mock).

    Returns:
        ``True`` if all recognised goals are met; ``False`` if any are missed.
    """
    for goal in goals:
        mapping = _METRIC_MAP.get(goal.metric)
        if mapping is None:
            # Unknown metric — skip rather than fail
            logger.debug(
                "_all_goals_met: unrecognised metric '%s' — ignoring", goal.metric
            )
            continue

        attr, is_min = mapping
        actual = getattr(summary, attr, None)

        if actual is None:
            # No data recorded for this metric — treat as not meeting the goal.
            logger.debug(
                "_all_goals_met: summary attribute '%s' is None for metric '%s' — goal not met",
                attr,
                goal.metric,
            )
            return False

        if is_min:
            # User must reach AT LEAST the target.
            if float(actual) < float(goal.target_value):
                logger.debug(
                    "_all_goals_met: min goal '%s' NOT met — actual=%.2f target=%.2f",
                    goal.metric,
                    float(actual),
                    float(goal.target_value),
                )
                return False
        else:
            # User must stay AT OR BELOW the target.
            if float(actual) > float(goal.target_value):
                logger.debug(
                    "_all_goals_met: max goal '%s' NOT met — actual=%.2f target=%.2f",
                    goal.metric,
                    float(actual),
                    float(goal.target_value),
                )
                return False

    return True


async def _upsert_streak(
    db: AsyncSession,
    user_id: str,
    activity_date: date,
) -> UserStreak:
    """Find or create the nutrition_goals streak row, then increment it.

    Uses the same consecutive-day logic as :class:`StreakTracker`:
    - First ever hit → creates row with ``current_count=1``.
    - Consecutive day → increments ``current_count``.
    - Duplicate call (same date) → no change (idempotent).
    - Gap > 1 day → resets ``current_count`` to 1.

    Args:
        db: Active async database session.
        user_id: The authenticated user's ID.
        activity_date: The calendar date of the successful goal day.

    Returns:
        The updated (or newly created) :class:`UserStreak` instance.
    """
    from datetime import timedelta  # noqa: PLC0415

    date_str = activity_date.isoformat()

    result = await db.execute(
        select(UserStreak).where(
            UserStreak.user_id == user_id,
            UserStreak.streak_type == STREAK_TYPE,
        )
    )
    streak = result.scalar_one_or_none()

    if streak is None:
        streak = UserStreak(
            id=str(uuid.uuid4()),
            user_id=user_id,
            streak_type=STREAK_TYPE,
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
            # Race condition: another request created the row at the same time.
            await db.rollback()
            result = await db.execute(
                select(UserStreak).where(
                    UserStreak.user_id == user_id,
                    UserStreak.streak_type == STREAK_TYPE,
                )
            )
            streak = result.scalar_one()

        logger.info(
            "_upsert_streak: created nutrition_goals streak for user='%s' on %s",
            user_id,
            date_str,
        )
        return streak

    # Determine day delta against the last recorded activity.
    if streak.last_activity_date is None:
        delta_days = None
    else:
        last_date = date.fromisoformat(streak.last_activity_date)
        delta_days = (activity_date - last_date).days

    if delta_days == 0:
        # Idempotent duplicate for the same day — return as-is.
        logger.debug(
            "_upsert_streak: duplicate call for user='%s' on %s — no change",
            user_id,
            date_str,
        )
        return streak

    if delta_days == 1:
        streak.current_count += 1
    else:
        # Gap of more than one day — restart the streak.
        logger.info(
            "_upsert_streak: gap of %s days for user='%s' — resetting streak to 1",
            delta_days,
            user_id,
        )
        streak.current_count = 1

    streak.last_activity_date = date_str
    streak.is_frozen = False

    if streak.current_count > streak.longest_count:
        streak.longest_count = streak.current_count

    await db.commit()
    await db.refresh(streak)
    return streak
