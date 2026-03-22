"""Unified health data ingest endpoints.

POST /api/v1/ingest            — single manual event
POST /api/v1/ingest/session    — session with multiple linked events
POST /api/v1/ingest/bulk       — bulk device sync (async aggregation)
DELETE /api/v1/events/{id}     — soft-delete a manual event (user correction)
GET /api/v1/ingest/status/{id} — bulk sync status poll
"""
from __future__ import annotations

import uuid
import logging
from datetime import date, datetime, timezone
from typing import Any

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Request
from pydantic import BaseModel, field_validator
from sqlalchemy import select, text
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_authenticated_user_id
from app.database import get_db
from app.limiter import limiter
from app.models.health_event import HealthEvent
from app.models.metric_definition import MetricDefinition
from app.models.daily_summary import DailySummary
from app.services.ingest_service import compute_local_date, validate_metric_value
from app.services.aggregation_service import aggregate_events

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/ingest", tags=["ingest"])


# ── Pydantic schemas ──────────────────────────────────────────────────────────

class SingleIngestRequest(BaseModel):
    metric_type: str
    value: float
    unit: str
    source: str
    recorded_at: str          # ISO 8601 with UTC offset — REQUIRED
    idempotency_key: str | None = None
    metadata: dict | None = None

    @field_validator("recorded_at")
    @classmethod
    def must_have_utc_offset(cls, v: str) -> str:
        from app.services.ingest_service import compute_local_date
        compute_local_date(v)   # raises ValueError if no offset
        return v


class SingleIngestResponse(BaseModel):
    event_id: str
    daily_total: float | None
    unit: str
    date: str


class MetricPayload(BaseModel):
    metric_type: str
    value: float
    unit: str
    idempotency_key: str | None = None
    metadata: dict | None = None


class SessionIngestRequest(BaseModel):
    activity_type: str
    source: str
    started_at: str
    ended_at: str | None = None
    idempotency_key: str | None = None
    metrics: list[MetricPayload]


class SessionIngestResponse(BaseModel):
    session_id: str
    event_ids: list[str]
    date: str


class BulkEventPayload(BaseModel):
    metric_type: str
    value: float
    unit: str
    recorded_at: str
    granularity: str = "point_in_time"
    idempotency_key: str | None = None
    metadata: dict | None = None

    @field_validator("recorded_at")
    @classmethod
    def must_have_offset(cls, v: str) -> str:
        from app.services.ingest_service import compute_local_date
        compute_local_date(v)
        return v


class BulkIngestRequest(BaseModel):
    source: str
    events: list[BulkEventPayload]


class BulkIngestResponse(BaseModel):
    task_id: str
    event_count: int
    status: str


class DeleteEventResponse(BaseModel):
    event_id: str
    deleted_at: str
    updated_daily_total: float | None


# ── Helpers ───────────────────────────────────────────────────────────────────

async def _get_metric_def(
    db: AsyncSession, metric_type: str
) -> MetricDefinition | None:
    row = await db.execute(
        select(MetricDefinition).where(MetricDefinition.metric_type == metric_type)
    )
    return row.scalar_one_or_none()


