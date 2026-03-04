"""Tests for AnomalyDetector.

Covers the five required scenarios:

1. ``test_no_anomaly_when_within_threshold`` — value within 1.5 stddev → empty list
2. ``test_elevated_anomaly_detected``         — 2.5 stddev → severity="elevated"
3. ``test_critical_anomaly_detected``         — 3.5 stddev → severity="critical"
4. ``test_insufficient_data_skipped``         — <14 days → no anomaly check
5. ``test_direction_high_and_low``            — detects both high and low anomalies

All tests use a mocked AsyncSession populated with synthetic
``DailyHealthMetrics`` and ``SleepRecord`` instances so that no real
database connection is required.
"""

from __future__ import annotations

import math
from datetime import date, timedelta
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.models.daily_metrics import DailyHealthMetrics
from app.models.health_data import SleepRecord
from app.services.anomaly_detector import (
    AnomalyDetector,
    AnomalyResult,
    _MIN_DATA_POINTS,
    _LOOKBACK_DAYS,
)


# ---------------------------------------------------------------------------
# Fixture helpers
# ---------------------------------------------------------------------------


def _make_daily_row(date_str: str, resting_hr: float | None = None, steps: int | None = None) -> DailyHealthMetrics:
    """Build a minimal DailyHealthMetrics object without a database."""
    row = DailyHealthMetrics.__new__(DailyHealthMetrics)
    row.date = date_str
    row.resting_heart_rate = resting_hr
    row.hrv_ms = None
    row.steps = steps
    row.active_calories = None
    return row


def _make_sleep_row(date_str: str, hours: float | None = None, quality: int | None = None) -> SleepRecord:
    """Build a minimal SleepRecord object without a database."""
    row = SleepRecord.__new__(SleepRecord)
    row.date = date_str
    row.hours = hours
    row.quality_score = quality
    return row


def _build_baseline(
    target_date: date,
    baseline_mean: float,
    baseline_stddev: float,
    n_days: int = _MIN_DATA_POINTS,
) -> list[float]:
    """Generate *n_days* values whose mean and stddev match the given parameters.

    Uses an alternating pattern around *baseline_mean* so that the
    population stddev equals *baseline_stddev*.
    """
    if n_days < 2:
        return [baseline_mean] * n_days

    # Pattern: alternate +stddev and -stddev around mean.
    # Population stddev of the alternating sequence equals stddev when n is even.
    half = n_days // 2
    values = [baseline_mean + baseline_stddev] * half + [baseline_mean - baseline_stddev] * (n_days - half)
    return values


def _make_mock_db(daily_rows: list[DailyHealthMetrics], sleep_rows: list[SleepRecord]) -> AsyncMock:
    """Return an AsyncMock AsyncSession whose execute() yields the given rows."""
    db = AsyncMock()

    async def _execute(stmt):
        # Inspect the stmt to determine which table is being queried.
        # We use the compiled string as a heuristic; a real app would use
        # SQLAlchemy's inspection API or separate call tracking.
        stmt_str = str(stmt)
        mock_result = MagicMock()
        if "daily_health_metrics" in stmt_str or "DailyHealthMetrics" in str(type(stmt)):
            mock_result.scalars.return_value.all.return_value = daily_rows
        else:
            mock_result.scalars.return_value.all.return_value = sleep_rows
        return mock_result

    db.execute = _execute
    return db


# ---------------------------------------------------------------------------
# A simpler approach: mock the private fetch methods directly
# ---------------------------------------------------------------------------


@pytest.fixture
def detector() -> AnomalyDetector:
    return AnomalyDetector()


@pytest.fixture
def target() -> date:
    return date(2026, 3, 4)


