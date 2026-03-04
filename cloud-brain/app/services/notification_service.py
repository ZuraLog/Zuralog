"""
Zuralog Cloud Brain — NotificationService.

Thin wrapper around PushService that adds persistence: every push
dispatched via this service is recorded in ``notification_logs`` so
the mobile app can display a full notification history feed.

Usage:
    notification_service = NotificationService(
        push_service=push_svc,
        db_factory=async_session,
    )
    log = await notification_service.send_and_persist(
        user_id="user-123",
        title="Your streak!",
        body="You hit 7 days in a row.",
        notification_type=NotificationType.STREAK,
        device_token="fcm-token-abc",
        deep_link="zuralog://streak/7",
    )
"""

from __future__ import annotations

import logging
from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.notification_log import NotificationLog, NotificationType
from app.services.push_service import PushService

logger = logging.getLogger(__name__)


class NotificationService:
    """Sends push notifications and persists them to ``notification_logs``.

    Attributes:
        push_service: PushService instance used for FCM dispatch.
        db_factory: Callable that returns an async context manager yielding
            an ``AsyncSession`` (e.g. ``async_session`` from database.py).
            Required when the service is called from a Celery task (no
            request-scoped DB session available). Pass ``None`` if you will
            always supply a session explicitly via ``send_and_persist``.
    """

    def __init__(self, push_service: PushService, db_factory=None) -> None:
        self.push_service = push_service
        self._db_factory = db_factory

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    async def send_and_persist(
        self,
        user_id: str,
        title: str,
        body: str,
        notification_type: NotificationType,
        device_token: str | None = None,
        deep_link: str | None = None,
        db: AsyncSession | None = None,
    ) -> NotificationLog:
        """Send a push notification and persist a NotificationLog record.

        Steps:
        1. Create and persist a ``NotificationLog`` row with the current UTC
           timestamp as ``sent_at``.
        2. Attempt FCM dispatch if ``device_token`` is provided and FCM is
           configured. Failure is logged but never raises (graceful degradation).
        3. Return the persisted ``NotificationLog`` instance.

        Args:
            user_id: Zuralog user ID (Supabase Auth UID).
            title: Notification title text.
            body: Notification body text.
            notification_type: Semantic category for the notification.
            device_token: FCM device registration token. If None, no push
                is sent but the log record is still created.
            deep_link: Optional URI for client-side tap navigation,
                e.g. ``"zuralog://insight/abc123"``.
            db: Optional existing ``AsyncSession``. If supplied, the caller
                is responsible for committing. If None, a new session is
                opened from ``db_factory``.

        Returns:
            The persisted ``NotificationLog`` instance.

        Raises:
            RuntimeError: If no ``db`` and no ``db_factory`` was provided.
        """
        log_record = NotificationLog(
            user_id=user_id,
            title=title,
            body=body,
            type=notification_type.value,
            deep_link=deep_link,
            sent_at=datetime.now(timezone.utc),
        )

        if db is not None:
            await self._persist(log_record, db)
        else:
            if self._db_factory is None:
                raise RuntimeError("NotificationService requires either a db session or a db_factory")
            async with self._db_factory() as session:
                await self._persist(log_record, session)

        # Attempt FCM send — never let a push failure break the caller.
        if device_token:
            try:
                fcm_data: dict[str, str] = {"notification_id": log_record.id}
                if deep_link:
                    fcm_data["deep_link"] = deep_link
                self.push_service.send_notification(
                    token=device_token,
                    title=title,
                    body=body,
                    data=fcm_data,
                )
            except Exception:  # noqa: BLE001
                logger.exception(
                    "FCM dispatch failed for notification %s (user %s) — log persisted anyway",
                    log_record.id,
                    user_id,
                )

        return log_record

    async def get_notifications(
        self,
        user_id: str,
        limit: int = 50,
        offset: int = 0,
        db: AsyncSession | None = None,
    ) -> list[NotificationLog]:
        """Retrieve paginated notifications for a user, newest first.

        Args:
            user_id: Zuralog user ID.
            limit: Maximum rows to return.
            offset: Rows to skip (pagination).
            db: Optional existing session. If None, opens from factory.

        Returns:
            List of ``NotificationLog`` objects ordered by ``sent_at`` desc.
        """
        stmt = (
            select(NotificationLog)
            .where(NotificationLog.user_id == user_id)
            .order_by(NotificationLog.sent_at.desc())
            .limit(limit)
            .offset(offset)
        )

        if db is not None:
            result = await db.execute(stmt)
            return list(result.scalars().all())

        if self._db_factory is None:
            raise RuntimeError("NotificationService requires either a db session or a db_factory")

        async with self._db_factory() as session:
            result = await session.execute(stmt)
            return list(result.scalars().all())

    async def mark_read(
        self,
        notification_id: str,
        user_id: str,
        db: AsyncSession | None = None,
    ) -> NotificationLog | None:
        """Mark a notification as read (set ``read_at = now()``).

        Only updates if ``read_at`` is currently null. Silently no-ops
        if already read.

        Args:
            notification_id: UUID of the NotificationLog row.
            user_id: Must match the row's ``user_id`` (ownership check).
            db: Optional existing session.

        Returns:
            Updated ``NotificationLog``, or ``None`` if not found.
        """
        stmt = select(NotificationLog).where(
            NotificationLog.id == notification_id,
            NotificationLog.user_id == user_id,
        )

        async def _run(session: AsyncSession) -> NotificationLog | None:
            result = await session.execute(stmt)
            record = result.scalar_one_or_none()
            if record is None:
                return None
            if record.read_at is None:
                record.read_at = datetime.now(timezone.utc)
                await session.commit()
                await session.refresh(record)
            return record

        if db is not None:
            return await _run(db)

        if self._db_factory is None:
            raise RuntimeError("NotificationService requires either a db session or a db_factory")

        async with self._db_factory() as session:
            return await _run(session)

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    @staticmethod
    async def _persist(record: NotificationLog, db: AsyncSession) -> None:
        """Add a NotificationLog record to the session and commit.

        Args:
            record: The record to persist.
            db: Open async session.
        """
        db.add(record)
        await db.commit()
        await db.refresh(record)
        logger.debug(
            "NotificationLog persisted: id=%s user=%s type=%s",
            record.id,
            record.user_id,
            record.type,
        )
