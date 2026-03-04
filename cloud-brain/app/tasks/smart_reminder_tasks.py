"""
Zuralog Cloud Brain — Smart Reminder Celery Tasks.

Two tasks:
- ``evaluate_reminders_task``: Hourly Beat task that fans out per-user
  evaluation to individual ``send_reminder_task`` calls.
- ``send_reminder_task``: Evaluates and sends reminders for a single user.

Both use asyncio.run() for DB access following the established pattern
in other Celery tasks (e.g. fitbit_sync.py).
"""

from __future__ import annotations

import asyncio
import logging

import sentry_sdk
from sqlalchemy import select

from app.database import async_session
from app.models.user import User
from app.models.user_device import UserDevice
from app.models.notification_log import NotificationType
from app.services.notification_service import NotificationService
from app.services.push_service import PushService
from app.services.smart_reminder import SmartReminderEngine
from app.worker import celery_app

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Hourly fan-out task
# ---------------------------------------------------------------------------


@celery_app.task(name="app.tasks.smart_reminder.evaluate_reminders_task")
def evaluate_reminders_task() -> dict:
    """Hourly task: evaluate and dispatch reminders for all active Pro users.

    Fetches all Pro-tier users and dispatches a ``send_reminder_task`` for
    each. Fan-out approach keeps the hourly task fast and failure-isolated.

    Returns:
        Dict with ``users_queued`` count.
    """
    logger.info("evaluate_reminders_task: starting hourly reminder evaluation")

    async def _run() -> dict:
        async with async_session() as db:
            # Only evaluate Pro users — reminders are a Pro feature.
            stmt = select(User).where(User.subscription_tier != "free")
            result = await db.execute(stmt)
            users = result.scalars().all()

        queued = 0
        for user in users:
            try:
                send_reminder_task.delay(user_id=user.id)
                queued += 1
            except Exception:  # noqa: BLE001
                logger.exception(
                    "evaluate_reminders_task: failed to queue reminder for user %s",
                    user.id,
                )

        logger.info("evaluate_reminders_task: queued %d users", queued)
        return {"users_queued": queued}

    return asyncio.run(_run())


# ---------------------------------------------------------------------------
# Per-user reminder task
# ---------------------------------------------------------------------------


@celery_app.task(
    name="app.tasks.smart_reminder.send_reminder_task",
    max_retries=2,
    default_retry_delay=60,
)
def send_reminder_task(user_id: str) -> dict:
    """Evaluate and send reminders for a single user.

    Steps:
    1. Generate reminder candidates via SmartReminderEngine.
    2. Look up the user's FCM device token.
    3. Send each reminder via NotificationService.
    4. Mark reminders as sent in Redis for deduplication.

    Args:
        user_id: Zuralog user ID.

    Returns:
        Dict with ``sent`` count and ``user_id``.
    """
    logger.debug("send_reminder_task: evaluating user %s", user_id)

    async def _run() -> dict:
        push_svc = PushService()
        notif_svc = NotificationService(push_service=push_svc, db_factory=async_session)
        # Note: In production, pass a real Redis client here.
        # For Phase 2, we run without Redis dedup in the task itself;
        # dedup is handled by SmartReminderEngine if redis_client is provided.
        engine = SmartReminderEngine(redis_client=None)

        async with async_session() as db:
            reminders = await engine.generate_reminders(user_id=user_id, session=db)

            if not reminders:
                return {"sent": 0, "user_id": user_id}

            # Get the user's most recent FCM token.
            device_stmt = (
                select(UserDevice)
                .where(UserDevice.user_id == user_id)
                .order_by(UserDevice.last_seen_at.desc())
                .limit(1)
            )
            device_result = await db.execute(device_stmt)
            device = device_result.scalar_one_or_none()
            device_token = device.fcm_token if device else None

            sent_count = 0
            for reminder in reminders:
                try:
                    await notif_svc.send_and_persist(
                        user_id=user_id,
                        title=reminder.title,
                        body=reminder.body,
                        notification_type=NotificationType.REMINDER,
                        device_token=device_token,
                        deep_link=reminder.deep_link,
                        db=db,
                    )
                    sent_count += 1
                    logger.info(
                        "send_reminder_task: sent %s reminder to user %s",
                        reminder.reminder_type.value,
                        user_id,
                    )
                except Exception:  # noqa: BLE001
                    logger.exception(
                        "send_reminder_task: failed to send reminder for user %s",
                        user_id,
                    )
                    sentry_sdk.capture_exception()

        return {"sent": sent_count, "user_id": user_id}

    return asyncio.run(_run())
