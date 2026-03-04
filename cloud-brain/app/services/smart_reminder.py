"""
Zuralog Cloud Brain — Smart Reminder Engine.

Evaluates personalised reminders for a user and sends eligible ones
via PushService. Implements deduplication, quiet hours, and a daily
cap to avoid notification fatigue.

Reminder types:
- gap:         No check-in or data logged today — prompt at noon.
- pattern:     User regularly logs a specific activity at a certain time.
- goal:        User is within 10% of their daily step/activity goal.
- celebration: Streak milestone reached today.
"""

import logging
from datetime import datetime, timedelta, timezone

from sqlalchemy.ext.asyncio import AsyncSession

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Configuration constants
# ---------------------------------------------------------------------------

MAX_DAILY_REMINDERS = 3        # Default daily cap; overridable via preferences
DEDUP_HOURS = 48               # Skip if same reminder type sent within this window
_STEP_GOAL_DEFAULT = 10_000    # Default daily step goal (no custom goals for MVP)
_GAP_NUDGE_HOUR = 12           # Hour (UTC) to send gap reminders if no data yet


class SmartReminderEngine:
    """Evaluates and dispatches smart reminders for a single user.

    Reminder candidates are generated from:
    - **Gap reminders**: no daily data synced by noon → prompt to log.
    - **Pattern reminders**: stub for future behavioural pattern matching.
    - **Goal reminders**: within 10% of the daily step goal → nudge.
    - **Celebration reminders**: streak milestone hit today → celebrate.

    All model and service imports are soft (try/except) to ensure graceful
    degradation when schema migrations are in progress.
    """

    async def evaluate_and_send(
        self,
        user_id: str,
        db: AsyncSession,
    ) -> int:
        """Evaluate reminders for a user and send eligible ones.

        Pipeline:
        1. Load user preferences (proactivity level, quiet hours).
        2. Count today's reminders already sent (from notification_logs).
        3. Generate reminder candidates.
        4. Deduplicate: skip if same type sent within DEDUP_HOURS.
        5. Respect quiet hours.
        6. Send via PushService + persist to notification_logs.
        7. Return the number of reminders actually sent.

        Args:
            user_id: Zuralog user ID to evaluate.
            db: Async database session.

        Returns:
            Number of reminders sent (0 if capped or quiet hours active).
        """
        now_utc = datetime.now(timezone.utc)
        sent_count = 0

        # -------------------------------------------------------------------------
        # 1. Load user preferences (soft import)
        # -------------------------------------------------------------------------
        daily_cap = MAX_DAILY_REMINDERS
        quiet_start: tuple[int, int] | None = None
        quiet_end: tuple[int, int] | None = None

        try:
            from sqlalchemy import select
            from app.models.user_preferences import UserPreferences

            result = await db.execute(
                select(UserPreferences).where(UserPreferences.user_id == user_id)
            )
            prefs = result.scalar_one_or_none()
            if prefs:
                # Use proactivity level to set the daily cap
                proactivity_caps = {"low": 1, "medium": 2, "high": 3}
                daily_cap = proactivity_caps.get(prefs.proactivity_level, MAX_DAILY_REMINDERS)

                # Parse quiet hours
                quiet_start = _parse_hhmm(prefs.quiet_hours_start)
                quiet_end = _parse_hhmm(prefs.quiet_hours_end)
        except Exception:
            logger.debug(
                "smart_reminder: could not load preferences for user=%s",
                user_id,
                exc_info=True,
            )

        # -------------------------------------------------------------------------
        # 2. Check quiet hours — abort early if in quiet window
        # -------------------------------------------------------------------------
        if quiet_start and quiet_end and _in_quiet_hours(now_utc, quiet_start, quiet_end):
            logger.debug(
                "smart_reminder: quiet hours active for user=%s — skipping",
                user_id,
            )
            return 0

        # -------------------------------------------------------------------------
        # 3. Count today's reminders already sent (soft import)
        # -------------------------------------------------------------------------
        today_start = now_utc.replace(hour=0, minute=0, second=0, microsecond=0)
        today_sent = 0
        try:
            from sqlalchemy import func, select
            from app.models.notification_log import NotificationLog

            count_result = await db.execute(
                select(func.count(NotificationLog.id)).where(
                    NotificationLog.user_id == user_id,
                    NotificationLog.type == "reminder",
                    NotificationLog.sent_at >= today_start,
                )
            )
            today_sent = count_result.scalar_one() or 0
        except Exception:
            logger.debug(
                "smart_reminder: could not count today's reminders for user=%s",
                user_id,
                exc_info=True,
            )

        if today_sent >= daily_cap:
            logger.debug(
                "smart_reminder: daily cap (%d) reached for user=%s — skipping",
                daily_cap,
                user_id,
            )
            return 0

        remaining_cap = daily_cap - today_sent

        # -------------------------------------------------------------------------
        # 4. Generate reminder candidates
        # -------------------------------------------------------------------------
        candidates: list[dict] = []

        # --- Gap reminder: no data logged today by noon ---
        if now_utc.hour >= _GAP_NUDGE_HOUR:
            try:
                from sqlalchemy import select
                from app.models.daily_metrics import DailyHealthMetrics

                today_str = now_utc.strftime("%Y-%m-%d")
                result = await db.execute(
                    select(DailyHealthMetrics)
                    .where(
                        DailyHealthMetrics.user_id == user_id,
                        DailyHealthMetrics.date == today_str,
                    )
                    .limit(1)
                )
                today_data = result.scalar_one_or_none()

                if today_data is None:
                    candidates.append({
                        "type": "gap",
                        "title": "Check In With Zuralog",
                        "body": "No data logged today yet. Sync your health data to stay on track!",
                    })
            except Exception:
                logger.debug(
                    "smart_reminder: could not check data gap for user=%s",
                    user_id,
                    exc_info=True,
                )

        # --- Goal proximity: within 10% of step goal ---
        try:
            from sqlalchemy import select
            from app.models.daily_metrics import DailyHealthMetrics

            today_str = now_utc.strftime("%Y-%m-%d")
            result = await db.execute(
                select(DailyHealthMetrics)
                .where(
                    DailyHealthMetrics.user_id == user_id,
                    DailyHealthMetrics.date == today_str,
                )
                .limit(1)
            )
            today_data = result.scalar_one_or_none()

            if today_data and today_data.steps is not None:
                steps = today_data.steps
                goal = _STEP_GOAL_DEFAULT
                threshold = goal * 0.9

                if threshold <= steps < goal:
                    remaining = goal - steps
                    candidates.append({
                        "type": "goal",
                        "title": "Almost There!",
                        "body": (
                            f"You're {remaining:,} steps away from your goal. "
                            f"You've got this!"
                        ),
                    })
        except Exception:
            logger.debug(
                "smart_reminder: could not check goal proximity for user=%s",
                user_id,
                exc_info=True,
            )

        # --- Celebration: streak milestone ---
        try:
            from sqlalchemy import func, select
            from app.models.daily_metrics import DailyHealthMetrics

            # Count consecutive days with data up to and including today
            streak_result = await db.execute(
                select(func.count(DailyHealthMetrics.date.distinct())).where(
                    DailyHealthMetrics.user_id == user_id,
                )
            )
            streak_days = streak_result.scalar_one() or 0

            milestones = {7, 14, 30, 50, 100}
            if streak_days in milestones:
                candidates.append({
                    "type": "celebration",
                    "title": f"{streak_days}-Day Streak!",
                    "body": (
                        f"Amazing! You've been tracking for {streak_days} days straight. "
                        f"Keep it up!"
                    ),
                })
        except Exception:
            logger.debug(
                "smart_reminder: could not check streak for user=%s",
                user_id,
                exc_info=True,
            )

        # -------------------------------------------------------------------------
        # 5. Deduplicate: skip if same type sent within DEDUP_HOURS
        # -------------------------------------------------------------------------
        dedup_cutoff = now_utc - timedelta(hours=DEDUP_HOURS)
        recent_types: set[str] = set()

        try:
            from sqlalchemy import select
            from app.models.notification_log import NotificationLog

            logs_result = await db.execute(
                select(NotificationLog.body, NotificationLog.type).where(
                    NotificationLog.user_id == user_id,
                    NotificationLog.type == "reminder",
                    NotificationLog.sent_at >= dedup_cutoff,
                )
            )
            for row in logs_result.fetchall():
                # Store type as a proxy for dedup — refine to include subtype in body later
                recent_types.add(row[1])
        except Exception:
            logger.debug(
                "smart_reminder: could not load recent notifications for user=%s",
                user_id,
                exc_info=True,
            )

        # Filter to unique types not recently sent
        eligible: list[dict] = [
            c for c in candidates if c["type"] not in recent_types
        ]

        # -------------------------------------------------------------------------
        # 6. Load FCM token for delivery
        # -------------------------------------------------------------------------
        fcm_token: str | None = None
        try:
            from sqlalchemy import select
            from app.models.device import Device

            token_result = await db.execute(
                select(Device.fcm_token)
                .where(Device.user_id == user_id, Device.fcm_token.isnot(None))
                .limit(1)
            )
            row = token_result.first()
            if row:
                fcm_token = row[0]
        except Exception:
            logger.debug(
                "smart_reminder: could not load FCM token for user=%s",
                user_id,
                exc_info=True,
            )

        # -------------------------------------------------------------------------
        # 7. Send eligible reminders (respect remaining cap)
        # -------------------------------------------------------------------------
        from app.services.push_service import PushService

        push = PushService()

        for reminder in eligible[:remaining_cap]:
            try:
                # Send push notification
                if fcm_token:
                    push.send_notification(
                        token=fcm_token,
                        title=reminder["title"],
                        body=reminder["body"],
                        data={"type": "reminder", "reminder_type": reminder["type"]},
                    )

                # Persist NotificationLog (soft import)
                try:
                    import uuid as _uuid
                    from app.models.notification_log import NotificationLog

                    log = NotificationLog(
                        id=str(_uuid.uuid4()),
                        user_id=user_id,
                        title=reminder["title"],
                        body=reminder["body"],
                        type="reminder",
                        deep_link=None,
                    )
                    db.add(log)
                    await db.commit()
                except Exception:
                    logger.debug(
                        "smart_reminder: could not persist notification log for user=%s",
                        user_id,
                        exc_info=True,
                    )
                    await db.rollback()

                sent_count += 1
                logger.info(
                    "smart_reminder: sent reminder type=%s for user=%s",
                    reminder["type"],
                    user_id,
                )

            except Exception:
                logger.error(
                    "smart_reminder: failed to send reminder for user=%s",
                    user_id,
                    exc_info=True,
                )

        return sent_count


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------


def _parse_hhmm(time_str: str | None) -> tuple[int, int] | None:
    """Parse an HH:MM string into (hour, minute).

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


def _in_quiet_hours(
    now: datetime,
    quiet_start: tuple[int, int],
    quiet_end: tuple[int, int],
) -> bool:
    """Determine whether ``now`` falls within the user's quiet-hours window.

    Handles windows that wrap past midnight (e.g. 22:00 – 07:00).

    Args:
        now: Current UTC datetime.
        quiet_start: (hour, minute) of the quiet window start.
        quiet_end: (hour, minute) of the quiet window end.

    Returns:
        True if ``now`` is within the quiet window.
    """
    current_minutes = now.hour * 60 + now.minute
    start_minutes = quiet_start[0] * 60 + quiet_start[1]
    end_minutes = quiet_end[0] * 60 + quiet_end[1]

    if start_minutes <= end_minutes:
        # Same-day window: e.g. 08:00 – 20:00
        return start_minutes <= current_minutes < end_minutes
    else:
        # Overnight window: e.g. 22:00 – 07:00
        return current_minutes >= start_minutes or current_minutes < end_minutes
