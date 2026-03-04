"""
Zuralog Cloud Brain — Insight Feed API Router.

Provides REST endpoints for the user-facing insight card feed:

- GET  /insights           — paginated, filterable list ordered by priority
- GET  /insights/unread-count — badge count of unread insights
- PATCH /insights/{id}     — mark an insight as read or dismissed

All endpoints require a valid Supabase JWT. Ownership is enforced at the
query level: every query filters by the authenticated user_id so no user
can read or mutate another user's insights.
"""

import logging
from datetime import datetime, timezone
from typing import Any

import sentry_sdk
from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, ConfigDict
from sqlalchemy import and_, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.deps import get_authenticated_user_id
from app.database import get_db
from app.models.insight import Insight, InsightType

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Response schemas
# ---------------------------------------------------------------------------


class InsightResponse(BaseModel):
    """Serialised representation of a single insight card.

    Attributes:
        id: Unique insight UUID.
        user_id: Owner's user ID.
        type: Insight category string (``InsightType`` value).
        title: Short headline.
        body: Full insight copy.
        data: Optional structured payload (charts, numbers).
        priority: 1 = highest, 10 = lowest.
        created_at: ISO-8601 UTC creation timestamp.
        read_at: ISO-8601 UTC read timestamp, or ``None``.
        dismissed_at: ISO-8601 UTC dismissal timestamp, or ``None``.
        is_read: Derived convenience flag.
        is_dismissed: Derived convenience flag.
    """

    model_config = ConfigDict(from_attributes=True)

    id: str
    user_id: str
    type: str
    title: str
    body: str
    data: dict | None = None
    priority: int
    created_at: datetime
    read_at: datetime | None = None
    dismissed_at: datetime | None = None
    is_read: bool
    is_dismissed: bool


class InsightListResponse(BaseModel):
    """Paginated list of insight cards.

    Attributes:
        total: Total number of insights matching the filter (for pagination UI).
        limit: Requested page size.
        offset: Requested page offset.
        items: Insights for this page.
    """

    total: int
    limit: int
    offset: int
    items: list[InsightResponse]


class InsightPatchRequest(BaseModel):
    """Request body for marking an insight read or dismissed.

    At least one field must be ``True``; both can be ``True`` simultaneously.

    Attributes:
        mark_read: Set ``read_at = now()`` when ``True``.
        mark_dismissed: Set ``dismissed_at = now()`` when ``True``.
    """

    mark_read: bool = False
    mark_dismissed: bool = False


class UnreadCountResponse(BaseModel):
    """Unread insight badge count.

    Attributes:
        unread_count: Number of insights with ``read_at IS NULL``.
    """

    unread_count: int


# ---------------------------------------------------------------------------
# Router
# ---------------------------------------------------------------------------


async def _set_sentry_module() -> None:
    sentry_sdk.set_tag("api.module", "insights")


router = APIRouter(
    prefix="/insights",
    tags=["insights"],
    dependencies=[Depends(_set_sentry_module)],
)


# ------------------------------------------------------------------
# Helper: build InsightResponse from ORM row
# ------------------------------------------------------------------


def _to_response(insight: Insight) -> InsightResponse:
    """Convert an ORM Insight row to a response schema.

    Args:
        insight: SQLAlchemy Insight model instance.

    Returns:
        InsightResponse populated from the model.
    """
    return InsightResponse(
        id=insight.id,
        user_id=insight.user_id,
        type=insight.type,
        title=insight.title,
        body=insight.body,
        data=insight.data,
        priority=insight.priority,
        created_at=insight.created_at,
        read_at=insight.read_at,
        dismissed_at=insight.dismissed_at,
        is_read=insight.is_read,
        is_dismissed=insight.is_dismissed,
    )


# ---------------------------------------------------------------------------
# GET /insights/unread-count — MUST be declared BEFORE /{insight_id} to
# avoid FastAPI routing the literal path "unread-count" to the param route.
# ---------------------------------------------------------------------------


