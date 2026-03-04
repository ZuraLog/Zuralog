"""
Zuralog Cloud Brain — Insight API.

Endpoints:
  GET  /api/v1/insights          — Paginated list of non-dismissed insight cards.
  PATCH /api/v1/insights/{id}    — Mark an insight as read or dismissed.

All endpoints are auth-guarded via ``get_authenticated_user_id``.
Dismissed insights are permanently excluded from GET responses.
"""

import logging
from datetime import datetime, timezone
from typing import Any, Literal

import sentry_sdk
from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, ConfigDict
from sqlalchemy import and_, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.deps import get_authenticated_user_id
from app.database import get_db
from app.models.insight import Insight

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/insights", tags=["insights"])

# ---------------------------------------------------------------------------
# Pydantic schemas
# ---------------------------------------------------------------------------


class InsightResponse(BaseModel):
    """Serialised insight card returned to the client.

    All datetime fields are returned as ISO-8601 strings so Flutter can
    parse them with ``DateTime.parse``. The ``data`` dict is passed
    through as-is for the card renderer to consume.

    Attributes:
        id: UUID primary key.
        user_id: Owner user ID.
        type: Insight category (e.g. ``sleep_analysis``, ``goal_nudge``).
        title: Short headline for the card.
        body: Full card body text.
        data: Arbitrary JSON payload for rich rendering.
        reasoning: Optional AI explanation, or ``None`` for rule-based cards.
        priority: 1 (highest) – 10 (lowest).
        created_at: ISO-8601 creation timestamp string.
        read_at: ISO-8601 read timestamp, or ``None`` if unread.
        dismissed_at: ISO-8601 dismiss timestamp, or ``None`` if not dismissed.
    """

    id: str
    user_id: str
    type: str
    title: str
    body: str
    data: dict
    reasoning: str | None
    priority: int
    created_at: str
    read_at: str | None
    dismissed_at: str | None

    model_config = ConfigDict(from_attributes=True)


class InsightListResponse(BaseModel):
    """Paginated envelope for the GET /insights response.

    Attributes:
        insights: The page of insight cards.
        total: Total number of non-dismissed insights matching the filter.
        has_more: True if there are additional pages beyond this one.
    """

    insights: list[InsightResponse]
    total: int
    has_more: bool


class InsightActionRequest(BaseModel):
    """Request body for PATCH /insights/{insight_id}.

    Attributes:
        action: ``"read"`` sets ``read_at``; ``"dismiss"`` sets
            ``dismissed_at``. Both are idempotent.
    """

    action: Literal["read", "dismiss"]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _insight_to_response(insight: Insight) -> InsightResponse:
    """Convert an ORM Insight instance to an InsightResponse.

    Datetime columns are stored as Python ``datetime`` objects by
    SQLAlchemy but the Pydantic schema expects strings. We convert here
    so the schema stays simple (no custom validators needed on the client).

    Args:
        insight: The ORM row to serialise.

    Returns:
        An ``InsightResponse`` ready to be JSON-encoded.
    """

    def _dt_str(value: Any) -> str | None:
        """Return ISO-8601 string or None."""
        if value is None:
            return None
        if isinstance(value, datetime):
            return value.isoformat()
        return str(value)

    return InsightResponse(
        id=insight.id,
        user_id=insight.user_id,
        type=insight.type,
        title=insight.title,
        body=insight.body,
        data=insight.data or {},
        reasoning=insight.reasoning,
        priority=insight.priority,
        created_at=_dt_str(insight.created_at) or "",
        read_at=_dt_str(insight.read_at),
        dismissed_at=_dt_str(insight.dismissed_at),
    )


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------