# ---------------------------------------------------------------------------
# Test 1 — no anomaly when within threshold (1.5 stddev)
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_no_anomaly_when_within_threshold(detector: AnomalyDetector, target: date) -> None:
    """A current value 1.5 stddevs from the mean should produce an empty result."""
    baseline_mean = 70.0
    baseline_stddev = 5.0
    target_date_str = target.isoformat()

    # Build 20 baseline rows (alternating around mean).
    baseline_values = _build_baseline(target, baseline_mean, baseline_stddev, n_days=20)
    daily_rows: list[DailyHealthMetrics] = []
    for i, val in enumerate(baseline_values):
        d = (target - timedelta(days=len(baseline_values) - i)).isoformat()
        daily_rows.append(_make_daily_row(d, resting_hr=val))

    # Current value = mean + 1.5 * stddev (below the 2.0 threshold)
    current_val = baseline_mean + 1.5 * baseline_stddev
    daily_rows.append(_make_daily_row(target_date_str, resting_hr=current_val))

    async def _fake_fetch_daily(user_id, db, td):
        return daily_rows

    async def _fake_fetch_sleep(user_id, db, td):
        return []

    with (
        patch.object(detector, "_fetch_daily_metrics", _fake_fetch_daily),
        patch.object(detector, "_fetch_sleep_records", _fake_fetch_sleep),
    ):
        results = await detector.check_user_metrics("user-1", AsyncMock(), target)

    assert results == [], f"Expected no anomalies, got: {results}"


# ---------------------------------------------------------------------------
# Test 2 — elevated anomaly detected (2.5 stddev)
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_elevated_anomaly_detected(detector: AnomalyDetector, target: date) -> None:
    """A current value 2.5 stddevs above the mean should be 'elevated'."""
    baseline_mean = 70.0
    baseline_stddev = 5.0
    target_date_str = target.isoformat()

    baseline_values = _build_baseline(target, baseline_mean, baseline_stddev, n_days=20)
    daily_rows: list[DailyHealthMetrics] = []
    for i, val in enumerate(baseline_values):
        d = (target - timedelta(days=len(baseline_values) - i)).isoformat()
        daily_rows.append(_make_daily_row(d, resting_hr=val))

    # 2.5 stddevs above mean
    current_val = baseline_mean + 2.5 * baseline_stddev
    daily_rows.append(_make_daily_row(target_date_str, resting_hr=current_val))

    async def _fake_fetch_daily(user_id, db, td):
        return daily_rows

    async def _fake_fetch_sleep(user_id, db, td):
        return []

    with (
        patch.object(detector, "_fetch_daily_metrics", _fake_fetch_daily),
        patch.object(detector, "_fetch_sleep_records", _fake_fetch_sleep),
    ):
        results = await detector.check_user_metrics("user-1", AsyncMock(), target)

    rhr_results = [r for r in results if r.metric == "resting_heart_rate"]
    assert len(rhr_results) == 1, f"Expected 1 resting_heart_rate result, got {rhr_results}"

    anomaly = rhr_results[0]
    assert anomaly.severity == "elevated", f"Expected 'elevated', got '{anomaly.severity}'"
    assert anomaly.direction == "high"
    assert 2.0 <= anomaly.deviation_magnitude < 3.0


# ---------------------------------------------------------------------------
# Test 3 — critical anomaly detected (3.5 stddev)
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_critical_anomaly_detected(detector: AnomalyDetector, target: date) -> None:
    """A current value 3.5 stddevs above the mean should be 'critical'."""
    baseline_mean = 70.0
    baseline_stddev = 5.0
    target_date_str = target.isoformat()

    baseline_values = _build_baseline(target, baseline_mean, baseline_stddev, n_days=20)
    daily_rows: list[DailyHealthMetrics] = []
    for i, val in enumerate(baseline_values):
        d = (target - timedelta(days=len(baseline_values) - i)).isoformat()
        daily_rows.append(_make_daily_row(d, resting_hr=val))

    # 3.5 stddevs above mean
    current_val = baseline_mean + 3.5 * baseline_stddev
    daily_rows.append(_make_daily_row(target_date_str, resting_hr=current_val))

    async def _fake_fetch_daily(user_id, db, td):
        return daily_rows

    async def _fake_fetch_sleep(user_id, db, td):
        return []

    with (
        patch.object(detector, "_fetch_daily_metrics", _fake_fetch_daily),
        patch.object(detector, "_fetch_sleep_records", _fake_fetch_sleep),
    ):
        results = await detector.check_user_metrics("user-1", AsyncMock(), target)

    rhr_results = [r for r in results if r.metric == "resting_heart_rate"]
    assert len(rhr_results) == 1

    anomaly = rhr_results[0]
    assert anomaly.severity == "critical", f"Expected 'critical', got '{anomaly.severity}'"
    assert anomaly.direction == "high"
    assert anomaly.deviation_magnitude >= 3.0


