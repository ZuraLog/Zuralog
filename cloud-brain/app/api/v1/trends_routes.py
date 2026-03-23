"""
Zuralog Cloud Brain — Trends API Router.

Provides the aggregated Trends Home endpoint consumed by the Flutter
Trends tab (Tab 4). Returns AI-surfaced correlation highlights and
time-machine period summaries.

Currently returns empty scaffolds so the client renders its designed
empty/onboarding state. Full computation will be wired in a future phase.
"""

import sentry_sdk
from fastapi import APIRouter, Depends, Query, Request
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_authenticated_user_id
from app.database import get_db
from app.limiter import limiter


async def _set_sentry_module() -> None:
    """Tag the current Sentry scope with the trends module name."""
    sentry_sdk.set_tag("api.module", "trends")


router = APIRouter(
    prefix="/trends",
    tags=["trends"],
    dependencies=[Depends(_set_sentry_module)],
)


@limiter.limit("60/minute")
@router.get("/home")
async def trends_home(
    request: Request,
    user_id: str = Depends(get_authenticated_user_id),
) -> dict:
    """Return aggregated Trends Home data.

    Returns correlation highlights and time-machine period summaries.
    Currently returns empty data with ``has_enough_data`` set to false
    so the Flutter client shows its designed onboarding state.

    Args:
        user_id: Authenticated user ID from JWT.

    Returns:
        dict matching the TrendsHomeData model shape.
    """
    return {
        "correlation_highlights": [],
        "time_periods": [],
        "has_enough_data": False,
    }


@limiter.limit("60/minute")
@router.get("/metrics")
async def trends_metrics(
    request: Request,
    user_id: str = Depends(get_authenticated_user_id),
) -> dict:
    """Return available metrics for the correlation explorer picker.

    Currently returns an empty list. Full metric discovery (driven by
    which data sources the user has connected) will be wired in a
    future phase.

    Args:
        user_id: Authenticated user ID from JWT.

    Returns:
        dict matching the AvailableMetricList model shape.
    """
    return {"metrics": []}


@limiter.limit("30/minute")
@router.get("/correlations")
async def trends_correlations(
    request: Request,
    metric_a: str,
    metric_b: str,
    lag_days: int = 0,
    time_range: str = "30d",
    custom_start: str | None = None,
    custom_end: str | None = None,
    user_id: str = Depends(get_authenticated_user_id),
) -> dict:
    """Run a correlation analysis between two metrics.

    Currently returns an empty scaffold. Full computation (Pearson
    coefficient, scatter data, AI annotation) will be wired in a
    future phase.

    Args:
        metric_a: ID of the first metric.
        metric_b: ID of the second metric.
        lag_days: Offset in days to apply to metric_b (0–3).
        time_range: Time window string (e.g. ``"30d"``, ``"90d"``).
        custom_start: ISO-8601 start date when ``time_range`` is ``"custom"``.
        custom_end: ISO-8601 end date when ``time_range`` is ``"custom"``.
        user_id: Authenticated user ID from JWT.

    Returns:
        dict matching the CorrelationAnalysis model shape.
    """
    return {
        "metric_a_id": metric_a,
        "metric_b_id": metric_b,
        "lag_days": lag_days,
        "coefficient": None,
        "p_value": None,
        "interpretation": "not_enough_data",
        "ai_annotation": "Not enough data yet to compute a correlation. Keep syncing your devices.",
        "scatter_data": [],
        "sample_size": 0,
    }


@limiter.limit("30/minute")
@router.get("/correlation")
async def trends_correlation(
    request: Request,
    metric_a: str = Query(...),
    metric_b: str = Query(...),
    days: int = Query(default=90, ge=7, le=365),
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(get_authenticated_user_id),
) -> dict:
    """Correlation between two metrics over a time range."""
    from datetime import timedelta
    import zoneinfo
    from datetime import datetime, timezone as tz

    row = await db.execute(
        text("SELECT timezone FROM user_preferences WHERE user_id = :uid"),
        {"uid": str(user_id)},
    )
    iana_tz = row.scalar_one_or_none() or "UTC"
    try:
        user_tz = zoneinfo.ZoneInfo(iana_tz)
    except Exception:
        user_tz = zoneinfo.ZoneInfo("UTC")
    local_date = datetime.now(tz=user_tz).date()
    start_date = local_date - timedelta(days=days)

    rows = await db.execute(
        text("""
            SELECT a.date, a.value AS metric_a_value, b.value AS metric_b_value
            FROM daily_summaries a
            JOIN daily_summaries b ON a.user_id = b.user_id AND a.date = b.date
            WHERE a.user_id = :uid
              AND a.metric_type = :ma
              AND b.metric_type = :mb
              AND a.date >= :start
            ORDER BY a.date
        """),
        {"uid": str(user_id), "ma": metric_a, "mb": metric_b, "start": start_date},
    )
    data_points = [
        {"date": str(r.date), metric_a: r.metric_a_value, metric_b: r.metric_b_value}
        for r in rows.fetchall()
    ]

    correlation = None
    if len(data_points) >= 3:
        import statistics

        xs = [p[metric_a] for p in data_points]
        ys = [p[metric_b] for p in data_points]
        try:
            correlation = round(statistics.correlation(xs, ys), 3)
        except statistics.StatisticsError:
            correlation = None

    return {"data_points": data_points, "correlation": correlation, "metric_a": metric_a, "metric_b": metric_b}
