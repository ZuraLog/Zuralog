"""
Zuralog Cloud Brain — Morning Briefing Celery Task.

Runs every 15 minutes via Celery Beat. For each user whose
``morning_briefing_time`` (UTC hour) falls in the current 15-minute window
and who has ``morning_briefing_enabled=True`` and a Pro subscription:

1. Fetch last night's sleep data (if available).
2. Generate personalised briefing text (sleep recap + focus + suggestion).
3. Look up the user's FCM token(s) from ``user_devices``.
4. Send push notification via NotificationService.
5. Persist an Insight card of type MORNING_BRIEFING.

Phase 2 note: UTC-only. Timezone-aware scheduling deferred to Phase 8.
"""

from __future__ import annotations

import asyncio
import logging
from datetime import date, datetime, timedelta, timezone

from sqlalchemy import select

from app.database import async_session
from app.models.insight import Insight, InsightType
from app.models.notification_log import NotificationType
from app.models.user import User
from app.models.user_device import UserDevice
from app.models.user_preferences import UserPreferences
from app.models.health_data import SleepRecord
from app.services.notification_service import NotificationService
from app.services.push_service import PushService
from app.worker import celery_app

logger = logging.getLogger(__name__)

# Window size for matching briefing time (minutes on each side of the window).
_WINDOW_MINUTES = 15


# ---------------------------------------------------------------------------
# Briefing content generation
# ---------------------------------------------------------------------------


def _generate_briefing_text(
    sleep_hours: float | None,
    sleep_quality: int | None,
    user_goals: list | None,
) -> tuple[str, str]:
    """Generate personalised morning briefing title and body.

    Args:
        sleep_hours: Hours slept last night, or None if no data.
        sleep_quality: Sleep quality score (0-100), or None.
        user_goals: List of goal dicts from UserPreferences, or None.

    Returns:
        Tuple of (title, body) strings.
    """
    title = "Good morning! Here's your briefing."

    parts: list[str] = []

    # Sleep recap
    if sleep_hours is not None:
        hours_str = f"{sleep_hours:.1f}"
        if sleep_quality is not None:
            if sleep_quality >= 80:
                quality_note = "Great quality sleep!"
            elif sleep_quality >= 60:
                quality_note = "Decent rest — you're on track."
            else:
                quality_note = "Light sleep — consider an earlier bedtime tonight."
            parts.append(f"You slept {hours_str} hours. {quality_note}")
        else:
            if sleep_hours >= 7.5:
                parts.append(f"You slept {hours_str} hours — solid rest.")
            elif sleep_hours >= 6:
                parts.append(f"You slept {hours_str} hours. A bit more rest could help recovery.")
            else:
                parts.append(f"You slept {hours_str} hours. Prioritise rest today if you can.")
    else:
        # Fallback when no sleep data
        parts.append("Start your day strong — consistency is the foundation of health.")

    # Today's focus from goals
    if user_goals:
        goal_metrics = [g.get("metric", "") for g in user_goals if g.get("metric")]
        if goal_metrics:
            focus = goal_metrics[0].replace("_", " ")
            parts.append(f"Today's focus: keep up your {focus} habit.")

    # One actionable suggestion
    if sleep_hours is not None and sleep_hours < 6:
        parts.append("Tip: A 20-minute nap can restore alertness without disrupting tonight's sleep.")
    elif not user_goals:
        parts.append("Tip: Setting a daily step goal is one of the highest-impact habits you can build.")
    else:
        parts.append("Tip: A 10-minute walk after meals can meaningfully improve glucose response.")

    body = " ".join(parts)
    return title, body


# ---------------------------------------------------------------------------
# Async core logic
# ---------------------------------------------------------------------------


