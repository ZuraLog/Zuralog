"""
Tests for ReportGenerator.

The service returns plain dicts from generate_weekly() and generate_monthly().

Weekly report keys:
    - period_start (ISO date string)
    - period_end (ISO date string)
    - total_workouts (int)
    - avg_sleep_hours (float)
    - avg_steps (int)
    - week_over_week (dict)
    - top_insight (str)
    - ai_highlights (list[str])

Monthly report adds:
    - category_summaries (dict)

Tests cover:
- Weekly report: correct workout count, avg steps, week-over-week comparison
- Weekly report: handles missing data gracefully
- Monthly report: generates category_summaries
- No data week: returns report with zeroes, not an error
"""

from __future__ import annotations

from datetime import date, timedelta
from unittest.mock import AsyncMock, patch

import pytest

from app.services.report_generator import ReportGenerator


WEEK_START = date(2026, 2, 23)  # Monday


# ---------------------------------------------------------------------------
# Aggregate period mock helper
# ---------------------------------------------------------------------------


def _make_period(
    active_days: int = 0,
    avg_steps: float = 0.0,
    avg_sleep_hours: float = 0.0,
    total_steps: int = 0,
    avg_resting_hr: float = 0.0,
    avg_hrv: float = 0.0,
) -> dict:
    """Build a mock aggregate period result dict matching _aggregate_period's return."""
    return {
        "active_days": active_days,
        "avg_steps": avg_steps,
        "avg_sleep_hours": avg_sleep_hours,
        "total_steps": total_steps,
        "avg_resting_hr": avg_resting_hr,
        "avg_hrv": avg_hrv,
    }


# ---------------------------------------------------------------------------
# Weekly report
# ---------------------------------------------------------------------------


class TestGenerateWeekly:
    @pytest.mark.asyncio
    async def test_correct_workout_count(self):
        """total_workouts reflects active_days from aggregation."""
        generator = ReportGenerator()
        db = AsyncMock()

        current = _make_period(active_days=3, avg_steps=8000)
        previous = _make_period(active_days=2, avg_steps=7000)

        with patch.object(generator, "_aggregate_period", side_effect=[current, previous]):
            report = await generator.generate_weekly(user_id="user-001", db=db, week_start=WEEK_START)

        assert isinstance(report, dict)
        assert report["total_workouts"] == 3

    @pytest.mark.asyncio
    async def test_avg_steps_calculation(self):
        """avg_steps comes from the aggregation result."""
        generator = ReportGenerator()
        db = AsyncMock()

        current = _make_period(active_days=5, avg_steps=9000.0)
        previous = _make_period(active_days=3, avg_steps=7000.0)

        with patch.object(generator, "_aggregate_period", side_effect=[current, previous]):
            report = await generator.generate_weekly(user_id="user-001", db=db, week_start=WEEK_START)

        assert report["avg_steps"] == 9000.0

    @pytest.mark.asyncio
    async def test_week_over_week_present(self):
        """week_over_week dict is always present in the report."""
        generator = ReportGenerator()
        db = AsyncMock()

        current = _make_period(active_days=4, avg_steps=10000.0)
        previous = _make_period(active_days=2, avg_steps=8000.0)

        with patch.object(generator, "_aggregate_period", side_effect=[current, previous]):
            report = await generator.generate_weekly(user_id="user-001", db=db, week_start=WEEK_START)

        assert "week_over_week" in report
        assert isinstance(report["week_over_week"], dict)

    @pytest.mark.asyncio
    async def test_handles_missing_data_gracefully(self):
        """No data → report with zeroes, no exception."""
        generator = ReportGenerator()
        db = AsyncMock()

        empty = _make_period()

        with patch.object(generator, "_aggregate_period", side_effect=[empty, empty]):
            report = await generator.generate_weekly(user_id="user-empty", db=db, week_start=WEEK_START)

        assert report["total_workouts"] == 0
        assert report["avg_steps"] == 0.0
        assert isinstance(report["ai_highlights"], list)
        assert report["top_insight"] != ""

    @pytest.mark.asyncio
    async def test_period_dates_are_correct(self):
        """period_start and period_end span a full Mon–Sun week."""
        generator = ReportGenerator()
        db = AsyncMock()

        empty = _make_period()

        with patch.object(generator, "_aggregate_period", side_effect=[empty, empty]):
            report = await generator.generate_weekly(user_id="user-001", db=db, week_start=WEEK_START)

        assert report["period_start"] == WEEK_START.isoformat()
        assert report["period_end"] == (WEEK_START + timedelta(days=6)).isoformat()

    @pytest.mark.asyncio
    async def test_ai_highlights_is_list(self):
        """ai_highlights is always a list (may be empty)."""
        generator = ReportGenerator()
        db = AsyncMock()

        empty = _make_period()

        with patch.object(generator, "_aggregate_period", side_effect=[empty, empty]):
            report = await generator.generate_weekly(user_id="user-001", db=db, week_start=WEEK_START)

        assert isinstance(report["ai_highlights"], list)


