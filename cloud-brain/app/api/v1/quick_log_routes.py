"""
Zuralog Cloud Brain — Quick Log API.

Endpoints:
  POST /api/v1/quick-log          — Log a single metric entry.
  POST /api/v1/quick-log/batch    — Log multiple metric entries at once.
  GET  /api/v1/quick-log          — Query log history with optional filters.
  GET  /api/v1/quick-log/latest   — Get most recent log value per requested metric type.

All endpoints are auth-guarded; users can only access their own logs.
Multiple logs per day are permitted (no uniqueness constraint). The GET
endpoint supports filtering by metric_type and date range.
"""

import logging
import uuid
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, Request, status
from pydantic import BaseModel, ConfigDict
from collections import defaultdict

from sqlalchemy import distinct, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_authenticated_user_id
from app.database import get_db
from app.limiter import limiter
from app.models.quick_log import QuickLog, VALID_METRIC_TYPES

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/quick-log", tags=["quick-log"])

# ---------------------------------------------------------------------------
# Pydantic schemas
# ---------------------------------------------------------------------------


# ---------------------------------------------------------------------------
# Typed log schemas
# ---------------------------------------------------------------------------


class SleepLogCreate(BaseModel):
    bedtime: str  # ISO8601
    wake_time: str  # ISO8601
    duration_minutes: int | None = None  # Ignored — server calculates from bedtime/wake_time
    quality_rating: int | None = None  # 1-5
    interruptions: int | None = None  # 0-20
    factors: list[str] = []
    notes: str | None = None
    source: str = "manual"
    logged_at: str | None = None


class RunLogCreate(BaseModel):
    activity_type: str
    distance_km: float
    duration_seconds: int
    avg_pace_seconds_per_km: int | None = None
    effort_level: str | None = None
    notes: str | None = None
    source: str = "manual"
    logged_at: str | None = None


class MealLogCreate(BaseModel):
    meal_type: str
    description: str | None = None
    calories_kcal: int | None = None
    feel_chips: list[str] = []
    tags: list[str] = []
    notes: str | None = None
    quick_mode: bool = False
    logged_at: str | None = None


class SupplementLogCreate(BaseModel):
    taken_supplement_ids: list[str] = []
    notes: str | None = None
    logged_at: str | None = None


class SymptomLogCreate(BaseModel):
    body_areas: list[str]
    severity: str
    symptom_type: str | None = None
    timing: str | None = None
    notes: str | None = None
    logged_at: str | None = None


class WaterLogCreate(BaseModel):
    amount_ml: float
    vessel_key: str | None = None  # informational only, not validated server-side
    logged_at: str | None = None


class WellnessLogCreate(BaseModel):
    mood: float | None = None  # 1.0–10.0
    energy: float | None = None  # 1.0–10.0
    stress: float | None = None  # 1.0–10.0
    notes: str | None = None  # max 500 chars
    logged_at: str | None = None


class WeightLogCreate(BaseModel):
    value_kg: float  # always stored in kg; client converts before submitting
    logged_at: str | None = None


class StepsLogCreate(BaseModel):
    steps: int
    mode: str = "add"  # "add" | "override"
    source: str = "manual"  # "manual" | "apple_health" | "health_connect"
    logged_at: str | None = None


class SupplementListEntry(BaseModel):
    name: str
    dose: str | None = None
    timing: str | None = None


