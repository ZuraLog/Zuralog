"""
Zuralog Cloud Brain — Anomaly Detector Service.

Detects statistically significant deviations in user health metrics by
computing rolling 30-day baselines and flagging values that exceed two
standard deviations from the mean.

Modules:
    AnomalySeverity: Classification enum for deviation magnitude.
    AnomalyResult: Structured result dataclass for a single anomaly.
    AnomalyDetector: Service that queries the DB and runs detection logic.
"""

from __future__ import annotations

import logging
import math
import uuid
from dataclasses import dataclass, field
from datetime import date, datetime, timedelta, timezone
from enum import Enum
from typing import TYPE_CHECKING

from sqlalchemy import select

if TYPE_CHECKING:
    from sqlalchemy.ext.asyncio import AsyncSession

from app.models.daily_metrics import DailyHealthMetrics
from app.models.health_data import SleepRecord

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Thresholds
# ---------------------------------------------------------------------------

_MIN_DATA_POINTS: int = 14
"""Minimum number of historical observations required before anomaly detection
is activated for a metric.  Below this threshold there is insufficient data to
establish a reliable baseline."""

_ELEVATED_THRESHOLD: float = 2.0
"""Deviation beyond this many standard deviations (inclusive) triggers an
ELEVATED anomaly."""

_CRITICAL_THRESHOLD: float = 2.5
"""Deviation at or beyond this many standard deviations triggers a CRITICAL
anomaly."""

# ---------------------------------------------------------------------------
# Metric columns to inspect on DailyHealthMetrics
# ---------------------------------------------------------------------------

_SCALAR_METRICS: list[str] = [
    "steps",
    "active_calories",
    "resting_heart_rate",
    "hrv_ms",
    "vo2_max",
    "body_fat_percentage",
    "respiratory_rate",
    "oxygen_saturation",
]
"""Ordered list of DailyHealthMetrics column names evaluated by the detector."""


# ---------------------------------------------------------------------------
# Public dataclasses / enums
# ---------------------------------------------------------------------------


class AnomalySeverity(Enum):
    """Severity classification for a detected anomaly.

    Members:
        NORMAL: Value is within expected range (no anomaly).
        ELEVATED: Value deviates 2.0–2.49 standard deviations from baseline.
        CRITICAL: Value deviates >= 2.5 standard deviations from baseline.
    """

    NORMAL = "normal"
    ELEVATED = "elevated"
    CRITICAL = "critical"


@dataclass
class AnomalyResult:
    """Result of an anomaly check for a single health metric.

    Attributes:
        metric_name: Name of the health metric (e.g. ``"steps"``).
        current_value: Today's observed value for the metric.
        baseline_mean: 30-day rolling mean of the metric.
        baseline_std: 30-day rolling standard deviation of the metric.
        deviation_magnitude: Absolute deviation in standard-deviation units.
        severity: Classified severity of the anomaly.
        detected_at: UTC timestamp when the anomaly was detected.
    """

    metric_name: str
    current_value: float
    baseline_mean: float
    baseline_std: float
    deviation_magnitude: float
    severity: AnomalySeverity
    detected_at: datetime = field(default_factory=lambda: datetime.now(tz=timezone.utc))


# ---------------------------------------------------------------------------
# Helper statistics
# ---------------------------------------------------------------------------


def _mean(values: list[float]) -> float:
    """Compute arithmetic mean of a non-empty list.

    Args:
        values: List of float values. Must not be empty.

    Returns:
        Arithmetic mean as a float.
    """
    return sum(values) / len(values)


def _std(values: list[float], mean: float) -> float:
    """Compute population standard deviation.

    Uses population (N) denominator, consistent with how rolling baselines
    are typically reported in health analytics contexts.

    Args:
        values: List of float values.
        mean: Pre-computed mean of the list.

    Returns:
        Population standard deviation as a float, or 0.0 for a single point.
    """
    if len(values) < 2:
        return 0.0
    variance = sum((v - mean) ** 2 for v in values) / len(values)
    return math.sqrt(variance)


def _classify_severity(deviation: float) -> AnomalySeverity:
    """Map a deviation magnitude to an AnomalySeverity level.

    Args:
        deviation: Absolute deviation in standard-deviation units.

    Returns:
        CRITICAL if deviation >= 2.5, ELEVATED if >= 2.0, else NORMAL.
    """
    if deviation >= _CRITICAL_THRESHOLD:
        return AnomalySeverity.CRITICAL
    if deviation >= _ELEVATED_THRESHOLD:
        return AnomalySeverity.ELEVATED
    return AnomalySeverity.NORMAL


