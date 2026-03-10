"""
Zuralog Cloud Brain — Smart Reminder Celery Task.

Runs hourly via Celery Beat. Iterates over all active users (those who have
synced data in the last 30 days) and calls SmartReminderEngine.evaluate_and_send()
for each one.

An "active user" is defined as a user with at least one DailyHealthMetrics row
dated within the last 30 days, ensuring the reminder engine only fires for
users who are actually engaging with the platform.

Architecture notes:
- The Celery task is synchronous; async DB access is bridged via asyncio.run().
- SmartReminderEngine handles all per-user logic (dedup, quiet hours, daily cap).
- Errors for individual users are caught and logged without halting the batch.
"""

import asyncio
import logging
from datetime import datetime, timedelta, timezone

import sentry_sdk

from app.database import worker_async_session as async_session
from app.services.smart_reminder import SmartReminderEngine
from app.worker import celery_app

logger = logging.getLogger(__name__)

# How far back to look when determining "active" users
_ACTIVE_WINDOW_DAYS = 30


@celery_app.task(name="app.tasks.smart_reminder_tasks.send_smart_reminders")
def send_smart_reminders() -> dict:
    """Evaluate and send smart reminders for all active users.

    Runs hourly via Celery Beat. For each user who has synced health data
    within the last 30 days, SmartReminderEngine.evaluate_and_send() is called
    to determine whether any reminders are due.

    Returns:
        Summary dict with keys: ``users_evaluated``, ``total_sent``, ``errors``.
    """
    logger.info("send_smart_reminders: task started")

    async def _run() -> dict:
        users_evaluated = 0
        total_sent = 0
        errors = 0

        cutoff = datetime.now(timezone.utc) - timedelta(days=_ACTIVE_WINDOW_DAYS)
        cutoff_str = cutoff.strftime("%Y-%m-%d")

        async with async_session() as db:
            # ------------------------------------------------------------------
            # 1. Get IDs of active users (synced data in the last 30 days)
            # ------------------------------------------------------------------
            active_user_ids: list[str] = []
            try:
                from sqlalchemy import select
                from app.models.daily_metrics import DailyHealthMetrics

                result = await db.execute(
                    select(DailyHealthMetrics.user_id)
                    .where(DailyHealthMetrics.date >= cutoff_str)
                    .distinct()
                )
                active_user_ids = [row[0] for row in result.fetchall()]
            except Exception as exc:
                logger.error(
                    "send_smart_reminders: failed to query active users",
                    exc_info=True,
                )
                sentry_sdk.capture_exception(exc)
                return {"users_evaluated": 0, "total_sent": 0, "errors": 1}

            logger.info(
                "send_smart_reminders: found %d active users",
                len(active_user_ids),
            )

            # ------------------------------------------------------------------
            # 2. Evaluate reminders for each active user
            # ------------------------------------------------------------------
            engine = SmartReminderEngine()

            for user_id in active_user_ids:
                users_evaluated += 1
                try:
                    sent = await engine.evaluate_and_send(user_id=user_id, db=db)
                    total_sent += sent
                    if sent > 0:
                        logger.info(
                            "send_smart_reminders: sent %d reminder(s) for user=%s",
                            sent,
                            user_id,
                        )
                except Exception:
                    errors += 1
                    logger.error(
                        "send_smart_reminders: failed for user=%s",
                        user_id,
                        exc_info=True,
                    )
                    sentry_sdk.capture_exception()

        summary = {
            "users_evaluated": users_evaluated,
            "total_sent": total_sent,
            "errors": errors,
        }
        logger.info("send_smart_reminders: task complete %s", summary)
        return summary

    return asyncio.run(_run())
