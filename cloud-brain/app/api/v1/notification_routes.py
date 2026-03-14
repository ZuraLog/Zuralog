"""
Zuralog Cloud Brain — Notification API.

Endpoints:
  GET   /api/v1/notifications                   — Paginated notification history, ordered by date DESC.
  PATCH /api/v1/notifications/{notification_id} — Mark a notification as read.

All endpoints are auth-guarded via ``get_authenticated_user_id``.
Notifications are strictly scoped to the authenticated user.
"""

import logging
from datetime import datetime, timezone
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, ConfigDict
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_authenticated_user_id
from app.database import get_db
from app.models.notification_log import NotificationLog

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/notifications", tags=["notifications"])


# ---------------------------------------------------------------------------
# Pydantic schemas
# ---------------------------------------------------------------------------


class NotificationResponse(BaseModel):
    """Serialised notification log entry returned to the client.

    All datetime fields are returned as ISO-8601 strings for easy parsing
    by the Flutter client.

    Attributes:
        id: UUID primary key.
        user_id: Owner user ID.
        title: Notification title text.
        body: Notification body text.
        type: Notification category (e.g. ``insight``, ``streak``).
        deep_link: Optional URI for in-app navigation, or ``None``.
        sent_at: ISO-8601 timestamp when the notification was sent.
        read_at: ISO-8601 timestamp when it was read, or ``None`` if unread.
    """

    id: str
    user_id: str
    title: str
    body: str
    type: str
    deep_link: str | None
    sent_at: str
    read_at: str | None

    model_config = ConfigDict(from_attributes=True)


class NotificationListResponse(BaseModel):
    """Paginated envelope for GET /notifications.

    Attributes:
        notifications: The page of notification records.
        total: Total number of notifications for this user.
        page: Current page number (1-indexed).
        page_size: Number of records per page.
    """

    notifications: list[NotificationResponse]
    total: int
    page: int
    page_size: int


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _dt_str(value: Any) -> str | None:
    """Return an ISO-8601 string for a datetime value, or None.

    Args:
        value: A ``datetime`` instance, string, or ``None``.

    Returns:
        ISO-8601 formatted string, or ``None``.
    """
    if value is None:
        return None
    if isinstance(value, datetime):
        return value.isoformat()
    return str(value)


def _notification_to_response(row: NotificationLog) -> NotificationResponse:
    """Convert a ``NotificationLog`` ORM row to a ``NotificationResponse``.

    Args:
        row: The ORM instance to serialise.

    Returns:
        A ``NotificationResponse`` ready for JSON encoding.
    """
    return NotificationResponse(
        id=row.id,
        user_id=row.user_id,
        title=row.title,
        body=row.body,
        type=row.type,
        deep_link=row.deep_link,
        sent_at=_dt_str(row.sent_at) or "",
        read_at=_dt_str(row.read_at),
    )


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------


@router.get("", summary="List notification history", response_model=NotificationListResponse)
async def list_notifications(
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
    page: int = Query(1, ge=1, description="Page number (1-indexed)"),
    page_size: int = Query(20, ge=1, le=100, description="Number of records per page"),
) -> dict[str, Any]:
    """Return paginated notification history for the authenticated user.

    Notifications are ordered by ``sent_at`` DESC (most recent first).

    Args:
        user_id: Authenticated user ID (injected by dependency).
        db: Async database session.
        page: Page number, 1-indexed.
        page_size: Number of records per page (1–100, default 20).

    Returns:
        ``{ notifications, total, page, page_size }`` envelope.
    """
    offset = (page - 1) * page_size

    # Count total notifications for this user
    count_stmt = (
        select(func.count())
        .select_from(NotificationLog)
        .where(NotificationLog.user_id == user_id)
    )
    count_result = await db.execute(count_stmt)
    total: int = count_result.scalar_one()

    # Fetch paginated page
    stmt = (
        select(NotificationLog)
        .where(NotificationLog.user_id == user_id)
        .order_by(NotificationLog.sent_at.desc())
        .limit(page_size)
        .offset(offset)
    )
    result = await db.execute(stmt)
    rows = result.scalars().all()

    notifications = [_notification_to_response(row) for row in rows]

    logger.debug(
        "list_notifications: user=%s total=%d page=%d page_size=%d returned=%d",
        user_id,
        total,
        page,
        page_size,
        len(notifications),
    )

    return {
        "notifications": [n.model_dump() for n in notifications],
        "total": total,
        "page": page,
        "page_size": page_size,
    }


@router.patch("/{notification_id}", summary="Mark notification as read")
async def mark_notification_read(
    notification_id: str,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> dict[str, Any]:
    """Mark a notification as read by setting ``read_at`` to now.

    The operation is idempotent — calling it on an already-read notification
    succeeds and returns the existing ``read_at`` timestamp unchanged.

    Args:
        notification_id: UUID of the notification to mark as read.
        user_id: Authenticated user ID (injected by dependency).
        db: Async database session.

    Returns:
        Updated ``NotificationResponse`` dict.

    Raises:
        HTTPException: 404 if the notification does not exist or belongs
            to a different user.
    """
    result = await db.execute(
        select(NotificationLog).where(
            NotificationLog.id == notification_id,
            NotificationLog.user_id == user_id,
        )
    )
    notification = result.scalar_one_or_none()

    if notification is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Notification not found.",
        )

    if notification.read_at is None:
        notification.read_at = datetime.now(timezone.utc)  # type: ignore[assignment]
        await db.commit()
        await db.refresh(notification)
        logger.info(
            "notification marked read: id=%s user=%s", notification_id, user_id
        )

    return _notification_to_response(notification).model_dump()