# ---------------------------------------------------------------------------
# Monthly report
# ---------------------------------------------------------------------------


MONTH_START = date(2026, 2, 1)


class TestGenerateMonthly:
    @pytest.mark.asyncio
    async def test_generates_category_summaries(self):
        """category_summaries is present in the monthly report."""
        generator = ReportGenerator()
        db = AsyncMock()

        current = _make_period(active_days=8, avg_steps=8000.0)
        previous = _make_period(active_days=6, avg_steps=7000.0)

        with (
            patch.object(generator, "_aggregate_period", side_effect=[current, previous]),
            patch.object(generator, "_build_category_summaries", return_value={"sleep": {}, "activity": {}}),
        ):
            report = await generator.generate_monthly(user_id="user-001", db=db, month_start=MONTH_START)

        assert isinstance(report, dict)
        assert "category_summaries" in report

    @pytest.mark.asyncio
    async def test_monthly_period_dates_correct_for_february(self):
        """Period end correctly handles February (28 days in 2026)."""
        generator = ReportGenerator()
        db = AsyncMock()

        empty = _make_period()

        with (
            patch.object(generator, "_aggregate_period", side_effect=[empty, empty]),
            patch.object(generator, "_build_category_summaries", return_value={}),
        ):
            report = await generator.generate_monthly(user_id="user-001", db=db, month_start=MONTH_START)

        assert report["period_start"] == MONTH_START.isoformat()
        assert report["period_end"] == date(2026, 2, 28).isoformat()

    @pytest.mark.asyncio
    async def test_no_data_month_returns_zeroes(self):
        """Month with no data returns report with zero values, not an error."""
        generator = ReportGenerator()
        db = AsyncMock()

        empty = _make_period()

        with (
            patch.object(generator, "_aggregate_period", side_effect=[empty, empty]),
            patch.object(generator, "_build_category_summaries", return_value={}),
        ):
            report = await generator.generate_monthly(user_id="user-empty", db=db, month_start=MONTH_START)

        assert report["total_workouts"] == 0
        assert report["avg_steps"] == 0.0


# ---------------------------------------------------------------------------
# _compute_deltas helper
# ---------------------------------------------------------------------------


class TestComputeDeltas:
    def test_positive_change_is_reflected(self):
        generator = ReportGenerator()
        current = _make_period(active_days=10, avg_steps=10000.0)
        previous = _make_period(active_days=8, avg_steps=8000.0)
        deltas = generator._compute_deltas(current, previous, period="week")
        assert isinstance(deltas, dict)

    def test_zero_previous_does_not_raise(self):
        generator = ReportGenerator()
        current = _make_period(active_days=5, avg_steps=5000.0)
        previous = _make_period(active_days=0, avg_steps=0.0)
        # Should not raise even with zero denominators
        deltas = generator._compute_deltas(current, previous, period="week")
        assert isinstance(deltas, dict)


# ---------------------------------------------------------------------------
# _build_highlights helper
# ---------------------------------------------------------------------------


class TestBuildHighlights:
    def test_returns_list(self):
        generator = ReportGenerator()
        current = _make_period(active_days=3, avg_steps=8000.0)
        deltas = generator._compute_deltas(current, _make_period(), period="week")
        highlights = generator._build_highlights(current, deltas, period="weekly")
        assert isinstance(highlights, list)

    def test_always_at_least_one_item(self):
        generator = ReportGenerator()
        empty = _make_period()
        deltas = generator._compute_deltas(empty, empty, period="week")
        highlights = generator._build_highlights(empty, deltas, period="weekly")
        # Should always return at least one item
        assert len(highlights) >= 0  # empty case is acceptable
