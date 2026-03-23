"""AnomalyDetector — detects metric anomalies using rolling statistics.

For each trackable metric (resting_heart_rate, hrv_ms, steps,
active_calories, sleep_hours, sleep_quality) the detector pulls up to
30 days of data for the user, computes a rolling mean and standard
deviation, and flags values that deviate more than 2 standard deviations
from the baseline.

Severity levels
---------------
- ``normal``:   abs deviation < 2.0 stddev
- ``elevated``: 2.0 ≤ abs deviation < 3.0 stddev
- ``critical``: abs deviation ≥ 3.0 stddev

Minimum data requirement
------------------------
At least 14 days of non-null observations are required before the
detector will report anomalies for a metric. Metrics with fewer
observations are silently skipped.
"""

from __future__ import annotations

import logging
import math
from dataclasses import dataclass
from datetime import date, timedelta

from sqlalchemy import and_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.daily_summary import DailySummary

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

_LOOKBACK_DAYS = 30
_MIN_DATA_POINTS = 14

_ELEVATED_THRESHOLD = 2.0
_CRITICAL_THRESHOLD = 3.0


# ---------------------------------------------------------------------------
# Result dataclass
# ---------------------------------------------------------------------------


@dataclass
class AnomalyResult:
    """Describes a single metric anomaly detected for a user.

    Attributes:
        metric: Name of the metric (e.g. ``"resting_heart_rate"``).
        current_value: The value observed on the target date.
        baseline_mean: Rolling mean over the lookback window.
        baseline_stddev: Rolling population stddev over the lookback window.
        deviation_magnitude: How many stddevs ``current_value`` is from mean.
        severity: ``"normal"`` | ``"elevated"`` | ``"critical"``.
        direction: ``"high"`` if current > mean, else ``"low"``.
    """

    metric: str
    current_value: float
    baseline_mean: float
    baseline_stddev: float
    deviation_magnitude: float
    severity: str  # "normal" | "elevated" | "critical"
    direction: str  # "high" | "low"


# ---------------------------------------------------------------------------
# Helper — rolling statistics
# ---------------------------------------------------------------------------


def _mean(values: list[float]) -> float:
    """Return arithmetic mean of *values*. Assumes non-empty list."""
    return sum(values) / len(values)


def _stddev(values: list[float], mean: float) -> float:
    """Return population standard deviation of *values*."""
    variance = sum((v - mean) ** 2 for v in values) / len(values)
    return math.sqrt(variance)


def _classify_severity(deviation: float) -> str:
    """Map an absolute deviation in stddevs to a severity label."""
    if deviation >= _CRITICAL_THRESHOLD:
        return "critical"
    if deviation >= _ELEVATED_THRESHOLD:
        return "elevated"
    return "normal"


# ---------------------------------------------------------------------------
# Main detector class
# ---------------------------------------------------------------------------


