"""Tests for HealthScoreCalculator.

Covers the six required scenarios using unittest.mock to avoid a real
database.  Each test builds a fixture AsyncSession whose ``execute``
side-effect returns pre-built ORM-like objects.
"""

from __future__ import annotations

import statistics
from datetime import date, datetime, timedelta, timezone
from types import SimpleNamespace
from typing import Any
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.health_score import (
    HealthScoreCalculator,
    HealthScoreResult,
    _METRIC_LABELS,
)


# ---------------------------------------------------------------------------
# Helpers / fixtures
# ---------------------------------------------------------------------------

def _make_daily(
    date_str: str,
    steps: int | None = 8000,
    active_calories: int | None = 400,
    resting_heart_rate: float | None = 58.0,
    hrv_ms: float | None = 55.0,
) -> SimpleNamespace:
    """Build a mock DailyHealthMetrics row."""
    return SimpleNamespace(
        date=date_str,
        steps=steps,
        active_calories=active_calories,
        resting_heart_rate=resting_heart_rate,
        hrv_ms=hrv_ms,
    )


def _make_sleep(date_str: str, hours: float = 7.5, quality_score: int | None = 80) -> SimpleNamespace:
    """Build a mock SleepRecord row."""
    return SimpleNamespace(date=date_str, hours=hours, quality_score=quality_score)


def _today() -> str:
    return datetime.now(tz=timezone.utc).date().isoformat()


def _date_before(days: int) -> str:
    d = datetime.now(tz=timezone.utc).date() - timedelta(days=days)
    return d.isoformat()


def _make_activity(date_str: str, calories: int = 300, duration_seconds: int = 1800) -> SimpleNamespace:
    """Build a mock UnifiedActivity row."""
    d = date.fromisoformat(date_str)
    return SimpleNamespace(
        start_time=datetime(d.year, d.month, d.day, 10, 0, 0, tzinfo=timezone.utc),
        calories=calories,
        duration_seconds=duration_seconds,
    )


# ---------------------------------------------------------------------------
# DB session mock factory
# ---------------------------------------------------------------------------

def _build_db(
    daily_rows: list,
    sleep_rows: list,
    activity_rows: list | None = None,
) -> AsyncMock:
    """Create an AsyncMock database session.

    ``execute`` is called once per query type (daily metrics, sleep, activity,
    and up to 31 sleep-consistency windows).  We detect which query was issued
    by inspecting the model class embedded in the WHERE clause via the
    statement's first WHERE column name.  Because SQLAlchemy compiled queries
    are complex objects, we count calls and return data in a predictable order:

    Call order inside ``HealthScoreCalculator.calculate``:
        1. DailyHealthMetrics (30-day window)
        2. SleepRecord (30-day window)
        3. UnifiedActivity (30-day window)
        4. SleepRecord for today's 7-day consistency window
        5. SleepRecord × 30 for historical consistency stddev list

    We use a simple counter to distinguish call groups.
    """
    if activity_rows is None:
        activity_rows = []

    db = AsyncMock()
    call_counter = {"n": 0}

    async def _execute(stmt, *args, **kwargs):
        n = call_counter["n"]
        call_counter["n"] += 1

        mock_result = MagicMock()
        mock_scalars = MagicMock()

        if n == 0:
            # First call: DailyHealthMetrics history
            mock_scalars.all.return_value = daily_rows
        elif n == 1:
            # Second call: SleepRecord history (30-day)
            mock_scalars.all.return_value = sleep_rows
        elif n == 2:
            # Third call: UnifiedActivity history
            mock_scalars.all.return_value = activity_rows
        else:
            # All subsequent: SleepRecord for consistency windows
            # Return the same sleep_rows so consistency windows get data
            mock_scalars.all.return_value = sleep_rows

        mock_result.scalars.return_value = mock_scalars
        return mock_result

    db.execute.side_effect = _execute
    return db


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------


