"""
Zuralog Cloud Brain — Notification Routes.

REST endpoints for the in-app notification centre:
  GET  /api/v1/notifications           — paginated feed grouped by day
  GET  /api/v1/notifications/unread-count  — unread badge count
  PATCH /api/v1/notifications/{id}     — mark a notification as read

Authentication: Bearer JWT via ``get_authenticated_user_id``.
"""

from __future__ import annotations

import logging
from collections import defaultdict
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.deps import get_authenticated_user_id
from app.database import get_db
from app.models.notification_log import NotificationLog

logger = logging.getLogger(__name__)

router = APIRouter(tags=["notifications"])


# ---------------------------------------------------------------------------
# Response helpers
# ---------------------------------------------------------------------------


def _group_by_day(notifications: list[NotificationLog]) -> list[dict]:
    """Group a list of NotificationLog records into day buckets.

    Each bucket is a dict with:
      - ``date``: ISO date string (YYYY-MM-DD)
      - ``notifications``: list of serialized notification dicts

    Args:
        notifications: Ordered list of NotificationLog objects.

    Returns:
        List of day-bucket dicts ordered by date descending.
    """
    buckets: dict[str, list[dict]] = defaultdict(list)
    for notif in notifications:
        if notif.sent_at:
            day = notif.sent_at.date().isoformat()
        else:
            day = notif.created_at.date().isoformat()
        buckets[day].append(notif.to_dict())

    # Sort dates descending (most recent day first).
    return [{"date": day, "notifications": notifs} for day, notifs in sorted(buckets.items(), reverse=True)]


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------


@router.get("/notifications/unread-count")
async def get_unread_count(
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Return the count of unread notifications for the authenticated user.

    Unread = ``read_at IS NULL``.

    Returns:
        ``{"unread_count": int}``
    """
    stmt = select(func.count(NotificationLog.id)).where(
        NotificationLog.user_id == user_id,
        NotificationLog.read_at.is_(None),
    )
    result = await db.execute(stmt)
    count: int = result.scalar_one_or_none() or 0
    return {"unread_count": count}


@router.get("/notifications")
async def list_notifications(
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
) -> dict:
    """Return a paginated, day-grouped notification feed for the user.

    Notifications are ordered by ``sent_at`` descending (newest first).

    Args:
        limit: Maximum number of notifications to return (1–200).
        offset: Number of records to skip for pagination.

    Returns:
        ``{"groups": [...], "total": int, "limit": int, "offset": int}``
        where each group is ``{"date": "YYYY-MM-DD", "notifications": [...]}``
    """
    # Total count for pagination metadata.
    count_stmt = select(func.count(NotificationLog.id)).where(
        NotificationLog.user_id == user_id,
    )
    count_result = await db.execute(count_stmt)
    total: int = count_result.scalar_one_or_none() or 0

    # Fetch the page.
    stmt = (
        select(NotificationLog)
        .where(NotificationLog.user_id == user_id)
        .order_by(NotificationLog.sent_at.desc())
        .limit(limit)
        .offset(offset)
    )
    result = await db.execute(stmt)
    notifications = result.scalars().all()

    groups = _group_by_day(list(notifications))

    return {
        "groups": groups,
        "total": total,
        "limit": limit,
        "offset": offset,
    }


@router.patch("/notifications/{notification_id}")
async def mark_notification_read(
    notification_id: str,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Mark a specific notification as read.

    Sets ``read_at = now()`` if the notification belongs to the
    authenticated user and has not already been read.

    Args:
        notification_id: UUID of the NotificationLog record.

    Returns:
        The updated notification dict.

    Raises:
        404 if the notification does not exist or belongs to another user.
    """
    stmt = select(NotificationLog).where(
        NotificationLog.id == notification_id,
        NotificationLog.user_id == user_id,
    )
    result = await db.execute(stmt)
    notification = result.scalar_one_or_none()

    if notification is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Notification not found",
        )

    if notification.read_at is None:
        notification.read_at = datetime.now(timezone.utc)
        await db.commit()
        await db.refresh(notification)
        logger.debug("Notification %s marked as read for user %s", notification_id, user_id)

    return notification.to_dict()
