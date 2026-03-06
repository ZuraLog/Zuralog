"""
Zuralog Cloud Brain — Morning Briefing Celery Task.

Sends personalised morning briefing push notifications to users whose
``morning_briefing_time`` falls within the current 15-minute window.

Scheduled via Celery Beat at 15-minute intervals. For each eligible user:
1. Checks if the user's preferred briefing time matches the current UTC slot.
2. Queries yesterday's DailyHealthMetrics for a data-driven briefing.
3. Builds a personalised briefing message (graceful fallback if no data).
4. Sends via PushService and persists as a NotificationLog + Insight.

Architecture notes:
- The Celery task is synchronous; async DB access is bridged with asyncio.run().
- All model imports are soft (try/except) to handle schema drift gracefully.
- morning_briefing_enabled is checked via notification_settings JSON to
  maintain backwards compatibility if the column does not exist.
"""

import asyncio
import logging
from datetime import datetime, timedelta, timezone

import sentry_sdk

from app.database import async_session
from app.worker import celery_app

logger = logging.getLogger(__name__)

# Half-window (minutes) around a user's briefing_time for eligibility.
_WINDOW_MINUTES = 7.5


def _parse_hhmm(time_str: str | None) -> tuple[int, int] | None:
    """Parse an HH:MM string into (hour, minute) integers.

    Args:
        time_str: Time string in 'HH:MM' format, or None.

    Returns:
        (hour, minute) tuple, or None if parsing fails.
    """
    if not time_str:
        return None
    try:
        parts = time_str.strip().split(":")
        return int(parts[0]), int(parts[1])
    except (ValueError, IndexError):
        return None


def _is_in_window(target_hour: int, target_minute: int, now: datetime) -> bool:
    """Check whether a target HH:MM falls within ±7.5 minutes of ``now``.

    Compares the target time against the current UTC minute-of-day with a
    ±7.5-minute tolerance window to account for the 15-minute Beat schedule.

    Args:
        target_hour: Target hour (0-23, UTC).
        target_minute: Target minute (0-59).
        now: Current UTC datetime.

    Returns:
        True if the target time is within the window.
    """
    now_total = now.hour * 60 + now.minute
    target_total = target_hour * 60 + target_minute

    # Handle midnight wrap-around
    diff = abs(now_total - target_total)
    if diff > 720:  # more than 12 hours apart — wrap
        diff = 1440 - diff

    return diff <= _WINDOW_MINUTES


def _build_briefing_message(metrics: object | None) -> str:
    """Build a personalised briefing message from yesterday's metrics.

    Args:
        metrics: DailyHealthMetrics ORM instance for yesterday, or None.

    Returns:
        A human-readable briefing string.
    """
    if metrics is None:
        return (
            "Good morning! Keep syncing your data for personalised briefings. "
            "Check in with Zuralog throughout the day to build your health baseline."
        )

    parts: list[str] = ["Good morning!"]

    # Sleep recap (HRV as proxy for recovery quality)
    if hasattr(metrics, "hrv_ms") and metrics.hrv_ms is not None:
        hrv = metrics.hrv_ms
        if hrv >= 50:
            parts.append(f"Yesterday: great recovery — HRV was {hrv:.0f} ms.")
        elif hrv >= 30:
            parts.append(f"Yesterday: moderate recovery — HRV was {hrv:.0f} ms.")
        else:
            parts.append(
                f"Yesterday: low HRV ({hrv:.0f} ms) — prioritise rest today."
            )

    # Activity summary
    if hasattr(metrics, "steps") and metrics.steps is not None:
        steps = metrics.steps
        if steps >= 10000:
            parts.append(f"You hit {steps:,} steps — well done!")
        elif steps >= 7000:
            parts.append(f"You logged {steps:,} steps — solid effort.")
        else:
            parts.append(
                f"You logged {steps:,} steps. Try to move more today!"
            )

    # Suggestion based on resting heart rate
    if (
        hasattr(metrics, "resting_heart_rate")
        and metrics.resting_heart_rate is not None
    ):
        rhr = metrics.resting_heart_rate
        if rhr > 80:
            parts.append(
                "Your resting heart rate is elevated. Focus on hydration and stress management."
            )
        else:
            parts.append("Your heart rate looks healthy. Keep up the good work!")

    if len(parts) == 1:
        # Only the greeting — add a generic tip
        parts.append(
            "Today looks like a great day to move, hydrate, and check in with Zuralog."
        )

    return " ".join(parts)


