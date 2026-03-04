"""
Zuralog Cloud Brain — Data Maturity Service.

Determines how many days of health data a user has accumulated and maps
that count to a maturity level.  The maturity level gates features that
require a baseline of historical data (e.g. anomaly detection, correlations).

Levels
------
building  (1–6 days)   — Too early for meaningful analysis.
ready     (7–13 days)  — Basic insights available.
strong    (14–29 days) — Anomaly detection and full insights active.
excellent (30+ days)   — All features active with high confidence.
"""

import logging
from typing import Any

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.daily_metrics import DailyHealthMetrics

logger = logging.getLogger(__name__)


class DataMaturityService:
    """Service for evaluating a user's health data maturity level.

    Maturity is determined by counting the number of distinct calendar days
    for which the user has at least one ``DailyHealthMetrics`` row. Richer
    feature sets are unlocked as more days of data accumulate.

    Usage::

        svc = DataMaturityService()
        info = await svc.get_maturity(user_id, db)
        # {"days": 12, "level": "ready", "label": "Ready", "features": {...}}
    """

    LEVELS: list[dict[str, Any]] = [
        {
            "level": "building",
            "min_days": 1,
            "max_days": 6,
            "label": "Building",
        },
        {
            "level": "ready",
            "min_days": 7,
            "max_days": 13,
            "label": "Ready",
        },
        {
            "level": "strong",
            "min_days": 14,
            "max_days": 29,
            "label": "Strong",
        },
        {
            "level": "excellent",
            "min_days": 30,
            "max_days": None,
            "label": "Excellent",
        },
    ]

    async def get_maturity(self, user_id: str, db: AsyncSession) -> dict[str, Any]:
        """Return the current data maturity level for a user.

        Counts distinct dates in ``daily_health_metrics`` for the given
        user, then maps the count to a level and computes feature gates.

        Args:
            user_id: The user to evaluate.
            db: Active async database session.

        Returns:
            A dict with the following keys:

            - ``days``: Total distinct days of data (int).
            - ``level``: Maturity level string (e.g. ``"ready"``).
            - ``label``: Human-readable label (e.g. ``"Ready"``).
            - ``features``: Feature gate dict from :meth:`get_feature_gates`.
        """
        try:
            stmt = select(
                func.count(DailyHealthMetrics.date.distinct())
            ).where(DailyHealthMetrics.user_id == user_id)
            result = await db.execute(stmt)
            days: int = result.scalar_one() or 0
        except Exception:
            logger.exception(
                "data_maturity: failed to count days for user=%s", user_id
            )
            days = 0

        level_info = self._classify(days)
        features = self.get_feature_gates(days)

        logger.debug(
            "data_maturity: user=%s days=%d level=%s",
            user_id,
            days,
            level_info["level"],
        )

        return {
            "days": days,
            "level": level_info["level"],
            "label": level_info["label"],
            "features": features,
        }

    def get_feature_gates(self, days: int) -> dict[str, bool]:
        """Return feature availability flags based on the number of data days.

        Feature gates:
        - ``correlations``: Enabled once the user has ≥ 7 days of data.
          At least one week is needed for any meaningful cross-metric
          correlation.
        - ``anomaly_detection``: Enabled at ≥ 14 days — requires a two-week
          baseline to distinguish noise from genuine anomalies.
        - ``health_score_footnote``: ``True`` when the user has < 7 days of
          data — the client should render a disclaimer noting the score is
          preliminary.
        - ``full_insights``: Enabled at ≥ 14 days, when the analytics engine
          has enough history for confident recommendations.

        Args:
            days: Number of distinct days of data the user has.

        Returns:
            Dict mapping feature name to bool availability flag.
        """
        return {
            "correlations": days >= 7,
            "anomaly_detection": days >= 14,
            "health_score_footnote": days < 7,
            "full_insights": days >= 14,
        }

    def _classify(self, days: int) -> dict[str, Any]:
        """Map a day count to the appropriate maturity level dict.

        Args:
            days: Number of distinct days of health data.

        Returns:
            A level dict from :attr:`LEVELS` (always returns a dict —
            returns the last level if ``days`` exceeds all thresholds).
        """
        if days == 0:
            # No data yet — return building level with "no data" semantics
            return {"level": "building", "label": "Building"}

        for level in self.LEVELS:
            max_days = level["max_days"]
            if max_days is None or days <= max_days:
                return level

        # days > all max values — return the last (highest) level
        return self.LEVELS[-1]
