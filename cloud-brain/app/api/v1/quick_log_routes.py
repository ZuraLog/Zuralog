"""
Zuralog Cloud Brain — Quick Log API Routes.

Low-friction endpoints for logging individual health metric data points.
Supports single-entry and atomic batch submission, plus time-range history
queries with optional metric-type filtering.

Endpoints:
    POST /api/v1/quick-log         — Log a single metric entry
    POST /api/v1/quick-log/batch   — Atomically log multiple entries
    GET  /api/v1/quick-log         — Query history by date range and type
"""

import logging
from datetime import datetime, timedelta, timezone
from typing import Any

from fastapi import APIRouter, Depends, Query, status
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.deps import get_authenticated_user_id
from app.database import get_db
from app.models.quick_log import MetricType, QuickLog

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/quick-log",
    tags=["quick-log"],
)


# ---------------------------------------------------------------------------
# Schemas
# ---------------------------------------------------------------------------


class QuickLogRequest(BaseModel):
    """Request body for a single quick-log entry.

    Attributes:
        metric_type: The metric category to log.
        value: Numeric value (required for scored metrics; optional for
            notes/symptoms).
        text_value: Text content (required for notes/symptoms; optional
            for scored metrics).
        tags: Symptom chip list (optional).
        logged_at: Override the timestamp. Defaults to server time when
            not provided.
    """

    metric_type: MetricType
    value: float | None = None
    text_value: str | None = None
    tags: list[str] | None = None
    logged_at: datetime | None = Field(
        default=None,
        description="Defaults to now when not provided",
    )


class QuickLogResponse(BaseModel):
    """API response for a quick-log entry."""

    id: str
    user_id: str
    metric_type: str
    value: float | None
    text_value: str | None
    tags: list[str] | None
    logged_at: Any
    created_at: Any

    model_config = {"from_attributes": True}


class BatchQuickLogRequest(BaseModel):
    """Request body for atomically submitting multiple quick-log entries.

    Attributes:
        entries: List of quick-log items to persist in a single transaction.
    """

    entries: list[QuickLogRequest] = Field(min_length=1)


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------


@router.post("", status_code=status.HTTP_201_CREATED, response_model=QuickLogResponse)
async def create_quick_log(
    body: QuickLogRequest,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> QuickLog:
    """Log a single health metric data point.

    Args:
        body: The metric payload.
        user_id: Authenticated user ID from JWT.
        db: Injected async database session.

    Returns:
        The created :class:`QuickLog` row.
    """
    entry = QuickLog(
        user_id=user_id,
        metric_type=body.metric_type.value,
        value=body.value,
        text_value=body.text_value,
        tags=body.tags,
        logged_at=body.logged_at or datetime.now(tz=timezone.utc),
    )
    db.add(entry)
    await db.commit()
    await db.refresh(entry)
    return entry


@router.post(
    "/batch",
    status_code=status.HTTP_201_CREATED,
    response_model=list[QuickLogResponse],
)
async def batch_create_quick_logs(
    body: BatchQuickLogRequest,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> list[QuickLog]:
    """Atomically log multiple metric data points in a single transaction.

    All entries are committed together; if any entry fails validation the
    entire batch is rejected.

    Args:
        body: Batch payload containing one or more quick-log entries.
        user_id: Authenticated user ID from JWT.
        db: Injected async database session.

    Returns:
        List of created :class:`QuickLog` rows.
    """
    now = datetime.now(tz=timezone.utc)
    logs: list[QuickLog] = []

    for item in body.entries:
        log = QuickLog(
            user_id=user_id,
            metric_type=item.metric_type.value,
            value=item.value,
            text_value=item.text_value,
            tags=item.tags,
            logged_at=item.logged_at or now,
        )
        db.add(log)
        logs.append(log)

    await db.commit()

    for log in logs:
        await db.refresh(log)

    return logs


@router.get("", response_model=list[QuickLogResponse])
async def get_quick_log_history(
    metric_type: MetricType | None = Query(default=None, description="Filter by type"),
    start: datetime | None = Query(default=None, description="Inclusive start UTC datetime"),
    end: datetime | None = Query(default=None, description="Inclusive end UTC datetime"),
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> list[QuickLog]:
    """Return quick-log history with optional metric type and time filters.

    Defaults to the last 30 days when no range is specified.

    Args:
        metric_type: Optional filter to a single metric category.
        start: Inclusive lower bound for ``logged_at``. Defaults to 30d ago.
        end: Inclusive upper bound for ``logged_at``. Defaults to now.
        user_id: Authenticated user ID from JWT.
        db: Injected async database session.

    Returns:
        List of :class:`QuickLog` rows ordered by ``logged_at`` descending.
    """
    now = datetime.now(tz=timezone.utc)
    effective_end = end or now
    effective_start = start or (now - timedelta(days=30))

    query = (
        select(QuickLog)
        .where(
            QuickLog.user_id == user_id,
            QuickLog.logged_at >= effective_start,
            QuickLog.logged_at <= effective_end,
        )
        .order_by(QuickLog.logged_at.desc())
    )

    if metric_type is not None:
        query = query.where(QuickLog.metric_type == metric_type.value)

    result = await db.execute(query)
    return list(result.scalars().all())
