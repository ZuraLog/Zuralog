"""Unified health data ingest endpoints.

POST /api/v1/ingest            — single manual event
POST /api/v1/ingest/session    — session with multiple linked events
POST /api/v1/ingest/bulk       — bulk device sync (async aggregation)
DELETE /api/v1/events/{id}     — soft-delete a manual event (user correction)
GET /api/v1/ingest/status/{id} — bulk sync status poll
"""
from __future__ import annotations

import hashlib
import json
import uuid
import logging
from datetime import date, datetime, timezone
from typing import Any, Literal

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Request
from pydantic import BaseModel, Field, field_validator
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
from app.services.ingest_post_processing import trigger_streaks_for_metric

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/ingest", tags=["ingest"])


# ── Shared validators ────────────────────────────────────────────────────────

def _validate_metadata_size(v: dict | None) -> dict | None:
    if v is not None and len(json.dumps(v)) > 4096:
        raise ValueError("metadata must be under 4 KB when serialized")
    return v


# ── Pydantic schemas ──────────────────────────────────────────────────────────

class SingleIngestRequest(BaseModel):
    metric_type: str = Field(max_length=100)
    value: float
    unit: str = Field(max_length=50)
    source: str = Field(max_length=100)
    recorded_at: str          # ISO 8601 with UTC offset — REQUIRED
    idempotency_key: str | None = Field(default=None, max_length=200)
    metadata: dict | None = None

    @field_validator("recorded_at")
    @classmethod
    def must_have_utc_offset(cls, v: str) -> str:
        from app.services.ingest_service import compute_local_date
        compute_local_date(v)   # raises ValueError if no offset
        return v

    @field_validator("metadata")
    @classmethod
    def check_metadata_size(cls, v: dict | None) -> dict | None:
        return _validate_metadata_size(v)


class SingleIngestResponse(BaseModel):
    event_id: str
    daily_total: float | None
    unit: str
    date: str


class MetricPayload(BaseModel):
    metric_type: str = Field(max_length=100)
    value: float
    unit: str = Field(max_length=50)
    idempotency_key: str | None = Field(default=None, max_length=200)
    metadata: dict | None = None

    @field_validator("metadata")
    @classmethod
    def check_metadata_size(cls, v: dict | None) -> dict | None:
        return _validate_metadata_size(v)


class SessionIngestRequest(BaseModel):
    activity_type: str = Field(max_length=100)
    source: str = Field(max_length=100)
    started_at: str
    ended_at: str | None = None
    idempotency_key: str | None = Field(default=None, max_length=200)
    metrics: list[MetricPayload] = Field(max_length=50)

    @field_validator("started_at")
    @classmethod
    def must_have_started_at_offset(cls, v: str) -> str:
        from app.services.ingest_service import compute_local_date
        compute_local_date(v)
        return v

    @field_validator("ended_at")
    @classmethod
    def must_have_ended_at_offset(cls, v: str | None) -> str | None:
        if v is not None:
            from app.services.ingest_service import compute_local_date
            compute_local_date(v)
        return v


class SessionIngestResponse(BaseModel):
    session_id: str
    event_ids: list[str]
    date: str


class BulkEventPayload(BaseModel):
    metric_type: str = Field(max_length=100)
    value: float
    unit: str = Field(max_length=50)
    recorded_at: str
    granularity: Literal["point_in_time", "daily_aggregate"] = "point_in_time"
    idempotency_key: str | None = Field(default=None, max_length=200)
    metadata: dict | None = None

    @field_validator("recorded_at")
    @classmethod
    def must_have_offset(cls, v: str) -> str:
        from app.services.ingest_service import compute_local_date
        compute_local_date(v)
        return v

    @field_validator("metadata")
    @classmethod
    def check_metadata_size(cls, v: dict | None) -> dict | None:
        return _validate_metadata_size(v)