@celery_app.task(name="app.tasks.morning_briefing_task.send_morning_briefings")
def send_morning_briefings() -> dict:
    """Send morning briefing push notifications to eligible users.

    Runs every 15 minutes via Celery Beat. For each user whose
    ``morning_briefing_time`` falls within the current ±7.5-minute window
    and who has briefings enabled, generates and delivers a personalised
    morning summary.

    Returns:
        Summary dict with counts of users processed, briefings sent, and errors.
    """
    logger.info("send_morning_briefings: task started")

    async def _run() -> dict:
        processed = 0
        sent = 0
        errors = 0

        async with async_session() as db:
            # ------------------------------------------------------------------
            # 1. Load users with morning_briefing_time set (soft import)
            # ------------------------------------------------------------------
            try:
                from sqlalchemy import select
                from app.models.user_preferences import UserPreferences

                result = await db.execute(
                    select(UserPreferences).where(
                        UserPreferences.morning_briefing_time.isnot(None)
                    )
                )
                all_prefs = result.scalars().all()
            except Exception as exc:
                logger.error(
                    "send_morning_briefings: failed to query user_preferences",
                    exc_info=True,
                )
                sentry_sdk.capture_exception(exc)
                return {"processed": 0, "sent": 0, "errors": 1}

            now_utc = datetime.now(timezone.utc)
            yesterday_str = (now_utc - timedelta(days=1)).strftime("%Y-%m-%d")

            for prefs in all_prefs:
                user_id: str = prefs.user_id
                processed += 1

                try:
                    # ------------------------------------------------------------------
                    # 2. Check if briefings are enabled (from notification_settings JSON)
                    # ------------------------------------------------------------------
                    notification_settings: dict = prefs.notification_settings or {}
                    briefing_enabled = notification_settings.get(
                        "morning_briefing_enabled", True  # enabled by default
                    )
                    if not briefing_enabled:
                        logger.debug(
                            "send_morning_briefings: briefings disabled for user=%s",
                            user_id,
                        )
                        continue

                    # ------------------------------------------------------------------
                    # 3. Check if this user's briefing_time is in the current window
                    # ------------------------------------------------------------------
                    parsed = _parse_hhmm(prefs.morning_briefing_time)
                    if parsed is None:
                        continue
                    target_hour, target_minute = parsed

                    if not _is_in_window(target_hour, target_minute, now_utc):
                        continue

                    # ------------------------------------------------------------------
                    # 4. Load yesterday's health metrics (soft import)
                    # ------------------------------------------------------------------
                    yesterday_metrics = None
                    try:
                        from sqlalchemy import select
                        from app.models.daily_metrics import DailyHealthMetrics

                        metrics_result = await db.execute(
                            select(DailyHealthMetrics)
                            .where(
                                DailyHealthMetrics.user_id == user_id,
                                DailyHealthMetrics.date == yesterday_str,
                            )
                            .limit(1)
                        )
                        yesterday_metrics = metrics_result.scalar_one_or_none()
                    except Exception:
                        logger.debug(
                            "send_morning_briefings: could not load metrics for user=%s",
                            user_id,
                            exc_info=True,
                        )

                    # ------------------------------------------------------------------
                    # 5. Build briefing message
                    # ------------------------------------------------------------------
                    briefing_body = _build_briefing_message(yesterday_metrics)
                    briefing_title = "Your Morning Briefing"

                    # ------------------------------------------------------------------
                    # 6. Get device FCM token and send push notification
                    # ------------------------------------------------------------------
                    fcm_token: str | None = None
                    try:
                        from sqlalchemy import select
                        from app.models.device import Device

                        token_result = await db.execute(
                            select(Device.fcm_token)
                            .where(
                                Device.user_id == user_id,
                                Device.fcm_token.isnot(None),
                            )
                            .limit(1)
                        )
                        row = token_result.first()
                        if row:
                            fcm_token = row[0]
                    except Exception:
                        logger.debug(
                            "send_morning_briefings: could not load FCM token for user=%s",
                            user_id,
                            exc_info=True,
                        )

                    if fcm_token:
                        from app.services.push_service import PushService

                        push = PushService()
                        push.send_notification(
                            token=fcm_token,
                            title=briefing_title,
                            body=briefing_body,
                            data={"type": "briefing"},
                        )

                    # ------------------------------------------------------------------
                    # 7. Persist NotificationLog (soft import)
                    # ------------------------------------------------------------------
                    try:
                        import uuid as _uuid
                        from app.models.notification_log import NotificationLog

                        log = NotificationLog(
                            id=str(_uuid.uuid4()),
                            user_id=user_id,
                            title=briefing_title,
                            body=briefing_body,
                            type="briefing",
                            deep_link=None,
                        )
                        db.add(log)
                    except Exception:
                        logger.debug(
                            "send_morning_briefings: could not persist notification log for user=%s",
                            user_id,
                            exc_info=True,
                        )

                    # ------------------------------------------------------------------
                    # 8. Persist Insight card (soft import)
                    # ------------------------------------------------------------------
                    try:
                        import uuid as _uuid
                        from app.models.insight import Insight

                        card = Insight(
                            id=str(_uuid.uuid4()),
                            user_id=user_id,
                            type="welcome",  # closest INSIGHT_TYPE for a briefing
                            title=briefing_title,
                            body=briefing_body,
                            data={"source": "morning_briefing", "generated_at": now_utc.isoformat()},
                            reasoning=None,
                            priority=1,
                        )
                        db.add(card)
                    except Exception:
                        logger.debug(
                            "send_morning_briefings: could not persist insight card for user=%s",
                            user_id,
                            exc_info=True,
                        )

                    await db.commit()
                    sent += 1

                    logger.info(
                        "send_morning_briefings: briefing sent for user=%s",
                        user_id,
                    )

                except Exception:
                    errors += 1
                    logger.error(
                        "send_morning_briefings: failed for user=%s",
                        user_id,
                        exc_info=True,
                    )
                    sentry_sdk.capture_exception()
                    try:
                        await db.rollback()
                    except Exception:
                        pass

        summary = {"processed": processed, "sent": sent, "errors": errors}
        logger.info("send_morning_briefings: task complete %s", summary)
        return summary

    return asyncio.run(_run())
