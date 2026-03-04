"""
Tests for ReportGenerator.

Tests cover:
- Weekly report: correct workout count, avg sleep, week-over-week comparison
- Weekly report: handles missing data gracefully
- Monthly report: generates summaries for each category
- No data week: returns report with zeroes, not an error
"""

from __future__ import annotations

from datetime import date, datetime, timedelta, timezone
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.report_generator import (
    ReportGenerator,
    WeeklyReport,
    MonthlyReport,
    _pct_change,
    _generate_weekly_highlights,
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _sleep(hours: float, date_str: str) -> MagicMock:
    r = MagicMock()
    r.hours = hours
    r.date = date_str
    return r


def _metrics(steps: int, date_str: str) -> MagicMock:
    r = MagicMock()
    r.steps = steps
    r.date = date_str
    return r


def _activity(start_date_str: str) -> MagicMock:
    a = MagicMock()
    a.start_time = datetime.fromisoformat(f"{start_date_str}T10:00:00").replace(tzinfo=timezone.utc)
    return a


WEEK_START = date(2026, 2, 23)  # Monday


# ---------------------------------------------------------------------------
# _pct_change helper
# ---------------------------------------------------------------------------


class TestPctChange:
    def test_positive_change(self):
        assert _pct_change(110, 100) == 10.0

    def test_negative_change(self):
        assert _pct_change(90, 100) == -10.0

    def test_zero_previous(self):
        assert _pct_change(50, 0) == 0.0

    def test_no_change(self):
        assert _pct_change(100, 100) == 0.0


# ---------------------------------------------------------------------------
# Weekly report
# ---------------------------------------------------------------------------


class TestGenerateWeekly:
    @pytest.mark.asyncio
    async def test_correct_workout_count(self):
        """total_workouts reflects activities within the week."""
        generator = ReportGenerator()
        db = AsyncMock()

        week_dates = [(WEEK_START + timedelta(days=i)).isoformat() for i in range(7)]
        activities = [_activity(d) for d in week_dates[:3]]  # 3 workouts this week

        sleep_rows = [_sleep(7.5, d) for d in week_dates]
        step_rows = [_metrics(8000, d) for d in week_dates]

        with (
            patch.object(generator, "_count_activities", side_effect=[3, 0]),
            patch.object(generator, "_get_sleep_rows", side_effect=[sleep_rows, []]),
            patch.object(generator, "_get_step_rows", side_effect=[step_rows, []]),
        ):
            report = await generator.generate_weekly(user_id="user-001", week_start=WEEK_START, session=db)

        assert isinstance(report, WeeklyReport)
        assert report.total_workouts == 3

    @pytest.mark.asyncio
    async def test_avg_sleep_calculation(self):
        """avg_sleep_hours is correctly averaged across the week."""
        generator = ReportGenerator()
        db = AsyncMock()

        week_dates = [(WEEK_START + timedelta(days=i)).isoformat() for i in range(7)]
        sleep_rows = [_sleep(7.0, d) for d in week_dates[:5]]  # 5 nights × 7h = 7.0 avg
        step_rows = [_metrics(5000, d) for d in week_dates]

        with (
            patch.object(generator, "_count_activities", side_effect=[2, 1]),
            patch.object(generator, "_get_sleep_rows", side_effect=[sleep_rows, []]),
            patch.object(generator, "_get_step_rows", side_effect=[step_rows, []]),
        ):
            report = await generator.generate_weekly(user_id="user-001", week_start=WEEK_START, session=db)

        assert report.avg_sleep_hours == 7.0

    @pytest.mark.asyncio
    async def test_week_over_week_comparison(self):
        """week_over_week includes current/previous/change_pct for each metric."""
        generator = ReportGenerator()
        db = AsyncMock()

        week_dates = [(WEEK_START + timedelta(days=i)).isoformat() for i in range(7)]
        sleep_rows = [_sleep(8.0, d) for d in week_dates]
        prev_sleep = [_sleep(7.0, d) for d in week_dates]
        step_rows = [_metrics(10000, d) for d in week_dates]
        prev_steps = [_metrics(8000, d) for d in week_dates]

        with (
            patch.object(generator, "_count_activities", side_effect=[4, 2]),
            patch.object(generator, "_get_sleep_rows", side_effect=[sleep_rows, prev_sleep]),
            patch.object(generator, "_get_step_rows", side_effect=[step_rows, prev_steps]),
        ):
            report = await generator.generate_weekly(user_id="user-001", week_start=WEEK_START, session=db)

        wow = report.week_over_week
        assert "workouts" in wow
        assert "sleep" in wow
        assert "steps" in wow
        assert wow["workouts"]["current"] == 4
        assert wow["workouts"]["previous"] == 2
        assert wow["workouts"]["change_pct"] == 100.0

    @pytest.mark.asyncio
    async def test_handles_missing_data_gracefully(self):
        """No data → report with zeroes, no exception."""
        generator = ReportGenerator()
        db = AsyncMock()

        with (
            patch.object(generator, "_count_activities", return_value=0),
            patch.object(generator, "_get_sleep_rows", return_value=[]),
            patch.object(generator, "_get_step_rows", return_value=[]),
        ):
            report = await generator.generate_weekly(user_id="user-empty", week_start=WEEK_START, session=db)

        assert report.total_workouts == 0
        assert report.avg_sleep_hours == 0.0
        assert report.avg_steps == 0
        assert isinstance(report.ai_highlights, list)
        assert report.top_insight != ""

    @pytest.mark.asyncio
    async def test_period_dates_are_correct(self):
        """period_start / period_end span a full Mon–Sun week."""
        generator = ReportGenerator()
        db = AsyncMock()

        with (
            patch.object(generator, "_count_activities", return_value=0),
            patch.object(generator, "_get_sleep_rows", return_value=[]),
            patch.object(generator, "_get_step_rows", return_value=[]),
        ):
            report = await generator.generate_weekly(user_id="user-001", week_start=WEEK_START, session=db)

        assert report.period_start == WEEK_START
        assert report.period_end == WEEK_START + timedelta(days=6)


# ---------------------------------------------------------------------------
# Monthly report
# ---------------------------------------------------------------------------


MONTH_START = date(2026, 2, 1)


class TestGenerateMonthly:
    @pytest.mark.asyncio
    async def test_generates_category_summaries(self):
        """category_summaries contains sleep and activity keys."""
        generator = ReportGenerator()
        db = AsyncMock()

        dates = [(MONTH_START + timedelta(days=i)).isoformat() for i in range(28)]
        sleep_rows = [_sleep(7.0, d) for d in dates[:20]]
        step_rows = [_metrics(8000, d) for d in dates]

        with (
            patch.object(generator, "_count_activities", return_value=8),
            patch.object(generator, "_get_sleep_rows", return_value=sleep_rows),
            patch.object(generator, "_get_step_rows", return_value=step_rows),
        ):
            report = await generator.generate_monthly(user_id="user-001", month_start=MONTH_START, session=db)

        assert isinstance(report, MonthlyReport)
        assert "sleep" in report.category_summaries
        assert "activity" in report.category_summaries

    @pytest.mark.asyncio
    async def test_monthly_period_dates_correct_for_february(self):
        """Period end correctly handles February (28 days in 2026)."""
        generator = ReportGenerator()
        db = AsyncMock()

        with (
            patch.object(generator, "_count_activities", return_value=0),
            patch.object(generator, "_get_sleep_rows", return_value=[]),
            patch.object(generator, "_get_step_rows", return_value=[]),
        ):
            report = await generator.generate_monthly(user_id="user-001", month_start=MONTH_START, session=db)

        assert report.period_start == MONTH_START
        assert report.period_end == date(2026, 2, 28)

    @pytest.mark.asyncio
    async def test_no_data_month_returns_zeroes(self):
        """Month with no data returns report with zero values, not an error."""
        generator = ReportGenerator()
        db = AsyncMock()

        with (
            patch.object(generator, "_count_activities", return_value=0),
            patch.object(generator, "_get_sleep_rows", return_value=[]),
            patch.object(generator, "_get_step_rows", return_value=[]),
        ):
            report = await generator.generate_monthly(user_id="user-empty", month_start=MONTH_START, session=db)

        assert report.category_summaries["sleep"]["avg_hours"] == 0.0
        assert report.category_summaries["activity"]["total_workouts"] == 0
        assert isinstance(report.ai_recommendations, list)
        assert len(report.ai_recommendations) > 0

    @pytest.mark.asyncio
    async def test_ai_recommendations_generated(self):
        """Report includes AI recommendations regardless of data volume."""
        generator = ReportGenerator()
        db = AsyncMock()

        with (
            patch.object(generator, "_count_activities", return_value=5),
            patch.object(generator, "_get_sleep_rows", return_value=[]),
            patch.object(generator, "_get_step_rows", return_value=[]),
        ):
            report = await generator.generate_monthly(user_id="user-001", month_start=MONTH_START, session=db)

        assert len(report.ai_recommendations) >= 1


# ---------------------------------------------------------------------------
# _generate_weekly_highlights
# ---------------------------------------------------------------------------


class TestWeeklyHighlights:
    def test_great_sleep_week_highlight(self):
        highlights = _generate_weekly_highlights(7.8, 9000, 4, {})
        assert any("7.8 hours" in h for h in highlights)

    def test_no_workouts_generates_encouragement(self):
        highlights = _generate_weekly_highlights(6.5, 5000, 0, {})
        assert any("No workouts" in h or "workout" in h.lower() for h in highlights)

    def test_returns_at_most_three_highlights(self):
        highlights = _generate_weekly_highlights(7.0, 8000, 3, {})
        assert len(highlights) <= 3
