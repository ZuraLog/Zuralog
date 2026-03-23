"""
Zuralog Cloud Brain — Analytics Service Facade.

High-level facade that composes all four analytics modules
(CorrelationAnalyzer, TrendDetector, GoalTracker, InsightGenerator)
and provides database-backed methods for the analytics API router.

This service handles data fetching via raw SQL against the
``daily_summaries`` table and delegates computation to the pure-logic
analytics modules.
"""

import logging
from datetime import date, timedelta
from typing import Any

from sqlalchemy import select, text as sql_text
from sqlalchemy.ext.asyncio import AsyncSession

from app.analytics.correlation_analyzer import CorrelationAnalyzer
from app.analytics.goal_tracker import GoalTracker
from app.analytics.insight_generator import InsightGenerator
from app.analytics.trend_detector import TrendDetector
from app.models.user_goal import UserGoal

logger = logging.getLogger(__name__)

# Mapping from public metric names to metric_type values stored in
# the ``daily_summaries`` table.
_METRIC_TYPE_MAP: dict[str, str] = {
    "steps": "steps",
    "calories_consumed": "calories",
    "calories_burned": "active_calories",
    "sleep_hours": "sleep_duration",
    "weight_kg": "weight_kg",
    "workouts": "exercise_minutes",
    "resting_heart_rate": "resting_heart_rate",
    "exercise_minutes": "exercise_minutes",
    "active_calories": "active_calories",
}


