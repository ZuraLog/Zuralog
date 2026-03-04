"""
Zuralog Cloud Brain — Report Generator.

Generates weekly and monthly health summary reports for users by
aggregating normalized health data from the database.

Both report types are pure data objects — they do not send push
notifications or persist themselves. That is handled by report_tasks.py.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from datetime import date, datetime, timedelta, timezone

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.health_data import SleepRecord, UnifiedActivity
from app.models.daily_metrics import DailyHealthMetrics

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Report dataclasses
# ---------------------------------------------------------------------------


@dataclass
class WeeklyReport:
    """Summary report for a single calendar week.

    Attributes:
        period_start: Monday of the report week.
        period_end: Sunday of the report week.
        total_workouts: Count of activities recorded during the week.
        avg_sleep_hours: Average nightly sleep duration (0.0 if no data).
        avg_steps: Average daily step count (0 if no data).
        top_insight: Most relevant AI-generated insight string.
        week_over_week: Per-metric comparison to the previous week.
            Format: ``{metric: {current, previous, change_pct}}``.
        ai_highlights: List of 2–3 sentence narrative highlights.
        generated_at: Timestamp of report generation.
    """

    period_start: date
    period_end: date
    total_workouts: int
    avg_sleep_hours: float
    avg_steps: int
    top_insight: str
    week_over_week: dict
    ai_highlights: list[str]
    generated_at: datetime


@dataclass
class MonthlyReport:
    """Summary report for a calendar month.

    Attributes:
        period_start: First day of the report month.
        period_end: Last day of the report month.
        category_summaries: Per-category (sleep, activity, etc.) summary dicts.
        top_correlations: Notable cross-metric correlations found this month.
        goal_progress: List of goal progress dicts (metric, target, achieved).
        trend_directions: Per-metric trend dict (``{"steps": "up"}``, etc.).
        ai_recommendations: 3–5 actionable recommendations for next month.
        generated_at: Timestamp of report generation.
    """

    period_start: date
    period_end: date
    category_summaries: dict
    top_correlations: list[dict]
    goal_progress: list[dict]
    trend_directions: dict
    ai_recommendations: list[str]
    generated_at: datetime


# ---------------------------------------------------------------------------
# ReportGenerator
# ---------------------------------------------------------------------------


class ReportGenerator:
    """Generate weekly and monthly health reports from persisted health data.

    All methods are async and require an open ``AsyncSession``. Reports are
    returned as pure dataclass instances; persistence is the caller's
    responsibility.
    """

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    async def generate_weekly(
        self,
        user_id: str,
        week_start: date,
        session: AsyncSession,
    ) -> WeeklyReport:
        """Generate a weekly report for the 7-day period starting at ``week_start``.

        Args:
            user_id: Zuralog user ID.
            week_start: Monday of the target week (inclusive).
            session: Open async DB session.

        Returns:
            Populated WeeklyReport dataclass.
        """
        week_end = week_start + timedelta(days=6)
        prev_week_start = week_start - timedelta(days=7)
        prev_week_end = week_start - timedelta(days=1)

        week_start_str = week_start.isoformat()
        week_end_str = week_end.isoformat()
        prev_start_str = prev_week_start.isoformat()
        prev_end_str = prev_week_end.isoformat()

        # Activity count
        total_workouts = await self._count_activities(user_id, week_start_str, week_end_str, session)

        # Sleep average
        sleep_rows = await self._get_sleep_rows(user_id, week_start_str, week_end_str, session)
        avg_sleep = sum(r.hours for r in sleep_rows) / len(sleep_rows) if sleep_rows else 0.0

        # Steps average
        step_rows = await self._get_step_rows(user_id, week_start_str, week_end_str, session)
        avg_steps = sum(r.steps for r in step_rows if r.steps) // max(len(step_rows), 1) if step_rows else 0

        # Previous week for comparison
        prev_workouts = await self._count_activities(user_id, prev_start_str, prev_end_str, session)
        prev_sleep_rows = await self._get_sleep_rows(user_id, prev_start_str, prev_end_str, session)
        prev_avg_sleep = sum(r.hours for r in prev_sleep_rows) / len(prev_sleep_rows) if prev_sleep_rows else 0.0
        prev_step_rows = await self._get_step_rows(user_id, prev_start_str, prev_end_str, session)
        prev_avg_steps = (
            sum(r.steps for r in prev_step_rows if r.steps) // max(len(prev_step_rows), 1) if prev_step_rows else 0
        )

        week_over_week = {
            "workouts": {
                "current": total_workouts,
                "previous": prev_workouts,
                "change_pct": _pct_change(total_workouts, prev_workouts),
            },
            "sleep": {
                "current": round(avg_sleep, 2),
                "previous": round(prev_avg_sleep, 2),
                "change_pct": _pct_change(avg_sleep, prev_avg_sleep),
            },
            "steps": {
                "current": avg_steps,
                "previous": prev_avg_steps,
                "change_pct": _pct_change(avg_steps, prev_avg_steps),
            },
        }

        # AI highlights
        ai_highlights = _generate_weekly_highlights(
            avg_sleep=avg_sleep,
            avg_steps=avg_steps,
            total_workouts=total_workouts,
            wow=week_over_week,
        )

        top_insight = ai_highlights[0] if ai_highlights else "Keep tracking for personalised insights."

        return WeeklyReport(
            period_start=week_start,
            period_end=week_end,
            total_workouts=total_workouts,
            avg_sleep_hours=round(avg_sleep, 2),
            avg_steps=avg_steps,
            top_insight=top_insight,
            week_over_week=week_over_week,
            ai_highlights=ai_highlights,
            generated_at=datetime.now(timezone.utc),
        )

    async def generate_monthly(
        self,
        user_id: str,
        month_start: date,
        session: AsyncSession,
    ) -> MonthlyReport:
        """Generate a monthly report for the calendar month containing ``month_start``.

        Args:
            user_id: Zuralog user ID.
            month_start: First day of the target month.
            session: Open async DB session.

        Returns:
            Populated MonthlyReport dataclass.
        """
        # Calculate month end
        if month_start.month == 12:
            month_end = date(month_start.year + 1, 1, 1) - timedelta(days=1)
        else:
            month_end = date(month_start.year, month_start.month + 1, 1) - timedelta(days=1)

        start_str = month_start.isoformat()
        end_str = month_end.isoformat()

        # Category summaries
        sleep_rows = await self._get_sleep_rows(user_id, start_str, end_str, session)
        step_rows = await self._get_step_rows(user_id, start_str, end_str, session)
        total_workouts = await self._count_activities(user_id, start_str, end_str, session)

        avg_sleep = sum(r.hours for r in sleep_rows) / len(sleep_rows) if sleep_rows else 0.0
        avg_steps = sum(r.steps for r in step_rows if r.steps) // max(len(step_rows), 1) if step_rows else 0

        category_summaries = {
            "sleep": {
                "avg_hours": round(avg_sleep, 2),
                "days_tracked": len(sleep_rows),
                "best_night": max((r.hours for r in sleep_rows), default=0.0),
                "worst_night": min((r.hours for r in sleep_rows), default=0.0),
            },
            "activity": {
                "total_workouts": total_workouts,
                "avg_daily_steps": avg_steps,
                "days_with_steps": len([r for r in step_rows if r.steps]),
            },
        }

        # Simple trend directions (first-half vs second-half of month)
        trend_directions = _calc_trend_directions(sleep_rows, step_rows, month_start, month_end)

        # Goal progress — placeholder; full impl requires user goals lookup.
        goal_progress: list[dict] = []

        # Top correlations — Phase 2 stub; full correlation analysis is Phase 3.
        top_correlations: list[dict] = []

        ai_recommendations = _generate_monthly_recommendations(
            avg_sleep=avg_sleep,
            avg_steps=avg_steps,
            total_workouts=total_workouts,
        )

        return MonthlyReport(
            period_start=month_start,
            period_end=month_end,
            category_summaries=category_summaries,
            top_correlations=top_correlations,
            goal_progress=goal_progress,
            trend_directions=trend_directions,
            ai_recommendations=ai_recommendations,
            generated_at=datetime.now(timezone.utc),
        )

    # ------------------------------------------------------------------
    # Private DB helpers
    # ------------------------------------------------------------------

    @staticmethod
    async def _count_activities(
        user_id: str,
        start_str: str,
        end_str: str,
        session: AsyncSession,
    ) -> int:
        select(func.count(UnifiedActivity.id)).where(
            UnifiedActivity.user_id == user_id,
            func.cast(
                UnifiedActivity.start_time,
                session.bind.dialect.name == "postgresql" and func.date or UnifiedActivity.start_time,
            )
            >= start_str,  # type: ignore[attr-defined]
        )
        # Simpler cross-db compatible approach: fetch and count in Python
        rows_stmt = select(UnifiedActivity).where(
            UnifiedActivity.user_id == user_id,
        )
        result = await session.execute(rows_stmt)
        all_activities = result.scalars().all()
        return sum(
            1
            for a in all_activities
            if a.start_time is not None and start_str <= a.start_time.date().isoformat() <= end_str
        )

    @staticmethod
    async def _get_sleep_rows(
        user_id: str,
        start_str: str,
        end_str: str,
        session: AsyncSession,
    ) -> list[SleepRecord]:
        stmt = select(SleepRecord).where(
            SleepRecord.user_id == user_id,
            SleepRecord.date >= start_str,
            SleepRecord.date <= end_str,
        )
        result = await session.execute(stmt)
        return list(result.scalars().all())

    @staticmethod
    async def _get_step_rows(
        user_id: str,
        start_str: str,
        end_str: str,
        session: AsyncSession,
    ) -> list[DailyHealthMetrics]:
        stmt = select(DailyHealthMetrics).where(
            DailyHealthMetrics.user_id == user_id,
            DailyHealthMetrics.date >= start_str,
            DailyHealthMetrics.date <= end_str,
        )
        result = await session.execute(stmt)
        return list(result.scalars().all())


# ---------------------------------------------------------------------------
# Pure helper functions
# ---------------------------------------------------------------------------


def _pct_change(current: float | int, previous: float | int) -> float:
    """Calculate percentage change from previous to current.

    Args:
        current: Current period value.
        previous: Previous period value.

    Returns:
        Percentage change as a float. Returns 0.0 if previous is 0.
    """
    if not previous:
        return 0.0
    return round(((current - previous) / previous) * 100, 1)


def _generate_weekly_highlights(
    avg_sleep: float,
    avg_steps: int,
    total_workouts: int,
    wow: dict,
) -> list[str]:
    """Generate 2–3 narrative highlight strings for a weekly report.

    Args:
        avg_sleep: Average sleep hours.
        avg_steps: Average daily steps.
        total_workouts: Number of workouts.
        wow: Week-over-week comparison dict.

    Returns:
        List of highlight strings.
    """
    highlights: list[str] = []

    # Sleep highlight
    if avg_sleep >= 7.5:
        highlights.append(f"Great sleep week — you averaged {avg_sleep:.1f} hours per night.")
    elif avg_sleep >= 6:
        highlights.append(f"Average sleep was {avg_sleep:.1f} hours. Targeting 7.5+ can boost recovery.")
    elif avg_sleep > 0:
        highlights.append(
            f"Sleep averaged only {avg_sleep:.1f} hours this week. Prioritising rest will improve all other metrics."
        )

    # Activity highlight
    if total_workouts >= 4:
        highlights.append(f"You completed {total_workouts} workouts — excellent consistency!")
    elif total_workouts > 0:
        highlights.append(f"You got {total_workouts} workout(s) in. Aim for 4+ next week for compounding benefits.")
    else:
        highlights.append("No workouts logged this week. Even 2–3 sessions make a measurable difference.")

    # Steps highlight
    if avg_steps >= 8000:
        highlights.append(f"Step count was strong at {avg_steps:,} per day on average.")
    elif avg_steps > 0:
        highlights.append(f"Daily steps averaged {avg_steps:,}. 8,000+ is the evidence-backed target for health.")

    return highlights[:3]


def _generate_monthly_recommendations(
    avg_sleep: float,
    avg_steps: int,
    total_workouts: int,
) -> list[str]:
    """Generate 3–5 actionable recommendations for next month.

    Args:
        avg_sleep: Average nightly sleep hours this month.
        avg_steps: Average daily steps this month.
        total_workouts: Total workouts this month.

    Returns:
        List of recommendation strings.
    """
    recs: list[str] = []

    if avg_sleep < 7.0:
        recs.append(
            "Prioritise sleep: set a consistent bedtime 30 minutes earlier than current and keep it on weekends."
        )
    if avg_steps < 7000:
        recs.append(
            "Increase daily steps: adding a 15-minute walk after dinner can add 1,500–2,000 steps effortlessly."
        )
    if total_workouts < 8:  # Less than 2 per week
        recs.append(
            "Schedule workouts: blocking two 45-minute sessions per week on your calendar triples completion rates."
        )
    if avg_sleep >= 7.5 and avg_steps >= 8000:
        recs.append(
            "You're building great habits — consider adding heart rate zone training to unlock deeper insights."
        )

    recs.append("Keep logging consistently: 30+ days of data unlocks advanced AI correlations and anomaly detection.")

    return recs[:5]


def _calc_trend_directions(
    sleep_rows: list[SleepRecord],
    step_rows: list[DailyHealthMetrics],
    month_start: date,
    month_end: date,
) -> dict:
    """Calculate simple trend directions by comparing first vs second half of month.

    Args:
        sleep_rows: Sleep records for the month.
        step_rows: Daily metrics records for the month.
        month_start: First day of the month.
        month_end: Last day of the month.

    Returns:
        Dict mapping metric name to direction string ("up", "down", "stable").
    """
    midpoint = month_start + (month_end - month_start) / 2
    mid_str = midpoint.isoformat()

    def _direction(first_half: list[float], second_half: list[float]) -> str:
        if not first_half or not second_half:
            return "stable"
        avg_first = sum(first_half) / len(first_half)
        avg_second = sum(second_half) / len(second_half)
        if avg_second > avg_first * 1.05:
            return "up"
        elif avg_second < avg_first * 0.95:
            return "down"
        return "stable"

    sleep_first = [r.hours for r in sleep_rows if r.date <= mid_str]
    sleep_second = [r.hours for r in sleep_rows if r.date > mid_str]
    steps_first = [r.steps for r in step_rows if r.date <= mid_str and r.steps]
    steps_second = [r.steps for r in step_rows if r.date > mid_str and r.steps]

    return {
        "sleep": _direction(sleep_first, sleep_second),
        "steps": _direction(steps_first, steps_second),
    }