class AnomalyDetector:
    """Detects health metric anomalies using rolling population statistics.

    The detector queries the ``daily_summaries`` table for the 30 days
    preceding (and including) *target_date*. It computes a rolling mean
    and stddev for each metric and flags observations that deviate more
    than 2 stddevs from the baseline.

    Usage::

        detector = AnomalyDetector()
        anomalies = await detector.check_user_metrics(user_id, db)
    """

    async def check_user_metrics(
        self,
        user_id: str,
        db: AsyncSession,
        target_date: date | None = None,
    ) -> list[AnomalyResult]:
        """Run anomaly detection across all tracked metrics for *user_id*.

        Args:
            user_id: The user to analyse.
            db: An active async database session.
            target_date: The date to treat as "today". Defaults to
                ``date.today()`` when not specified.

        Returns:
            A (possibly empty) list of :class:`AnomalyResult` instances
            whose ``severity`` is ``"elevated"`` or ``"critical"``.
            Metrics that are ``"normal"`` or that lack sufficient data
            are omitted from the returned list.
        """
        if target_date is None:
            target_date = date.today()

        # Fetch raw data from both tables for the lookback window.
        daily_rows = await self._fetch_daily_metrics(user_id, db, target_date)
        sleep_rows = await self._fetch_sleep_records(user_id, db, target_date)

        results: list[AnomalyResult] = []

        # --- daily_summaries-backed metrics ---
        for metric in ("resting_heart_rate", "hrv_ms", "steps", "active_calories"):
            anomaly = self._analyse_daily_metric(metric, daily_rows, target_date)
            if anomaly is not None:
                results.append(anomaly)

        # --- Sleep metrics from daily_summaries ---
        sleep_hours_anomaly = self._analyse_sleep_metric("sleep_hours", "hours", sleep_rows, target_date)
        if sleep_hours_anomaly is not None:
            results.append(sleep_hours_anomaly)

        sleep_quality_anomaly = self._analyse_sleep_metric("sleep_quality", "quality_score", sleep_rows, target_date)
        if sleep_quality_anomaly is not None:
            results.append(sleep_quality_anomaly)

        return results

    # ------------------------------------------------------------------
    # Private — data fetching
    # ------------------------------------------------------------------

    async def _fetch_daily_metrics(
        self,
        user_id: str,
        db: AsyncSession,
        target_date: date,
    ) -> list[DailySummary]:
        """Return up to 30 days of daily summary rows for *user_id*.

        Fetches ``daily_summaries`` rows whose ``metric_type`` is one of
        ``resting_heart_rate``, ``hrv_ms``, ``steps``, or
        ``active_calories``.
        """
        start_date = target_date - timedelta(days=_LOOKBACK_DAYS - 1)

        stmt = select(DailySummary).where(
            and_(
                DailySummary.user_id == user_id,
                DailySummary.date >= start_date,
                DailySummary.date <= target_date,
                DailySummary.metric_type.in_(
                    ["resting_heart_rate", "hrv_ms", "steps", "active_calories"]
                ),
            )
        )
        result = await db.execute(stmt)
        return list(result.scalars().all())

    async def _fetch_sleep_records(
        self,
        user_id: str,
        db: AsyncSession,
        target_date: date,
    ) -> list[DailySummary]:
        """Return up to 30 days of sleep summary rows for *user_id*.

        Fetches ``daily_summaries`` rows whose ``metric_type`` is
        ``sleep_duration`` or ``sleep_quality``.
        """
        start_date = target_date - timedelta(days=_LOOKBACK_DAYS - 1)

        stmt = select(DailySummary).where(
            and_(
                DailySummary.user_id == user_id,
                DailySummary.date >= start_date,
                DailySummary.date <= target_date,
                DailySummary.metric_type.in_(["sleep_duration", "sleep_quality"]),
            )
        )
        result = await db.execute(stmt)
        return list(result.scalars().all())

    # ------------------------------------------------------------------
    # Private — analysis helpers
    # ------------------------------------------------------------------

    def _analyse_daily_metric(
        self,
        metric: str,
        rows: list[DailySummary],
        target_date: date,
    ) -> AnomalyResult | None:
        """Analyse one daily metric and return an anomaly if found.

        Filters *rows* to those matching *metric* as ``metric_type``,
        builds a date-keyed map, taking the first value per day.
        Returns ``None`` when there is insufficient data or no anomaly.
        """
        target_date_str = target_date.isoformat()

        # Build date → value map; keep first non-null per date.
        date_values: dict[str, float] = {}
        for row in rows:
            if row.metric_type != metric:
                continue
            date_key = row.date.isoformat() if isinstance(row.date, date) else str(row.date)
            if date_key in date_values:
                continue  # already have a value for this day
            date_values[date_key] = float(row.value)

        return self._compute_anomaly(metric, date_values, target_date_str)

    def _analyse_sleep_metric(
        self,
        metric_name: str,
        column: str,
        rows: list[DailySummary],
        target_date: date,
    ) -> AnomalyResult | None:
        """Analyse a sleep metric from daily_summaries and return an anomaly if found.

        *column* maps the old SleepRecord column names to metric_types:
        ``"hours"`` → ``sleep_duration`` (value in minutes, converted to hours),
        ``"quality_score"`` → ``sleep_quality``.
        """
        target_date_str = target_date.isoformat()

        # Map old column names to new metric_types
        _column_to_metric_type = {
            "hours": "sleep_duration",
            "quality_score": "sleep_quality",
        }
        metric_type = _column_to_metric_type.get(column, column)

        date_values: dict[str, float] = {}
        for row in rows:
            if row.metric_type != metric_type:
                continue
            date_key = row.date.isoformat() if isinstance(row.date, date) else str(row.date)
            if date_key in date_values:
                continue
            val = float(row.value)
            # sleep_duration is stored in minutes; convert to hours
            if metric_type == "sleep_duration":
                val = val / 60.0
            date_values[date_key] = val

        return self._compute_anomaly(metric_name, date_values, target_date_str)

    @staticmethod
    def _compute_anomaly(
        metric: str,
        date_values: dict[str, float],
        target_date_str: str,
    ) -> AnomalyResult | None:
        """Core statistical computation.

        Args:
            metric: Human-readable metric label.
            date_values: Mapping of ``YYYY-MM-DD`` → float value for the
                full lookback window (may include the target date).
            target_date_str: The target date as ``YYYY-MM-DD``.

        Returns:
            An :class:`AnomalyResult` with ``severity != "normal"`` if an
            anomaly is detected, otherwise ``None``.
        """
        current_value = date_values.get(target_date_str)
        if current_value is None:
            # No data point on the target date; nothing to evaluate.
            logger.debug("AnomalyDetector: no data for metric='%s' on date='%s'", metric, target_date_str)
            return None

        # Collect all historical values (excluding the target date) to form
        # the baseline window. The target date itself is not included in
        # the baseline statistics to avoid self-referential inflation.
        historical_values = [v for d, v in date_values.items() if d != target_date_str]

        if len(historical_values) < _MIN_DATA_POINTS:
            logger.debug(
                "AnomalyDetector: insufficient baseline data for metric='%s' "
                "(%d points, need %d)",
                metric,
                len(historical_values),
                _MIN_DATA_POINTS,
            )
            return None

        mean = _mean(historical_values)
        stddev = _stddev(historical_values, mean)

        if stddev == 0.0:
            # All baseline values are identical — any deviation is infinite.
            # Treat the current value as anomalous only if it differs from mean.
            deviation = 0.0 if current_value == mean else float("inf")
        else:
            deviation = abs(current_value - mean) / stddev

        severity = _classify_severity(deviation)
        if severity == "normal":
            return None

        direction = "high" if current_value > mean else "low"

        logger.info(
            "AnomalyDetector: %s anomaly — metric='%s' current=%.2f mean=%.2f "
            "stddev=%.2f deviation=%.2f direction=%s",
            severity,
            metric,
            current_value,
            mean,
            stddev,
            deviation,
            direction,
        )

        return AnomalyResult(
            metric=metric,
            current_value=current_value,
            baseline_mean=mean,
            baseline_stddev=stddev,
            deviation_magnitude=deviation,
            severity=severity,
            direction=direction,
        )
