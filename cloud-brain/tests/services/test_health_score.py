"""Tests for HealthScoreCalculator.

Covers the six required scenarios using unittest.mock to avoid a real
database.  Each test builds a fixture AsyncSession whose ``execute``
side-effect returns mock result objects compatible with the raw-SQL
query pattern used by the rewritten service (``result.fetchall()``
returning rows with named attributes like ``row.date``,
``row.metric_type``, ``row.value``).
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

def _today() -> str:
    return datetime.now(tz=timezone.utc).date().isoformat()


def _today_date() -> date:
    return datetime.now(tz=timezone.utc).date()


def _date_before(days: int) -> str:
    d = datetime.now(tz=timezone.utc).date() - timedelta(days=days)
    return d.isoformat()


def _make_raw_row(**kwargs) -> SimpleNamespace:
    """Build a mock raw-SQL result row with named attributes."""
    return SimpleNamespace(**kwargs)


def _make_daily_summary_rows(
    date_str: str,
    steps: int | None = 8000,
    active_calories: int | None = 400,
    resting_heart_rate: float | None = 58.0,
    hrv_ms: float | None = 55.0,
) -> list[SimpleNamespace]:
    """Build daily_summaries rows for a single date (one row per metric)."""
    rows = []
    if steps is not None:
        rows.append(_make_raw_row(date=date_str, metric_type="steps", value=steps))
    if active_calories is not None:
        rows.append(_make_raw_row(date=date_str, metric_type="active_calories", value=active_calories))
    if resting_heart_rate is not None:
        rows.append(_make_raw_row(date=date_str, metric_type="resting_heart_rate", value=resting_heart_rate))
    if hrv_ms is not None:
        rows.append(_make_raw_row(date=date_str, metric_type="hrv_ms", value=hrv_ms))
    return rows


def _make_sleep_summary_rows(
    date_str: str,
    sleep_minutes: float = 450.0,
    sleep_quality: int | None = 80,
) -> list[SimpleNamespace]:
    """Build daily_summaries rows for sleep metrics on a single date."""
    rows = [_make_raw_row(date=date_str, metric_type="sleep_duration", value=sleep_minutes)]
    if sleep_quality is not None:
        rows.append(_make_raw_row(date=date_str, metric_type="sleep_quality", value=sleep_quality))
    return rows


# ---------------------------------------------------------------------------
# DB session mock factory
# ---------------------------------------------------------------------------

def _build_db(
    daily_metric_rows: list[SimpleNamespace],
    sleep_metric_rows: list[SimpleNamespace],
    activity_calorie_rows: list[SimpleNamespace] | None = None,
    sleep_date_rows: list[SimpleNamespace] | None = None,
) -> AsyncMock:
    """Create an AsyncMock database session for raw-SQL queries.

    The service calls db.execute(sql_text(...), params) and then
    result.fetchall() on each.  We use a call counter to return the
    right data for each query in order:

    Call order inside ``HealthScoreCalculator.calculate``:
        0. _fetch_daily_metrics_history  — daily metric rows
        1. _fetch_sleep_history          — sleep metric rows
        2. _fetch_activity_history       — active_calories rows
        3. _compute_sleep_consistency    — sleep date rows (7-day)
        4. _build_consistency_history    — sleep date rows (37-day) [only if #3 returned data]
    """
    if activity_calorie_rows is None:
        # Build from daily_metric_rows: extract active_calories entries
        activity_calorie_rows = [
            _make_raw_row(date=r.date, value=r.value)
            for r in daily_metric_rows
            if r.metric_type == "active_calories"
        ]

    if sleep_date_rows is None:
        # Build from sleep_metric_rows: extract sleep_duration dates
        sleep_date_rows = [
            _make_raw_row(date=r.date)
            for r in sleep_metric_rows
            if r.metric_type == "sleep_duration"
        ]

    db = AsyncMock()
    call_counter = {"n": 0}

    async def _execute(stmt, *args, **kwargs):
        n = call_counter["n"]
        call_counter["n"] += 1

        mock_result = MagicMock()

        if n == 0:
            # _fetch_daily_metrics_history
            mock_result.fetchall.return_value = daily_metric_rows
        elif n == 1:
            # _fetch_sleep_history
            mock_result.fetchall.return_value = sleep_metric_rows
        elif n == 2:
            # _fetch_activity_history
            mock_result.fetchall.return_value = activity_calorie_rows
        elif n == 3:
            # _compute_sleep_consistency (7-day sleep dates)
            mock_result.fetchall.return_value = sleep_date_rows
        else:
            # _build_consistency_history (37-day sleep dates)
            mock_result.fetchall.return_value = sleep_date_rows

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

        # Build daily_summaries rows for 30 days of history + today
        daily_rows = []
        sleep_rows = []
        for i in range(30):
            d = _date_before(i)
            daily_rows.extend(_make_daily_summary_rows(d))
            sleep_rows.extend(_make_sleep_summary_rows(d))
        daily_rows.extend(_make_daily_summary_rows(today))
        sleep_rows.extend(_make_sleep_summary_rows(today))

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

        # Only steps — no HRV, no resting HR, no active calories
        daily_rows = []
        sleep_rows = []
        for i in range(20):
            d = _date_before(i)
            daily_rows.extend(_make_daily_summary_rows(
                d, hrv_ms=None, resting_heart_rate=None, active_calories=None,
            ))
            sleep_rows.extend(_make_sleep_summary_rows(d))
        daily_rows.extend(_make_daily_summary_rows(
            today, hrv_ms=None, resting_heart_rate=None, active_calories=None,
        ))
        sleep_rows.extend(_make_sleep_summary_rows(today))

        # No activity rows since active_calories is None
        activity_rows: list[SimpleNamespace] = []

        db = _build_db(daily_rows, sleep_rows, activity_calorie_rows=activity_rows)
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

        # Daily rows with steps/HRV but NO active_calories and NO sleep
        daily_rows = []
        for i in range(15):
            d = _date_before(i)
            daily_rows.extend(_make_daily_summary_rows(d, active_calories=None))
        daily_rows.extend(_make_daily_summary_rows(today, active_calories=None))

        sleep_rows: list[SimpleNamespace] = []
        activity_rows: list[SimpleNamespace] = []
        sleep_date_rows: list[SimpleNamespace] = []

        db = _build_db(daily_rows, sleep_rows, activity_calorie_rows=activity_rows, sleep_date_rows=sleep_date_rows)
        calc = HealthScoreCalculator()
        result = await calc.calculate("user-3", db)

        assert result is None


class TestHealthScoreValidRange:
    """test_score_in_valid_range — score is always 0-100."""

    @pytest.mark.asyncio
    @pytest.mark.parametrize("score_band", ["low", "mid", "high"])
    async def test_score_in_valid_range(self, score_band: str):
        today = _today()

        daily_rows = []
        sleep_rows = []

        if score_band == "low":
            # Very poor metrics today vs excellent history
            daily_rows.extend(_make_daily_summary_rows(
                today, steps=100, active_calories=10,
                resting_heart_rate=100.0, hrv_ms=5.0,
            ))
            sleep_rows.extend(_make_sleep_summary_rows(today, sleep_minutes=180.0, sleep_quality=20))
            for i in range(1, 30):
                d = _date_before(i)
                daily_rows.extend(_make_daily_summary_rows(
                    d, steps=10000, active_calories=600,
                    resting_heart_rate=55.0, hrv_ms=70.0,
                ))
                sleep_rows.extend(_make_sleep_summary_rows(d, sleep_minutes=480.0, sleep_quality=90))
        elif score_band == "high":
            # Excellent metrics today vs poor history
            daily_rows.extend(_make_daily_summary_rows(
                today, steps=20000, active_calories=900,
                resting_heart_rate=45.0, hrv_ms=120.0,
            ))
            sleep_rows.extend(_make_sleep_summary_rows(today, sleep_minutes=540.0, sleep_quality=98))
            for i in range(1, 30):
                d = _date_before(i)
                daily_rows.extend(_make_daily_summary_rows(
                    d, steps=5000, active_calories=200,
                    resting_heart_rate=75.0, hrv_ms=30.0,
                ))
                sleep_rows.extend(_make_sleep_summary_rows(d, sleep_minutes=300.0, sleep_quality=40))
        else:
            # Average metrics
            daily_rows.extend(_make_daily_summary_rows(today))
            sleep_rows.extend(_make_sleep_summary_rows(today))
            for i in range(1, 30):
                d = _date_before(i)
                daily_rows.extend(_make_daily_summary_rows(d))
                sleep_rows.extend(_make_sleep_summary_rows(d))

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
        """Patch calculate() to avoid complex DB mocking for the loop."""
        calc = HealthScoreCalculator()
        fake_result = HealthScoreResult(
            score=72,
            sub_scores={"sleep": 80, "steps": 65},
            commentary="A solid day overall, with room to improve step count.",
            contributing_metrics=["sleep", "steps"],
            data_days=25,
        )

        db = AsyncMock()
        # get_7_day_history first queries HealthScoreCache; mock that
        mock_cache_result = MagicMock()
        mock_scalars = MagicMock()
        mock_scalars.all.return_value = []
        mock_cache_result.scalars.return_value = mock_scalars
        db.execute.return_value = mock_cache_result

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

        db = AsyncMock()
        # Mock the cache query to return empty
        mock_cache_result = MagicMock()
        mock_scalars = MagicMock()
        mock_scalars.all.return_value = []
        mock_cache_result.scalars.return_value = mock_scalars
        db.execute.return_value = mock_cache_result

        with patch.object(calc, "calculate", AsyncMock(return_value=None)):
            history = await calc.get_7_day_history("user-6", db)

        assert len(history) == 7
        for entry in history:
            assert entry["score"] is None
            assert entry["sub_scores"] == {}
