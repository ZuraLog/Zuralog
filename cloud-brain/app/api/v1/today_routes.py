"""Today tab endpoints."""
from datetime import date
import uuid
import logging

from fastapi import APIRouter, Depends, Query, Request
from pydantic import BaseModel
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_authenticated_user_id
from app.database import get_db
from app.limiter import limiter
from app.models.daily_summary import DailySummary
from app.models.health_event import HealthEvent

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/today", tags=["today"])


async def _get_user_local_date(db: AsyncSession, user_id: str) -> date:
    """Return the user's current local date based on their IANA timezone preference."""
    import zoneinfo
    from datetime import datetime, timezone as tz

    row = await db.execute(
        text("SELECT timezone FROM user_preferences WHERE user_id = :uid"),
        {"uid": user_id}
    )
    iana_tz = (row.scalar_one_or_none() or "UTC")
    try:
        user_tz = zoneinfo.ZoneInfo(iana_tz)
    except Exception:
        user_tz = zoneinfo.ZoneInfo("UTC")
    return datetime.now(tz=user_tz).date()


class TodayMetric(BaseModel):
    metric_type: str
    value: float
    unit: str


class TodaySummaryResponse(BaseModel):
    date: str
    metrics: list[TodayMetric]


class TodayEventItem(BaseModel):
    event_id: str
    metric_type: str
    value: float
    unit: str
    source: str
    recorded_at: str


class TodayTimelineResponse(BaseModel):
    events: list[TodayEventItem]
    next_cursor: str | None


class GoalProgressItem(BaseModel):
    metric_type: str
    current_value: float
    target_value: float
    unit: str
    percentage: float


@limiter.limit("120/minute")
@router.get("/summary", response_model=TodaySummaryResponse)
async def today_summary(
    request: Request,
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(get_authenticated_user_id),
) -> TodaySummaryResponse:
    local_date = await _get_user_local_date(db, user_id)
    rows = await db.execute(
        select(DailySummary.metric_type, DailySummary.value, DailySummary.unit).where(
            DailySummary.user_id == uuid.UUID(str(user_id)),
            DailySummary.date == local_date,
        )
    )
    metrics = [
        TodayMetric(metric_type=r.metric_type, value=r.value, unit=r.unit)
        for r in rows.fetchall()
    ]
    return TodaySummaryResponse(date=str(local_date), metrics=metrics)


@limiter.limit("120/minute")
@router.get("/timeline", response_model=TodayTimelineResponse)
async def today_timeline(
    request: Request,
    limit: int = Query(default=50, ge=1, le=200),
    before: str | None = Query(default=None),
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(get_authenticated_user_id),
) -> TodayTimelineResponse:
    local_date = await _get_user_local_date(db, user_id)

    query = (
        select(HealthEvent)
        .where(
            HealthEvent.user_id == uuid.UUID(str(user_id)),
            HealthEvent.local_date == local_date,
            HealthEvent.deleted_at.is_(None),
        )
        .order_by(HealthEvent.recorded_at.desc())
        .limit(limit + 1)
    )
    if before:
        query = query.where(HealthEvent.id < uuid.UUID(before))

    rows = await db.execute(query)
    events = rows.scalars().all()

    next_cursor = None
    if len(events) > limit:
        events = events[:limit]
        next_cursor = str(events[-1].id)

    return TodayTimelineResponse(
        events=[
            TodayEventItem(
                event_id=str(e.id),
                metric_type=e.metric_type,
                value=e.value,
                unit=e.unit,
                source=e.source,
                recorded_at=e.recorded_at.isoformat(),
            )
            for e in events
        ],
        next_cursor=next_cursor,
    )


@limiter.limit("60/minute")
@router.get("/goals-progress", response_model=list[GoalProgressItem])
async def today_goals_progress(
    request: Request,
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(get_authenticated_user_id),
) -> list[GoalProgressItem]:
    local_date = await _get_user_local_date(db, user_id)
    rows = await db.execute(
        text("""
            SELECT ds.metric_type, ds.value AS current_value, ug.target_value, ds.unit,
                   ROUND(CAST(ds.value / NULLIF(ug.target_value, 0) * 100 AS numeric), 1) AS percentage
            FROM daily_summaries ds
            JOIN user_goals ug ON ds.user_id = ug.user_id AND ds.metric_type = ug.metric_type
            WHERE ds.user_id = :uid AND ds.date = :d
        """),
        {"uid": str(user_id), "d": str(local_date)},
    )
    return [
        GoalProgressItem(
            metric_type=r.metric_type,
            current_value=r.current_value,
            target_value=r.target_value,
            unit=r.unit,
            percentage=float(r.percentage or 0),
        )
        for r in rows.fetchall()
    ]
