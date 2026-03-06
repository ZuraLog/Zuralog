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
from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.analytics.analytics_service import AnalyticsService
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
from app.api.v1.deps import get_authenticated_user_id
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
    request: Request,
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
    request: Request,
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
    request: Request,
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
    request: Request,
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
    request: Request,
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
    request: Request,
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


@router.get("/dashboard-insight", response_model=DashboardInsightResponse)
@cached(prefix="analytics.dashboard_insight", ttl=300, key_params=["user_id"])
async def dashboard_insight(
    request: Request,
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


@router.get("/dashboard-summary", response_model=DashboardSummaryResponse)
async def dashboard_summary(
    request: Request,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> DashboardSummaryResponse:
    """Return aggregated dashboard data for the Data tab Health Dashboard.

    Queries the last 14 days of health data across all category tables
    and returns category summaries with sparkline trends and deltas.

    Args:
        request: Incoming FastAPI request.
        user_id: Authenticated user ID from JWT.
        db: Async database session.

    Returns:
        DashboardSummaryResponse with category summaries and visible order.
    """
    from datetime import timedelta
    from sqlalchemy import text as sql_text

    today = date.today()
    day14_ago = today - timedelta(days=14)
    day7_ago = today - timedelta(days=7)

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
        h = int(v)
        m = round((v - h) * 60)
        return f"{h}h {m:02d}m"

    categories: list[CategorySummaryItem] = []
    visible_order: list[str] = []

    # ── Activity ──────────────────────────────────────────────────────────────
    result = await db.execute(
        sql_text(
            "SELECT date, steps FROM daily_health_metrics "
            "WHERE user_id = :uid AND date >= :d14 AND steps IS NOT NULL "
            "ORDER BY date"
        ),
        {"uid": user_id, "d14": day14_ago.isoformat()},
    )
    rows = [(r[0], float(r[1])) for r in result.fetchall()]
    recent_rows = [(d, v) for d, v in rows if d >= day7_ago.isoformat()]
    prior_rows = [(d, v) for d, v in rows if d < day7_ago.isoformat()]
    if recent_rows:
        primary = recent_rows[-1][1]
        categories.append(CategorySummaryItem(
            category="activity",
            primary_value=_fmt_steps(primary),
            unit="steps",
            delta_percent=_delta([v for _, v in recent_rows], [v for _, v in prior_rows]),
            trend=_trend(recent_rows),
            last_updated=recent_rows[-1][0],
            has_data=True,
        ))
        visible_order.append("activity")
    else:
        categories.append(CategorySummaryItem(category="activity", has_data=False))

    # ── Sleep ─────────────────────────────────────────────────────────────────
    result = await db.execute(
        sql_text(
            "SELECT date, hours FROM sleep_records "
            "WHERE user_id = :uid AND date >= :d14 AND hours IS NOT NULL "
            "ORDER BY date"
        ),
        {"uid": user_id, "d14": day14_ago.isoformat()},
    )
    rows = [(r[0], float(r[1])) for r in result.fetchall()]
    recent_rows = [(d, v) for d, v in rows if d >= day7_ago.isoformat()]
    prior_rows = [(d, v) for d, v in rows if d < day7_ago.isoformat()]
    if recent_rows:
        primary = recent_rows[-1][1]
        categories.append(CategorySummaryItem(
            category="sleep",
            primary_value=_fmt_hours(primary),
            unit=None,
            delta_percent=_delta([v for _, v in recent_rows], [v for _, v in prior_rows]),
            trend=_trend(recent_rows),
            last_updated=recent_rows[-1][0],
            has_data=True,
        ))
        visible_order.append("sleep")
    else:
        categories.append(CategorySummaryItem(category="sleep", has_data=False))

    # ── Heart ─────────────────────────────────────────────────────────────────
    result = await db.execute(
        sql_text(
            "SELECT date, resting_heart_rate FROM daily_health_metrics "
            "WHERE user_id = :uid AND date >= :d14 AND resting_heart_rate IS NOT NULL "
            "ORDER BY date"
        ),
        {"uid": user_id, "d14": day14_ago.isoformat()},
    )
    rows = [(r[0], float(r[1])) for r in result.fetchall()]
    recent_rows = [(d, v) for d, v in rows if d >= day7_ago.isoformat()]
    prior_rows = [(d, v) for d, v in rows if d < day7_ago.isoformat()]
    if recent_rows:
        primary = recent_rows[-1][1]
        categories.append(CategorySummaryItem(
            category="heart",
            primary_value=str(int(primary)),
            unit="bpm RHR",
            delta_percent=_delta([v for _, v in recent_rows], [v for _, v in prior_rows]),
            trend=_trend(recent_rows),
            last_updated=recent_rows[-1][0],
            has_data=True,
        ))
        visible_order.append("heart")
    else:
        categories.append(CategorySummaryItem(category="heart", has_data=False))

    # ── Body (Weight) ─────────────────────────────────────────────────────────
    result = await db.execute(
        sql_text(
            "SELECT date, weight_kg FROM weight_measurements "
            "WHERE user_id = :uid AND date >= :d14 AND weight_kg IS NOT NULL "
            "ORDER BY date"
        ),
        {"uid": user_id, "d14": day14_ago.isoformat()},
    )
    rows = [(r[0], float(r[1])) for r in result.fetchall()]
    recent_rows = [(d, v) for d, v in rows if d >= day7_ago.isoformat()]
    prior_rows = [(d, v) for d, v in rows if d < day7_ago.isoformat()]
    if recent_rows:
        primary = recent_rows[-1][1]
        categories.append(CategorySummaryItem(
            category="body",
            primary_value=f"{primary:.1f}",
            unit="kg",
            delta_percent=_delta([v for _, v in recent_rows], [v for _, v in prior_rows]),
            trend=_trend(recent_rows),
            last_updated=recent_rows[-1][0],
            has_data=True,
        ))
        visible_order.append("body")
    else:
        categories.append(CategorySummaryItem(category="body", has_data=False))

    # ── Vitals (SpO2) ─────────────────────────────────────────────────────────
    result = await db.execute(
        sql_text(
            "SELECT date, oxygen_saturation FROM daily_health_metrics "
            "WHERE user_id = :uid AND date >= :d14 AND oxygen_saturation IS NOT NULL "
            "ORDER BY date"
        ),
        {"uid": user_id, "d14": day14_ago.isoformat()},
    )
    rows = [(r[0], float(r[1])) for r in result.fetchall()]
    recent_rows = [(d, v) for d, v in rows if d >= day7_ago.isoformat()]
    prior_rows = [(d, v) for d, v in rows if d < day7_ago.isoformat()]
    if recent_rows:
        primary = recent_rows[-1][1]
        categories.append(CategorySummaryItem(
            category="vitals",
            primary_value=f"{primary:.0f}%",
            unit="SpO₂",
            delta_percent=_delta([v for _, v in recent_rows], [v for _, v in prior_rows]),
            trend=_trend(recent_rows),
            last_updated=recent_rows[-1][0],
            has_data=True,
        ))
        visible_order.append("vitals")
    else:
        categories.append(CategorySummaryItem(category="vitals", has_data=False))

    # ── Nutrition ─────────────────────────────────────────────────────────────
    result = await db.execute(
        sql_text(
            "SELECT date, calories FROM nutrition_entries "
            "WHERE user_id = :uid AND date >= :d14 AND calories IS NOT NULL "
            "ORDER BY date"
        ),
        {"uid": user_id, "d14": day14_ago.isoformat()},
    )
    rows = [(r[0], float(r[1])) for r in result.fetchall()]
    recent_rows = [(d, v) for d, v in rows if d >= day7_ago.isoformat()]
    prior_rows = [(d, v) for d, v in rows if d < day7_ago.isoformat()]
    if recent_rows:
        primary = recent_rows[-1][1]
        categories.append(CategorySummaryItem(
            category="nutrition",
            primary_value=f"{int(primary):,}",
            unit="kcal",
            delta_percent=_delta([v for _, v in recent_rows], [v for _, v in prior_rows]),
            trend=_trend(recent_rows),
            last_updated=recent_rows[-1][0],
            has_data=True,
        ))
        visible_order.append("nutrition")
    else:
        categories.append(CategorySummaryItem(category="nutrition", has_data=False))

    # ── Wellness (HRV) ────────────────────────────────────────────────────────
    result = await db.execute(
        sql_text(
            "SELECT date, hrv_ms FROM daily_health_metrics "
            "WHERE user_id = :uid AND date >= :d14 AND hrv_ms IS NOT NULL "
            "ORDER BY date"
        ),
        {"uid": user_id, "d14": day14_ago.isoformat()},
    )
    rows = [(r[0], float(r[1])) for r in result.fetchall()]
    recent_rows = [(d, v) for d, v in rows if d >= day7_ago.isoformat()]
    prior_rows = [(d, v) for d, v in rows if d < day7_ago.isoformat()]
    if recent_rows:
        primary = recent_rows[-1][1]
        categories.append(CategorySummaryItem(
            category="wellness",
            primary_value=f"{primary:.0f}",
            unit="ms HRV",
            delta_percent=_delta([v for _, v in recent_rows], [v for _, v in prior_rows]),
            trend=_trend(recent_rows),
            last_updated=recent_rows[-1][0],
            has_data=True,
        ))
        visible_order.append("wellness")
    else:
        categories.append(CategorySummaryItem(category="wellness", has_data=False))

    # ── Mobility (flights climbed) ────────────────────────────────────────────
    result = await db.execute(
        sql_text(
            "SELECT date, flights_climbed FROM daily_health_metrics "
            "WHERE user_id = :uid AND date >= :d14 AND flights_climbed IS NOT NULL "
            "ORDER BY date"
        ),
        {"uid": user_id, "d14": day14_ago.isoformat()},
    )
    rows = [(r[0], float(r[1])) for r in result.fetchall()]
    recent_rows = [(d, v) for d, v in rows if d >= day7_ago.isoformat()]
    prior_rows = [(d, v) for d, v in rows if d < day7_ago.isoformat()]
    if recent_rows:
        primary = recent_rows[-1][1]
        categories.append(CategorySummaryItem(
            category="mobility",
            primary_value=str(int(primary)),
            unit="flights",
            delta_percent=_delta([v for _, v in recent_rows], [v for _, v in prior_rows]),
            trend=_trend(recent_rows),
            last_updated=recent_rows[-1][0],
            has_data=True,
        ))
        visible_order.append("mobility")
    else:
        categories.append(CategorySummaryItem(category="mobility", has_data=False))

    # ── Cycle & Environment — no data tables yet ──────────────────────────────
    categories.append(CategorySummaryItem(category="cycle", has_data=False))
    categories.append(CategorySummaryItem(category="environment", has_data=False))

    return DashboardSummaryResponse(categories=categories, visible_order=visible_order)


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
    from datetime import timedelta
    from sqlalchemy import text as sql_text

    days_map = {"7D": 7, "30D": 30, "90D": 90}
    days = days_map.get(time_range.upper(), 7)
    since = (date.today() - timedelta(days=days)).isoformat()

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
        recent = values[-min(7, len(values)):]
        prior = values[-min(14, len(values)):-min(7, len(values))]
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

    if category == "activity":
        for col, mid, dn, unit in [
            ("steps", "steps", "Steps", "steps"),
            ("active_calories", "active_calories", "Active Calories", "kcal"),
            ("distance_meters", "distance", "Distance", "m"),
        ]:
            result = await db.execute(
                sql_text(f"SELECT date, {col} FROM daily_health_metrics "
                         "WHERE user_id = :uid AND date >= :since AND "
                         f"{col} IS NOT NULL ORDER BY date"),
                {"uid": user_id, "since": since},
            )
            rows = [(r[0], float(r[1])) for r in result.fetchall()]
            if rows:
                metrics.append(_make_series(mid, dn, unit, rows))

    elif category == "sleep":
        result = await db.execute(
            sql_text("SELECT date, hours FROM sleep_records "
                     "WHERE user_id = :uid AND date >= :since AND hours IS NOT NULL ORDER BY date"),
            {"uid": user_id, "since": since},
        )
        rows = [(r[0], float(r[1])) for r in result.fetchall()]
        if rows:
            metrics.append(_make_series("sleep_duration", "Sleep Duration", "hours", rows))
        result = await db.execute(
            sql_text("SELECT date, quality_score FROM sleep_records "
                     "WHERE user_id = :uid AND date >= :since AND quality_score IS NOT NULL ORDER BY date"),
            {"uid": user_id, "since": since},
        )
        rows = [(r[0], float(r[1])) for r in result.fetchall()]
        if rows:
            metrics.append(_make_series("sleep_quality", "Sleep Quality", "score", rows))

    elif category == "heart":
        for col, mid, dn, unit in [
            ("resting_heart_rate", "heart_rate_resting", "Resting Heart Rate", "bpm"),
            ("hrv_ms", "hrv", "Heart Rate Variability", "ms"),
            ("heart_rate_avg", "heart_rate_avg", "Avg Heart Rate", "bpm"),
        ]:
            result = await db.execute(
                sql_text(f"SELECT date, {col} FROM daily_health_metrics "
                         "WHERE user_id = :uid AND date >= :since AND "
                         f"{col} IS NOT NULL ORDER BY date"),
                {"uid": user_id, "since": since},
            )
            rows = [(r[0], float(r[1])) for r in result.fetchall()]
            if rows:
                metrics.append(_make_series(mid, dn, unit, rows))

    elif category == "body":
        result = await db.execute(
            sql_text("SELECT date, weight_kg FROM weight_measurements "
                     "WHERE user_id = :uid AND date >= :since AND weight_kg IS NOT NULL ORDER BY date"),
            {"uid": user_id, "since": since},
        )
        rows = [(r[0], float(r[1])) for r in result.fetchall()]
        if rows:
            metrics.append(_make_series("weight", "Weight", "kg", rows))
        result = await db.execute(
            sql_text("SELECT date, body_fat_percentage FROM daily_health_metrics "
                     "WHERE user_id = :uid AND date >= :since AND body_fat_percentage IS NOT NULL ORDER BY date"),
            {"uid": user_id, "since": since},
        )
        rows = [(r[0], float(r[1])) for r in result.fetchall()]
        if rows:
            metrics.append(_make_series("body_fat", "Body Fat", "%", rows))

    elif category == "vitals":
        for col, mid, dn, unit in [
            ("oxygen_saturation", "spo2", "Blood Oxygen", "%"),
            ("respiratory_rate", "respiratory_rate", "Respiratory Rate", "brpm"),
        ]:
            result = await db.execute(
                sql_text(f"SELECT date, {col} FROM daily_health_metrics "
                         "WHERE user_id = :uid AND date >= :since AND "
                         f"{col} IS NOT NULL ORDER BY date"),
                {"uid": user_id, "since": since},
            )
            rows = [(r[0], float(r[1])) for r in result.fetchall()]
            if rows:
                metrics.append(_make_series(mid, dn, unit, rows))

    elif category == "nutrition":
        for col, mid, dn, unit in [
            ("calories", "calories", "Calories", "kcal"),
            ("protein_grams", "protein", "Protein", "g"),
            ("carbs_grams", "carbs", "Carbohydrates", "g"),
            ("fat_grams", "fat", "Fat", "g"),
        ]:
            result = await db.execute(
                sql_text(f"SELECT date, {col} FROM nutrition_entries "
                         "WHERE user_id = :uid AND date >= :since AND "
                         f"{col} IS NOT NULL ORDER BY date"),
                {"uid": user_id, "since": since},
            )
            rows = [(r[0], float(r[1])) for r in result.fetchall()]
            if rows:
                metrics.append(_make_series(mid, dn, unit, rows))

    elif category == "wellness":
        for col, mid, dn, unit in [
            ("hrv_ms", "hrv", "HRV", "ms"),
            ("vo2_max", "vo2max", "VO₂ Max", "ml/kg/min"),
        ]:
            result = await db.execute(
                sql_text(f"SELECT date, {col} FROM daily_health_metrics "
                         "WHERE user_id = :uid AND date >= :since AND "
                         f"{col} IS NOT NULL ORDER BY date"),
                {"uid": user_id, "since": since},
            )
            rows = [(r[0], float(r[1])) for r in result.fetchall()]
            if rows:
                metrics.append(_make_series(mid, dn, unit, rows))

    elif category == "mobility":
        result = await db.execute(
            sql_text("SELECT date, flights_climbed FROM daily_health_metrics "
                     "WHERE user_id = :uid AND date >= :since AND flights_climbed IS NOT NULL ORDER BY date"),
            {"uid": user_id, "since": since},
        )
        rows = [(r[0], float(r[1])) for r in result.fetchall()]
        if rows:
            metrics.append(_make_series("flights_climbed", "Flights Climbed", "flights", rows))

    elif category in ("cycle", "environment"):
        # No data tables yet — return empty
        pass

    else:
        raise HTTPException(status_code=400, detail=f"Unknown category: {category}")

    return CategoryDetailResponse(
        category=category,
        metrics=metrics,
        time_range=time_range.upper(),
    )


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

    days_map = {"7D": 7, "30D": 30, "90D": 90}
    days = days_map.get(time_range.upper(), 7)
    since = (date.today() - timedelta(days=days)).isoformat()

    # Map metric_id → (table, column, display_name, unit, source, category)
    METRIC_MAP: dict[str, tuple[str, str, str, str, str, str]] = {
        "steps":              ("daily_health_metrics", "steps", "Steps", "steps", "apple_health", "activity"),
        "active_calories":    ("daily_health_metrics", "active_calories", "Active Calories", "kcal", "apple_health", "activity"),
        "distance":           ("daily_health_metrics", "distance_meters", "Distance", "m", "apple_health", "activity"),
        "sleep_duration":     ("sleep_records", "hours", "Sleep Duration", "hours", "apple_health", "sleep"),
        "sleep_quality":      ("sleep_records", "quality_score", "Sleep Quality", "score", "apple_health", "sleep"),
        "heart_rate_resting": ("daily_health_metrics", "resting_heart_rate", "Resting Heart Rate", "bpm", "apple_health", "heart"),
        "hrv":                ("daily_health_metrics", "hrv_ms", "Heart Rate Variability", "ms", "apple_health", "heart"),
        "heart_rate_avg":     ("daily_health_metrics", "heart_rate_avg", "Avg Heart Rate", "bpm", "apple_health", "heart"),
        "weight":             ("weight_measurements", "weight_kg", "Weight", "kg", "apple_health", "body"),
        "body_fat":           ("daily_health_metrics", "body_fat_percentage", "Body Fat", "%", "apple_health", "body"),
        "spo2":               ("daily_health_metrics", "oxygen_saturation", "Blood Oxygen", "%", "apple_health", "vitals"),
        "respiratory_rate":   ("daily_health_metrics", "respiratory_rate", "Respiratory Rate", "brpm", "apple_health", "vitals"),
        "calories":           ("nutrition_entries", "calories", "Calories", "kcal", "apple_health", "nutrition"),
        "protein":            ("nutrition_entries", "protein_grams", "Protein", "g", "apple_health", "nutrition"),
        "carbs":              ("nutrition_entries", "carbs_grams", "Carbohydrates", "g", "apple_health", "nutrition"),
        "fat":                ("nutrition_entries", "fat_grams", "Fat", "g", "apple_health", "nutrition"),
        "vo2max":             ("daily_health_metrics", "vo2_max", "VO₂ Max", "ml/kg/min", "apple_health", "wellness"),
        "flights_climbed":    ("daily_health_metrics", "flights_climbed", "Flights Climbed", "flights", "apple_health", "mobility"),
    }

    if metric_id not in METRIC_MAP:
        raise HTTPException(status_code=404, detail=f"Unknown metric: {metric_id}")

    table, col, display_name, unit, source, category = METRIC_MAP[metric_id]

    result = await db.execute(
        sql_text(
            f"SELECT date, {col} FROM {table} "
            "WHERE user_id = :uid AND date >= :since AND "
            f"{col} IS NOT NULL ORDER BY date"
        ),
        {"uid": user_id, "since": since},
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

    recent = values[-min(7, len(values)):]
    prior = values[-min(14, len(values)):-min(7, len(values))]
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