class AnalyticsService:
    """Facade composing analytics modules with database access.

    Provides high-level methods that fetch raw health data from the
    database and delegate computation to the pure-logic analytics
    modules: CorrelationAnalyzer, TrendDetector, GoalTracker, and
    InsightGenerator.

    Attributes:
        _correlation: Instance of CorrelationAnalyzer.
        _trend: Instance of TrendDetector.
        _goals: Instance of GoalTracker.
        _insight: Instance of InsightGenerator.
    """

    def __init__(self) -> None:
        """Initialize the analytics service with all sub-modules."""
        self._correlation = CorrelationAnalyzer()
        self._trend = TrendDetector()
        self._goals = GoalTracker()
        self._insight = InsightGenerator()

    async def get_daily_summary(
        self,
        db: AsyncSession,
        user_id: str,
        target_date: date,
    ) -> dict[str, Any]:
        """Aggregate health data for a single day.

        Queries the ``daily_summaries`` table for all metric types on
        the given date and maps them to the summary response keys.

        Args:
            db: Async database session.
            user_id: The user's unique identifier.
            target_date: The calendar date to summarize.

        Returns:
            A dict with keys: date, steps, calories_consumed,
            calories_burned, workouts_count, sleep_hours, weight_kg.
        """
        stmt = sql_text(
            "SELECT metric_type, value "
            "FROM daily_summaries "
            "WHERE user_id = :user_id AND date = :target_date"
        )
        rows = (await db.execute(stmt, {"user_id": user_id, "target_date": target_date})).all()

        # Build a lookup: metric_type -> value
        metrics: dict[str, float] = {row.metric_type: float(row.value) for row in rows}

        steps = int(metrics.get("steps", 0))
        calories_burned = int(metrics.get("active_calories", 0))
        calories_consumed = int(metrics.get("calories", 0))
        # sleep_duration is stored in minutes; convert to hours
        sleep_hours = round(metrics.get("sleep_duration", 0) / 60.0, 1)
        weight_kg: float | None = metrics.get("weight_kg")
        workouts_count = int(metrics.get("exercise_minutes", 0))

        return {
            "date": target_date.isoformat(),
            "steps": steps,
            "calories_consumed": calories_consumed,
            "calories_burned": calories_burned,
            "workouts_count": workouts_count,
            "sleep_hours": sleep_hours,
            "weight_kg": weight_kg,
        }

    async def get_weekly_trends(
        self,
        db: AsyncSession,
        user_id: str,
    ) -> dict[str, Any]:
        """Build 7-day trend arrays for dashboard charts.

        Performs a single query for the last 7 days of daily_summaries
        and pivots the results into parallel lists.

        Args:
            db: Async database session.
            user_id: The user's unique identifier.

        Returns:
            A dict with keys: dates, steps, calories_in, calories_out,
            sleep_hours — each a list of 7 values (oldest first).
        """
        today = date.today()
        start_date = today - timedelta(days=6)

        stmt = sql_text(
            "SELECT date, metric_type, value "
            "FROM daily_summaries "
            "WHERE user_id = :user_id "
            "  AND date >= :start_date "
            "  AND date <= :end_date "
            "ORDER BY date"
        )
        rows = (
            await db.execute(stmt, {"user_id": user_id, "start_date": start_date, "end_date": today})
        ).all()

        # Group values by date
        day_metrics: dict[date, dict[str, float]] = {}
        for row in rows:
            d = row.date if isinstance(row.date, date) else date.fromisoformat(str(row.date))
            day_metrics.setdefault(d, {})[row.metric_type] = float(row.value)

        dates: list[str] = []
        steps: list[int] = []
        calories_in: list[int] = []
        calories_out: list[int] = []
        sleep_list: list[float] = []

        for days_ago in range(6, -1, -1):
            day = today - timedelta(days=days_ago)
            m = day_metrics.get(day, {})
            dates.append(day.isoformat())
            steps.append(int(m.get("steps", 0)))
            calories_in.append(int(m.get("calories", 0)))
            calories_out.append(int(m.get("active_calories", 0)))
            sleep_list.append(round(m.get("sleep_duration", 0) / 60.0, 1))

        return {
            "dates": dates,
            "steps": steps,
            "calories_in": calories_in,
            "calories_out": calories_out,
            "sleep_hours": sleep_list,
        }

    async def get_sleep_activity_correlation(
        self,
        db: AsyncSession,
        user_id: str,
        days: int = 30,
        lag: int = 0,
    ) -> dict[str, Any]:
        """Compute correlation between sleep and activity.

        Fetches sleep_duration and active_calories from daily_summaries
        for the requested window and delegates to CorrelationAnalyzer
        for the Pearson coefficient.

        Args:
            db: Async database session.
            user_id: The user's unique identifier.
            days: Number of historical days to include (default 30).
            lag: Day offset for activity relative to sleep (default 0).

        Returns:
            A dict with keys: metric_x, metric_y, score, message,
            lag, data_points.
        """
        cutoff = date.today() - timedelta(days=days)

        stmt = sql_text(
            "SELECT date, metric_type, value "
            "FROM daily_summaries "
            "WHERE user_id = :user_id "
            "  AND date >= :cutoff "
            "  AND metric_type IN ('sleep_duration', 'active_calories') "
            "ORDER BY date"
        )
        rows = (await db.execute(stmt, {"user_id": user_id, "cutoff": cutoff})).all()

        # Separate into per-date dicts
        sleep_by_date: dict[str, float] = {}
        activity_by_date: dict[str, float] = {}
        for row in rows:
            d = str(row.date)
            if row.metric_type == "sleep_duration":
                # Convert minutes to hours
                sleep_by_date[d] = float(row.value) / 60.0
            elif row.metric_type == "active_calories":
                activity_by_date[d] = float(row.value)

        sleep_data: list[dict[str, Any]] = [
            {"date": d, "hours": h} for d, h in sorted(sleep_by_date.items())
        ]
        activity_data: list[dict[str, Any]] = [
            {"date": d, "calories": int(c)} for d, c in sorted(activity_by_date.items())
        ]

        result = self._correlation.analyze_sleep_impact_on_activity(
            sleep_data=sleep_data,
            activity_data=activity_data,
            lag=lag,
        )

        return {
            "metric_x": "sleep_hours",
            "metric_y": "activity_calories",
            "score": result.get("score", 0.0),
            "message": result.get("message", ""),
            "lag": result.get("lag", lag),
            "data_points": result.get("data_points", 0),
        }

    async def get_metric_trend(
        self,
        db: AsyncSession,
        user_id: str,
        metric: str,
        window_size: int = 7,
    ) -> dict[str, Any]:
        """Detect trend direction for a given health metric.

        Fetches the metric's daily values over a sufficient window
        and delegates to TrendDetector.

        Args:
            db: Async database session.
            user_id: The user's unique identifier.
            metric: Metric name (e.g. 'steps', 'calories_consumed',
                'sleep_hours', 'weight_kg').
            window_size: Size of each comparison window (default 7).

        Returns:
            A dict with keys: metric, trend, percent_change,
            recent_avg, previous_avg.
        """
        lookback_days = window_size * 3
        values = await self._fetch_metric_series(db, user_id, metric, lookback_days)

        result = self._trend.detect_trend(values, window_size=window_size)
        return {
            "metric": metric,
            "trend": result.get("trend", "insufficient_data"),
            "percent_change": result.get("percent_change", 0.0),
            "recent_avg": result.get("recent_avg", 0.0),
            "previous_avg": result.get("previous_avg", 0.0),
        }

    async def get_goal_progress(
        self,
        db: AsyncSession,
        user_id: str,
    ) -> list[dict[str, Any]]:
        """Compute progress for all active user goals.

        Fetches active UserGoal records, resolves the current value
        for each metric, and delegates to GoalTracker.

        Args:
            db: Async database session.
            user_id: The user's unique identifier.

        Returns:
            A list of goal progress dicts, each with keys: metric,
            period, target, current, progress_pct, is_met, remaining.
        """
        goals_stmt = select(UserGoal).where(
            UserGoal.user_id == user_id,
            UserGoal.is_active.is_(True),
        )
        goals_result = await db.execute(goals_stmt)
        goals = goals_result.scalars().all()

        progress_list: list[dict[str, Any]] = []
        for goal in goals:
            current = await self._get_current_metric_value(
                db,
                user_id,
                goal.metric,
                goal.period.value,
            )
            progress = self._goals.check_progress(
                metric=goal.metric,
                current_value=current,
                target_value=goal.target_value,
                period=goal.period.value,
            )
            progress_list.append(progress)

        return progress_list

    async def get_dashboard_insight(
        self,
        db: AsyncSession,
        user_id: str,
    ) -> dict[str, Any]:
        """Generate the dashboard insight of the day.

        Combines goal progress and metric trends, then delegates to
        InsightGenerator for a prioritized human-readable insight.

        Args:
            db: Async database session.
            user_id: The user's unique identifier.

        Returns:
            A dict with keys: insight (str), goals (list), trends (dict).
        """
        goal_status = await self.get_goal_progress(db, user_id)

        # Compute trends for key metrics.
        key_metrics = ["steps", "calories_consumed", "sleep_hours"]
        trends: dict[str, dict[str, Any]] = {}
        for metric in key_metrics:
            trend_result = await self.get_metric_trend(db, user_id, metric)
            trends[metric] = trend_result

        insight = self._insight.generate_dashboard_insight(goal_status, trends)

        return {
            "insight": insight,
            "goals": goal_status,
            "trends": trends,
        }

    async def _get_current_metric_value(
        self,
        db: AsyncSession,
        user_id: str,
        metric: str,
        period: str,
    ) -> float:
        """Fetch the current accumulated value for a metric and period.

        Determines the date range based on the period (daily = today,
        weekly = last 7 days, long_term = most recent value) and queries
        the ``daily_summaries`` table.

        Args:
            db: Async database session.
            user_id: The user's unique identifier.
            metric: Metric name (e.g. 'steps', 'calories_consumed').
            period: Goal period ('daily', 'weekly', or 'long_term').

        Returns:
            The accumulated or most recent metric value as a float.
            Returns 0.0 if no data is found.
        """
        metric_type = _METRIC_TYPE_MAP.get(metric)
        if metric_type is None:
            logger.warning("Unknown metric '%s'; returning 0.0", metric)
            return 0.0

        today = date.today()

        if period == "daily":
            start_date = today
        elif period == "weekly":
            start_date = today - timedelta(days=6)
        else:
            # long_term — return most recent value.
            start_date = today - timedelta(days=365)

        is_avg_metric = metric in ("sleep_hours", "weight_kg")
        is_latest_metric = metric == "weight_kg"

        if is_latest_metric:
            # For weight, return the most recent measurement.
            stmt = sql_text(
                "SELECT value FROM daily_summaries "
                "WHERE user_id = :user_id "
                "  AND metric_type = :metric_type "
                "  AND date >= :start_date "
                "  AND date <= :end_date "
                "ORDER BY date DESC LIMIT 1"
            )
            row = (
                await db.execute(
                    stmt,
                    {
                        "user_id": user_id,
                        "metric_type": metric_type,
                        "start_date": start_date,
                        "end_date": today,
                    },
                )
            ).first()
            return float(row.value) if row else 0.0

        if is_avg_metric:
            # For sleep, average over the range and convert minutes to hours.
            stmt = sql_text(
                "SELECT COALESCE(AVG(value), 0) AS agg "
                "FROM daily_summaries "
                "WHERE user_id = :user_id "
                "  AND metric_type = :metric_type "
                "  AND date >= :start_date "
                "  AND date <= :end_date"
            )
            row = (
                await db.execute(
                    stmt,
                    {
                        "user_id": user_id,
                        "metric_type": metric_type,
                        "start_date": start_date,
                        "end_date": today,
                    },
                )
            ).one()
            # sleep_duration stored in minutes, convert to hours
            return round(float(row.agg) / 60.0, 1)

        # Default: SUM over the range.
        stmt = sql_text(
            "SELECT COALESCE(SUM(value), 0) AS agg "
            "FROM daily_summaries "
            "WHERE user_id = :user_id "
            "  AND metric_type = :metric_type "
            "  AND date >= :start_date "
            "  AND date <= :end_date"
        )
        row = (
            await db.execute(
                stmt,
                {
                    "user_id": user_id,
                    "metric_type": metric_type,
                    "start_date": start_date,
                    "end_date": today,
                },
            )
        ).one()
        return float(row.agg)

    async def _fetch_metric_series(
        self,
        db: AsyncSession,
        user_id: str,
        metric: str,
        lookback_days: int,
    ) -> list[float]:
        """Fetch a chronological series of daily values for a metric.

        Used by trend detection. Produces one value per day for the
        requested lookback window.

        Args:
            db: Async database session.
            user_id: The user's unique identifier.
            metric: Metric name to fetch.
            lookback_days: Number of days of history to retrieve.

        Returns:
            A list of daily float values, oldest first.
        """
        metric_type = _METRIC_TYPE_MAP.get(metric)
        if metric_type is None:
            logger.warning("Unknown metric '%s' for series fetch; returning empty list", metric)
            return []

        cutoff = date.today() - timedelta(days=lookback_days)

        stmt = sql_text(
            "SELECT date, value "
            "FROM daily_summaries "
            "WHERE user_id = :user_id "
            "  AND metric_type = :metric_type "
            "  AND date >= :cutoff "
            "ORDER BY date"
        )
        rows = (
            await db.execute(
                stmt, {"user_id": user_id, "metric_type": metric_type, "cutoff": cutoff}
            )
        ).all()

        if metric == "sleep_hours":
            # Convert minutes to hours
            return [round(float(row.value) / 60.0, 1) for row in rows]

        return [float(row.value) for row in rows]
