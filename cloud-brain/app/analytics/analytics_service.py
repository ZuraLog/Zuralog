"""
Life Logger Cloud Brain — Analytics Service Facade.

High-level facade that composes all four analytics modules
(CorrelationAnalyzer, TrendDetector, GoalTracker, InsightGenerator)
and provides database-backed methods for the analytics API router.

This service handles data fetching via SQLAlchemy async queries and
delegates computation to the pure-logic analytics modules.
"""

import logging
from datetime import date, timedelta
from typing import Any

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.analytics.correlation_analyzer import CorrelationAnalyzer
from app.analytics.goal_tracker import GoalTracker
from app.analytics.insight_generator import InsightGenerator
from app.analytics.trend_detector import TrendDetector
from app.models.health_data import (
    NutritionEntry,
    SleepRecord,
    UnifiedActivity,
    WeightMeasurement,
)
from app.models.user_goal import UserGoal

logger = logging.getLogger(__name__)

# Conversion factor: average stride length in meters.
_METERS_PER_STEP = 0.762


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

        Queries activity calories/distance, nutrition intake, sleep
        duration, weight measurement, and workout count, then combines
        them into a single summary dict.

        Args:
            db: Async database session.
            user_id: The user's unique identifier.
            target_date: The calendar date to summarize.

        Returns:
            A dict with keys: date, steps, calories_consumed,
            calories_burned, workouts_count, sleep_hours, weight_kg.
        """
        date_str = target_date.isoformat()

        # Activity aggregates — filter by date portion of start_time.
        activity_stmt = select(
            func.coalesce(func.sum(UnifiedActivity.calories), 0).label("calories_burned"),
            func.coalesce(func.sum(UnifiedActivity.distance_meters), 0).label("total_distance"),
            func.count(UnifiedActivity.id).label("workouts_count"),
        ).where(
            UnifiedActivity.user_id == user_id,
            func.date(UnifiedActivity.start_time) == target_date,
        )
        activity_row = (await db.execute(activity_stmt)).one()

        calories_burned: int = int(activity_row.calories_burned)
        total_distance: float = float(activity_row.total_distance)
        workouts_count: int = int(activity_row.workouts_count)
        steps: int = int(total_distance / _METERS_PER_STEP)

        # Nutrition aggregate — filter by date string.
        nutrition_stmt = select(
            func.coalesce(func.sum(NutritionEntry.calories), 0).label("calories_consumed"),
        ).where(
            NutritionEntry.user_id == user_id,
            NutritionEntry.date == date_str,
        )
        nutrition_row = (await db.execute(nutrition_stmt)).one()
        calories_consumed: int = int(nutrition_row.calories_consumed)

        # Sleep aggregate — filter by date string.
        sleep_stmt = select(
            func.coalesce(func.avg(SleepRecord.hours), 0.0).label("sleep_hours"),
        ).where(
            SleepRecord.user_id == user_id,
            SleepRecord.date == date_str,
        )
        sleep_row = (await db.execute(sleep_stmt)).one()
        sleep_hours: float = round(float(sleep_row.sleep_hours), 1)

        # Weight — most recent measurement for the date.
        weight_stmt = (
            select(WeightMeasurement.weight_kg)
            .where(
                WeightMeasurement.user_id == user_id,
                WeightMeasurement.date == date_str,
            )
            .limit(1)
        )
        weight_row = (await db.execute(weight_stmt)).first()
        weight_kg: float | None = float(weight_row.weight_kg) if weight_row else None

        return {
            "date": date_str,
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

        Calls ``get_daily_summary`` for each of the last 7 days and
        collects the results into parallel lists.

        Args:
            db: Async database session.
            user_id: The user's unique identifier.

        Returns:
            A dict with keys: dates, steps, calories_in, calories_out,
            sleep_hours — each a list of 7 values (oldest first).
        """
        today = date.today()
        dates: list[str] = []
        steps: list[int] = []
        calories_in: list[int] = []
        calories_out: list[int] = []
        sleep_hours: list[float] = []

        for days_ago in range(6, -1, -1):
            day = today - timedelta(days=days_ago)
            summary = await self.get_daily_summary(db, user_id, day)
            dates.append(summary["date"])
            steps.append(summary["steps"])
            calories_in.append(summary["calories_consumed"])
            calories_out.append(summary["calories_burned"])
            sleep_hours.append(summary["sleep_hours"])

        return {
            "dates": dates,
            "steps": steps,
            "calories_in": calories_in,
            "calories_out": calories_out,
            "sleep_hours": sleep_hours,
        }

    async def get_sleep_activity_correlation(
        self,
        db: AsyncSession,
        user_id: str,
        days: int = 30,
        lag: int = 0,
    ) -> dict[str, Any]:
        """Compute correlation between sleep and activity.

        Fetches sleep and activity data for the requested window and
        delegates to CorrelationAnalyzer for Pearson coefficient.

        Args:
            db: Async database session.
            user_id: The user's unique identifier.
            days: Number of historical days to include (default 30).
            lag: Day offset for activity relative to sleep (default 0).

        Returns:
            A dict with keys: metric_x, metric_y, score, message,
            lag, data_points.
        """
        cutoff = (date.today() - timedelta(days=days)).isoformat()

        # Fetch sleep data.
        sleep_stmt = (
            select(SleepRecord.date, SleepRecord.hours)
            .where(
                SleepRecord.user_id == user_id,
                SleepRecord.date >= cutoff,
            )
            .order_by(SleepRecord.date)
        )
        sleep_rows = (await db.execute(sleep_stmt)).all()
        sleep_data: list[dict[str, Any]] = [{"date": row.date, "hours": row.hours} for row in sleep_rows]

        # Fetch activity data — aggregate calories per day.
        activity_stmt = (
            select(
                func.date(UnifiedActivity.start_time).label("activity_date"),
                func.sum(UnifiedActivity.calories).label("daily_calories"),
            )
            .where(
                UnifiedActivity.user_id == user_id,
                func.date(UnifiedActivity.start_time) >= cutoff,
            )
            .group_by(func.date(UnifiedActivity.start_time))
            .order_by(func.date(UnifiedActivity.start_time))
        )
        activity_rows = (await db.execute(activity_stmt)).all()
        activity_data: list[dict[str, Any]] = [
            {"date": str(row.activity_date), "calories": int(row.daily_calories)} for row in activity_rows
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
        the appropriate table.

        Args:
            db: Async database session.
            user_id: The user's unique identifier.
            metric: Metric name (e.g. 'steps', 'calories_consumed').
            period: Goal period ('daily', 'weekly', or 'long_term').

        Returns:
            The accumulated or most recent metric value as a float.
            Returns 0.0 if no data is found.
        """
        today = date.today()

        if period == "daily":
            start_date = today
        elif period == "weekly":
            start_date = today - timedelta(days=6)
        else:
            # long_term — return most recent value.
            start_date = today - timedelta(days=365)

        date_str_start = start_date.isoformat()
        date_str_end = today.isoformat()

        if metric == "steps":
            stmt = select(
                func.coalesce(func.sum(UnifiedActivity.distance_meters), 0),
            ).where(
                UnifiedActivity.user_id == user_id,
                func.date(UnifiedActivity.start_time) >= start_date,
                func.date(UnifiedActivity.start_time) <= today,
            )
            row = (await db.execute(stmt)).one()
            return float(int(float(row[0]) / _METERS_PER_STEP))

        if metric == "calories_consumed":
            stmt = select(
                func.coalesce(func.sum(NutritionEntry.calories), 0),
            ).where(
                NutritionEntry.user_id == user_id,
                NutritionEntry.date >= date_str_start,
                NutritionEntry.date <= date_str_end,
            )
            row = (await db.execute(stmt)).one()
            return float(row[0])

        if metric == "calories_burned":
            stmt = select(
                func.coalesce(func.sum(UnifiedActivity.calories), 0),
            ).where(
                UnifiedActivity.user_id == user_id,
                func.date(UnifiedActivity.start_time) >= start_date,
                func.date(UnifiedActivity.start_time) <= today,
            )
            row = (await db.execute(stmt)).one()
            return float(row[0])

        if metric == "sleep_hours":
            stmt = select(
                func.coalesce(func.avg(SleepRecord.hours), 0.0),
            ).where(
                SleepRecord.user_id == user_id,
                SleepRecord.date >= date_str_start,
                SleepRecord.date <= date_str_end,
            )
            row = (await db.execute(stmt)).one()
            return round(float(row[0]), 1)

        if metric == "weight_kg":
            stmt = (
                select(WeightMeasurement.weight_kg)
                .where(
                    WeightMeasurement.user_id == user_id,
                    WeightMeasurement.date >= date_str_start,
                    WeightMeasurement.date <= date_str_end,
                )
                .order_by(WeightMeasurement.date.desc())
                .limit(1)
            )
            row = (await db.execute(stmt)).first()
            return float(row[0]) if row else 0.0

        if metric == "workouts":
            stmt = select(
                func.count(UnifiedActivity.id),
            ).where(
                UnifiedActivity.user_id == user_id,
                func.date(UnifiedActivity.start_time) >= start_date,
                func.date(UnifiedActivity.start_time) <= today,
            )
            row = (await db.execute(stmt)).one()
            return float(row[0])

        logger.warning("Unknown metric '%s'; returning 0.0", metric)
        return 0.0

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
        cutoff = date.today() - timedelta(days=lookback_days)
        cutoff_str = cutoff.isoformat()

        if metric == "steps":
            stmt = (
                select(
                    func.date(UnifiedActivity.start_time).label("day"),
                    func.sum(UnifiedActivity.distance_meters).label("total_dist"),
                )
                .where(
                    UnifiedActivity.user_id == user_id,
                    func.date(UnifiedActivity.start_time) >= cutoff,
                )
                .group_by(func.date(UnifiedActivity.start_time))
                .order_by(func.date(UnifiedActivity.start_time))
            )
            rows = (await db.execute(stmt)).all()
            return [float(int((row.total_dist or 0) / _METERS_PER_STEP)) for row in rows]

        if metric == "calories_consumed":
            stmt = (
                select(NutritionEntry.date, func.sum(NutritionEntry.calories).label("total"))
                .where(
                    NutritionEntry.user_id == user_id,
                    NutritionEntry.date >= cutoff_str,
                )
                .group_by(NutritionEntry.date)
                .order_by(NutritionEntry.date)
            )
            rows = (await db.execute(stmt)).all()
            return [float(row.total) for row in rows]

        if metric == "calories_burned":
            stmt = (
                select(
                    func.date(UnifiedActivity.start_time).label("day"),
                    func.sum(UnifiedActivity.calories).label("total"),
                )
                .where(
                    UnifiedActivity.user_id == user_id,
                    func.date(UnifiedActivity.start_time) >= cutoff,
                )
                .group_by(func.date(UnifiedActivity.start_time))
                .order_by(func.date(UnifiedActivity.start_time))
            )
            rows = (await db.execute(stmt)).all()
            return [float(row.total) for row in rows]

        if metric == "sleep_hours":
            stmt = (
                select(SleepRecord.date, func.avg(SleepRecord.hours).label("avg_hours"))
                .where(
                    SleepRecord.user_id == user_id,
                    SleepRecord.date >= cutoff_str,
                )
                .group_by(SleepRecord.date)
                .order_by(SleepRecord.date)
            )
            rows = (await db.execute(stmt)).all()
            return [round(float(row.avg_hours), 1) for row in rows]

        if metric == "weight_kg":
            stmt = (
                select(WeightMeasurement.date, WeightMeasurement.weight_kg)
                .where(
                    WeightMeasurement.user_id == user_id,
                    WeightMeasurement.date >= cutoff_str,
                )
                .order_by(WeightMeasurement.date)
            )
            rows = (await db.execute(stmt)).all()
            return [float(row.weight_kg) for row in rows]

        logger.warning("Unknown metric '%s' for series fetch; returning empty list", metric)
        return []
