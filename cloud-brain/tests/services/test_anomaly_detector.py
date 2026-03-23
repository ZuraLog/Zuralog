"""Tests for AnomalyDetector.

Covers the five required scenarios:

1. ``test_no_anomaly_when_within_threshold`` — value within 1.5 stddev → empty list
2. ``test_elevated_anomaly_detected``         — 2.5 stddev → severity="elevated"
3. ``test_critical_anomaly_detected``         — 3.5 stddev → severity="critical"
4. ``test_insufficient_data_skipped``         — <14 days → no anomaly check
5. ``test_direction_high_and_low``            — detects both high and low anomalies

All tests use a mocked AsyncSession and synthetic ``DailySummary`` instances
so that no real database connection is required.
"""

from __future__ import annotations

import math
from datetime import date, timedelta
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.anomaly_detector import (
    AnomalyDetector,
    AnomalyResult,
    _MIN_DATA_POINTS,
    _LOOKBACK_DAYS,
)


# ---------------------------------------------------------------------------
# Fixture helpers
# ---------------------------------------------------------------------------


def _make_daily_summary(date_val: str | date, metric_type: str, value: float) -> SimpleNamespace:
    """Build a minimal DailySummary-like object without touching the ORM."""
    return SimpleNamespace(
        date=date_val if isinstance(date_val, date) else date.fromisoformat(date_val),
        metric_type=metric_type,
        value=value,
    )


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


def _build_rhr_rows(target: date, baseline_values: list[float], current_val: float | None = None):
    """Build a list of DailySummary-like rows for resting_heart_rate."""
    rows = []
    for i, val in enumerate(baseline_values):
        d = target - timedelta(days=len(baseline_values) - i)
        rows.append(_make_daily_summary(d, "resting_heart_rate", val))
    if current_val is not None:
        rows.append(_make_daily_summary(target, "resting_heart_rate", current_val))
    return rows


# ---------------------------------------------------------------------------
# Fixtures
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

    baseline_values = _build_baseline(target, baseline_mean, baseline_stddev, n_days=20)
    current_val = baseline_mean + 1.5 * baseline_stddev
    daily_rows = _build_rhr_rows(target, baseline_values, current_val)

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

    baseline_values = _build_baseline(target, baseline_mean, baseline_stddev, n_days=20)
    current_val = baseline_mean + 2.5 * baseline_stddev
    daily_rows = _build_rhr_rows(target, baseline_values, current_val)

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

    baseline_values = _build_baseline(target, baseline_mean, baseline_stddev, n_days=20)
    current_val = baseline_mean + 3.5 * baseline_stddev
    daily_rows = _build_rhr_rows(target, baseline_values, current_val)

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
    baseline_mean = 70.0
    baseline_stddev = 5.0

    # Only 10 baseline days — below _MIN_DATA_POINTS (14).
    baseline_values = _build_baseline(target, baseline_mean, baseline_stddev, n_days=10)
    current_val = baseline_mean + 10.0 * baseline_stddev
    daily_rows = _build_rhr_rows(target, baseline_values, current_val)

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
    baseline_values = _build_baseline(high_target, baseline_mean, baseline_stddev, n_days=20)
    high_rows = _build_rhr_rows(high_target, baseline_values, baseline_mean + 2.5 * baseline_stddev)

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
    low_rows = _build_rhr_rows(low_target, baseline_values, baseline_mean - 2.5 * baseline_stddev)

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