# ---------------------------------------------------------------------------
# Main service
# ---------------------------------------------------------------------------


class AnomalyDetector:
    """Service that detects statistical anomalies in a user's health metrics.

    Queries ``daily_health_metrics`` and ``sleep_records`` for the last 30
    days and applies a rolling-baseline z-score check.  Only metrics with
    at least ``_MIN_DATA_POINTS`` (14) non-null observations activate the
    check; metrics with fewer data points are silently skipped.

    Usage::

        detector = AnomalyDetector()
        results = await detector.check_for_anomalies(user_id, session)
        if results:
            await detector.store_anomaly_insights(user_id, results, session)
    """

    # ------------------------------------------------------------------
    # Core detection
    # ------------------------------------------------------------------

    async def check_for_anomalies(
        self,
        user_id: str,
        session: AsyncSession,
    ) -> list[AnomalyResult]:
        """Run anomaly detection across all monitored health metrics.

        Queries the last 30 days of ``daily_health_metrics`` rows for the
        user.  For each scalar metric listed in ``_SCALAR_METRICS``, collects
        all non-null values from the *prior* 29 days as the baseline, then
        compares today's value against that baseline.  Applies the same logic
        to ``sleep_records`` for sleep-duration anomalies.

        Args:
            user_id: The authenticated user's Supabase ID.
            session: An active async SQLAlchemy session.

        Returns:
            A list of :class:`AnomalyResult` objects, one per metric where an
            anomaly (ELEVATED or CRITICAL) was detected.  Returns an empty
            list if no anomalies are found or insufficient data exists.
        """
        today = date.today()
        window_start = (today - timedelta(days=29)).isoformat()  # 30-day window incl. today
        today_str = today.isoformat()

        # Fetch all rows for the rolling window
        stmt = (
            select(DailyHealthMetrics)
            .where(
                DailyHealthMetrics.user_id == user_id,
                DailyHealthMetrics.date >= window_start,
                DailyHealthMetrics.date <= today_str,
            )
            .order_by(DailyHealthMetrics.date)
        )
        result = await session.execute(stmt)
        rows: list[DailyHealthMetrics] = list(result.scalars().all())

        logger.debug(
            "AnomalyDetector: %d daily_health_metrics rows for user '%s' in window [%s, %s]",
            len(rows),
            user_id,
            window_start,
            today_str,
        )

        anomalies: list[AnomalyResult] = []

        # --- Scalar metrics --------------------------------------------------
        for metric in _SCALAR_METRICS:
            anomaly = self._check_scalar_metric(metric, today_str, rows)
            if anomaly is not None:
                anomalies.append(anomaly)

        # --- Sleep duration --------------------------------------------------
        sleep_anomaly = await self._check_sleep_duration(user_id, today_str, window_start, session)
        if sleep_anomaly is not None:
            anomalies.append(sleep_anomaly)

        logger.info(
            "AnomalyDetector: %d anomalies detected for user '%s'",
            len(anomalies),
            user_id,
        )
        return anomalies

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    def _check_scalar_metric(
        self,
        metric: str,
        today_str: str,
        rows: list[DailyHealthMetrics],
    ) -> AnomalyResult | None:
        """Evaluate a single scalar metric for anomalous behaviour.

        Splits the rows into baseline (all days *before* today) and today's
        observation.  Requires at least ``_MIN_DATA_POINTS`` non-null values
        across both sets before performing the z-score check.

        Args:
            metric: Column name on :class:`DailyHealthMetrics`.
            today_str: ISO date string for the current day (``YYYY-MM-DD``).
            rows: Pre-fetched rows for the 30-day window, including today.

        Returns:
            An :class:`AnomalyResult` if the deviation exceeds the threshold,
            otherwise ``None``.
        """
        baseline_values: list[float] = []
        today_value: float | None = None

        for row in rows:
            val = getattr(row, metric, None)
            if val is None:
                continue
            val = float(val)
            if row.date == today_str:
                # Take the latest row for today (last write wins)
                today_value = val
            else:
                baseline_values.append(val)

        # Include today in the count for the minimum-data-points gate
        total_points = len(baseline_values) + (1 if today_value is not None else 0)
        if total_points < _MIN_DATA_POINTS:
            logger.debug(
                "Metric '%s': only %d data points (need %d) — skipping",
                metric,
                total_points,
                _MIN_DATA_POINTS,
            )
            return None

        if today_value is None:
            return None

        if not baseline_values:
            return None

        mean = _mean(baseline_values)
        std = _std(baseline_values, mean)

        if std == 0.0:
            # All baseline values identical — cannot compute deviation
            return None

        deviation = abs(today_value - mean) / std
        severity = _classify_severity(deviation)

        if severity == AnomalySeverity.NORMAL:
            return None

        logger.info(
            "Anomaly detected — metric='%s' value=%.2f mean=%.2f std=%.2f deviation=%.2f severity=%s",
            metric,
            today_value,
            mean,
            std,
            deviation,
            severity.value,
        )

        return AnomalyResult(
            metric_name=metric,
            current_value=today_value,
            baseline_mean=mean,
            baseline_std=std,
            deviation_magnitude=deviation,
            severity=severity,
        )

    async def _check_sleep_duration(
        self,
        user_id: str,
        today_str: str,
        window_start: str,
        session: AsyncSession,
    ) -> AnomalyResult | None:
        """Evaluate sleep duration for anomalous behaviour.

        Fetches ``sleep_records`` for the 30-day window and applies the same
        z-score logic as the scalar metrics.

        Args:
            user_id: The authenticated user's Supabase ID.
            today_str: ISO date string for the current day.
            window_start: ISO date string for the start of the 30-day window.
            session: An active async SQLAlchemy session.

        Returns:
            An :class:`AnomalyResult` for ``sleep_duration_hours`` if an
            anomaly is detected, otherwise ``None``.
        """
        stmt = (
            select(SleepRecord)
            .where(
                SleepRecord.user_id == user_id,
                SleepRecord.date >= window_start,
                SleepRecord.date <= today_str,
            )
            .order_by(SleepRecord.date)
        )
        result = await session.execute(stmt)
        sleep_rows: list[SleepRecord] = list(result.scalars().all())

        baseline_values: list[float] = []
        today_value: float | None = None

        for row in sleep_rows:
            if row.hours is None:
                continue
            val = float(row.hours)
            if row.date == today_str:
                today_value = val
            else:
                baseline_values.append(val)

        total_points = len(baseline_values) + (1 if today_value is not None else 0)
        if total_points < _MIN_DATA_POINTS:
            return None

        if today_value is None or not baseline_values:
            return None

        mean = _mean(baseline_values)
        std = _std(baseline_values, mean)

        if std == 0.0:
            return None

        deviation = abs(today_value - mean) / std
        severity = _classify_severity(deviation)

        if severity == AnomalySeverity.NORMAL:
            return None

        return AnomalyResult(
            metric_name="sleep_duration_hours",
            current_value=today_value,
            baseline_mean=mean,
            baseline_std=std,
            deviation_magnitude=deviation,
            severity=severity,
        )

    # ------------------------------------------------------------------
    # Insight storage
    # ------------------------------------------------------------------

    async def store_anomaly_insights(
        self,
        user_id: str,
        anomalies: list[AnomalyResult],
        session: AsyncSession,
    ) -> None:
        """Persist detected anomalies as insight records.

        Each :class:`AnomalyResult` is stored as an ``Insight`` row via the
        ``app.models.insight`` model (available from Phase 2 onwards).  If the
        model is unavailable at import time the method logs a warning and
        returns without raising.

        Args:
            user_id: The authenticated user's Supabase ID.
            anomalies: List of anomalies to persist.
            session: An active async SQLAlchemy session.
        """
        if not anomalies:
            return

        try:
            from app.models.insight import Insight  # type: ignore[import]
        except ImportError:
            logger.warning("app.models.insight not yet available — anomaly insights not stored")
            return

        for anomaly in anomalies:
            title = f"{anomaly.metric_name.replace('_', ' ').title()} anomaly detected"
            body = (
                f"Today's {anomaly.metric_name} ({anomaly.current_value:.1f}) "
                f"deviates {anomaly.deviation_magnitude:.1f}σ from your 30-day "
                f"baseline (mean {anomaly.baseline_mean:.1f}, "
                f"std {anomaly.baseline_std:.1f}). "
                f"Severity: {anomaly.severity.value}."
            )
            data = {
                "metric_name": anomaly.metric_name,
                "current_value": anomaly.current_value,
                "baseline_mean": anomaly.baseline_mean,
                "baseline_std": anomaly.baseline_std,
                "deviation_magnitude": anomaly.deviation_magnitude,
                "severity": anomaly.severity.value,
                "detected_at": anomaly.detected_at.isoformat(),
            }
            priority = 2 if anomaly.severity == AnomalySeverity.CRITICAL else 3
            insight = Insight(
                id=str(uuid.uuid4()),
                user_id=user_id,
                type="anomaly_alert",
                title=title,
                body=body,
                data=data,
                priority=priority,
            )
            session.add(insight)

        await session.commit()
        logger.info(
            "Stored %d anomaly insight(s) for user '%s'",
            len(anomalies),
            user_id,
        )