async def _run_morning_briefings() -> dict:
    """Core async logic for send_morning_briefings_task.

    Returns:
        Dict with summary statistics.
    """
    now_utc = datetime.now(timezone.utc)
    current_hour = now_utc.hour
    current_minute = now_utc.minute

    # We match users whose briefing time hour == current_hour, and whose
    # briefing time minute falls within the current 15-minute window.
    window_start_minute = (current_minute // _WINDOW_MINUTES) * _WINDOW_MINUTES
    window_end_minute = window_start_minute + _WINDOW_MINUTES

    sent_count = 0
    skipped_count = 0

    push_svc = PushService()
    notif_svc = NotificationService(push_service=push_svc, db_factory=async_session)

    async with async_session() as db:
        # Fetch users with morning briefing enabled.
        prefs_stmt = select(UserPreferences).where(
            UserPreferences.morning_briefing_enabled.is_(True),
            UserPreferences.morning_briefing_time.isnot(None),
        )
        prefs_result = await db.execute(prefs_stmt)
        all_prefs = prefs_result.scalars().all()

        for prefs in all_prefs:
            try:
                briefing_time = prefs.morning_briefing_time
                if briefing_time is None:
                    continue

                # Check if this user's briefing time falls in the current window.
                b_hour = briefing_time.hour
                b_minute = briefing_time.minute

                if b_hour != current_hour:
                    continue
                if not (window_start_minute <= b_minute < window_end_minute):
                    continue

                user_id = prefs.user_id

                # Check subscription tier — morning briefing is Pro only.
                user_stmt = select(User).where(User.id == user_id)
                user_result = await db.execute(user_stmt)
                user = user_result.scalar_one_or_none()
                if user is None or not user.is_premium:
                    logger.debug("Morning briefing skipped for user %s — not Pro tier", user_id)
                    skipped_count += 1
                    continue

                # Fetch last night's sleep data.
                last_night = (date.today() - timedelta(days=1)).isoformat()
                sleep_stmt = (
                    select(SleepRecord)
                    .where(
                        SleepRecord.user_id == user_id,
                        SleepRecord.date == last_night,
                    )
                    .order_by(SleepRecord.created_at.desc())
                    .limit(1)
                )
                sleep_result = await db.execute(sleep_stmt)
                sleep_record = sleep_result.scalar_one_or_none()

                sleep_hours = sleep_record.hours if sleep_record else None
                sleep_quality = sleep_record.quality_score if sleep_record else None

                # Generate briefing text.
                title, body = _generate_briefing_text(
                    sleep_hours=sleep_hours,
                    sleep_quality=sleep_quality,
                    user_goals=prefs.goals,
                )

                # Look up the user's most recent FCM device token.
                device_stmt = (
                    select(UserDevice)
                    .where(
                        UserDevice.user_id == user_id,
                    )
                    .order_by(UserDevice.last_seen_at.desc())
                    .limit(1)
                )
                device_result = await db.execute(device_stmt)
                device = device_result.scalar_one_or_none()
                device_token = device.fcm_token if device else None

                # Send and persist notification.
                await notif_svc.send_and_persist(
                    user_id=user_id,
                    title=title,
                    body=body,
                    notification_type=NotificationType.BRIEFING,
                    device_token=device_token,
                    deep_link="zuralog://briefing/today",
                    db=db,
                )

                # Persist as an Insight card.
                insight = Insight(
                    user_id=user_id,
                    type=InsightType.MORNING_BRIEFING.value,
                    title=title,
                    body=body,
                    data={"sleep_hours": sleep_hours, "sleep_quality": sleep_quality},
                    priority=2,
                )
                db.add(insight)
                await db.commit()

                sent_count += 1
                logger.info("Morning briefing sent for user %s", user_id)

            except Exception:  # noqa: BLE001
                logger.exception("Morning briefing failed for user %s", prefs.user_id)

    return {"sent": sent_count, "skipped": skipped_count}


# ---------------------------------------------------------------------------
# Celery task
# ---------------------------------------------------------------------------


@celery_app.task(name="app.tasks.morning_briefing.send_morning_briefings_task")
def send_morning_briefings_task() -> dict:
    """Send morning briefings to users whose briefing time matches the current window.

    Runs every 15 minutes via Celery Beat. Matches users whose UTC
    ``morning_briefing_time`` hour:minute falls within the current
    15-minute scheduling window.

    Returns:
        Dict with ``sent`` and ``skipped`` counts.
    """
    logger.info("send_morning_briefings_task: starting morning briefing run")
    result = asyncio.run(_run_morning_briefings())
    logger.info(
        "send_morning_briefings_task: complete — sent=%d skipped=%d",
        result.get("sent", 0),
        result.get("skipped", 0),
    )
    return result