class TestHealthScoreFullData:
    """test_full_data_returns_score — all 6 metrics present."""

    @pytest.mark.asyncio
    async def test_full_data_returns_score(self):
        today = _today()
        daily_rows = [_make_daily(_date_before(i)) for i in range(30)] + [_make_daily(today)]
        sleep_rows = [_make_sleep(_date_before(i)) for i in range(30)] + [_make_sleep(today)]

        db = _build_db(daily_rows, sleep_rows)
        calc = HealthScoreCalculator()
        result = await calc.calculate("user-1", db)

        assert result is not None
        assert isinstance(result, HealthScoreResult)
        assert 0 <= result.score <= 100
        assert len(result.contributing_metrics) > 0
        assert result.data_days > 0
        assert isinstance(result.commentary, str)
        assert len(result.commentary) > 0


class TestHealthScorePartialData:
    """test_partial_data_redistributes_weights — only sleep + steps."""

    @pytest.mark.asyncio
    async def test_partial_data_redistributes_weights(self):
        today = _today()
        # Only steps and sleep — no HRV, no resting HR, no active calories
        daily_rows = [
            _make_daily(_date_before(i), hrv_ms=None, resting_heart_rate=None, active_calories=None)
            for i in range(20)
        ] + [_make_daily(today, hrv_ms=None, resting_heart_rate=None, active_calories=None)]
        sleep_rows = [_make_sleep(_date_before(i)) for i in range(20)] + [_make_sleep(today)]

        db = _build_db(daily_rows, sleep_rows)
        calc = HealthScoreCalculator()
        result = await calc.calculate("user-2", db)

        assert result is not None
        assert 0 <= result.score <= 100
        # Only sleep + steps (+ possibly sleep_consistency) should contribute
        for metric in result.contributing_metrics:
            assert metric in {"sleep", "steps", "sleep_consistency"}
        # Missing metrics must NOT appear in sub_scores
        assert "hrv" not in result.sub_scores
        assert "resting_hr" not in result.sub_scores
        assert "activity" not in result.sub_scores


class TestHealthScoreNoSleepNoActivity:
    """test_no_sleep_and_no_activity_returns_none — minimum requirement not met."""

    @pytest.mark.asyncio
    async def test_no_sleep_and_no_activity_returns_none(self):
        today = _today()
        # Daily rows exist (steps, HRV) but no sleep rows and no activity
        daily_rows = [
            _make_daily(_date_before(i), active_calories=None)
            for i in range(15)
        ] + [_make_daily(today, active_calories=None)]
        sleep_rows: list = []

        db = _build_db(daily_rows, sleep_rows, activity_rows=[])
        calc = HealthScoreCalculator()
        result = await calc.calculate("user-3", db)

        assert result is None


class TestHealthScoreValidRange:
    """test_score_in_valid_range — score is always 0-100."""

    @pytest.mark.asyncio
    @pytest.mark.parametrize("score_band", ["low", "mid", "high"])
    async def test_score_in_valid_range(self, score_band: str):
        today = _today()

        if score_band == "low":
            # Very poor metrics — today is the worst day by far
            today_daily = _make_daily(today, steps=100, active_calories=10, resting_heart_rate=100.0, hrv_ms=5.0)
            history = [_make_daily(_date_before(i), steps=10000, active_calories=600, resting_heart_rate=55.0, hrv_ms=70.0) for i in range(1, 30)]
            today_sleep = _make_sleep(today, hours=3.0, quality_score=20)
            sleep_history = [_make_sleep(_date_before(i), hours=8.0, quality_score=90) for i in range(1, 30)]
        elif score_band == "high":
            # Excellent metrics — today is the best day
            today_daily = _make_daily(today, steps=20000, active_calories=900, resting_heart_rate=45.0, hrv_ms=120.0)
            history = [_make_daily(_date_before(i), steps=5000, active_calories=200, resting_heart_rate=75.0, hrv_ms=30.0) for i in range(1, 30)]
            today_sleep = _make_sleep(today, hours=9.0, quality_score=98)
            sleep_history = [_make_sleep(_date_before(i), hours=5.0, quality_score=40) for i in range(1, 30)]
        else:
            # Average metrics
            today_daily = _make_daily(today)
            history = [_make_daily(_date_before(i)) for i in range(1, 30)]
            today_sleep = _make_sleep(today)
            sleep_history = [_make_sleep(_date_before(i)) for i in range(1, 30)]

        daily_rows = history + [today_daily]
        sleep_rows = sleep_history + [today_sleep]

        db = _build_db(daily_rows, sleep_rows)
        calc = HealthScoreCalculator()
        result = await calc.calculate("user-4", db)

        assert result is not None
        assert 0 <= result.score <= 100


