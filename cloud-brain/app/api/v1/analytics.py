"""
Zuralog Cloud Brain — Analytics API Router.

RESTful endpoints for health analytics: daily summaries, weekly trends,
sleep-activity correlation, metric trend detection, goal progress
tracking, and dashboard insights.

All endpoints delegate computation to the AnalyticsService facade,
which composes the pure-logic analytics modules with database access.
"""

import asyncio
import logging
import uuid
from collections.abc import Callable
from typing import cast
from datetime import date, timedelta

logger = logging.getLogger(__name__)

import sentry_sdk
from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy import text as sql_text
from sqlalchemy.ext.asyncio import AsyncSession

from app.analytics.analytics_service import AnalyticsService
from app.limiter import limiter
from app.api.v1.analytics_schemas import (
    CategoryDetailResponse,
    CategorySummaryItem,
    CorrelationResponse,
    DailySummaryResponse,
    DashboardInsightResponse,
    DashboardSummaryResponse,
    GoalProgressResponse,
    MetricDataPointItem,
    MetricDetailResponse,
    MetricSeriesItem,
    TrendResponse,
    UserGoalRequest,
    WeeklyTrendsResponse,
)
from app.api.deps import get_authenticated_user_id
from app.database import async_session, get_db
from app.models.user_goal import GoalPeriod, UserGoal
from app.services.cache_service import cached
from app.utils.user_date import get_user_local_date


# ── Module-level formatting helpers ──────────────────────────────────────────


def _delta(recent: list[float], prior: list[float]) -> float | None:
    if not recent or not prior:
        return None
    avg_r = sum(recent) / len(recent)
    avg_p = sum(prior) / len(prior)
    if avg_p == 0:
        return None
    return round(((avg_r - avg_p) / avg_p) * 100, 1)


def _trend(rows: list[tuple[str, float]], days: int = 7) -> list[float] | None:
    """Build trend list from (date_str, value) rows for the last `days` days."""
    if not rows:
        return None
    vals = [v for _, v in rows[-days:]]
    return vals if len(vals) >= 2 else None




def _fmt_steps(v: float) -> str:
    return f"{int(v):,}"


def _fmt_hours(v: float) -> str:
    """Format a duration stored in *minutes* as 'Xh YYm'."""
    total_min = round(v)
    h, m = divmod(total_min, 60)
    return f"{h}h {m:02d}m"


# ── Per-category parallel fetch helpers ──────────────────────────────────────

# Order of categories in dashboard_summary — must match the asyncio.gather call order.
_CATEGORY_ORDER: list[str] = [
    "activity", "sleep", "heart", "body", "vitals",
    "nutrition", "wellness", "mobility", "cycle", "environment",
]


async def _fetch_category_data(
    user_id: str,
    day14_ago: date,
    day7_ago: date,
    *,
    category: str,
    metric_type: str,
    unit: str | None,
    fmt: Callable[[float], str],
) -> "CategorySummaryItem":
    """Fetch 14-day history for one health category from daily_summaries."""
    async with async_session() as db:
        result = await db.execute(
            sql_text(
                "SELECT date, value FROM daily_summaries "
                "WHERE user_id = :uid AND metric_type = :mt AND date >= :d14 "
                "ORDER BY date"
            ),
            {"uid": user_id, "mt": metric_type, "d14": day14_ago},
        )
        rows = [(r[0], float(r[1])) for r in result.fetchall()]
    recent_rows = [(d, v) for d, v in rows if d >= day7_ago]
    prior_rows = [(d, v) for d, v in rows if d < day7_ago]
    if recent_rows:
        primary = recent_rows[-1][1]
        return CategorySummaryItem(
            category=category,
            primary_value=fmt(primary),
            unit=unit,
            delta_percent=_delta([v for _, v in recent_rows], [v for _, v in prior_rows]),
            trend=_trend(recent_rows),
            last_updated=recent_rows[-1][0],
            has_data=True,
        )
    return CategorySummaryItem(category=category, has_data=False)


async def _set_sentry_module() -> None:
    sentry_sdk.set_tag("api.module", "analytics")


router = APIRouter(
    prefix="/analytics",
    tags=["analytics"],
    dependencies=[Depends(_set_sentry_module)],
)

# Module-level singleton — stateless, safe to reuse across requests.
_analytics_service = AnalyticsService()