class SupplementListCreate(BaseModel):
    supplements: list[SupplementListEntry]


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
        data: Structured per-type payload dict.
        logged_at: ISO timestamp of when the metric was recorded.
    """

    id: str
    user_id: str
    metric_type: str
    value: float | None
    text_value: str | None
    tags: list
    data: dict
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
            detail=(f"Invalid metric_type '{metric_type}'. Must be one of: {sorted(VALID_METRIC_TYPES)}."),
        )


def _resolve_logged_at(logged_at: str | None) -> str:
    """Resolve the logged_at timestamp, defaulting to UTC now.

    Accepts ISO 8601 strings with any UTC offset. Always returns a UTC
    ISO 8601 string (``+00:00`` suffix). Validates that the timestamp is
    not more than 24 hours in the future or more than 1 year in the past.

    Args:
        logged_at: ISO 8601 datetime string from the client, or None.

    Returns:
        UTC ISO 8601 datetime string.

    Raises:
        HTTPException 422: if the value is out of the allowed window or
            not a valid ISO 8601 string.
    """
    if not logged_at:
        return datetime.now(timezone.utc).isoformat()
    try:
        dt = datetime.fromisoformat(logged_at.replace("Z", "+00:00"))
        now = datetime.now(timezone.utc)
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        else:
            dt = dt.astimezone(timezone.utc)
        if dt > now + timedelta(hours=24):
            raise HTTPException(
                status_code=422,
                detail="logged_at cannot be more than 24 hours in the future.",
            )
        if dt < now - timedelta(days=365):
            raise HTTPException(
                status_code=422,
                detail="logged_at cannot be more than 1 year in the past.",
            )
        return dt.isoformat()
    except (ValueError, OverflowError):
        raise HTTPException(
            status_code=422,
            detail="logged_at must be a valid ISO 8601 datetime string.",
        )


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
        "data": log.data or {},
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


def _aggregate_today_logs(logs) -> tuple[list[str], dict]:
    """Aggregate a list of today's QuickLog entries into logged_types and latest_values.

    Args:
        logs: List of QuickLog ORM instances, ordered oldest-first.
              (The query orders by logged_at ASC so newer entries overwrite earlier ones
              for 'latest' semantics.)

    Returns:
        Tuple of (logged_types, latest_values) where:
        - logged_types: sorted list of distinct metric_type strings
        - latest_values: dict mapping metric keys to their aggregated values
    """
    # Group entries by metric_type, preserving order (oldest first).
    by_type: dict[str, list] = defaultdict(list)
    for entry in logs:
        by_type[entry.metric_type].append(entry)

    latest_values: dict = {}

    # Water — cumulative sum
    if "water" in by_type:
        latest_values["water"] = sum(e.value or 0 for e in by_type["water"])

    # Mood / energy / stress — latest value
    for metric in ("mood", "energy", "stress"):
        if metric in by_type:
            latest = by_type[metric][-1]  # list is oldest-first; last = newest
            if latest.value is not None:
                latest_values[metric] = latest.value

    # Weight — latest value
    if "weight" in by_type:
        latest = by_type["weight"][-1]
        if latest.value is not None:
            latest_values["weight"] = latest.value

    # Sleep — latest value (duration_minutes stored in value column)
    if "sleep" in by_type:
        latest = by_type["sleep"][-1]
        if latest.value is not None:
            latest_values["sleep"] = latest.value

    # Run — latest distance + run_logged_at timestamp
    if "run" in by_type:
        latest = by_type["run"][-1]
        if latest.value is not None:
            latest_values["run"] = latest.value
        if latest.logged_at is not None:
            logged_at_val = latest.logged_at
            if hasattr(logged_at_val, "isoformat"):
                latest_values["run_logged_at"] = logged_at_val.isoformat()
            else:
                latest_values["run_logged_at"] = str(logged_at_val)

    # Meal — cumulative calories (null values treated as 0)
    if "meal" in by_type:
        latest_values["meal"] = sum(e.value or 0 for e in by_type["meal"])

    # Supplement — cumulative count of items taken
    if "supplement" in by_type:
        latest_values["supplement"] = sum(e.value or 0 for e in by_type["supplement"])

    # Symptom — latest severity string from text_value
    if "symptom" in by_type:
        latest = by_type["symptom"][-1]
        if latest.text_value:
            latest_values["symptom_severity"] = latest.text_value

    # Steps — sum add entries; override acts as a reset point
    if "steps" in by_type:
        entries = by_type["steps"]  # oldest-first
        last_override_idx = -1
        for i, e in enumerate(entries):
            if (e.data or {}).get("mode") == "override":
                last_override_idx = i

        if last_override_idx >= 0:
            override_val = entries[last_override_idx].value or 0
            add_after = sum(
                e.value or 0 for e in entries[last_override_idx + 1 :] if (e.data or {}).get("mode", "add") == "add"
            )
            latest_values["steps"] = override_val + add_after
        else:
            latest_values["steps"] = sum(e.value or 0 for e in entries if (e.data or {}).get("mode", "add") == "add")

    logged_types = sorted(by_type.keys())
    return logged_types, latest_values


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------


@router.post("", summary="Log a single metric entry")
@limiter.limit("60/minute")
async def create_quick_log(
    request: Request,
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
@limiter.limit("10/minute")
async def create_quick_log_batch(
    request: Request,
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

    if len(body) > 100:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Batch exceeds maximum of 100 entries.",
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
@limiter.limit("60/minute")
async def list_quick_logs(
    request: Request,
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

    limit = min(limit, 100)  # cap at 100 regardless of client request

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


# ---------------------------------------------------------------------------
# Typed log endpoints
# ---------------------------------------------------------------------------

_VALID_SEVERITY = frozenset({"mild", "moderate", "bad", "severe"})


@router.post("/sleep", summary="Log a sleep entry")
@limiter.limit("10/minute")
async def log_sleep(
    request: Request,
    body: SleepLogCreate,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Record a sleep entry with bedtime, wake time, and optional quality data.

    Args:
        request: The incoming FastAPI request (required by slowapi limiter).
        body: Sleep log payload.
        user_id: Authenticated user ID (injected by dependency).
        db: Async database session.

    Returns:
        Dict with id, logged_at, and type fields.

    Raises:
        HTTPException: 422 if wake_time is before bedtime, quality_rating is out
            of range, or interruptions is out of range.
    """
    try:
        bed = datetime.fromisoformat(body.bedtime.replace("Z", "+00:00"))
        wake = datetime.fromisoformat(body.wake_time.replace("Z", "+00:00"))
    except ValueError:
        raise HTTPException(status_code=422, detail="Invalid bedtime or wake_time format.")
    if wake <= bed:
        raise HTTPException(status_code=422, detail="wake_time must be after bedtime.")
    diff_minutes = int((wake - bed).total_seconds() / 60)
    if not (1 <= diff_minutes <= 1440):
        raise HTTPException(
            status_code=422,
            detail="Sleep duration must be between 1 minute and 24 hours.",
        )
    if body.quality_rating is not None and not (1 <= body.quality_rating <= 5):
        raise HTTPException(status_code=422, detail="quality_rating must be between 1 and 5.")
    if body.interruptions is not None and not (0 <= body.interruptions <= 20):
        raise HTTPException(status_code=422, detail="interruptions must be between 0 and 20.")
    if body.notes and len(body.notes) > 500:
        raise HTTPException(status_code=422, detail="notes must not exceed 500 characters.")

    data = {
        "bedtime": body.bedtime,
        "wake_time": body.wake_time,
        "duration_minutes": diff_minutes,
        "quality_rating": body.quality_rating,
        "interruptions": body.interruptions,
        "factors": body.factors,
        "notes": body.notes.strip() if body.notes else None,
        "source": body.source,
    }
    log = QuickLog(
        id=str(uuid.uuid4()),
        user_id=user_id,
        metric_type="sleep",
        value=float(diff_minutes),
        data=data,
        logged_at=_resolve_logged_at(body.logged_at),
    )
    db.add(log)
    await db.commit()
    await db.refresh(log)
    return {"id": log.id, "logged_at": str(log.logged_at), "type": "sleep"}


