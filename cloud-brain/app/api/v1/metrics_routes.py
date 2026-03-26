"""Metrics endpoints -- cross-date aggregations."""
import logging
from datetime import date

from fastapi import APIRouter, Depends, Query, Request
from pydantic import BaseModel
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_authenticated_user_id
from app.database import get_db
from app.limiter import limiter
from app.models.daily_summary import DailySummary

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/metrics", tags=["metrics"])


class LatestMetricItem(BaseModel):
    metric_type: str
    value: float
    unit: str
    date: str  # ISO date string (YYYY-MM-DD)


class LatestMetricsResponse(BaseModel):
    metrics: list[LatestMetricItem]


@limiter.limit("120/minute")
@router.get("/latest", response_model=LatestMetricsResponse)
async def metrics_latest(
    request: Request,
    types: str = Query(
        ...,
        description="Comma-separated metric type keys, e.g. weight_kg,steps,sleep_duration",
        min_length=1,
        max_length=500,
    ),
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(get_authenticated_user_id),
) -> LatestMetricsResponse:
    """Return the most recent non-stale daily summary row per requested metric type."""
    requested = [t.strip() for t in types.split(",") if t.strip()]
    if not requested:
        return LatestMetricsResponse(metrics=[])

    # Cap at 20 metric types to prevent abuse.
    requested = requested[:20]

    # Subquery: max date per metric type for this user (non-stale only).
    max_date_sq = (
        select(
            DailySummary.metric_type,
            func.max(DailySummary.date).label("max_date"),
        )
        .where(
            DailySummary.user_id == user_id,
            DailySummary.metric_type.in_(requested),
            DailySummary.is_stale.is_(False),
        )
        .group_by(DailySummary.metric_type)
        .subquery()
    )

    # Main query: join back to get the full row for each (metric_type, max_date).
    query = select(
        DailySummary.metric_type,
        DailySummary.value,
        DailySummary.unit,
        DailySummary.date,
    ).join(
        max_date_sq,
        (DailySummary.metric_type == max_date_sq.c.metric_type)
        & (DailySummary.date == max_date_sq.c.max_date),
    ).where(
        DailySummary.user_id == user_id,
        DailySummary.is_stale.is_(False),
    )

    rows = await db.execute(query)
    metrics = [
        LatestMetricItem(
            metric_type=r.metric_type, value=r.value,
            unit=r.unit, date=str(r.date),
        )
        for r in rows.fetchall()
    ]
    logger.info("[metrics_latest] user=%s requested=%s returned=%d",
        user_id[:8], requested, len(metrics))
    return LatestMetricsResponse(metrics=metrics)
