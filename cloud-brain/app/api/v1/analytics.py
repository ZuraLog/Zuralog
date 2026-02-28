"""
Zuralog Cloud Brain — Analytics API Router.

RESTful endpoints for health analytics: daily summaries, weekly trends,
sleep-activity correlation, metric trend detection, goal progress
tracking, and dashboard insights.

All endpoints delegate computation to the AnalyticsService facade,
which composes the pure-logic analytics modules with database access.
"""

import uuid
from datetime import date

import sentry_sdk
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.analytics.analytics_service import AnalyticsService
from app.api.v1.analytics_schemas import (
    CorrelationResponse,
    DailySummaryResponse,
    DashboardInsightResponse,
    GoalProgressResponse,
    TrendResponse,
    UserGoalRequest,
    WeeklyTrendsResponse,
)
from app.database import get_db
from app.models.user_goal import GoalPeriod, UserGoal
from app.services.cache_service import cached


async def _set_sentry_module() -> None:
    sentry_sdk.set_tag("api.module", "analytics")


router = APIRouter(
    prefix="/analytics",
    tags=["analytics"],
    dependencies=[Depends(_set_sentry_module)],
)

# Module-level singleton — stateless, safe to reuse across requests.
_analytics_service = AnalyticsService()


@router.get("/daily-summary", response_model=DailySummaryResponse)
@cached(prefix="analytics.daily_summary", ttl=300, key_params=["user_id", "date_str"])
async def daily_summary(
    user_id: str = Query(..., description="User ID"),
    date_str: str | None = Query(
        None,
        description="ISO-8601 date (YYYY-MM-DD). Defaults to today.",
    ),
    db: AsyncSession = Depends(get_db),
) -> DailySummaryResponse:
    """Get aggregated health data for a single day.

    Combines activity, nutrition, sleep, and weight data into a
    unified daily snapshot.

    Args:
        user_id: The user's unique identifier.
        date_str: Optional ISO-8601 date string. Defaults to today.
        db: Injected async database session.

    Returns:
        DailySummaryResponse with day's health aggregates.

    Raises:
        HTTPException: 400 if date_str cannot be parsed.
    """
    if date_str:
        try:
            target_date = date.fromisoformat(date_str)
        except ValueError as exc:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid date format: '{date_str}'. Use YYYY-MM-DD.",
            ) from exc
    else:
        target_date = date.today()

    result = await _analytics_service.get_daily_summary(db, user_id, target_date)
    return DailySummaryResponse(**result)


@router.get("/weekly-trends", response_model=WeeklyTrendsResponse)
@cached(prefix="analytics.weekly_trends", ttl=300, key_params=["user_id"])
async def weekly_trends(
    user_id: str = Query(..., description="User ID"),
    db: AsyncSession = Depends(get_db),
) -> WeeklyTrendsResponse:
    """Get 7-day trend data for dashboard charts.

    Returns parallel arrays of daily values for the most recent
    7 days, suitable for multi-series chart rendering.

    Args:
        user_id: The user's unique identifier.
        db: Injected async database session.

    Returns:
        WeeklyTrendsResponse with 7 days of data arrays.
    """
    result = await _analytics_service.get_weekly_trends(db, user_id)
    return WeeklyTrendsResponse(**result)


@router.get("/correlation/sleep-activity", response_model=CorrelationResponse)
@cached(prefix="analytics.correlation", ttl=900, key_params=["user_id", "days"])
async def sleep_activity_correlation(
    user_id: str = Query(..., description="User ID"),
    days: int = Query(30, ge=7, le=365, description="Lookback days"),
    lag: int = Query(0, ge=0, le=7, description="Day lag for activity"),
    db: AsyncSession = Depends(get_db),
) -> CorrelationResponse:
    """Analyze correlation between sleep and activity.

    Computes the Pearson correlation coefficient between sleep hours
    and activity calories over the requested window, with optional
    lag offset.

    Args:
        user_id: The user's unique identifier.
        days: Number of historical days to analyze (7-365).
        lag: Day offset for activity relative to sleep (0-7).
        db: Injected async database session.

    Returns:
        CorrelationResponse with score, message, and data points.
    """
    result = await _analytics_service.get_sleep_activity_correlation(
        db,
        user_id,
        days=days,
        lag=lag,
    )
    return CorrelationResponse(**result)