@router.get(
    "/unread-count",
    response_model=UnreadCountResponse,
    summary="Unread insight badge count",
)
async def get_unread_count(
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> UnreadCountResponse:
    """Return the number of unread insights for the authenticated user.

    Intended for the mobile badge indicator. Only counts non-dismissed,
    unread insights.

    Args:
        user_id: Injected authenticated user ID.
        db: Injected async database session.

    Returns:
        UnreadCountResponse with the count of unread insights.
    """
    stmt = (
        select(func.count())
        .select_from(Insight)
        .where(
            and_(
                Insight.user_id == user_id,
                Insight.read_at.is_(None),
                Insight.dismissed_at.is_(None),
            )
        )
    )
    result = await db.execute(stmt)
    count: int = result.scalar_one()
    return UnreadCountResponse(unread_count=count)


# ---------------------------------------------------------------------------
# GET /insights
# ---------------------------------------------------------------------------


@router.get(
    "",
    response_model=InsightListResponse,
    summary="List insight cards",
)
async def list_insights(
    limit: int = Query(default=20, ge=1, le=100, description="Page size"),
    offset: int = Query(default=0, ge=0, description="Page offset"),
    type: InsightType | None = Query(default=None, description="Filter by insight type"),
    from_date: datetime | None = Query(
        default=None,
        description="Filter insights created at or after this UTC datetime",
    ),
    to_date: datetime | None = Query(
        default=None,
        description="Filter insights created before or at this UTC datetime",
    ),
    include_dismissed: bool = Query(
        default=False,
        description="Include dismissed insights (excluded by default)",
    ),
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> InsightListResponse:
    """Return a paginated, filterable list of insight cards.

    Results are ordered by priority (ascending, 1 = most important) then
    ``created_at`` descending so the freshest high-priority cards appear
    first.

    Args:
        limit: Maximum number of insights to return (1–100).
        offset: Number of insights to skip for pagination.
        type: Optional insight type filter.
        from_date: Optional lower bound on ``created_at``.
        to_date: Optional upper bound on ``created_at``.
        include_dismissed: When False (default), dismissed insights are hidden.
        user_id: Injected authenticated user ID.
        db: Injected async database session.

    Returns:
        InsightListResponse with total count, pagination meta, and items.
    """
    filters: list[Any] = [Insight.user_id == user_id]

    if type is not None:
        filters.append(Insight.type == type.value)

    if from_date is not None:
        filters.append(Insight.created_at >= from_date)

    if to_date is not None:
        filters.append(Insight.created_at <= to_date)

    if not include_dismissed:
        filters.append(Insight.dismissed_at.is_(None))

    where_clause = and_(*filters)

    # Total count for pagination header
    count_stmt = select(func.count()).select_from(Insight).where(where_clause)
    total: int = (await db.execute(count_stmt)).scalar_one()

    # Paginated data
    data_stmt = (
        select(Insight)
        .where(where_clause)
        .order_by(Insight.priority.asc(), Insight.created_at.desc())
        .offset(offset)
        .limit(limit)
    )
    rows = (await db.execute(data_stmt)).scalars().all()

    return InsightListResponse(
        total=total,
        limit=limit,
        offset=offset,
        items=[_to_response(r) for r in rows],
    )


# ---------------------------------------------------------------------------
# PATCH /insights/{insight_id}
# ---------------------------------------------------------------------------


@router.patch(
    "/{insight_id}",
    response_model=InsightResponse,
    summary="Mark an insight read or dismissed",
)
async def patch_insight(
    insight_id: str,
    body: InsightPatchRequest,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> InsightResponse:
    """Mark an insight as read and/or dismissed.

    Both ``mark_read`` and ``mark_dismissed`` can be set in a single call.
    Already-set timestamps are NOT overwritten (idempotent).

    Args:
        insight_id: UUID of the insight to update.
        body: Patch request indicating which flags to set.
        user_id: Injected authenticated user ID.
        db: Injected async database session.

    Returns:
        The updated InsightResponse.

    Raises:
        HTTPException 404: Insight not found.
        HTTPException 403: Insight belongs to another user.
        HTTPException 400: No action requested.
    """
    if not body.mark_read and not body.mark_dismissed:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="At least one of mark_read or mark_dismissed must be true.",
        )

    stmt = select(Insight).where(Insight.id == insight_id)
    result = await db.execute(stmt)
    insight: Insight | None = result.scalar_one_or_none()

    if insight is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Insight not found.",
        )

    if insight.user_id != user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied.",
        )

    now = datetime.now(tz=timezone.utc)

    if body.mark_read and insight.read_at is None:
        insight.read_at = now

    if body.mark_dismissed and insight.dismissed_at is None:
        insight.dismissed_at = now

    await db.commit()
    await db.refresh(insight)

    return _to_response(insight)
