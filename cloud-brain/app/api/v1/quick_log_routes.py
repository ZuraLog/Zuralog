"""
Zuralog Cloud Brain — Quick Log API.

Endpoints:
  POST /api/v1/quick-log          — Log a single metric entry.
  POST /api/v1/quick-log/batch    — Log multiple metric entries at once.
  GET  /api/v1/quick-log          — Query log history with optional filters.

All endpoints are auth-guarded; users can only access their own logs.
Multiple logs per day are permitted (no uniqueness constraint). The GET
endpoint supports filtering by metric_type and date range.
"""

import logging
import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, ConfigDict
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.deps import get_authenticated_user_id
from app.database import get_db
from app.models.quick_log import QuickLog, VALID_METRIC_TYPES

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/quick-log", tags=["quick-log"])

# ---------------------------------------------------------------------------
# Pydantic schemas
# ---------------------------------------------------------------------------


class QuickLogCreate(BaseModel):
    """Payload for a single quick-log entry.

    Attributes:
        metric_type: One of: water, mood, energy, stress, sleep_quality, pain, notes.
        value: Numeric measurement value. Optional for text-only metrics.
        text_value: Free-text content. Optional for numeric-only metrics.
        tags: Array of tag strings. Defaults to empty list.
        logged_at: ISO datetime string. Defaults to server time if not provided.
    """

    metric_type: str
    value: float | None = None
    text_value: str | None = None
    tags: list[str] = []
    logged_at: str | None = None  # ISO datetime; defaults to now if not provided


class QuickLogResponse(BaseModel):
    """Single quick-log entry payload returned to the client.

    Attributes:
        id: UUID primary key.
        user_id: Owning user's ID.
        metric_type: The logged metric type.
        value: Numeric measurement value or None.
        text_value: Free-text content or None.
        tags: Array of tag strings.
        logged_at: ISO timestamp of when the metric was recorded.
    """

    id: str
    user_id: str
    metric_type: str
    value: float | None
    text_value: str | None
    tags: list
    logged_at: str

    model_config = ConfigDict(from_attributes=True)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _validate_metric_type(metric_type: str) -> None:
    """Validate that metric_type is one of the allowed values.

    Args:
        metric_type: The metric type string to validate.

    Raises:
        HTTPException: 422 if the value is not in VALID_METRIC_TYPES.
    """
    if metric_type not in VALID_METRIC_TYPES:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=(
                f"Invalid metric_type '{metric_type}'. "
                f"Must be one of: {sorted(VALID_METRIC_TYPES)}."
            ),
        )


def _resolve_logged_at(logged_at: str | None) -> str:
    """Resolve the logged_at timestamp, defaulting to UTC now.

    Args:
        logged_at: ISO datetime string provided by the client, or None.

    Returns:
        ISO datetime string to store.
    """
    if logged_at:
        return logged_at
    return datetime.now(timezone.utc).isoformat()


def _log_to_response(log: QuickLog) -> dict:
    """Serialize a QuickLog ORM object to a response dict.

    Args:
        log: The ORM instance to serialize.

    Returns:
        Dict suitable for the QuickLogResponse schema.
    """
    return {
        "id": log.id,
        "user_id": log.user_id,
        "metric_type": log.metric_type,
        "value": log.value,
        "text_value": log.text_value,
        "tags": log.tags or [],
        "logged_at": str(log.logged_at),
    }


def _build_log(user_id: str, body: QuickLogCreate) -> QuickLog:
    """Construct a QuickLog ORM instance from a create payload.

    Args:
        user_id: Authenticated user ID.
        body: Incoming create payload.

    Returns:
        Unsaved QuickLog ORM instance.
    """
    return QuickLog(
        id=str(uuid.uuid4()),
        user_id=user_id,
        metric_type=body.metric_type,
        value=body.value,
        text_value=body.text_value,
        tags=body.tags,
        logged_at=_resolve_logged_at(body.logged_at),
    )


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------


@router.post("", summary="Log a single metric entry")
async def create_quick_log(
    body: QuickLogCreate,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Record a single rapid-log metric entry.

    Args:
        body: Metric type, value, and optional metadata.
        user_id: Authenticated user ID (injected by dependency).
        db: Async database session.

    Returns:
        The created QuickLogResponse.

    Raises:
        HTTPException: 422 if metric_type is not a valid value.
    """
    _validate_metric_type(body.metric_type)

    log = _build_log(user_id, body)
    db.add(log)
    await db.commit()
    await db.refresh(log)
    logger.info("Quick log created: user=%s type=%s", user_id, body.metric_type)
    return _log_to_response(log)


@router.post("/batch", summary="Log multiple metric entries at once")
async def create_quick_log_batch(
    body: list[QuickLogCreate],
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> list[dict]:
    """Record multiple rapid-log metric entries in a single request.

    All entries in the batch are validated before any are persisted. If any
    entry has an invalid metric_type the entire batch is rejected.

    Args:
        body: List of metric entries to create.
        user_id: Authenticated user ID.
        db: Async database session.

    Returns:
        List of created QuickLogResponse dicts.

    Raises:
        HTTPException: 400 if the batch is empty.
        HTTPException: 422 if any entry has an invalid metric_type.
    """
    if not body:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Batch cannot be empty.",
        )

    # Validate all entries before persisting any
    for item in body:
        _validate_metric_type(item.metric_type)

    logs = [_build_log(user_id, item) for item in body]
    db.add_all(logs)
    await db.commit()

    # Refresh all to get server-assigned values
    for log in logs:
        await db.refresh(log)

    logger.info("Batch quick log created: user=%s count=%d", user_id, len(logs))
    return [_log_to_response(log) for log in logs]


@router.get("", summary="Query quick-log history")
async def list_quick_logs(
    metric_type: str | None = None,
    date_from: str | None = None,
    date_to: str | None = None,
    limit: int = 50,
    offset: int = 0,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> list[dict]:
    """List quick-log entries for the authenticated user with optional filters.

    Results are ordered newest-first. Date filters compare against the
    ``logged_at`` timestamp column using lexicographic ISO string ordering.

    Args:
        metric_type: Filter to a specific metric type. Optional.
        date_from: Earliest logged_at to include (ISO datetime string). Optional.
        date_to: Latest logged_at to include (ISO datetime string). Optional.
        limit: Maximum entries to return. Defaults to 50.
        offset: Number of entries to skip. Defaults to 0.
        user_id: Authenticated user ID.
        db: Async database session.

    Returns:
        List of QuickLogResponse dicts.

    Raises:
        HTTPException: 422 if metric_type filter is not a valid value.
    """
    if metric_type is not None:
        _validate_metric_type(metric_type)

    query = select(QuickLog).where(QuickLog.user_id == user_id)

    if metric_type:
        query = query.where(QuickLog.metric_type == metric_type)
    if date_from:
        query = query.where(QuickLog.logged_at >= date_from)
    if date_to:
        query = query.where(QuickLog.logged_at <= date_to)

    query = query.order_by(QuickLog.logged_at.desc()).offset(offset).limit(limit)

    result = await db.execute(query)
    logs = result.scalars().all()
    return [_log_to_response(log) for log in logs]
