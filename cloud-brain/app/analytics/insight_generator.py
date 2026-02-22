"""
Life Logger Cloud Brain — Insight Generator.

Synthesizes analytics data (goal progress, trend directions) into a single
human-readable "Insight of the Day" string for the dashboard header.

Uses a **rule-based priority system** to select the most actionable insight:

1. **Goal near-misses** — unmet goals with ≥ 80 % progress (urgent nudge).
2. **Negative trends** — metrics trending downward (motivational nudge).
3. **All goals met** — every tracked goal is satisfied (celebration).
4. **Positive trends** — metrics trending upward (encouragement).
5. **Default fallback** — generic consistency message when nothing notable.

All methods are pure functions with no side effects or database access.
"""

import logging
from typing import Any

logger = logging.getLogger(__name__)


class InsightGenerator:
    """Generates a single prioritized insight from goal and trend data.

    The generator evaluates a list of goal-progress snapshots and a dict
    of trend summaries, then walks the priority ladder to produce the
    highest-priority insight that applies. Only one insight string is
    returned per invocation.

    Class Constants:
        NEAR_MISS_THRESHOLD: Minimum ``progress_pct`` (inclusive) for an
            unmet goal to be considered a "near miss".
    """

    NEAR_MISS_THRESHOLD: int = 80

    def generate_dashboard_insight(
        self,
        goal_status: list[dict[str, Any]],
        trends: dict[str, dict[str, Any]],
    ) -> str:
        """Produce the highest-priority insight for the dashboard header.

        Walks the priority ladder from most-urgent to least-urgent and
        returns the first insight that matches the supplied data:

        1. Goal near-miss (unmet, progress ≥ ``NEAR_MISS_THRESHOLD``).
        2. Negative trend (any metric trending ``"down"``).
        3. All goals met (every goal in the list has ``is_met=True``).
        4. Positive trend (any metric trending ``"up"``).
        5. Generic fallback.

        Args:
            goal_status: A list of goal-progress dicts. Each dict must
                contain the keys ``metric`` (``str``), ``is_met``
                (``bool``), ``progress_pct`` (``float``), and
                ``remaining`` (``float``).
            trends: A mapping of metric name to trend summary dict. Each
                trend dict must contain ``trend`` (one of ``"up"``,
                ``"down"``, ``"stable"``) and ``percent_change``
                (``float``).

        Returns:
            A 1–2 sentence human-readable insight string.
        """
        # Priority 1 — goal near-misses
        near_miss = self._find_near_miss(goal_status)
        if near_miss is not None:
            return self._format_near_miss(near_miss)

        # Priority 2 — negative trends
        negative = self._find_trend_by_direction(trends, direction="down")
        if negative is not None:
            metric, trend_data = negative
            return self._format_negative_trend(metric, trend_data)

        # Priority 3 — all goals met
        if goal_status and all(g["is_met"] for g in goal_status):
            return "All goals hit today! You're on fire."

        # Priority 4 — positive trends
        positive = self._find_trend_by_direction(trends, direction="up")
        if positive is not None:
            metric, trend_data = positive
            return self._format_positive_trend(metric, trend_data)

        # Priority 5 — default fallback
        return "Consistency is key. Keep tracking and the insights will come."

    # ------------------------------------------------------------------
    # Private helpers
    # ------------------------------------------------------------------

    def _find_near_miss(
        self,
        goal_status: list[dict[str, Any]],
    ) -> dict[str, Any] | None:
        """Return the first unmet goal whose progress meets the near-miss bar.

        Args:
            goal_status: List of goal-progress dicts.

        Returns:
            The first qualifying goal dict, or ``None`` if no near-miss
            is found.
        """
        for goal in goal_status:
            if not goal["is_met"] and goal["progress_pct"] >= self.NEAR_MISS_THRESHOLD:
                return goal
        return None

    @staticmethod
    def _find_trend_by_direction(
        trends: dict[str, dict[str, Any]],
        *,
        direction: str,
    ) -> tuple[str, dict[str, Any]] | None:
        """Find the first metric whose trend matches *direction*.

        Args:
            trends: Metric-name → trend-summary mapping.
            direction: Desired trend direction (``"up"`` or ``"down"``).

        Returns:
            A ``(metric, trend_data)`` tuple for the first match, or
            ``None`` if no metric trends in the given direction.
        """
        for metric, trend_data in trends.items():
            if trend_data.get("trend") == direction:
                return metric, trend_data
        return None

    @staticmethod
    def _format_near_miss(goal: dict[str, Any]) -> str:
        """Format a near-miss goal into a motivational nudge string.

        Args:
            goal: A goal-progress dict with ``metric`` and ``remaining``.

        Returns:
            Human-readable nudge like ``"So close! Just 1500 more steps
            to hit your goal. You've got this!"``.
        """
        metric = goal["metric"]
        remaining = goal["remaining"]
        return f"So close! Just {remaining} more {metric} to hit your goal. You've got this!"

    @staticmethod
    def _format_negative_trend(
        metric: str,
        trend_data: dict[str, Any],
    ) -> str:
        """Format a downward trend into a supportive nudge.

        Args:
            metric: Name of the declining metric.
            trend_data: Trend summary containing ``percent_change``.

        Returns:
            Human-readable nudge highlighting the decline and
            encouraging recovery.
        """
        pct = abs(trend_data["percent_change"])
        return f"Your {metric} is trending down {pct}% recently. A small pick-me-up today can turn things around!"

    @staticmethod
    def _format_positive_trend(
        metric: str,
        trend_data: dict[str, Any],
    ) -> str:
        """Format an upward trend into an encouraging message.

        Args:
            metric: Name of the improving metric.
            trend_data: Trend summary containing ``percent_change``.

        Returns:
            Human-readable encouragement highlighting the improvement.
        """
        pct = abs(trend_data["percent_change"])
        return f"You're crushing it! {metric} is up {pct}% recently. Keep the momentum going!"