class BulkIngestRequest(BaseModel):
    source: str = Field(max_length=100)
    events: list[BulkEventPayload] = Field(max_length=500)


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
    # Acquire advisory lock to serialize concurrent recomputes for same tuple
    lock_key = int(hashlib.md5(f"{user_id}:{local_date}:{metric_type}".encode()).hexdigest()[:8], 16) & 0x7FFFFFFF
    await db.execute(text("SELECT pg_advisory_xact_lock(:key)"), {"key": lock_key})

    rows = await db.execute(
        select(HealthEvent.value, HealthEvent.recorded_at, HealthEvent.created_at)
        .where(
            HealthEvent.user_id == user_id,
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
            {"uid": str(user_id), "d": local_date, "mt": metric_type},
        )
        return None

    now = datetime.now(tz=timezone.utc)
    stmt = pg_insert(DailySummary).values(
        user_id=user_id,
        date=local_date,
        metric_type=metric_type,
        value=result.value,
        unit=result.unit,
        event_count=result.event_count,
        is_stale=False,
        computed_at=now,
    ).on_conflict_do_update(
        constraint="uq_daily_summaries_user_date_metric",
        set_={
            "value": result.value,
            "event_count": result.event_count,
            "is_stale": False,
            "computed_at": now,
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
    logger.info(
        "[ingest_single] user=%s metric_type=%s value=%s unit=%s "
        "source=%s recorded_at=%s idempotency_key=%s",
        user_id[:8], body.metric_type, body.value, body.unit,
        body.source, body.recorded_at, body.idempotency_key,
    )
    local_date = compute_local_date(body.recorded_at)

    # Idempotency check
    if body.idempotency_key:
        existing = await db.execute(
            select(HealthEvent).where(
                HealthEvent.user_id == user_id,
                HealthEvent.idempotency_key == body.idempotency_key,
            )
        )
        existing_event = existing.scalar_one_or_none()
        if existing_event:
            logger.info(
                "[ingest_single] idempotency hit — event_id=%s", existing_event.id
            )
            # Return original event data — idempotent success
            summary = await db.execute(
                select(DailySummary.value).where(
                    DailySummary.user_id == user_id,
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
        logger.info(
            "[ingest_single] metric_def found — aggregation_fn=%s "
            "min=%s max=%s unit=%s",
            metric_def.aggregation_fn, metric_def.min_value,
            metric_def.max_value, metric_def.unit,
        )
        try:
            validate_metric_value(
                body.metric_type, body.value,
                metric_def.min_value, metric_def.max_value,
            )
        except ValueError as exc:
            logger.warning("[ingest_single] validation failed: %s", exc)
            raise HTTPException(status_code=422, detail=str(exc))
    else:
        logger.warning("[ingest_single] unknown metric_type=%s", body.metric_type)
        raise HTTPException(status_code=422, detail=f"Unknown metric type: '{body.metric_type}'")

    event = HealthEvent(
        user_id=user_id,
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
    logger.info("[ingest_single] event flushed — event_id=%s", event.id)

    # Synchronous aggregation
    daily_total = await _recompute_daily_summary(
        db, user_id, local_date,
        body.metric_type, metric_def.unit, metric_def.aggregation_fn,
    )
    await db.commit()
    logger.info(
        "[ingest_single] ✅ committed — event_id=%s daily_total=%s",
        event.id, daily_total,
    )

    await trigger_streaks_for_metric(db, user_id, body.metric_type, local_date)

    return SingleIngestResponse(
        event_id=str(event.id),
        daily_total=daily_total,
        unit=body.unit,
        date=str(local_date),
    )


@limiter.limit("30/minute")
@router.post("/session", status_code=201, response_model=SessionIngestResponse)
async def ingest_session(
    request: Request,
    body: SessionIngestRequest,
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(get_authenticated_user_id),
) -> SessionIngestResponse:
    """Log an activity session with linked metric events."""
    local_date = compute_local_date(body.started_at)

    # Idempotency: check activity_sessions
    if body.idempotency_key:
        from app.models.activity_session import ActivitySession
        existing = await db.execute(
            select(ActivitySession).where(
                ActivitySession.user_id == user_id,
                ActivitySession.idempotency_key == body.idempotency_key,
            )
        )
        existing_session = existing.scalar_one_or_none()
        if existing_session:
            # Fetch event IDs linked to this session
            linked = await db.execute(
                select(HealthEvent.id).where(HealthEvent.session_id == existing_session.id)
            )
            event_ids = [str(r.id) for r in linked.fetchall()]
            return SessionIngestResponse(
                session_id=str(existing_session.id),
                event_ids=event_ids,
                date=str(local_date),
            )

    from app.models.activity_session import ActivitySession
    session = ActivitySession(
        user_id=user_id,
        activity_type=body.activity_type,
        source=body.source,
        started_at=datetime.fromisoformat(body.started_at),
        ended_at=datetime.fromisoformat(body.ended_at) if body.ended_at else None,
        idempotency_key=body.idempotency_key,
    )
    db.add(session)
    await db.flush()

    event_ids: list[str] = []
    for m in body.metrics:
        metric_def = await _get_metric_def(db, m.metric_type)
        if metric_def:
            try:
                validate_metric_value(m.metric_type, m.value, metric_def.min_value, metric_def.max_value)
            except ValueError as exc:
                raise HTTPException(status_code=422, detail=str(exc))

        event = HealthEvent(
            user_id=user_id,
            metric_type=m.metric_type,
            value=m.value,
            unit=m.unit,
            source=body.source,
            recorded_at=datetime.fromisoformat(body.started_at),
            local_date=local_date,
            granularity="point_in_time",
            session_id=session.id,
            idempotency_key=m.idempotency_key,
            metadata_=m.metadata,
        )
        db.add(event)
        await db.flush()
        event_ids.append(str(event.id))

        agg_fn = metric_def.aggregation_fn if metric_def else "sum"
        unit = metric_def.unit if metric_def else m.unit
        await _recompute_daily_summary(db, user_id, local_date, m.metric_type, unit, agg_fn)

    await db.commit()

    # Trigger streaks for each unique (metric_type, local_date) pair in the session.
    seen_pairs: set[tuple[str, date]] = set()
    for m in body.metrics:
        pair = (m.metric_type, compute_local_date(body.started_at))
        if pair not in seen_pairs:
            seen_pairs.add(pair)
            await trigger_streaks_for_metric(db, user_id, m.metric_type, pair[1])

    return SessionIngestResponse(session_id=str(session.id), event_ids=event_ids, date=str(local_date))


@limiter.limit("10/minute")
@router.post("/bulk", status_code=202, response_model=BulkIngestResponse)
async def ingest_bulk(
    request: Request,
    body: BulkIngestRequest,
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(get_authenticated_user_id),
) -> BulkIngestResponse:
    """Bulk device sync — inserts all events transactionally, aggregation async."""
    # Validate all events BEFORE any DB operations
    affected_combos: set[tuple[str, date, str]] = set()
    for ev in body.events:
        local_date = compute_local_date(ev.recorded_at)
        metric_def = await _get_metric_def(db, ev.metric_type)
        if not metric_def:
            raise HTTPException(status_code=422, detail=f"Unknown metric type: '{ev.metric_type}'")
        try:
            validate_metric_value(ev.metric_type, ev.value, metric_def.min_value, metric_def.max_value)
        except ValueError as exc:
            raise HTTPException(status_code=422, detail=str(exc))
        affected_combos.add((str(user_id), local_date, ev.metric_type))

    # Insert all events
    for ev in body.events:
        local_date = compute_local_date(ev.recorded_at)
        event = HealthEvent(
            user_id=user_id,
            metric_type=ev.metric_type,
            value=ev.value,
            unit=ev.unit,
            source=body.source,
            recorded_at=datetime.fromisoformat(ev.recorded_at),
            local_date=local_date,
            granularity=ev.granularity,
            idempotency_key=ev.idempotency_key,
            metadata_=ev.metadata,
        )
        db.add(event)

    # Mark affected daily_summaries as stale BEFORE commit so both
    # event inserts and stale-marking are atomic in one transaction.
    from app.models.daily_summary import DailySummary as DS
    for uid, ld, mt in affected_combos:
        await db.execute(
            text(
                "UPDATE daily_summaries SET is_stale = true "
                "WHERE user_id = :uid AND date = :d AND metric_type = :mt"
            ),
            {"uid": uid, "d": ld, "mt": mt},
        )

    await db.commit()

    # Enqueue Celery aggregation task
    try:
        from app.tasks.aggregation_tasks import recompute_daily_summaries_for_batch
        batch = [{"user_id": uid, "local_date": str(ld), "metric_type": mt} for uid, ld, mt in affected_combos]
        task = recompute_daily_summaries_for_batch.delay(batch=batch)
        task_id = task.id
    except Exception as exc:
        logger.error("Failed to enqueue aggregation task for user %s: %s", user_id, exc)
        # If Celery isn't available, generate a placeholder task_id
        task_id = str(uuid.uuid4())

    # Trigger streaks for each unique (metric_type, local_date) pair in the batch.
    for uid, ld, mt in affected_combos:
        await trigger_streaks_for_metric(db, uid, mt, ld)

    return BulkIngestResponse(task_id=task_id, event_count=len(body.events), status="processing")


@limiter.limit("120/minute")
@router.get("/status/{task_id}")
async def bulk_ingest_status(
    request: Request,
    task_id: str,
    user_id: str = Depends(get_authenticated_user_id),
) -> dict:
    """Poll the status of a bulk ingest aggregation task."""
    try:
        from celery.result import AsyncResult
        result = AsyncResult(task_id)
        status_map = {
            "PENDING": "processing",
            "STARTED": "processing",
            "SUCCESS": "complete",
            "FAILURE": "failed",
            "RETRY": "processing",
            "REVOKED": "failed",
        }
        if result.state == "FAILURE":
            logger.error("Celery task %s failed: %s", task_id, result.info)
        return {
            "task_id": task_id,
            "status": status_map.get(result.state, "processing"),
            "detail": "Aggregation failed" if result.state == "FAILURE" else None,
        }
    except ImportError:
        return {"task_id": task_id, "status": "processing", "detail": None}


# ── Events Router (soft-delete) ─────────────────────────────────────────────

events_router = APIRouter(prefix="/events", tags=["events"])


@limiter.limit("60/minute")
@events_router.delete("/{event_id}", response_model=DeleteEventResponse)
async def delete_event(
    request: Request,
    event_id: str,
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(get_authenticated_user_id),
) -> DeleteEventResponse:
    """Soft-delete a manual event (user correction)."""
    result = await db.execute(
        select(HealthEvent).where(HealthEvent.id == uuid.UUID(event_id), HealthEvent.user_id == user_id)
    )
    event = result.scalar_one_or_none()

    if not event:
        raise HTTPException(status_code=404, detail="Event not found")

    if event.source != "manual":
        raise HTTPException(status_code=422, detail="Device events cannot be deleted by users.")

    if event.deleted_at is not None:
        raise HTTPException(status_code=404, detail="Event already deleted")

    event.deleted_at = datetime.now(tz=timezone.utc)
    await db.flush()

    # Fetch metric def for aggregation
    metric_def = await _get_metric_def(db, event.metric_type)
    agg_fn = metric_def.aggregation_fn if metric_def else "sum"
    unit = metric_def.unit if metric_def else event.unit

    daily_total = await _recompute_daily_summary(
        db, str(user_id), event.local_date,
        event.metric_type, unit, agg_fn,
    )
    await db.commit()

    return DeleteEventResponse(
        event_id=str(event.id),
        deleted_at=event.deleted_at.isoformat(),
        updated_daily_total=daily_total,
    )
