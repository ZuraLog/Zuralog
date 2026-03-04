"""
Zuralog Cloud Brain — Data Maturity Service.

Calculates a user's "data maturity level" based on how many days of
health data they have recorded. This drives progressive feature unlock:
more data → more powerful AI features become available.

Levels:
  BUILDING  (1–6 days)   — basic tracking only
  READY     (7–13 days)  — health score, correlations, weekly report
  STRONG    (14–29 days) — anomaly detection, trend analysis
  EXCELLENT (30+ days)   — advanced insights, full correlation engine

Thresholds are defined as class constants and can be adjusted without
changing any other code.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from enum import Enum

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.daily_metrics import DailyHealthMetrics

logger = logging.getLogger(__name__)


class MaturityLevel(str, Enum):
    """Data maturity tier.

    Attributes:
        BUILDING: 1–6 days of data. Basic tracking only.
        READY: 7–13 days. Weekly report and correlations unlock.
        STRONG: 14–29 days. Anomaly detection and trend analysis unlock.
        EXCELLENT: 30+ days. Full advanced insights unlock.
    """

    BUILDING = "building"
    READY = "ready"
    STRONG = "strong"
    EXCELLENT = "excellent"


@dataclass
class DataMaturityResult:
    """The data maturity assessment for a single user.

    Attributes:
        level: Current MaturityLevel.
        days_with_data: Total distinct days with any health data.
        percentage: Progress toward the next level (0–100).
        features_unlocked: List of feature names available at this level.
        features_locked: List of feature names not yet available.
        next_milestone_days: Days remaining until the next maturity level.
    """

    level: MaturityLevel
    days_with_data: int
    percentage: float
    features_unlocked: list[str]
    features_locked: list[str]
    next_milestone_days: int


class DataMaturityService:
    """Calculate data maturity level and feature availability for a user.

    Class Constants:
        FEATURE_THRESHOLDS: Feature name → minimum days_with_data required.
        _LEVEL_THRESHOLDS: Days required to enter each MaturityLevel.
        _LEVEL_ORDER: List of levels in ascending order.
    """

    FEATURE_THRESHOLDS: dict[str, int] = {
        "health_score_full": 7,
        "anomaly_detection": 14,
        "correlations": 7,
        "weekly_report": 7,
        "trend_analysis": 14,
        "advanced_insights": 30,
    }

    _LEVEL_THRESHOLDS: dict[MaturityLevel, int] = {
        MaturityLevel.BUILDING: 1,
        MaturityLevel.READY: 7,
        MaturityLevel.STRONG: 14,
        MaturityLevel.EXCELLENT: 30,
    }

    _LEVEL_ORDER: list[MaturityLevel] = [
        MaturityLevel.BUILDING,
        MaturityLevel.READY,
        MaturityLevel.STRONG,
        MaturityLevel.EXCELLENT,
    ]

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    async def get_maturity(self, user_id: str, session: AsyncSession) -> DataMaturityResult:
        """Calculate data maturity level for a user.

        Counts the distinct calendar days on which the user has at least
        one DailyHealthMetrics row (from any source).

        Args:
            user_id: Zuralog user ID.
            session: Open async DB session.

        Returns:
            Populated DataMaturityResult.
        """
        days_with_data = await self._count_days_with_data(user_id, session)

        level = self._level_for_days(days_with_data)
        percentage = self._progress_percentage(days_with_data, level)
        next_milestone = self._next_milestone_days(days_with_data, level)

        unlocked = [feature for feature, threshold in self.FEATURE_THRESHOLDS.items() if days_with_data >= threshold]
        locked = [feature for feature, threshold in self.FEATURE_THRESHOLDS.items() if days_with_data < threshold]

        return DataMaturityResult(
            level=level,
            days_with_data=days_with_data,
            percentage=percentage,
            features_unlocked=sorted(unlocked),
            features_locked=sorted(locked),
            next_milestone_days=next_milestone,
        )

    def get_feature_available(self, feature: str, days_with_data: int) -> bool:
        """Check if a specific feature is available given the user's data days.

        Args:
            feature: Feature name (must be in FEATURE_THRESHOLDS).
            days_with_data: Number of days with health data.

        Returns:
            True if the feature is available, False if not yet unlocked.
            Returns True for unknown features (fail-open for unregistered features).
        """
        threshold = self.FEATURE_THRESHOLDS.get(feature)
        if threshold is None:
            logger.warning("Unknown feature '%s' in get_feature_available", feature)
            return True
        return days_with_data >= threshold

    # ------------------------------------------------------------------
    # Private helpers
    # ------------------------------------------------------------------

    @staticmethod
    async def _count_days_with_data(user_id: str, session: AsyncSession) -> int:
        """Count distinct calendar days with at least one health metric.

        Args:
            user_id: Zuralog user ID.
            session: Open async DB session.

        Returns:
            Count of distinct date strings in DailyHealthMetrics.
        """
        stmt = select(func.count(func.distinct(DailyHealthMetrics.date))).where(
            DailyHealthMetrics.user_id == user_id,
        )
        result = await session.execute(stmt)
        count = result.scalar_one_or_none()
        return int(count) if count else 0

    def _level_for_days(self, days: int) -> MaturityLevel:
        """Return the MaturityLevel that corresponds to the given day count.

        Args:
            days: Number of days with health data.

        Returns:
            The highest MaturityLevel the user has reached.
        """
        level = MaturityLevel.BUILDING
        for lvl in self._LEVEL_ORDER:
            if days >= self._LEVEL_THRESHOLDS[lvl]:
                level = lvl
        return level

    def _progress_percentage(self, days: int, level: MaturityLevel) -> float:
        """Calculate progress toward the next maturity level (0.0–100.0).

        Returns 100.0 if the user has reached the highest level (EXCELLENT).

        Args:
            days: Days with data.
            level: Current MaturityLevel.

        Returns:
            Percentage as a float in range [0.0, 100.0].
        """
        if level == MaturityLevel.EXCELLENT:
            return 100.0

        level_idx = self._LEVEL_ORDER.index(level)
        current_threshold = self._LEVEL_THRESHOLDS[level]
        next_level = self._LEVEL_ORDER[level_idx + 1]
        next_threshold = self._LEVEL_THRESHOLDS[next_level]

        span = next_threshold - current_threshold
        progress = days - current_threshold
        return round(min(max((progress / span) * 100, 0.0), 100.0), 1)

    def _next_milestone_days(self, days: int, level: MaturityLevel) -> int:
        """Calculate how many more days are needed to reach the next level.

        Returns 0 if the user has already reached EXCELLENT.

        Args:
            days: Days with data.
            level: Current MaturityLevel.

        Returns:
            Number of additional days needed.
        """
        if level == MaturityLevel.EXCELLENT:
            return 0

        level_idx = self._LEVEL_ORDER.index(level)
        next_level = self._LEVEL_ORDER[level_idx + 1]
        next_threshold = self._LEVEL_THRESHOLDS[next_level]
        return max(next_threshold - days, 0)