@router.post("/run", summary="Log a run or cardio activity")
@limiter.limit("20/minute")
async def log_run(
    request: Request,
    body: RunLogCreate,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Record a run or cardio activity entry.

    Args:
        request: The incoming FastAPI request (required by slowapi limiter).
        body: Run log payload.
        user_id: Authenticated user ID (injected by dependency).
        db: Async database session.

    Returns:
        Dict with id, logged_at, and type fields.

    Raises:
        HTTPException: 422 if distance_km or duration_seconds are out of range.
    """
    if not (0.01 <= body.distance_km <= 1000):
        raise HTTPException(
            status_code=422,
            detail="distance_km must be between 0.01 and 1000.",
        )
    if not (1 <= body.duration_seconds <= 86400):
        raise HTTPException(
            status_code=422,
            detail="duration_seconds must be between 1 and 86400.",
        )
    if body.notes and len(body.notes) > 500:
        raise HTTPException(status_code=422, detail="notes must not exceed 500 characters.")
    activity_type = body.activity_type.strip().lower()
    pace = body.avg_pace_seconds_per_km or (
        int(body.duration_seconds / body.distance_km) if body.distance_km > 0 else None
    )
    data = {
        "activity_type": activity_type,
        "distance_km": body.distance_km,
        "duration_seconds": body.duration_seconds,
        "avg_pace_seconds_per_km": pace,
        "effort_level": body.effort_level,
        "notes": body.notes.strip() if body.notes else None,
        "source": body.source,
    }
    log = QuickLog(
        id=str(uuid.uuid4()),
        user_id=user_id,
        metric_type="run",
        value=body.distance_km,
        data=data,
        logged_at=_resolve_logged_at(body.logged_at),
    )
    db.add(log)
    await db.commit()
    await db.refresh(log)
    return {"id": log.id, "logged_at": str(log.logged_at), "type": "run"}


@router.post("/meal", summary="Log a meal")
@limiter.limit("30/minute")
async def log_meal(
    request: Request,
    body: MealLogCreate,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Record a meal entry.

    In full mode (quick_mode=False) a description is required.
    In quick mode only a meal_type is required.

    Args:
        request: The incoming FastAPI request (required by slowapi limiter).
        body: Meal log payload.
        user_id: Authenticated user ID (injected by dependency).
        db: Async database session.

    Returns:
        Dict with id, logged_at, and type fields.

    Raises:
        HTTPException: 422 if full mode is used without a description, or if
            calories_kcal is out of range.
    """
    if not body.quick_mode and not body.description:
        raise HTTPException(status_code=422, detail="description is required in full mode.")
    if body.description and len(body.description) > 1000:
        raise HTTPException(
            status_code=422,
            detail="description must not exceed 1000 characters.",
        )
    if body.calories_kcal is not None and not (0 <= body.calories_kcal <= 9999):
        raise HTTPException(
            status_code=422,
            detail="calories_kcal must be between 0 and 9999.",
        )
    if body.notes and len(body.notes) > 500:
        raise HTTPException(status_code=422, detail="notes must not exceed 500 characters.")
    meal_type = body.meal_type.strip().lower()
    data = {
        "meal_type": meal_type,
        "description": body.description.strip() if body.description else None,
        "calories_kcal": body.calories_kcal,
        "feel_chips": body.feel_chips,
        "tags": body.tags,
        "notes": body.notes.strip() if body.notes else None,
        "quick_mode": body.quick_mode,
    }
    log = QuickLog(
        id=str(uuid.uuid4()),
        user_id=user_id,
        metric_type="meal",
        value=float(body.calories_kcal) if body.calories_kcal is not None else None,
        data=data,
        logged_at=_resolve_logged_at(body.logged_at),
    )
    db.add(log)
    await db.commit()
    await db.refresh(log)
    return {"id": log.id, "logged_at": str(log.logged_at), "type": "meal"}


@router.post("/supplements", summary="Log today's supplements taken")
@limiter.limit("10/minute")
async def log_supplements(
    request: Request,
    body: SupplementLogCreate,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Record which supplements the user took today.

    Validates that every supplement ID in taken_supplement_ids belongs to the
    authenticated user.  Foreign IDs (from a different account) are rejected
    with 422 to prevent enumeration.

    Args:
        request: The incoming FastAPI request (required by slowapi limiter).
        body: Supplement log payload.
        user_id: Authenticated user ID (injected by dependency).
        db: Async database session.

    Returns:
        Dict with id, logged_at, and type fields.

    Raises:
        HTTPException: 422 if any supplement ID does not belong to this user.
    """
    from app.models.user_supplement import UserSupplement  # noqa: PLC0415

    if body.notes and len(body.notes) > 500:
        raise HTTPException(status_code=422, detail="notes must not exceed 500 characters.")
    if body.taken_supplement_ids:
        result = await db.execute(
            select(UserSupplement.id).where(
                UserSupplement.id.in_(body.taken_supplement_ids),
                UserSupplement.user_id == user_id,
            )
        )
        valid_ids = {row[0] for row in result.all()}
        invalid = set(body.taken_supplement_ids) - valid_ids
        if invalid:
            raise HTTPException(
                status_code=422, detail="One or more supplement IDs are invalid or do not belong to this account."
            )
    data = {
        "taken_supplement_ids": body.taken_supplement_ids,
        "notes": body.notes.strip() if body.notes else None,
    }
    log = QuickLog(
        id=str(uuid.uuid4()),
        user_id=user_id,
        metric_type="supplement",
        value=float(len(body.taken_supplement_ids)),
        data=data,
        logged_at=_resolve_logged_at(body.logged_at),
    )
    db.add(log)
    await db.commit()
    await db.refresh(log)
    return {"id": log.id, "logged_at": str(log.logged_at), "type": "supplement"}


@router.post("/symptom", summary="Log a symptom")
@limiter.limit("20/minute")
async def log_symptom(
    request: Request,
    body: SymptomLogCreate,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Record a symptom entry.

    Args:
        request: The incoming FastAPI request (required by slowapi limiter).
        body: Symptom log payload.
        user_id: Authenticated user ID (injected by dependency).
        db: Async database session.

    Returns:
        Dict with id, logged_at, and type fields.

    Raises:
        HTTPException: 422 if body_areas is empty or severity is not a
            recognised value.
    """
    if not body.body_areas:
        raise HTTPException(status_code=422, detail="body_areas must not be empty.")
    if body.severity not in _VALID_SEVERITY:
        raise HTTPException(
            status_code=422,
            detail=f"severity must be one of {sorted(_VALID_SEVERITY)}.",
        )
    if body.notes and len(body.notes) > 500:
        raise HTTPException(status_code=422, detail="notes must not exceed 500 characters.")
    data = {
        "body_areas": body.body_areas,
        "severity": body.severity,
        "symptom_type": body.symptom_type,
        "timing": body.timing,
        "notes": body.notes.strip() if body.notes else None,
    }
    log = QuickLog(
        id=str(uuid.uuid4()),
        user_id=user_id,
        metric_type="symptom",
        text_value=body.severity,
        data=data,
        logged_at=_resolve_logged_at(body.logged_at),
    )
    db.add(log)
    await db.commit()
    await db.refresh(log)
    return {"id": log.id, "logged_at": str(log.logged_at), "type": "symptom"}


@router.post("/water", summary="Log a water intake entry")
@limiter.limit("60/minute")
async def log_water(
    request: Request,
    body: WaterLogCreate,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Record a water intake entry.

    Args:
        request: The incoming FastAPI request (required by slowapi limiter).
        body: Water log payload.
        user_id: Authenticated user ID (injected by dependency).
        db: Async database session.

    Returns:
        Dict with id, logged_at, and type fields.

    Raises:
        HTTPException: 422 if amount_ml is out of range.
    """
    if not (1 <= body.amount_ml <= 5000):
        raise HTTPException(
            status_code=422,
            detail="amount_ml must be between 1 and 5000.",
        )
    if body.vessel_key and len(body.vessel_key) > 100:
        raise HTTPException(
            status_code=422,
            detail="vessel_key must not exceed 100 characters.",
        )
    data = {
        "amount_ml": body.amount_ml,
        "vessel_key": body.vessel_key,
    }
    log = QuickLog(
        id=str(uuid.uuid4()),
        user_id=user_id,
        metric_type="water",
        value=body.amount_ml,
        data=data,
        logged_at=_resolve_logged_at(body.logged_at),
    )
    db.add(log)
    await db.commit()
    await db.refresh(log)
    return {"id": log.id, "logged_at": str(log.logged_at), "type": "water"}


@router.post("/wellness", summary="Log a wellness check-in")
@limiter.limit("30/minute")
async def log_wellness(
    request: Request,
    body: WellnessLogCreate,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Record a wellness check-in with optional mood, energy, and stress values.

    Stores one quick_log row per submitted metric. At least one of mood,
    energy, or stress must be provided.

    Args:
        request: The incoming FastAPI request (required by slowapi limiter).
        body: Wellness check-in payload.
        user_id: Authenticated user ID (injected by dependency).
        db: Async database session.

    Returns:
        Dict with logged_at and type fields, plus a list of created entry IDs.

    Raises:
        HTTPException: 422 if all three of mood/energy/stress are null, any
            value is out of range, or notes exceeds 500 characters.
    """
    if all(v is None for v in [body.mood, body.energy, body.stress]):
        raise HTTPException(
            status_code=422,
            detail="At least one of mood, energy, or stress must be provided.",
        )
    for field_name, field_val in [("mood", body.mood), ("energy", body.energy), ("stress", body.stress)]:
        if field_val is not None and not (1.0 <= field_val <= 10.0):
            raise HTTPException(
                status_code=422,
                detail=f"{field_name} must be between 1.0 and 10.0.",
            )
    if body.notes and len(body.notes) > 500:
        raise HTTPException(status_code=422, detail="notes must not exceed 500 characters.")

    resolved_at = _resolve_logged_at(body.logged_at)
    notes_clean = body.notes.strip() if body.notes else None
    logs = []
    for metric, val in [("mood", body.mood), ("energy", body.energy), ("stress", body.stress)]:
        if val is not None:
            logs.append(
                QuickLog(
                    id=str(uuid.uuid4()),
                    user_id=user_id,
                    metric_type=metric,
                    value=val,
                    data={"notes": notes_clean} if notes_clean else {},
                    logged_at=resolved_at,
                )
            )
    db.add_all(logs)
    await db.commit()
    for log in logs:
        await db.refresh(log)
    ids = [log.id for log in logs]
    return {"ids": ids, "logged_at": resolved_at, "type": "wellness"}


@router.post("/weight", summary="Log a body weight entry")
@limiter.limit("10/minute")
async def log_weight(
    request: Request,
    body: WeightLogCreate,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Record a body weight entry. Always stored in kilograms.

    Args:
        request: The incoming FastAPI request (required by slowapi limiter).
        body: Weight log payload with value in kg.
        user_id: Authenticated user ID (injected by dependency).
        db: Async database session.

    Returns:
        Dict with id, logged_at, and type fields.

    Raises:
        HTTPException: 422 if value_kg is out of range.
    """
    if not (20.0 <= body.value_kg <= 500.0):
        raise HTTPException(
            status_code=422,
            detail="value_kg must be between 20.0 and 500.0.",
        )
    log = QuickLog(
        id=str(uuid.uuid4()),
        user_id=user_id,
        metric_type="weight",
        value=body.value_kg,
        data={"value_kg": body.value_kg},
        logged_at=_resolve_logged_at(body.logged_at),
    )
    db.add(log)
    await db.commit()
    await db.refresh(log)
    return {"id": log.id, "logged_at": str(log.logged_at), "type": "weight"}


@router.post("/steps", summary="Log a step count")
@limiter.limit("10/minute")
async def log_steps(
    request: Request,
    body: StepsLogCreate,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Record a step count entry.

    mode='add' accumulates on today's running total.
    mode='override' acts as a reset point; earlier entries for today are
    ignored when the summary is computed.

    Args:
        request: The incoming FastAPI request (required by slowapi limiter).
        body: Steps log payload.
        user_id: Authenticated user ID (injected by dependency).
        db: Async database session.

    Returns:
        Dict with id, logged_at, and type fields.

    Raises:
        HTTPException: 422 if steps is out of range or mode is invalid.
    """
    if not (0 <= body.steps <= 100_000):
        raise HTTPException(
            status_code=422,
            detail="steps must be between 0 and 100,000.",
        )
    if body.mode not in ("add", "override"):
        raise HTTPException(
            status_code=422,
            detail="mode must be 'add' or 'override'.",
        )
    if body.source not in ("manual", "apple_health", "health_connect"):
        raise HTTPException(
            status_code=422,
            detail="source must be 'manual', 'apple_health', or 'health_connect'.",
        )
    data = {"steps": body.steps, "mode": body.mode, "source": body.source}
    log = QuickLog(
        id=str(uuid.uuid4()),
        user_id=user_id,
        metric_type="steps",
        value=float(body.steps),
        data=data,
        logged_at=_resolve_logged_at(body.logged_at),
    )
    db.add(log)
    await db.commit()
    await db.refresh(log)
    return {"id": log.id, "logged_at": str(log.logged_at), "type": "steps"}


@router.get("/my-metric-types", summary="Get all metric types the user has ever logged")
@limiter.limit("60/minute")
async def get_my_metric_types(
    request: Request,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Return the distinct metric type strings this user has ever logged.

    Used by the mobile app to determine which snapshot cards to display.
    Returns at most ~12 values (one per supported metric type).

    Args:
        request: The incoming FastAPI request (required by slowapi limiter).
        user_id: Authenticated user ID (injected by dependency).
        db: Async database session.

    Returns:
        Dict with a ``metric_types`` list of distinct type strings.
    """
    result = await db.execute(select(distinct(QuickLog.metric_type)).where(QuickLog.user_id == user_id))
    types = sorted(row[0] for row in result.all())
    return {"metric_types": types}


@router.get("/summary/today", summary="Get today's aggregated log summary")
@limiter.limit("60/minute")
async def get_summary_today(
    request: Request,
    tz_offset: int = 0,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Return an aggregated summary of the authenticated user's logs for today.

    'Today' is the calendar day in the user's local timezone, determined by
    the tz_offset query parameter (minutes offset from UTC, e.g. -300 for EST).

    Aggregation rules per metric type:
    - water, meal, supplement: cumulative sum
    - steps: sum of 'add' entries; an 'override' entry resets the count
    - mood, energy, stress, weight, sleep, run: latest value today

    Args:
        request: The incoming FastAPI request (required by slowapi limiter).
        tz_offset: User's timezone offset from UTC in minutes. Defaults to 0 (UTC).
        user_id: Authenticated user ID (injected by dependency).
        db: Async database session.

    Returns:
        Dict with logged_types (list of strings) and latest_values (dict).

    Raises:
        HTTPException: 422 if tz_offset is outside [-720, 840].
    """
    if not (-720 <= tz_offset <= 840):
        raise HTTPException(
            status_code=422,
            detail="tz_offset must be between -720 and 840 minutes.",
        )

    now_utc = datetime.now(timezone.utc)
    user_offset = timedelta(minutes=tz_offset)
    now_local = now_utc + user_offset
    today_start_local = now_local.replace(hour=0, minute=0, second=0, microsecond=0)
    today_start_utc = today_start_local - user_offset
    today_end_utc = today_start_utc + timedelta(hours=24)

    result = await db.execute(
        select(QuickLog)
        .where(
            QuickLog.user_id == user_id,
            QuickLog.logged_at >= today_start_utc,
            QuickLog.logged_at < today_end_utc,
        )
        .order_by(QuickLog.logged_at.asc())
    )
    logs = result.scalars().all()

    logged_types, latest_values = _aggregate_today_logs(logs)
    return {"logged_types": logged_types, "latest_values": latest_values}


# ---------------------------------------------------------------------------
# Latest values endpoint
# ---------------------------------------------------------------------------


@router.get("/latest", summary="Get the most recent log entry per requested metric type")
@limiter.limit("60/minute")
async def get_latest_log_values(
    request: Request,
    types: str = "",
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Return the most recent quick-log entry for each requested metric type.

    The Cloud Brain is the authoritative deduplicated source — data ingested
    from Apple Health, Health Connect, Strava, and manual entries is all
    surfaced here.

    Args:
        request: The incoming FastAPI request (required by slowapi limiter).
        types: Comma-separated list of metric type strings (e.g. 'weight,steps').
               If absent or empty, returns an empty dict.
        user_id: Authenticated user ID (injected by dependency).
        db: Async database session.

    Returns:
        Dict keyed by metric type. Each value is a dict with type-specific
        fields plus ``logged_at`` and ``source``.
        Types that have never been logged are absent from the response.

    Raises:
        HTTPException: 422 if any requested type is not in VALID_METRIC_TYPES, or
            if more than 12 types are requested.
    """
    if not types or not types.strip():
        return {}

    requested = list(dict.fromkeys(t.strip() for t in types.split(",") if t.strip()))

    if len(requested) > 12:
        raise HTTPException(
            status_code=422,
            detail="Maximum 12 types per request.",
        )

    for t in requested:
        if t not in VALID_METRIC_TYPES:
            raise HTTPException(
                status_code=422,
                detail=f"Invalid metric type '{t}'. Must be one of: {sorted(VALID_METRIC_TYPES)}.",
            )

    # Single query: most recent row per metric type for this user.
    # ROW_NUMBER window function is standard SQL and works on all backends.
    subq = (
        select(
            QuickLog,
            func.row_number()
            .over(
                partition_by=QuickLog.metric_type,
                order_by=QuickLog.logged_at.desc(),
            )
            .label("rn"),
        )
        .where(
            QuickLog.user_id == user_id,
            QuickLog.metric_type.in_(requested),
        )
        .subquery()
    )
    stmt = select(QuickLog).where(
        QuickLog.id == subq.c.id,
        subq.c.rn == 1,
    )
    rows = (await db.execute(stmt)).scalars().all()
    logs_by_type: dict[str, QuickLog] = {log.metric_type: log for log in rows}

    result: dict = {}
    for metric_type in requested:
        log = logs_by_type.get(metric_type)
        if log is None:
            continue

        logged_at_str = log.logged_at.isoformat() if hasattr(log.logged_at, "isoformat") else str(log.logged_at)
        source = (log.data or {}).get("source", "manual")

        if metric_type == "weight":
            result["weight"] = {
                "value_kg": log.value,
                "logged_at": logged_at_str,
                "source": source,
            }
        elif metric_type == "steps":
            result["steps"] = {
                "steps": int(log.value or 0),
                "logged_at": logged_at_str,
                "source": source,
            }
        else:
            # Generic fallback for other types — value + logged_at + source
            result[metric_type] = {
                "value": log.value,
                "text_value": log.text_value,
                "logged_at": logged_at_str,
                "source": source,
            }

    return result


# ---------------------------------------------------------------------------
# Supplement list management
# ---------------------------------------------------------------------------


@router.get("/user/supplements-list", summary="Get user's saved supplement list")
@limiter.limit("30/minute")
async def get_supplements_list(
    request: Request,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Return the user's active supplement list ordered by sort_order then created_at.

    Args:
        request: The incoming FastAPI request (required by slowapi limiter).
        user_id: Authenticated user ID (injected by dependency).
        db: Async database session.

    Returns:
        Dict with a ``supplements`` list containing id, name, dose, and timing.
    """
    from app.models.user_supplement import UserSupplement  # noqa: PLC0415

    result = await db.execute(
        select(UserSupplement)
        .where(UserSupplement.user_id == user_id, UserSupplement.is_active == True)  # noqa: E712
        .order_by(UserSupplement.sort_order, UserSupplement.created_at)
    )
    supplements = result.scalars().all()
    return {"supplements": [{"id": s.id, "name": s.name, "dose": s.dose, "timing": s.timing} for s in supplements]}


@router.post("/user/supplements-list", summary="Replace user's supplement list")
@limiter.limit("10/minute")
async def update_supplements_list(
    request: Request,
    body: SupplementListCreate,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Replace the user's active supplement list with a new ordered set.

    Existing active items are soft-deleted (is_active=False) rather than
    physically removed so that past supplement logs that reference their IDs
    remain valid.  New items are inserted with sort_order derived from their
    position in the submitted array.

    Args:
        request: The incoming FastAPI request (required by slowapi limiter).
        body: New supplement list.
        user_id: Authenticated user ID (injected by dependency).
        db: Async database session.

    Returns:
        Dict with the newly created ``supplements`` list.

    Raises:
        HTTPException: 422 if more than 50 supplements are submitted or any
            name is empty or too long.
    """
    from app.models.user_supplement import UserSupplement  # noqa: PLC0415

    if len(body.supplements) > 50:
        raise HTTPException(status_code=422, detail="Maximum 50 supplements per user.")
    for entry in body.supplements:
        if not entry.name or not entry.name.strip():
            raise HTTPException(status_code=422, detail="Supplement name must not be empty.")
        if len(entry.name) > 200:
            raise HTTPException(
                status_code=422,
                detail="Supplement name must not exceed 200 characters.",
            )
    # Soft-delete existing active items so past logs retain referential integrity.
    existing = await db.execute(
        select(UserSupplement).where(
            UserSupplement.user_id == user_id,
            UserSupplement.is_active == True,  # noqa: E712
        )
    )
    for row in existing.scalars().all():
        row.is_active = False
        row.updated_at = datetime.now(timezone.utc)
    new_items = [
        UserSupplement(
            id=str(uuid.uuid4()),
            user_id=user_id,
            name=entry.name.strip(),
            dose=entry.dose.strip() if entry.dose else None,
            timing=entry.timing,
            sort_order=idx,
        )
        for idx, entry in enumerate(body.supplements)
    ]
    db.add_all(new_items)
    await db.commit()
    return {"supplements": [{"id": s.id, "name": s.name, "dose": s.dose, "timing": s.timing} for s in new_items]}
