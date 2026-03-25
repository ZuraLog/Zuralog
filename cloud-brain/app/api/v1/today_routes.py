"""Today tab endpoints."""
from datetime import date, datetime
import logging
import uuid as uuid_mod

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from pydantic import BaseModel
import sqlalchemy as sa
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_authenticated_user_id
from app.database import get_db
from app.limiter import limiter
from app.models.daily_summary import DailySummary
from app.models.health_event import HealthEvent
from app.utils.user_date import get_user_local_date

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/today", tags=["today"])


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
    local_date = await get_user_local_date(db, user_id)
    rows = await db.execute(
        select(DailySummary.metric_type, DailySummary.value, DailySummary.unit).where(
            DailySummary.user_id == user_id,
            DailySummary.date == local_date,
            DailySummary.is_stale.is_(False),
        )
    )
    metrics = [
        TodayMetric(metric_type=r.metric_type, value=r.value, unit=r.unit)
        for r in rows.fetchall()
    ]
    logger.info(
        "[today_summary] user=%s date=%s metrics=%s",
        user_id[:8], local_date,
        [(m.metric_type, type(m.value).__name__, m.value) for m in metrics],
    )
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
    local_date = await get_user_local_date(db, user_id)

    query = (
        select(HealthEvent)
        .where(
            HealthEvent.user_id == user_id,
            HealthEvent.local_date == local_date,
            HealthEvent.deleted_at.is_(None),
        )
        .order_by(HealthEvent.recorded_at.desc(), HealthEvent.id.desc())
        .limit(limit + 1)
    )
    if before:
        try:
            # Composite cursor: "ISO_TIMESTAMP_UUID"
            cursor_parts = before.rsplit("_", 1)
            cursor_time = datetime.fromisoformat(cursor_parts[0])
            cursor_id = uuid_mod.UUID(cursor_parts[1])
        except (ValueError, IndexError):
            raise HTTPException(status_code=422, detail="Invalid cursor format")
        query = query.where(
            sa.or_(
                HealthEvent.recorded_at < cursor_time,
                sa.and_(
                    HealthEvent.recorded_at == cursor_time,
                    HealthEvent.id < cursor_id,
                ),
            )
        )

    rows = await db.execute(query)
    events = rows.scalars().all()

    next_cursor = None
    if len(events) > limit:
        events = events[:limit]
        next_cursor = f"{events[-1].recorded_at.isoformat()}_{events[-1].id}"

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
    local_date = await get_user_local_date(db, user_id)
    rows = await db.execute(
        text("""
            SELECT ds.metric_type, ds.value AS current_value, ug.target_value, ds.unit,
                   ROUND(CAST(ds.value / NULLIF(ug.target_value, 0) * 100 AS numeric), 1) AS percentage
            FROM daily_summaries ds
            JOIN user_goals ug ON ds.user_id = ug.user_id AND ds.metric_type = ug.metric
            WHERE ds.user_id = :uid AND ds.date = :d
        """),
        {"uid": str(user_id), "d": local_date},
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