@limiter.limit("60/minute")
@router.get("/daily-summary", response_model=DailySummaryResponse)
@cached(prefix="analytics.daily_summary", ttl=300, key_params=["user_id", "date_str"])
async def daily_summary(
    request: Request,
    user_id: str = Depends(get_authenticated_user_id),
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
        target_date = await get_user_local_date(db, user_id)

    result = await _analytics_service.get_daily_summary(db, user_id, target_date)
    return DailySummaryResponse(**result)


@limiter.limit("60/minute")
@router.get("/weekly-trends", response_model=WeeklyTrendsResponse)
@cached(prefix="analytics.weekly_trends", ttl=300, key_params=["user_id"])
async def weekly_trends(
    request: Request,
    user_id: str = Depends(get_authenticated_user_id),
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


@limiter.limit("60/minute")
@router.get("/correlation/sleep-activity", response_model=CorrelationResponse)
@cached(prefix="analytics.correlation", ttl=900, key_params=["user_id", "days"])
async def sleep_activity_correlation(
    request: Request,
    user_id: str = Depends(get_authenticated_user_id),
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


@limiter.limit("60/minute")
@router.get("/trend/{metric}", response_model=TrendResponse)
@cached(prefix="analytics.trend", ttl=300, key_params=["user_id", "metric", "window_size"])
async def metric_trend(
    request: Request,
    metric: str,
    user_id: str = Depends(get_authenticated_user_id),
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


@limiter.limit("60/minute")
@router.get("/goals", response_model=list[GoalProgressResponse])
@cached(prefix="analytics.goals", ttl=300, key_params=["user_id"])
async def get_goals(
    request: Request,
    user_id: str = Depends(get_authenticated_user_id),
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


@limiter.limit("30/minute")
@router.post("/goals", response_model=GoalProgressResponse, status_code=201)
async def create_or_update_goal(
    request: Request,
    body: UserGoalRequest,
    user_id: str = Depends(get_authenticated_user_id),
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

    analytics_svc = getattr(request.app.state, "analytics_service", None)
    if analytics_svc:
        analytics_svc.capture(
            distinct_id=user_id,
            event="goals_updated",
            properties={"goal_count": 1},
        )

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


@limiter.limit("60/minute")
@router.get("/dashboard-insight", response_model=DashboardInsightResponse)
@cached(prefix="analytics.dashboard_insight", ttl=300, key_params=["user_id"])
async def dashboard_insight(
    request: Request,
    user_id: str = Depends(get_authenticated_user_id),
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

    analytics_svc = getattr(request.app.state, "analytics_service", None)
    if analytics_svc:
        analytics_svc.capture(
            distinct_id=user_id,
            event="analytics_viewed",
            properties={"view_type": "dashboard_insight"},
        )

    # Convert nested dicts to response models.
    goals = [GoalProgressResponse(**g) for g in result["goals"]]
    trends = {k: TrendResponse(**v) for k, v in result["trends"].items()}

    return DashboardInsightResponse(
        insight=result["insight"],
        goals=goals,
        trends=trends,
    )


@limiter.limit("60/minute")
@router.get("/dashboard-summary", response_model=DashboardSummaryResponse)
@cached(prefix="analytics.dashboard_summary", ttl=300, key_params=["user_id"])
async def dashboard_summary(
    request: Request,
    user_id: str = Depends(get_authenticated_user_id),
    force_refresh: bool = Query(False, description="Bypass server cache for this request"),
) -> DashboardSummaryResponse:
    """Return aggregated dashboard data for the Data tab Health Dashboard.

    Runs all 8 category queries concurrently via asyncio.gather — each
    helper opens its own session so sessions are never shared across tasks.

    Args:
        request: Incoming FastAPI request.
        user_id: Authenticated user ID from JWT.
        force_refresh: When True, the @cached decorator skips the cached result
            and re-fetches fresh data, then re-populates the cache.

    Returns:
        DashboardSummaryResponse with category summaries and visible order.
    """
    _ = force_refresh  # consumed by @cached
    async with async_session() as temp_db:
        today = await get_user_local_date(temp_db, user_id)
    day14_ago = today - timedelta(days=14)
    day7_ago = today - timedelta(days=7)

    raw_results = await asyncio.gather(
        _fetch_category_data(
            user_id,
            day14_ago,
            day7_ago,
            category="activity",
            metric_type="steps",
            unit="steps",
            fmt=_fmt_steps,
        ),
        _fetch_category_data(
            user_id,
            day14_ago,
            day7_ago,
            category="sleep",
            metric_type="sleep_duration",
            unit=None,
            fmt=_fmt_hours,
        ),
        _fetch_category_data(
            user_id,
            day14_ago,
            day7_ago,
            category="heart",
            metric_type="resting_heart_rate",
            unit="bpm RHR",
            fmt=lambda v: str(int(v)),
        ),
        _fetch_category_data(
            user_id,
            day14_ago,
            day7_ago,
            category="body",
            metric_type="weight_kg",
            unit="kg",
            fmt=lambda v: f"{v:.1f}",
        ),
        _fetch_category_data(
            user_id,
            day14_ago,
            day7_ago,
            category="vitals",
            metric_type="spo2",
            unit="SpO₂",
            fmt=lambda v: f"{v:.0f}%",
        ),
        _fetch_category_data(
            user_id,
            day14_ago,
            day7_ago,
            category="nutrition",
            metric_type="calories",
            unit="kcal",
            fmt=lambda v: f"{int(v):,}",
        ),
        _fetch_category_data(
            user_id,
            day14_ago,
            day7_ago,
            category="wellness",
            metric_type="mood",
            unit="/10 mood",
            fmt=lambda v: f"{v:.0f}",
        ),
        _fetch_category_data(
            user_id,
            day14_ago,
            day7_ago,
            category="mobility",
            metric_type="floors_climbed",
            unit="floors",
            fmt=lambda v: str(int(v)),
        ),
        _fetch_category_data(
            user_id,
            day14_ago,
            day7_ago,
            category="cycle",
            metric_type="cycle_day",
            unit="day",
            fmt=lambda v: f"Day {int(v)}",
        ),
        _fetch_category_data(
            user_id,
            day14_ago,
            day7_ago,
            category="environment",
            metric_type="noise_exposure",
            unit="dB",
            fmt=lambda v: f"{v:.0f}",
        ),
        return_exceptions=True,
    )

    categories: list[CategorySummaryItem] = []
    for category_name, result in zip(_CATEGORY_ORDER, raw_results):
        if isinstance(result, Exception):
            logger.warning(
                "dashboard_summary: failed to fetch %s data for user %s: %s",
                category_name,
                user_id,
                result,
            )
            categories.append(CategorySummaryItem(category=category_name, has_data=False))
        else:
            categories.append(cast(CategorySummaryItem, result))

    visible_order = [c.category for c in categories if c.has_data]

    return DashboardSummaryResponse(categories=categories, visible_order=visible_order)


@limiter.limit("60/minute")
@router.get("/category", response_model=CategoryDetailResponse)
async def category_detail(
    request: Request,
    category: str = Query(..., description="Category slug (e.g. 'activity', 'sleep')"),
    time_range: str = Query("7D", description="Time range: 7D, 30D, 90D"),
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> CategoryDetailResponse:
    """Return all metrics for a health category with time-series data.

    Queries the appropriate tables for the requested category and
    returns metric series for the specified time range.

    Args:
        request: Incoming FastAPI request.
        category: Category slug (activity, sleep, body, heart, vitals,
            nutrition, wellness, mobility, cycle, environment).
        time_range: Time window — '7D', '30D', or '90D'.
        user_id: Authenticated user ID from JWT.
        db: Async database session.

    Returns:
        CategoryDetailResponse with ordered metric series.

    Raises:
        HTTPException: 400 if category is not recognised.
    """
    # HIGH-04: normalise category slug before any branching
    category = category.lower().strip()

    # HIGH-03: reject unknown range values — never silently fall back
    VALID_RANGES = {"7D", "30D", "90D"}
    if time_range.upper() not in VALID_RANGES:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid time_range '{time_range}'. Must be one of: 7D, 30D, 90D.",
        )

    days_map = {"7D": 7, "30D": 30, "90D": 90}
    days = days_map[time_range.upper()]
    today = await get_user_local_date(db, user_id)
    since = today - timedelta(days=days)

    def _make_series(
        metric_id: str,
        display_name: str,
        unit: str,
        rows: list[tuple[str, float]],
        source: str = "apple_health",
    ) -> MetricSeriesItem:
        if not rows:
            return MetricSeriesItem(
                metric_id=metric_id,
                display_name=display_name,
                unit=unit,
                source_integration=source,
            )
        pts = [MetricDataPointItem(timestamp=d, value=v) for d, v in rows]
        values = [v for _, v in rows]
        avg = round(sum(values) / len(values), 2) if values else None
        recent = values[-min(7, len(values)) :]
        prior = values[-min(14, len(values)) : -min(7, len(values))]
        delta = None
        if recent and prior:
            avg_r = sum(recent) / len(recent)
            avg_p = sum(prior) / len(prior)
            if avg_p != 0:
                delta = round(((avg_r - avg_p) / avg_p) * 100, 1)
        current = values[-1]
        return MetricSeriesItem(
            metric_id=metric_id,
            display_name=display_name,
            unit=unit,
            data_points=pts,
            source_integration=source,
            current_value=f"{current:,.1f}" if current != int(current) else f"{int(current):,}",
            delta_percent=delta,
            average=avg,
        )

    metrics: list[MetricSeriesItem] = []

    async def _query_daily_summaries(metric_type: str) -> list[tuple]:
        """Query a single metric_type from daily_summaries."""
        r = await db.execute(
            sql_text(
                "SELECT date, value FROM daily_summaries "
                "WHERE user_id = :uid AND metric_type = :mt AND date >= :since "
                "ORDER BY date"
            ),
            {"uid": user_id, "mt": metric_type, "since": since},
        )
        return [(row[0], float(row[1])) for row in r.fetchall()]

    if category == "activity":
        for mt, mid, dn, unit in [
            ("steps",           "steps",            "Steps",            "steps"),
            ("active_calories", "active_calories",  "Active Calories",  "kcal"),
            ("distance",        "distance",         "Distance",         "m"),
            ("exercise_minutes","exercise_minutes",  "Exercise Minutes", "min"),
            ("walking_speed",   "walking_speed",    "Walking Speed",    "m/s"),
            ("running_pace",    "running_pace",     "Running Pace",     "s/km"),
            ("floors_climbed",  "floors_climbed",   "Floors Climbed",   "floors"),
        ]:
            rows = await _query_daily_summaries(mt)
            if rows:
                metrics.append(_make_series(mid, dn, unit, rows))

    elif category == "sleep":
        for mt, mid, dn, unit in [
            ("sleep_duration",      "sleep_duration",   "Sleep Duration",   "min"),
            ("deep_sleep_minutes",  "sleep_stages",     "Deep Sleep",       "min"),
            ("rem_sleep_minutes",   "rem_sleep",        "REM Sleep",        "min"),
            ("sleep_efficiency",    "sleep_efficiency", "Sleep Efficiency", "%"),
            ("sleep_quality",       "sleep_quality",    "Sleep Quality",    "score"),
        ]:
            rows = await _query_daily_summaries(mt)
            if rows:
                metrics.append(_make_series(mid, dn, unit, rows))

    elif category == "heart":
        for mt, mid, dn, unit in [
            ("resting_heart_rate", "resting_heart_rate", "Resting Heart Rate",    "bpm"),
            ("hrv_ms",             "hrv",                "HRV",                   "ms"),
            ("vo2_max",            "vo2_max",            "VO₂ Max",               "mL/kg/min"),
            ("respiratory_rate",   "respiratory_rate",   "Respiratory Rate",      "brpm"),
            ("heart_rate_avg",     "heart_rate_avg",     "Avg Heart Rate",        "bpm"),
        ]:
            rows = await _query_daily_summaries(mt)
            if rows:
                metrics.append(_make_series(mid, dn, unit, rows))

    elif category == "body":
        for mt, mid, dn, unit in [
            ("weight_kg",           "weight",            "Weight",            "kg"),
            ("muscle_mass_kg",      "muscle_mass",       "Muscle Mass",       "kg"),
            ("body_fat_percentage", "body_fat",          "Body Fat",          "%"),
            ("body_temperature",    "body_temperature",  "Body Temperature",  "°C"),
            ("wrist_temperature",   "wrist_temperature", "Wrist Temperature", "°C"),
        ]:
            rows = await _query_daily_summaries(mt)
            if rows:
                metrics.append(_make_series(mid, dn, unit, rows))

    elif category == "vitals":
        for mt, mid, dn, unit in [
            ("spo2",          "spo2",          "Blood Oxygen",  "%"),
            ("blood_glucose", "blood_glucose",  "Blood Glucose", "mmol/L"),
        ]:
            rows = await _query_daily_summaries(mt)
            if rows:
                metrics.append(_make_series(mid, dn, unit, rows))

    elif category == "nutrition":
        for mt, mid, dn, unit in [
            ("calories",      "calories", "Calories", "kcal"),
            ("protein_grams", "protein",  "Protein",  "g"),
            ("carbs_grams",   "macros",   "Carbs",    "g"),
            ("fat_grams",     "fat",      "Fat",      "g"),
            ("water_ml",      "water",    "Water",    "mL"),
        ]:
            rows = await _query_daily_summaries(mt)
            if rows:
                metrics.append(_make_series(mid, dn, unit, rows))

    elif category == "wellness":
        for mt, mid, dn, unit in [
            ("mood",            "mood",            "Mood",            "/10"),
            ("energy",          "energy",          "Energy",          "/10"),
            ("stress",          "stress",          "Stress",          "/100"),
            ("mindful_minutes", "mindful_minutes", "Mindful Minutes", "min"),
        ]:
            rows = await _query_daily_summaries(mt)
            if rows:
                metrics.append(_make_series(mid, dn, unit, rows))

    elif category == "mobility":
        for mt, mid, dn, unit in [
            ("floors_climbed", "floors_climbed", "Floors Climbed", "floors"),
            ("walking_speed",  "walking_speed",  "Walking Speed",  "m/s"),
        ]:
            rows = await _query_daily_summaries(mt)
            if rows:
                metrics.append(_make_series(mid, dn, unit, rows))

    elif category == "cycle":
        rows = await _query_daily_summaries("cycle_day")
        if rows:
            metrics.append(_make_series("cycle", "Cycle", "day", rows))

    elif category == "environment":
        for mt, mid, dn, unit in [
            ("noise_exposure", "environment", "Noise Exposure", "dB"),
            ("uv_index",       "uv_index",   "UV Index",       "UV"),
        ]:
            rows = await _query_daily_summaries(mt)
            if rows:
                metrics.append(_make_series(mid, dn, unit, rows))

    else:
        raise HTTPException(status_code=400, detail="Invalid category")

    return CategoryDetailResponse(
        category=category,
        metrics=metrics,
        time_range=time_range.upper(),
    )


@limiter.limit("60/minute")
@router.get("/metric", response_model=MetricDetailResponse)
async def metric_detail(
    request: Request,
    metric_id: str = Query(..., description="Metric slug (e.g. 'steps', 'heart_rate_resting')"),
    time_range: str = Query("7D", description="Time range: 7D, 30D, 90D"),
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> MetricDetailResponse:
    """Return deep-dive data for a single metric.

    Fetches the full time series for the metric, computes current value,
    average, and week-over-week delta, and generates an AI insight.

    Args:
        request: Incoming FastAPI request.
        metric_id: Metric slug identifier.
        time_range: Time window — '7D', '30D', or '90D'.
        user_id: Authenticated user ID from JWT.
        db: Async database session.

    Returns:
        MetricDetailResponse with complete time series and AI insight.

    Raises:
        HTTPException: 404 if metric_id is not recognised.
    """
    from datetime import timedelta
    from sqlalchemy import text as sql_text

    # HIGH-03: reject unknown range values — never silently fall back
    VALID_RANGES = {"7D", "30D", "90D"}
    if time_range.upper() not in VALID_RANGES:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid time_range '{time_range}'. Must be one of: 7D, 30D, 90D.",
        )

    days_map = {"7D": 7, "30D": 30, "90D": 90}
    days = days_map[time_range.upper()]
    today = await get_user_local_date(db, user_id)
    since = today - timedelta(days=days)

    # Map metric_id slug (matches Flutter TileId.metricSlug) →
    #   (metric_type, display_name, unit, source, category)
    METRIC_MAP: dict[str, tuple[str, str, str, str, str]] = {
        # Activity
        "steps":            ("steps",            "Steps",            "steps",       "apple_health", "activity"),
        "active_calories":  ("active_calories",  "Active Calories",  "kcal",        "apple_health", "activity"),
        "distance":         ("distance",         "Distance",         "m",           "apple_health", "activity"),
        "exercise_minutes": ("exercise_minutes", "Exercise Minutes", "min",         "apple_health", "activity"),
        "walking_speed":    ("walking_speed",    "Walking Speed",    "m/s",         "apple_health", "activity"),
        "running_pace":     ("running_pace",     "Running Pace",     "s/km",        "apple_health", "activity"),
        "floors_climbed":   ("floors_climbed",   "Floors Climbed",   "floors",      "apple_health", "activity"),
        # Sleep
        "sleep_duration":   ("sleep_duration",      "Sleep Duration",   "min",   "apple_health", "sleep"),
        "sleep_stages":     ("deep_sleep_minutes",  "Sleep Stages",     "min deep","apple_health", "sleep"),
        # Heart
        "resting_heart_rate": ("resting_heart_rate", "Resting Heart Rate", "bpm",       "apple_health", "heart"),
        "hrv":              ("hrv_ms",             "HRV",               "ms",        "apple_health", "heart"),
        "vo2_max":          ("vo2_max",            "VO₂ Max",           "mL/kg/min", "apple_health", "heart"),
        "respiratory_rate": ("respiratory_rate",   "Respiratory Rate",  "brpm",      "apple_health", "heart"),
        # Body
        "weight":               ("weight_kg",           "Weight",            "kg",  "apple_health", "body"),
        "body_fat":             ("body_fat_percentage", "Body Fat",          "%",   "apple_health", "body"),
        "body_temperature":     ("body_temperature",    "Body Temperature",  "°C",  "apple_health", "body"),
        "wrist_temperature":    ("wrist_temperature",   "Wrist Temperature", "°C",  "apple_health", "body"),
        # Vitals
        "spo2":          ("spo2",          "Blood Oxygen",  "%",       "apple_health", "vitals"),
        "blood_glucose": ("blood_glucose", "Blood Glucose", "mmol/L",  "apple_health", "vitals"),
        # Nutrition
        "calories": ("calories",      "Calories", "kcal", "apple_health", "nutrition"),
        "water":    ("water_ml",      "Water",    "mL",   "apple_health", "nutrition"),
        "macros":   ("carbs_grams",   "Macros",   "g",    "apple_health", "nutrition"),
        # Wellness
        "mood":            ("mood",            "Mood",            "/10", "apple_health", "wellness"),
        "energy":          ("energy",          "Energy",          "/10", "apple_health", "wellness"),
        "stress":          ("stress",          "Stress",          "/100","apple_health", "wellness"),
        "mindful_minutes": ("mindful_minutes", "Mindful Minutes", "min", "apple_health", "wellness"),
        # Mobility
        "mobility": ("floors_climbed",   "Mobility",      "floors", "apple_health", "mobility"),
        # Cycle
        "cycle":       ("cycle_day",        "Cycle",         "day", "apple_health", "cycle"),
        # Environment
        "environment": ("noise_exposure",   "Environment",   "dB",  "apple_health", "environment"),
    }

    if metric_id not in METRIC_MAP:
        raise HTTPException(status_code=404, detail=f"Unknown metric: {metric_id!r}")

    metric_type, display_name, unit, source, category = METRIC_MAP[metric_id]

    result = await db.execute(
        sql_text(
            "SELECT date, value FROM daily_summaries "
            "WHERE user_id = :uid AND metric_type = :mt AND date >= :since "
            "ORDER BY date"
        ),
        {"uid": user_id, "mt": metric_type, "since": since},
    )
    rows = [(r[0], float(r[1])) for r in result.fetchall()]

    if not rows:
        # Return empty series — not a 404, just no data
        return MetricDetailResponse(
            series=MetricSeriesItem(
                metric_id=metric_id,
                display_name=display_name,
                unit=unit,
                source_integration=source,
            ),
            category=category,
            ai_insight=None,
        )

    pts = [MetricDataPointItem(timestamp=d, value=v) for d, v in rows]
    values = [v for _, v in rows]
    avg = round(sum(values) / len(values), 2)
    current = values[-1]
    current_str = f"{current:,.1f}" if current != int(current) else f"{int(current):,}"

    recent = values[-min(7, len(values)) :]
    prior = values[-min(14, len(values)) : -min(7, len(values))]
    delta = None
    if recent and prior:
        avg_r = sum(recent) / len(recent)
        avg_p = sum(prior) / len(prior)
        if avg_p != 0:
            delta = round(((avg_r - avg_p) / avg_p) * 100, 1)

    # Simple insight text (not LLM — just template-based for now)
    trend_word = "stable"
    if delta is not None:
        if delta > 5:
            trend_word = "trending upward"
        elif delta < -5:
            trend_word = "trending downward"

    ai_insight = (
        f"Your {display_name} is {trend_word} over the selected period. "
        f"Current: {current_str} {unit}. "
        f"Average: {avg:.1f} {unit}."
    )

    return MetricDetailResponse(
        series=MetricSeriesItem(
            metric_id=metric_id,
            display_name=display_name,
            unit=unit,
            data_points=pts,
            source_integration=source,
            current_value=current_str,
            delta_percent=delta,
            average=avg,
        ),
        category=category,
        ai_insight=ai_insight,
    )