@router.get("/trend/{metric}", response_model=TrendResponse)
@cached(prefix="analytics.trend", ttl=300, key_params=["user_id", "metric"])
async def metric_trend(
    metric: str,
    user_id: str = Query(..., description="User ID"),
    window_size: int = Query(7, ge=3, le=30, description="Window size"),
    db: AsyncSession = Depends(get_db),
) -> TrendResponse:
    """Detect trend direction for a single health metric.

    Compares the recent window average against the previous window
    to classify the metric as trending up, down, or stable.

    Args:
        metric: Metric name (e.g. 'steps', 'calories_consumed').
        user_id: The user's unique identifier.
        window_size: Size of each comparison window (3-30).
        db: Injected async database session.

    Returns:
        TrendResponse with trend direction and statistics.
    """
    result = await _analytics_service.get_metric_trend(
        db,
        user_id,
        metric,
        window_size=window_size,
    )
    return TrendResponse(**result)


@router.get("/goals", response_model=list[GoalProgressResponse])
@cached(prefix="analytics.goals", ttl=300, key_params=["user_id"])
async def get_goals(
    user_id: str = Query(..., description="User ID"),
    db: AsyncSession = Depends(get_db),
) -> list[GoalProgressResponse]:
    """Get progress for all active user goals.

    Returns current progress toward each of the user's active goals,
    including percentage completion and remaining deficit.

    Args:
        user_id: The user's unique identifier.
        db: Injected async database session.

    Returns:
        A list of GoalProgressResponse for each active goal.
    """
    results = await _analytics_service.get_goal_progress(db, user_id)
    return [GoalProgressResponse(**r) for r in results]


@router.post("/goals", response_model=GoalProgressResponse, status_code=201)
async def create_or_update_goal(
    body: UserGoalRequest,
    user_id: str = Query(..., description="User ID"),
    db: AsyncSession = Depends(get_db),
) -> GoalProgressResponse:
    """Create or update a user goal (upsert by user_id + metric).

    If a goal already exists for the given user and metric, updates
    its target value and period. Otherwise creates a new goal.

    Args:
        body: Goal creation/update request with metric, target, period.
        user_id: The user's unique identifier.
        db: Injected async database session.

    Returns:
        GoalProgressResponse reflecting the saved goal's current progress.
    """
    from sqlalchemy import select as sa_select

    # Check for existing goal.
    stmt = sa_select(UserGoal).where(
        UserGoal.user_id == user_id,
        UserGoal.metric == body.metric,
    )
    result = await db.execute(stmt)
    existing_goal: UserGoal | None = result.scalar_one_or_none()

    if existing_goal:
        existing_goal.target_value = body.target_value
        existing_goal.period = GoalPeriod(body.period)
        existing_goal.is_active = True
    else:
        new_goal = UserGoal(
            id=str(uuid.uuid4()),
            user_id=user_id,
            metric=body.metric,
            target_value=body.target_value,
            period=GoalPeriod(body.period),
            is_active=True,
        )
        db.add(new_goal)

    await db.commit()

    # Compute current progress for the response.
    current = await _analytics_service._get_current_metric_value(
        db,
        user_id,
        body.metric,
        body.period,
    )
    from app.analytics.goal_tracker import GoalTracker

    tracker = GoalTracker()
    progress = tracker.check_progress(
        metric=body.metric,
        current_value=current,
        target_value=body.target_value,
        period=body.period,
    )
    return GoalProgressResponse(**progress)


@router.get("/dashboard-insight", response_model=DashboardInsightResponse)
@cached(prefix="analytics.dashboard_insight", ttl=300, key_params=["user_id"])
async def dashboard_insight(
    user_id: str = Query(..., description="User ID"),
    db: AsyncSession = Depends(get_db),
) -> DashboardInsightResponse:
    """Get the dashboard insight of the day.

    Synthesizes goal progress and metric trends into a single
    prioritized human-readable insight, along with structured
    goal and trend data.

    Args:
        user_id: The user's unique identifier.
        db: Injected async database session.

    Returns:
        DashboardInsightResponse with insight text, goals, and trends.
    """
    result = await _analytics_service.get_dashboard_insight(db, user_id)

    # Convert nested dicts to response models.
    goals = [GoalProgressResponse(**g) for g in result["goals"]]
    trends = {k: TrendResponse(**v) for k, v in result["trends"].items()}

    return DashboardInsightResponse(
        insight=result["insight"],
        goals=goals,
        trends=trends,
    )
