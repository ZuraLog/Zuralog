"""Coach context endpoints — provides AI coach with structured health context."""
import logging
from datetime import timedelta

from fastapi import APIRouter, Depends, Query, Request
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_authenticated_user_id
from app.database import get_db
from app.limiter import limiter
from app.models.daily_summary import DailySummary
from app.models.health_event import HealthEvent
from app.utils.user_date import get_user_local_date

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/coach", tags=["coach"])


@limiter.limit("30/minute")
@router.get("/context")
async def coach_context(
    request: Request,
    days: int = Query(default=30, ge=1, le=90),
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(get_authenticated_user_id),
) -> dict:
    """Structured health context for AI coach — daily summaries, recent events, sessions."""
    local_date = await get_user_local_date(db, user_id)
    start_date = local_date - timedelta(days=days)

    # Daily summaries for the past N days
    summary_rows = await db.execute(
        select(DailySummary.date, DailySummary.metric_type, DailySummary.value, DailySummary.unit)
        .where(
            DailySummary.user_id == user_id,
            DailySummary.date >= start_date,
        )
        .order_by(DailySummary.date.desc())
    )
    daily_summaries = [
        {"date": str(r.date), "metric_type": r.metric_type, "value": r.value, "unit": r.unit}
        for r in summary_rows.fetchall()
    ]

    # Recent events (last 200)
    event_rows = await db.execute(
        select(HealthEvent)
        .where(
            HealthEvent.user_id == user_id,
            HealthEvent.local_date >= start_date,
            HealthEvent.deleted_at.is_(None),
        )
        .order_by(HealthEvent.recorded_at.desc())
        .limit(200)
    )
    recent_events = [
        {
            "event_id": str(e.id),
            "metric_type": e.metric_type,
            "value": e.value,
            "unit": e.unit,
            "source": e.source,
            "recorded_at": e.recorded_at.isoformat(),
        }
        for e in event_rows.scalars().all()
    ]

    # Activity sessions
    from app.models.activity_session import ActivitySession

    session_rows = await db.execute(
        select(ActivitySession)
        .where(
            ActivitySession.user_id == user_id,
            ActivitySession.started_at >= start_date,
        )
        .order_by(ActivitySession.started_at.desc())
        .limit(50)
    )
    sessions = [
        {
            "session_id": str(s.id),
            "activity_type": s.activity_type,
            "source": s.source,
            "started_at": s.started_at.isoformat(),
            "ended_at": s.ended_at.isoformat() if s.ended_at else None,
        }
        for s in session_rows.scalars().all()
    ]

    return {"daily_summaries": daily_summaries, "recent_events": recent_events, "sessions": sessions}


@limiter.limit("60/minute")
@router.get("/events")
async def coach_events(
    request: Request,
    metric_type: str = Query(...),
    days: int = Query(default=30, ge=1, le=365),
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(get_authenticated_user_id),
) -> dict:
    """Filtered health events for a specific metric."""
    local_date = await get_user_local_date(db, user_id)
    start_date = local_date - timedelta(days=days)

    rows = await db.execute(
        select(HealthEvent)
        .where(
            HealthEvent.user_id == user_id,
            HealthEvent.metric_type == metric_type,
            HealthEvent.local_date >= start_date,
            HealthEvent.deleted_at.is_(None),
        )
        .order_by(HealthEvent.recorded_at.desc())
        .limit(500)
    )
    events = [
        {
            "event_id": str(e.id),
            "value": e.value,
            "unit": e.unit,
            "recorded_at": e.recorded_at.isoformat(),
            "source": e.source,
        }
        for e in rows.scalars().all()
    ]
    return {"metric_type": metric_type, "events": events}