async def _recompute_daily_summary(
    db: AsyncSession,
    user_id: str,
    local_date: date,
    metric_type: str,
    unit: str,
    aggregation_fn: str,
) -> float | None:
    """Re-aggregate all non-deleted events and upsert daily_summaries."""
    rows = await db.execute(
        select(HealthEvent.value, HealthEvent.recorded_at, HealthEvent.created_at)
        .where(
            HealthEvent.user_id == uuid.UUID(str(user_id)),
            HealthEvent.local_date == local_date,
            HealthEvent.metric_type == metric_type,
            HealthEvent.deleted_at.is_(None),
        )
    )
    events = [
        {"value": r.value, "recorded_at": r.recorded_at, "created_at": r.created_at}
        for r in rows.fetchall()
    ]

    from app.services.aggregation_service import aggregate_events, AggregationResult
    result = aggregate_events(events, fn=aggregation_fn, unit=unit)

    if result is None:
        # All events deleted — remove the summary row
        await db.execute(
            text(
                "DELETE FROM daily_summaries "
                "WHERE user_id = :uid AND date = :d AND metric_type = :mt"
            ),
            {"uid": str(user_id), "d": str(local_date), "mt": metric_type},
        )
        return None

    stmt = pg_insert(DailySummary).values(
        user_id=uuid.UUID(str(user_id)),
        date=local_date,
        metric_type=metric_type,
        value=result.value,
        unit=result.unit,
        event_count=result.event_count,
        is_stale=False,
        computed_at=datetime.now(tz=timezone.utc),
    ).on_conflict_do_update(
        constraint="uq_daily_summaries_user_date_metric",
        set_={
            "value": result.value,
            "event_count": result.event_count,
            "is_stale": False,
            "computed_at": datetime.now(tz=timezone.utc),
        },
    )
    await db.execute(stmt)
    return result.value


# ── Routes ────────────────────────────────────────────────────────────────────

@limiter.limit("60/minute")
@router.post("", status_code=201, response_model=SingleIngestResponse)
async def ingest_single(
    request: Request,
    body: SingleIngestRequest,
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(get_authenticated_user_id),
) -> SingleIngestResponse:
    """Log a single manual health event synchronously."""
    local_date = compute_local_date(body.recorded_at)

    # Idempotency check
    if body.idempotency_key:
        existing = await db.execute(
            select(HealthEvent).where(
                HealthEvent.user_id == uuid.UUID(str(user_id)),
                HealthEvent.idempotency_key == body.idempotency_key,
            )
        )
        existing_event = existing.scalar_one_or_none()
        if existing_event:
            # Return original event data — idempotent success
            summary = await db.execute(
                select(DailySummary.value).where(
                    DailySummary.user_id == uuid.UUID(str(user_id)),
                    DailySummary.date == local_date,
                    DailySummary.metric_type == body.metric_type,
                )
            )
            daily_total = summary.scalar_one_or_none()
            return SingleIngestResponse(
                event_id=str(existing_event.id),
                daily_total=daily_total,
                unit=body.unit,
                date=str(local_date),
            )

    # Validate value range
    metric_def = await _get_metric_def(db, body.metric_type)
    if metric_def:
        try:
            validate_metric_value(
                body.metric_type, body.value,
                metric_def.min_value, metric_def.max_value,
            )
        except ValueError as exc:
            raise HTTPException(status_code=422, detail=str(exc))
    else:
        # Unknown metric: auto-insert placeholder, store event
        await db.execute(
            pg_insert(MetricDefinition)
            .values(
                metric_type=body.metric_type,
                display_name=body.metric_type,
                unit=body.unit,
                category="unknown",
                aggregation_fn="sum",
                data_type="float",
                is_active=False,
            )
            .on_conflict_do_nothing()
        )
        metric_def = MetricDefinition(
            metric_type=body.metric_type,
            display_name=body.metric_type,
            unit=body.unit,
            category="unknown",
            aggregation_fn="sum",
            data_type="float",
            is_active=False,
        )

    event = HealthEvent(
        user_id=uuid.UUID(str(user_id)),
        metric_type=body.metric_type,
        value=body.value,
        unit=body.unit,
        source=body.source,
        recorded_at=datetime.fromisoformat(body.recorded_at),
        local_date=local_date,
        granularity="point_in_time",
        idempotency_key=body.idempotency_key,
        metadata_=body.metadata,
    )
    db.add(event)
    await db.flush()   # get the id

    # Synchronous aggregation
    daily_total = await _recompute_daily_summary(
        db, user_id, local_date,
        body.metric_type, metric_def.unit, metric_def.aggregation_fn,
    )
    await db.commit()

    return SingleIngestResponse(
        event_id=str(event.id),
        daily_total=daily_total,
        unit=body.unit,
        date=str(local_date),
    )
