"""
Zuralog Cloud Brain — Goal Tracker.

Compares current metric values against user-defined targets and calculates
streaks of consecutive days meeting a goal. Used to power progress
dashboards and motivational nudges such as "You've hit your step goal
3 days in a row!"

All methods are pure functions with no side effects or database access.
"""

import logging
from typing import Any

logger = logging.getLogger(__name__)


class GoalTracker:
    """Evaluates goal progress and computes achievement streaks.

    Provides two core capabilities:

    1. **Progress checking** — compares a single metric snapshot against a
       target and returns completion percentage and remaining deficit.
    2. **Streak calculation** — walks backward through a series of daily
       values to count consecutive days a target was met.

    All methods are stateless and side-effect-free.
    """

    def check_progress(
        self,
        metric: str,
        current_value: float,
        target_value: float,
        period: str,
    ) -> dict[str, Any]:
        """Check how a metric's current value compares to its target.

        Calculates the percentage of the target achieved and whether the
        goal has been met. Handles edge cases like a zero or negative
        target by treating the goal as automatically met.

        Args:
            metric: Name of the metric being tracked (e.g. ``"steps"``).
            current_value: The observed value for the current period.
            target_value: The user-defined goal value for the period.
            period: Time granularity of the goal (e.g. ``"daily"``,
                ``"weekly"``).

        Returns:
            A dict with the following keys:

            - **metric** (``str``): Echo of the input metric name.
            - **period** (``str``): Echo of the input period.
            - **target** (``float``): The target value.
            - **current** (``float``): The current value.
            - **progress_pct** (``float``): Percentage of target achieved,
              rounded to 1 decimal place. Capped conceptually but not
              numerically (can exceed 100).
            - **is_met** (``bool``): ``True`` when ``current_value``
              equals or exceeds ``target_value``.
            - **remaining** (``float``): Deficit to reach the target, or
              ``0`` if the goal is already met.
        """
        if target_value <= 0:
            logger.debug(
                "Target for '%s' is %s (≤ 0); treating as met.",
                metric,
                target_value,
            )
            return {
                "metric": metric,
                "period": period,
                "target": target_value,
                "current": current_value,
                "progress_pct": 100.0,
                "is_met": True,
                "remaining": 0,
            }

        progress_pct = round((current_value / target_value) * 100, 1)
        is_met = current_value >= target_value
        remaining = max(0, target_value - current_value)

        return {
            "metric": metric,
            "period": period,
            "target": target_value,
            "current": current_value,
            "progress_pct": progress_pct,
            "is_met": is_met,
            "remaining": remaining,
        }

    def calculate_streak(
        self,
        daily_values: list[float],
        target: float,
    ) -> dict[str, Any]:
        """Count consecutive recent days where a target was met or exceeded.

        Iterates backward from the most recent entry in ``daily_values``.
        The streak breaks at the first day whose value falls below
        ``target``.

        Args:
            daily_values: Ordered numeric observations (oldest first,
                most recent last). Each element represents one day's
                measurement.
            target: The minimum value required for a day to count as
                meeting the goal.

        Returns:
            A dict with the following keys:

            - **streak_days** (``int``): Number of consecutive recent
              days meeting the target. ``0`` if the most recent day
              missed or the list is empty.
            - **is_active** (``bool``): ``True`` when the most recent
              day meets the target (i.e. the streak is ongoing).
        """
        if not daily_values:
            return {"streak_days": 0, "is_active": False}

        streak = 0
        for value in reversed(daily_values):
            if value >= target:
                streak += 1
            else:
                break

        return {
            "streak_days": streak,
            "is_active": streak > 0,
        }
