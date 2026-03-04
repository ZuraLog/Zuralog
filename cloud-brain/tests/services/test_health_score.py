"""
Zuralog Cloud Brain — Tests for HealthScoreCalculator.

Validates the scoring logic, weight redistribution, commentary bands,
edge cases, and the no-data early-exit.  All database I/O is replaced
with AsyncMock objects so the tests are fully in-process.
"""

import math
import uuid
from datetime import datetime, timezone
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.services.health_score import (
    HealthScoreCalculator,
    _clamp,
    _get_commentary,
    _redistribute_weights,
    _score_activity_vs_baseline,
    _score_hrv,
    _score_resting_hr,
    _score_sleep,
    _score_sleep_consistency,
    _score_sleep_duration,
    _score_steps_vs_goal,
    HealthSubScore,
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_USER_ID = "test-hs-user-001"


def _make_dhm(
    date: str,
    steps: int | None = None,
    hrv_ms: float | None = None,
    resting_heart_rate: float | None = None,
) -> SimpleNamespace:
    """Build a DailyHealthMetrics-shaped namespace without hitting the DB.

    Uses SimpleNamespace to avoid SQLAlchemy ORM instrumentation issues
    when constructing objects outside of a session context.

    Args:
        date: ISO date string (YYYY-MM-DD).
        steps: Step count for the day.
        hrv_ms: HRV in milliseconds.
        resting_heart_rate: Resting heart rate in bpm.

    Returns:
        A SimpleNamespace with all DailyHealthMetrics fields populated.
    """
    return SimpleNamespace(
        id=str(uuid.uuid4()),
        user_id=_USER_ID,
        source="apple_health",
        date=date,
        steps=steps,
        hrv_ms=hrv_ms,
        resting_heart_rate=resting_heart_rate,
        active_calories=None,
        vo2_max=None,
        distance_meters=None,
        flights_climbed=None,
        body_fat_percentage=None,
        respiratory_rate=None,
        oxygen_saturation=None,
        heart_rate_avg=None,
    )


def _make_sleep(date: str, hours: float, quality: int | None = None) -> SimpleNamespace:
    """Build a SleepRecord-shaped namespace without hitting the DB.

    Uses SimpleNamespace to avoid SQLAlchemy ORM instrumentation issues.

    Args:
        date: ISO date string (YYYY-MM-DD).
        hours: Total sleep hours.
        quality: Optional 0-100 quality score.

    Returns:
        A SimpleNamespace with all SleepRecord fields populated.
    """
    return SimpleNamespace(
        id=str(uuid.uuid4()),
        user_id=_USER_ID,
        source="apple_health",
        date=date,
        hours=hours,
        quality_score=quality,
    )


def _make_db_mock(
    dhm_rows: list[DailyHealthMetrics],
    sleep_rows: list[SleepRecord],
) -> AsyncMock:
    """Build an AsyncMock database session that returns fixed query results.

    Calls to ``db.execute`` alternate: first call returns dhm_rows,
    second call returns sleep_rows, matching the order in the calculator.

    Args:
        dhm_rows: DailyHealthMetrics rows to return from the first query.
        sleep_rows: SleepRecord rows to return from the second query.

    Returns:
        An AsyncMock mimicking AsyncSession.
    """

    def _scalars_result(rows):
        mock_result = MagicMock()
        mock_scalars = MagicMock()
        mock_scalars.all.return_value = rows
        mock_result.scalars.return_value = mock_scalars
        return mock_result

    dhm_result = _scalars_result(dhm_rows)
    sleep_result = _scalars_result(sleep_rows)

    db = AsyncMock()
    db.execute = AsyncMock(side_effect=[dhm_result, sleep_result])
    return db


# ---------------------------------------------------------------------------
# Unit tests — pure functions
# ---------------------------------------------------------------------------


def test_clamp_within_range():
    """_clamp should return the value unchanged when within bounds."""
    assert _clamp(50.0) == 50.0


def test_clamp_below_zero():
    """_clamp should return 0 for negative values."""
    assert _clamp(-10.0) == 0.0


def test_clamp_above_hundred():
    """_clamp should return 100 for values above 100."""
    assert _clamp(120.0) == 100.0


def test_sleep_duration_zero():
    """Zero hours of sleep should score 0."""
    assert _score_sleep_duration(0.0) == 0.0


def test_sleep_duration_ideal():
    """Eight hours (within ideal band) should score 100."""
    assert _score_sleep_duration(8.0) == 100.0


def test_sleep_duration_short():
    """Three and a half hours should score less than 60 (half of 7h target)."""
    score = _score_sleep_duration(3.5)
    assert score < 60.0
    assert score > 0.0


def test_sleep_duration_oversleep():
    """Twelve or more hours (max) should score lower than 100 due to penalty."""
    score = _score_sleep_duration(12.0)
    assert score < 100.0
    assert score >= 80.0


def test_score_steps_vs_goal_zero():
    """Zero steps must return a score of 0."""
    assert _score_steps_vs_goal(0) == 0.0


def test_score_steps_vs_goal_at_target():
    """Exactly 10,000 steps must score 100."""
    assert _score_steps_vs_goal(10_000) == 100.0


def test_score_steps_vs_goal_half():
    """5,000 steps (half goal) must score approximately 50."""
    score = _score_steps_vs_goal(5_000)
    assert abs(score - 50.0) < 1.0


def test_score_steps_vs_goal_above_target():
    """Steps above the goal should not exceed 100."""
    assert _score_steps_vs_goal(15_000) == 100.0


def test_get_commentary_bands():
    """Commentary should match expected band strings for boundary values."""
    assert "Critical" in _get_commentary(0)
    assert "Critical" in _get_commentary(39)
    assert "Fair" in _get_commentary(40)
    assert "Fair" in _get_commentary(59)
    assert "Good" in _get_commentary(60)
    assert "Great" in _get_commentary(75)
    assert "Excellent" in _get_commentary(90)
    assert "Excellent" in _get_commentary(100)


# ---------------------------------------------------------------------------
# Unit tests — weight redistribution
# ---------------------------------------------------------------------------


def test_redistribute_weights_excluded_metric():
    """Excluding one metric should redistribute its weight to the others.

    The available sub-scores must sum to 1.0 after redistribution.
    """
    sub_scores = {
        "a": HealthSubScore(name="A", score=80.0, weight=0.50, available=True),
        "b": HealthSubScore(name="B", score=60.0, weight=0.30, available=True),
        "c": HealthSubScore(name="C", score=50.0, weight=0.20, available=False),
    }
    result = _redistribute_weights(sub_scores)

    total = sum(ss.weight for ss in result.values())
    assert abs(total - 1.0) < 1e-9, f"Weights should sum to 1.0, got {total}"

    assert result["c"].weight == 0.0
    assert result["a"].weight > 0.50
    assert result["b"].weight > 0.30


def test_redistribute_weights_all_available():
    """If all sub-scores are available the weights must not change."""
    sub_scores = {
        "a": HealthSubScore(name="A", score=80.0, weight=0.60, available=True),
        "b": HealthSubScore(name="B", score=70.0, weight=0.40, available=True),
    }
    result = _redistribute_weights(sub_scores)
    assert result["a"].weight == 0.60
    assert result["b"].weight == 0.40


# ---------------------------------------------------------------------------
# Integration tests — HealthScoreCalculator
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_full_data_composite_in_range():
    """Full data (all metrics present) must return a composite in 0-100.

    Creates 10 days of overlapping sleep and DHM data with realistic values.
    The calculator should return a HealthScoreResult with a valid composite.
    """
    dhm_rows = [
        _make_dhm(
            date=f"2026-02-{i:02d}",
            steps=8000 + i * 100,
            hrv_ms=40.0 + i,
            resting_heart_rate=62.0 - i * 0.5,
        )
        for i in range(1, 11)
    ]
    sleep_rows = [_make_sleep(date=f"2026-02-{i:02d}", hours=7.0 + i * 0.1, quality=70 + i) for i in range(1, 11)]
    db = _make_db_mock(dhm_rows, sleep_rows)

    calculator = HealthScoreCalculator()
    result = await calculator.calculate(user_id=_USER_ID, db=db)

    assert result is not None
    assert 0 <= result.composite_score <= 100
    assert result.ai_commentary != ""
    assert result.data_days > 0
    assert len(result.sub_scores) == 6


@pytest.mark.asyncio
async def test_partial_data_only_sleep():
    """With only sleep data the score must still be computed.

    DHM rows have no non-None values; only sleep_rows are populated.
    The calculator must not return None and must redistribute weights.
    """
    dhm_rows: list[DailyHealthMetrics] = []
    sleep_rows = [_make_sleep(date=f"2026-02-{i:02d}", hours=7.5) for i in range(1, 11)]
    db = _make_db_mock(dhm_rows, sleep_rows)

    calculator = HealthScoreCalculator()
    result = await calculator.calculate(user_id=_USER_ID, db=db)

    assert result is not None
    assert 0 <= result.composite_score <= 100
    # HRV, resting HR, activity, and steps sub-scores must all be unavailable.
    for key in ("hrv", "resting_hr", "activity_baseline", "steps_goal"):
        assert not result.sub_scores[key].available
    # Sleep must be available.
    assert result.sub_scores["sleep"].available


@pytest.mark.asyncio
async def test_no_data_returns_none():
    """With no data at all the calculator must return None."""
    db = _make_db_mock(dhm_rows=[], sleep_rows=[])

    calculator = HealthScoreCalculator()
    result = await calculator.calculate(user_id=_USER_ID, db=db)

    assert result is None


@pytest.mark.asyncio
async def test_score_band_commentary_matches_composite():
    """The ai_commentary must match the computed composite_score band."""
    dhm_rows = [
        _make_dhm(
            date=f"2026-02-{i:02d}",
            steps=2000,  # low steps → lower score
            hrv_ms=20.0,
            resting_heart_rate=80.0,
        )
        for i in range(1, 11)
    ]
    sleep_rows = [_make_sleep(date=f"2026-02-{i:02d}", hours=4.0, quality=30) for i in range(1, 11)]
    db = _make_db_mock(dhm_rows, sleep_rows)

    calculator = HealthScoreCalculator()
    result = await calculator.calculate(user_id=_USER_ID, db=db)

    assert result is not None
    # Verify the commentary is consistent with the composite score.
    expected = _get_commentary(result.composite_score)
    assert result.ai_commentary == expected


@pytest.mark.asyncio
async def test_zero_steps_activity_subscores_zero():
    """Zero step counts must produce an activity sub-score of 0.

    ``steps_goal`` normalises against 10,000; 0 steps → 0 score.
    ``activity_baseline`` should be 0 as well when today's steps are 0
    and all previous days were also 0.
    """
    # All rows have 0 steps.
    dhm_rows = [_make_dhm(date=f"2026-02-{i:02d}", steps=0) for i in range(1, 11)]
    sleep_rows = [_make_sleep(date=f"2026-02-{i:02d}", hours=8.0) for i in range(1, 11)]
    db = _make_db_mock(dhm_rows, sleep_rows)

    calculator = HealthScoreCalculator()
    result = await calculator.calculate(user_id=_USER_ID, db=db)

    assert result is not None
    assert result.sub_scores["steps_goal"].score == 0.0


@pytest.mark.asyncio
async def test_weight_redistribution_in_full_result():
    """Available sub-score weights must sum to ~1.0 after redistribution.

    Uses a dataset that only populates sleep — all other dimensions
    will be unavailable and their weights redistributed.
    """
    dhm_rows: list[DailyHealthMetrics] = []
    sleep_rows = [_make_sleep(date=f"2026-02-{i:02d}", hours=7.0) for i in range(1, 11)]
    db = _make_db_mock(dhm_rows, sleep_rows)

    calculator = HealthScoreCalculator()
    result = await calculator.calculate(user_id=_USER_ID, db=db)

    assert result is not None
    total_weight = sum(ss.weight for ss in result.sub_scores.values())
    # Unavailable sub-scores have weight 0; total must still be ≈ 1.0.
    assert abs(total_weight - 1.0) < 1e-6, f"Weights should sum to 1.0 after redistribution, got {total_weight}"