# ---------------------------------------------------------------------------
# Test 4 — insufficient data is skipped (<14 days)
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_insufficient_data_skipped(detector: AnomalyDetector, target: date) -> None:
    """Fewer than 14 days of data should yield no anomaly results."""
    target_date_str = target.isoformat()
    baseline_mean = 70.0
    baseline_stddev = 5.0

    # Only 10 baseline days — below _MIN_DATA_POINTS (14).
    baseline_values = _build_baseline(target, baseline_mean, baseline_stddev, n_days=10)
    daily_rows: list[DailyHealthMetrics] = []
    for i, val in enumerate(baseline_values):
        d = (target - timedelta(days=len(baseline_values) - i)).isoformat()
        daily_rows.append(_make_daily_row(d, resting_hr=val))

    # Even an extreme current value should not trigger an anomaly.
    current_val = baseline_mean + 10.0 * baseline_stddev
    daily_rows.append(_make_daily_row(target_date_str, resting_hr=current_val))

    async def _fake_fetch_daily(user_id, db, td):
        return daily_rows

    async def _fake_fetch_sleep(user_id, db, td):
        return []

    with (
        patch.object(detector, "_fetch_daily_metrics", _fake_fetch_daily),
        patch.object(detector, "_fetch_sleep_records", _fake_fetch_sleep),
    ):
        results = await detector.check_user_metrics("user-1", AsyncMock(), target)

    assert results == [], (
        f"Expected no anomalies with insufficient data, got: {results}. "
        f"Baseline days provided: {len(baseline_values)}, minimum required: {_MIN_DATA_POINTS}"
    )


# ---------------------------------------------------------------------------
# Test 5 — direction: detects both high and low anomalies
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_direction_high_and_low(detector: AnomalyDetector, target: date) -> None:
    """The detector should correctly classify both high and low anomalies."""
    baseline_mean = 70.0
    baseline_stddev = 5.0

    # --- HIGH anomaly: current > mean by 2.5 stddevs ---
    high_target = target
    high_target_str = high_target.isoformat()
    baseline_values = _build_baseline(high_target, baseline_mean, baseline_stddev, n_days=20)
    high_rows: list[DailyHealthMetrics] = []
    for i, val in enumerate(baseline_values):
        d = (high_target - timedelta(days=len(baseline_values) - i)).isoformat()
        high_rows.append(_make_daily_row(d, resting_hr=val))
    high_rows.append(_make_daily_row(high_target_str, resting_hr=baseline_mean + 2.5 * baseline_stddev))

    async def _fake_fetch_daily_high(user_id, db, td):
        return high_rows

    async def _fake_fetch_sleep_empty(user_id, db, td):
        return []

    with (
        patch.object(detector, "_fetch_daily_metrics", _fake_fetch_daily_high),
        patch.object(detector, "_fetch_sleep_records", _fake_fetch_sleep_empty),
    ):
        high_results = await detector.check_user_metrics("user-high", AsyncMock(), high_target)

    high_rhr = [r for r in high_results if r.metric == "resting_heart_rate"]
    assert len(high_rhr) == 1
    assert high_rhr[0].direction == "high", f"Expected direction='high', got '{high_rhr[0].direction}'"
    assert high_rhr[0].current_value > high_rhr[0].baseline_mean

    # --- LOW anomaly: current < mean by 2.5 stddevs ---
    low_target = target - timedelta(days=1)
    low_target_str = low_target.isoformat()
    low_rows: list[DailyHealthMetrics] = []
    for i, val in enumerate(baseline_values):
        d = (low_target - timedelta(days=len(baseline_values) - i)).isoformat()
        low_rows.append(_make_daily_row(d, resting_hr=val))
    low_rows.append(_make_daily_row(low_target_str, resting_hr=baseline_mean - 2.5 * baseline_stddev))

    async def _fake_fetch_daily_low(user_id, db, td):
        return low_rows

    with (
        patch.object(detector, "_fetch_daily_metrics", _fake_fetch_daily_low),
        patch.object(detector, "_fetch_sleep_records", _fake_fetch_sleep_empty),
    ):
        low_results = await detector.check_user_metrics("user-low", AsyncMock(), low_target)

    low_rhr = [r for r in low_results if r.metric == "resting_heart_rate"]
    assert len(low_rhr) == 1
    assert low_rhr[0].direction == "low", f"Expected direction='low', got '{low_rhr[0].direction}'"
    assert low_rhr[0].current_value < low_rhr[0].baseline_mean