class TestHealthScoreCommentary:
    """test_commentary_generation — correct commentary for each score band."""

    @pytest.mark.parametrize(
        "score,expected_fragment",
        [
            (85, "excellent"),
            (65, "solid day"),
            (45, "pulling your score down"),
            (25, "recovery"),
        ],
    )
    def test_commentary_generation(self, score: int, expected_fragment: str):
        sub_scores = {"sleep": score - 5, "steps": score + 5, "hrv": score}
        calc = HealthScoreCalculator()
        commentary = calc._generate_commentary(score, sub_scores)
        assert expected_fragment.lower() in commentary.lower()

    def test_commentary_no_sub_scores(self):
        calc = HealthScoreCalculator()
        commentary = calc._generate_commentary(50, {})
        assert isinstance(commentary, str)
        assert len(commentary) > 0


class TestHealthScore7DayHistory:
    """test_7_day_history — returns list of 7 entries."""

    @pytest.mark.asyncio
    async def test_7_day_history_returns_seven_entries(self):
        today = date.today()
        # Build history for each of the 7 days
        daily_rows = []
        sleep_rows = []
        for i in range(7):
            d = (today - timedelta(days=i)).isoformat()
            daily_rows.extend([_make_daily(d)] * 5)
            sleep_rows.extend([_make_sleep(d)] * 5)

        # Also add 30-day history so percentile ranking has data
        for i in range(7, 37):
            d = (today - timedelta(days=i)).isoformat()
            daily_rows.append(_make_daily(d))
            sleep_rows.append(_make_sleep(d))

        # For get_7_day_history, each call to calculate() makes multiple DB
        # queries.  We supply a generous pool of rows each time.
        db = AsyncMock()

        async def _execute(stmt, *args, **kwargs):
            mock_result = MagicMock()
            mock_scalars = MagicMock()
            mock_scalars.all.return_value = daily_rows + sleep_rows
            mock_result.scalars.return_value = mock_scalars
            return mock_result

        db.execute.side_effect = _execute

        # Patch calculate to avoid complex DB call counting inside the loop
        calc = HealthScoreCalculator()
        fake_result = HealthScoreResult(
            score=72,
            sub_scores={"sleep": 80, "steps": 65},
            commentary="A solid day overall, with room to improve step count.",
            contributing_metrics=["sleep", "steps"],
            data_days=25,
        )

        with patch.object(calc, "calculate", AsyncMock(return_value=fake_result)):
            history = await calc.get_7_day_history("user-5", db)

        assert len(history) == 7
        for entry in history:
            assert "date" in entry
            assert "score" in entry
            assert "sub_scores" in entry

    @pytest.mark.asyncio
    async def test_7_day_history_includes_none_for_missing_days(self):
        """Days with no data produce ``score: None`` entries (not omitted)."""
        calc = HealthScoreCalculator()

        with patch.object(calc, "calculate", AsyncMock(return_value=None)):
            db = AsyncMock()
            history = await calc.get_7_day_history("user-6", db)

        assert len(history) == 7
        for entry in history:
            assert entry["score"] is None
            assert entry["sub_scores"] == {}