@router.get("", summary="List insight cards", response_model=InsightListResponse)
async def list_insights(
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
    type: str | None = Query(None, description="Filter by insight type (e.g. sleep_analysis)"),
    date_from: str | None = Query(None, description="ISO date lower bound (YYYY-MM-DD, inclusive)"),
    date_to: str | None = Query(None, description="ISO date upper bound (YYYY-MM-DD, inclusive)"),
    limit: int = Query(20, ge=1, le=100, description="Page size"),
    offset: int = Query(0, ge=0, description="Pagination offset"),
) -> dict[str, Any]:
    """Return a paginated list of non-dismissed insight cards for the authenticated user.

    Cards are ordered by **priority ASC** (most urgent first), then
    **created_at DESC** (newest within each priority tier first).

    Args:
        user_id: Authenticated user ID (injected by dependency).
        db: Async database session.
        type: Optional insight type filter.
        date_from: Optional ISO date (YYYY-MM-DD) lower bound on ``created_at``.
        date_to: Optional ISO date (YYYY-MM-DD) upper bound on ``created_at``.
        limit: Page size (1–100, default 20).
        offset: Pagination offset (default 0).

    Returns:
        ``{ insights, total, has_more }`` envelope.
    """
    sentry_sdk.set_user({"id": user_id})

    # Base filter: user's non-dismissed insights
    filters = [
        Insight.user_id == user_id,
        Insight.dismissed_at.is_(None),
    ]

    if type is not None:
        filters.append(Insight.type == type)

    if date_from is not None:
        filters.append(Insight.created_at >= date_from)

    if date_to is not None:
        # Treat date_to as end-of-day by appending a time component
        filters.append(Insight.created_at <= f"{date_to}T23:59:59")

    where_clause = and_(*filters)

    # Count total matching rows (before pagination)
    count_stmt = select(func.count()).select_from(Insight).where(where_clause)
    count_result = await db.execute(count_stmt)
    total: int = count_result.scalar_one()

    # Fetch page
    stmt = (
        select(Insight)
        .where(where_clause)
        .order_by(Insight.priority.asc(), Insight.created_at.desc())
        .limit(limit)
        .offset(offset)
    )
    result = await db.execute(stmt)
    rows = result.scalars().all()

    insights = [_insight_to_response(row) for row in rows]
    has_more = (offset + len(insights)) < total

    logger.debug(
        "list_insights: user=%s total=%d offset=%d limit=%d returned=%d",
        user_id,
        total,
        offset,
        limit,
        len(insights),
    )

    return {
        "insights": [i.model_dump() for i in insights],
        "total": total,
        "has_more": has_more,
    }


@router.patch("/{insight_id}", summary="Mark insight as read or dismissed")
async def update_insight(
    insight_id: str,
    body: InsightActionRequest,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> dict[str, Any]:
    """Mark an insight as read or dismissed.

    Both actions are idempotent — repeated calls for an already-read or
    already-dismissed insight succeed with 200 and the existing timestamp.

    Args:
        insight_id: UUID of the insight to update.
        body: ``{ "action": "read" | "dismiss" }``.
        user_id: Authenticated user ID (injected by dependency).
        db: Async database session.

    Returns:
        Updated ``InsightResponse`` dict.

    Raises:
        HTTPException: 404 if the insight does not exist or belongs to
            a different user.
    """
    sentry_sdk.set_user({"id": user_id})

    result = await db.execute(
        select(Insight).where(
            Insight.id == insight_id,
            Insight.user_id == user_id,
        )
    )
    insight = result.scalar_one_or_none()

    if insight is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Insight not found.",
        )

    now = datetime.now(timezone.utc)

    if body.action == "read":
        if insight.read_at is None:
            insight.read_at = now  # type: ignore[assignment]
            logger.info("insight marked read: id=%s user=%s", insight_id, user_id)
    elif body.action == "dismiss":
        if insight.dismissed_at is None:
            insight.dismissed_at = now  # type: ignore[assignment]
            logger.info("insight dismissed: id=%s user=%s", insight_id, user_id)

    await db.commit()
    await db.refresh(insight)

    return _insight_to_response(insight).model_dump()
