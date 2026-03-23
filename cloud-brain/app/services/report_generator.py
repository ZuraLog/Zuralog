"""
Zuralog Cloud Brain — Report Generator Service.

Generates weekly and monthly health summary reports by aggregating data
from ``daily_summaries``.  AI highlights in this service are
rule-based text templates; LLM-enhanced highlights are added by the
Celery task layer that calls this service.

Reports include:
  - Aggregated workout counts, step totals, sleep hours.
  - Week-over-week and month-over-month deltas.
  - Rule-based textual highlights.
"""

import logging
from datetime import date, timedelta
from typing import Any

from sqlalchemy import and_, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.daily_summary import DailySummary

logger = logging.getLogger(__name__)


class ReportGenerator:
    """Generates weekly and monthly health summary reports.

    All aggregation is performed via async SQLAlchemy queries against the
    ``daily_summaries`` table.  No external APIs are called — this
    service is purely database-driven.

    Usage::

        gen = ReportGenerator()
        report = await gen.generate_weekly(user_id, db, week_start=date(2026, 3, 3))
    """

    # ---------------------------------------------------------------------------
    # Public API
    # ---------------------------------------------------------------------------

    async def generate_weekly(
        self,
        user_id: str,
        db: AsyncSession,
        week_start: date,
    ) -> dict[str, Any]:
        """Generate a weekly health summary report.

        Aggregates ``daily_summaries`` for the 7-day window starting
        at ``week_start`` (inclusive) through ``week_start + 6 days``
        (inclusive).

        Also computes week-over-week deltas by querying the preceding
        7-day window.

        Args:
            user_id: User to generate the report for.
            db: Active async database session.
            week_start: First day of the report period (typically Monday).

        Returns:
            A dict containing:

            - ``period_start``: ISO date string (YYYY-MM-DD).
            - ``period_end``: ISO date string (YYYY-MM-DD).
            - ``total_workouts``: Number of days with active_calories > 0
              (used as a proxy for workout days in the absence of explicit
              workout records).
            - ``avg_sleep_hours``: Average sleep duration across the week
              (currently 0.0 — sleep data stored separately in future).
            - ``avg_steps``: Average daily step count.
            - ``week_over_week``: Delta strings for each metric.
            - ``top_insight``: Single key finding string.
            - ``ai_highlights``: List of 3–5 rule-based highlight strings.
        """
        week_end = week_start + timedelta(days=6)
        current = await self._aggregate_period(user_id, db, week_start, week_end)

        # Previous week for deltas
        prev_start = week_start - timedelta(days=7)
        prev_end = week_start - timedelta(days=1)
        previous = await self._aggregate_period(user_id, db, prev_start, prev_end)

        wow = self._compute_deltas(current, previous, period="week")
        highlights = self._build_highlights(current, wow, period="weekly")

        return {
            "period_start": week_start.isoformat(),
            "period_end": week_end.isoformat(),
            "total_workouts": current["active_days"],
            "avg_sleep_hours": current["avg_sleep_hours"],
            "avg_steps": current["avg_steps"],
            "week_over_week": wow,
            "top_insight": highlights[0] if highlights else "Keep going — your data is building.",
            "ai_highlights": highlights,
        }

    async def generate_monthly(
        self,
        user_id: str,
        db: AsyncSession,
        month_start: date,
    ) -> dict[str, Any]:
        """Generate a monthly health summary report.

        Aggregates ``daily_summaries`` for the entire calendar month
        starting at ``month_start``.

        Also computes month-over-month deltas against the preceding month.

        Args:
            user_id: User to generate the report for.
            db: Active async database session.
            month_start: First day of the report month (day must be 1).

        Returns:
            A dict containing all weekly report fields plus:

            - ``category_summaries``: Dict with per-category (activity,
              heart, body) aggregated stats for the month.
        """
        # Compute end of month
        if month_start.month == 12:
            next_month = date(month_start.year + 1, 1, 1)
        else:
            next_month = date(month_start.year, month_start.month + 1, 1)
        month_end = next_month - timedelta(days=1)

        current = await self._aggregate_period(user_id, db, month_start, month_end)

        # Previous month
        if month_start.month == 1:
            prev_month_start = date(month_start.year - 1, 12, 1)
        else:
            prev_month_start = date(month_start.year, month_start.month - 1, 1)
        prev_month_end = month_start - timedelta(days=1)
        previous = await self._aggregate_period(
            user_id, db, prev_month_start, prev_month_end
        )

        mom = self._compute_deltas(current, previous, period="month")
        highlights = self._build_highlights(current, mom, period="monthly")

        category_summaries = await self._build_category_summaries(
            user_id, db, month_start, month_end
        )

        return {
            "period_start": month_start.isoformat(),
            "period_end": month_end.isoformat(),
            "total_workouts": current["active_days"],
            "avg_sleep_hours": current["avg_sleep_hours"],
            "avg_steps": current["avg_steps"],
            "week_over_week": mom,
            "top_insight": highlights[0] if highlights else "Keep going — your data is building.",
            "ai_highlights": highlights,
            "category_summaries": category_summaries,
        }

    # ---------------------------------------------------------------------------
    # Private helpers
    # ---------------------------------------------------------------------------

    async def _aggregate_period(
        self,
        user_id: str,
        db: AsyncSession,
        start: date,
        end: date,
    ) -> dict[str, Any]:
        """Aggregate health metrics for a calendar period.

        Queries ``daily_summaries`` for the relevant metric_types and
        computes averages / sums / counts in SQL.

        Args:
            user_id: User to aggregate for.
            db: Active async database session.
            start: Inclusive period start (date).
            end: Inclusive period end (date).

        Returns:
            A dict with aggregated values:
            ``active_days``, ``avg_sleep_hours``, ``avg_steps``,
            ``avg_resting_hr``, ``avg_hrv``, ``total_steps``.
        """
        _METRIC_TYPES = [
            "steps", "active_calories", "resting_heart_rate",
            "hrv_ms", "sleep_duration", "weight_kg",
        ]

        # Pivot aggregation: one query pulling AVG/SUM per metric_type
        stmt = select(
            DailySummary.metric_type,
            func.avg(DailySummary.value).label("avg_val"),
            func.sum(DailySummary.value).label("sum_val"),
            func.count(DailySummary.date.distinct()).label("day_count"),
        ).where(
            and_(
                DailySummary.user_id == user_id,
                DailySummary.date >= start,
                DailySummary.date <= end,
                DailySummary.metric_type.in_(_METRIC_TYPES),
            )
        ).group_by(DailySummary.metric_type)

        # Separate query: active days (days with active_calories > 0)
        active_days_stmt = select(
            func.count(DailySummary.date.distinct())
        ).where(
            and_(
                DailySummary.user_id == user_id,
                DailySummary.date >= start,
                DailySummary.date <= end,
                DailySummary.metric_type == "active_calories",
                DailySummary.value > 0,
            )
        )

        try:
            result = await db.execute(stmt)
            rows = result.all()
            active_result = await db.execute(active_days_stmt)
            active_days: int = active_result.scalar_one() or 0

            # Build a lookup by metric_type
            agg: dict[str, Any] = {}
            for row in rows:
                agg[row.metric_type] = {
                    "avg": float(row.avg_val or 0),
                    "sum": float(row.sum_val or 0),
                    "days": int(row.day_count or 0),
                }

            avg_sleep_minutes = agg.get("sleep_duration", {}).get("avg", 0.0)

            return {
                "active_days": active_days,
                "avg_sleep_hours": round(avg_sleep_minutes / 60.0, 1),
                "avg_steps": round(agg.get("steps", {}).get("avg", 0)),
                "total_steps": int(agg.get("steps", {}).get("sum", 0)),
                "avg_resting_hr": round(
                    agg.get("resting_heart_rate", {}).get("avg", 0), 1
                ),
                "avg_hrv": round(agg.get("hrv_ms", {}).get("avg", 0), 1),
            }
        except Exception:
            logger.exception(
                "report_generator: aggregation failed for user=%s %s–%s",
                user_id,
                start.isoformat(),
                end.isoformat(),
            )
            return {
                "active_days": 0,
                "avg_sleep_hours": 0.0,
                "avg_steps": 0,
                "total_steps": 0,
                "avg_resting_hr": 0.0,
                "avg_hrv": 0.0,
            }

    async def _build_category_summaries(
        self,
        user_id: str,
        db: AsyncSession,
        start: date,
        end: date,
    ) -> dict[str, Any]:
        """Build per-category summary dicts for a monthly report.

        Categories mirror the Zuralog health category color system:
        activity, heart, and body.

        Args:
            user_id: User to summarise for.
            db: Active async database session.
            start: Inclusive period start.
            end: Inclusive period end.

        Returns:
            Dict with keys ``activity``, ``heart``, ``body``.
        """
        agg = await self._aggregate_period(user_id, db, start, end)
        return {
            "activity": {
                "active_days": agg["active_days"],
                "total_steps": agg["total_steps"],
                "avg_steps_per_day": agg["avg_steps"],
            },
            "heart": {
                "avg_resting_hr": agg["avg_resting_hr"],
                "avg_hrv_ms": agg["avg_hrv"],
            },
            "body": {
                # Body composition data (weight, body fat) stored via blood_pressure
                # and future body composition tables — placeholder for now.
                "data_available": False,
            },
        }

    @staticmethod
    def _compute_deltas(
        current: dict[str, Any],
        previous: dict[str, Any],
        period: str,
    ) -> dict[str, str]:
        """Compute human-readable delta strings between two periods.

        Args:
            current: Aggregated metrics for the current period.
            previous: Aggregated metrics for the comparison period.
            period: ``"week"`` or ``"month"`` — used in log messages only.

        Returns:
            Dict of delta strings, e.g. ``{"workouts": "+2", "steps": "-500"}``.
        """
        def _delta_str(curr: float, prev: float, unit: str = "") -> str:
            diff = curr - prev
            sign = "+" if diff >= 0 else ""
            if unit:
                return f"{sign}{diff:.1f}{unit}"
            return f"{sign}{int(diff)}"

        return {
            "workouts": _delta_str(
                current["active_days"], previous["active_days"]
            ),
            "sleep": _delta_str(
                current["avg_sleep_hours"], previous["avg_sleep_hours"], "h"
            ),
            "steps": _delta_str(current["avg_steps"], previous["avg_steps"]),
        }

    @staticmethod
    def _build_highlights(
        agg: dict[str, Any],
        deltas: dict[str, str],
        period: str,
    ) -> list[str]:
        """Generate rule-based highlight strings for a report.

        These are deterministic text highlights. An LLM-backed variant
        in the Celery task layer can enrich or replace these strings.

        Args:
            agg: Aggregated metrics for the period.
            deltas: Delta strings from :meth:`_compute_deltas`.
            period: ``"weekly"`` or ``"monthly"`` — for contextual phrasing.

        Returns:
            A list of 3–5 highlight strings.
        """
        highlights: list[str] = []
        period_label = "this week" if period == "weekly" else "this month"

        # Active days highlight
        active_days = agg["active_days"]
        if active_days >= 5:
            highlights.append(
                f"Great consistency — {active_days} active day{'s' if active_days != 1 else ''} {period_label}."
            )
        elif active_days >= 3:
            highlights.append(
                f"{active_days} active day{'s' if active_days != 1 else ''} {period_label} — solid effort."
            )
        elif active_days > 0:
            highlights.append(
                f"{active_days} active day{'s' if active_days != 1 else ''} logged {period_label}. Aim for 3+ to build momentum."
            )
        else:
            highlights.append("No activity data logged yet. Start moving to see your stats here.")

        # Step count highlight
        avg_steps = agg["avg_steps"]
        if avg_steps >= 10000:
            highlights.append(
                f"Averaging {avg_steps:,} steps/day — above the recommended 10 000 daily."
            )
        elif avg_steps >= 7000:
            highlights.append(
                f"Averaging {avg_steps:,} steps/day — close to the recommended 10 000."
            )
        elif avg_steps > 0:
            highlights.append(
                f"Averaging {avg_steps:,} steps/day. Try adding a short walk to boost this."
            )

        # Workout delta highlight
        wow_workouts = deltas.get("workouts", "0")
        _period_label = {"weekly": "week", "monthly": "month"}.get(period, period)
        if wow_workouts.startswith("+") and wow_workouts != "+0":
            highlights.append(
                f"Active days up {wow_workouts} vs the previous {_period_label} — great progress."
            )
        elif wow_workouts.startswith("-"):
            highlights.append(
                f"Active days down {wow_workouts} vs the previous {_period_label}. Try to maintain consistency."
            )

        # Heart rate highlight
        avg_rhr = agg["avg_resting_hr"]
        if avg_rhr > 0:
            if avg_rhr < 60:
                highlights.append(
                    f"Resting heart rate of {avg_rhr} bpm — excellent cardiovascular fitness."
                )
            elif avg_rhr < 80:
                highlights.append(f"Resting heart rate averaging {avg_rhr} bpm — within healthy range.")
            else:
                highlights.append(
                    f"Resting heart rate of {avg_rhr} bpm — consider adding cardio to bring this down."
                )

        # Ensure we return at least 1 and at most 5 highlights
        if not highlights:
            highlights.append("Keep syncing your data to unlock personalised highlights.")

        return highlights[:5]
