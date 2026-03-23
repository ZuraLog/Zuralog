"""
Zuralog Cloud Brain — Background Alert Celery Task.

Checks for alertable events for a user after a health data ingest and
fires push notifications via ``PushService.send_and_persist()``.

Events checked
--------------
1. **Anomaly alert** — ``insights`` rows of type ``anomaly_alert`` created
   in the last hour signal an unusual metric that warrants immediate user
   attention.
2. **Goal reached** — ``daily_summaries`` for today vs ``user_goals``
   for the ``steps`` metric.  Generalised to any ``daily`` goal metric
   that maps to a ``metric_type`` in ``daily_summaries``.
3. **Streak milestone** — ``user_streaks.current_count`` matching one of
   the canonical milestone counts (7, 14, 30, 60, 90, 180, 365 days).
4. **Stale integration** — any ``Integration`` whose ``last_synced_at``
   is more than 24 hours ago (or has never been synced).

All checks are wrapped in individual try/except blocks so a failure in
one check never prevents the others from running.

Architecture
------------
- Runs in the synchronous Celery worker process.
- Async DB access is bridged via ``asyncio.run(_run())``.
- Push delivery is delegated to ``PushService.send_and_persist()``.
- User notification preferences are respected: each check reads
  ``UserPreferences.notification_settings`` and bails early if the
  relevant toggle is disabled.
"""

from __future__ import annotations

import asyncio
import json
import logging
from datetime import datetime, timedelta, timezone
from typing import Any

import sentry_sdk

from app.database import worker_async_session as async_session
from app.services.push_service import PushService
from app.worker import celery_app

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

# Canonical streak milestone day counts that trigger a notification.
_STREAK_MILESTONES: frozenset[int] = frozenset({7, 14, 30, 60, 90, 180, 365})

# How old (in hours) a last_synced_at must be before we consider it stale.
_INTEGRATION_STALE_HOURS: int = 24

# Notification setting keys (keys inside UserPreferences.notification_settings JSON).
_NOTIF_KEY_ANOMALY = "anomaly_alerts"
_NOTIF_KEY_GOAL = "goal_alerts"
_NOTIF_KEY_STREAK = "streak_milestones"
_NOTIF_KEY_STALE = "integration_reminders"


# ---------------------------------------------------------------------------
# Helper: check notification preference
# ---------------------------------------------------------------------------


def _notifications_enabled(notification_settings: dict[str, Any], key: str) -> bool:
    """Return True if the given notification toggle is enabled (or not set).

    Defaults to ``True`` so that users without explicit preferences still
    receive all notifications.

    Args:
        notification_settings: The ``notification_settings`` JSON dict from
            ``UserPreferences``.
        key: The toggle key to look up.

    Returns:
        ``True`` if the toggle is absent (default on) or explicitly ``True``.
    """
    return bool(notification_settings.get(key, True))


# ---------------------------------------------------------------------------
# Celery task
# ---------------------------------------------------------------------------


@celery_app.task(name="app.tasks.background_alerts.check_user_events")
def check_user_events(user_id: str) -> dict[str, Any]:
    """Check for alertable events and fire push notifications for a user.

    Called after health data ingest events. Checks four event categories
    independently so a failure in one does not suppress others.

    Args:
        user_id: Zuralog user ID to evaluate.

    Returns:
        A summary dict with:
            - ``user_id``: The user that was checked.
            - ``anomalies_notified``: Count of anomaly alerts sent.
            - ``goals_notified``: Count of goal completion alerts sent.
            - ``streaks_notified``: Count of streak milestone alerts sent.
            - ``stale_integrations_notified``: Count of stale-sync alerts sent.
            - ``status``: ``"ok"`` on success.
    """
    logger.info("check_user_events: starting for user '%s'", user_id)

    async def _run() -> dict[str, Any]:
        push_service = PushService()

        results: dict[str, Any] = {
            "user_id": user_id,
            "anomalies_notified": 0,
            "goals_notified": 0,
            "streaks_notified": 0,
            "stale_integrations_notified": 0,
            "status": "ok",
        }

        # ------------------------------------------------------------------
        # Load user notification preferences (soft import — graceful if missing)
        # ------------------------------------------------------------------
        notification_settings: dict[str, Any] = {}
        try:
            from sqlalchemy import select

            from app.models.user_preferences import UserPreferences

            async with async_session() as db:
                pref_result = await db.execute(
                    select(UserPreferences.notification_settings).where(
                        UserPreferences.user_id == user_id
                    )
                )
                row = pref_result.scalar_one_or_none()
                if row is not None:
                    if isinstance(row, dict):
                        notification_settings = row
                    elif isinstance(row, str):
                        try:
                            notification_settings = json.loads(row)
                        except (ValueError, TypeError):
                            notification_settings = {}
                    else:
                        notification_settings = {}
        except Exception:
            logger.warning(
                "check_user_events: could not load notification preferences "
                "for user=%s — defaulting to all enabled",
                user_id,
            )

        # ==================================================================
        # Check 1: Recent anomaly insights
        # ==================================================================
        if _notifications_enabled(notification_settings, _NOTIF_KEY_ANOMALY):
            try:
                from sqlalchemy import select

                from app.models.insight import Insight

                one_hour_ago = datetime.now(timezone.utc) - timedelta(hours=1)

                async with async_session() as db:
                    anomaly_result = await db.execute(
                        select(Insight).where(
                            Insight.user_id == user_id,
                            Insight.type == "anomaly_alert",
                            Insight.created_at >= one_hour_ago,
                            Insight.dismissed_at.is_(None),
                        )
                    )
                    anomalies = anomaly_result.scalars().all()

                    for anomaly in anomalies:
                        sent = await push_service.send_and_persist(
                            user_id=user_id,
                            title="Unusual health pattern detected",
                            body=anomaly.body or "An anomaly was detected in your recent health data.",
                            notification_type="anomaly_alert",
                            deep_link=f"zuralog://insights/{anomaly.id}",
                            data={"insight_id": str(anomaly.id), "type": "anomaly_alert"},
                            db=db,
                        )
                        if sent:
                            results["anomalies_notified"] += 1
                            logger.info(
                                "check_user_events: anomaly notification sent for user=%s insight=%s",
                                user_id,
                                anomaly.id,
                            )

            except Exception:
                logger.exception(
                    "check_user_events: error checking anomalies for user=%s", user_id
                )
                sentry_sdk.capture_exception()

        # ==================================================================
        # Check 2: Goal completion (steps and other daily metrics)
        # ==================================================================
        if _notifications_enabled(notification_settings, _NOTIF_KEY_GOAL):
            try:
                from sqlalchemy import func, select

                from app.models.daily_summary import DailySummary
                from app.models.user_goal import GoalPeriod, UserGoal

                today = datetime.now(timezone.utc).date()

                # Map goal metric names to daily_summaries metric_type values
                _metric_type_map: dict[str, str] = {
                    "steps": "steps",
                    "active_calories": "active_calories",
                    "distance_meters": "distance",
                    "flights_climbed": "floors_climbed",
                }

                async with async_session() as db:
                    # Load all active daily goals for the user
                    goals_result = await db.execute(
                        select(UserGoal).where(
                            UserGoal.user_id == user_id,
                            UserGoal.is_active.is_(True),
                            UserGoal.period == GoalPeriod.DAILY,
                        )
                    )
                    daily_goals = goals_result.scalars().all()

                    for goal in daily_goals:
                        metric_type = _metric_type_map.get(goal.metric)
                        if metric_type is None:
                            continue  # metric not tracked in daily_summaries

                        # Fetch today's metric value from daily_summaries
                        today_result = await db.execute(
                            select(func.sum(DailySummary.value)).where(
                                DailySummary.user_id == user_id,
                                DailySummary.date == today,
                                DailySummary.metric_type == metric_type,
                            )
                        )
                        actual_value = today_result.scalar_one_or_none() or 0.0

                        if actual_value >= goal.target_value:
                            metric_label = goal.metric.replace("_", " ").title()
                            target_label = (
                                f"{int(goal.target_value):,}"
                                if goal.target_value == int(goal.target_value)
                                else f"{goal.target_value:,.1f}"
                            )
                            sent = await push_service.send_and_persist(
                                user_id=user_id,
                                title="Goal reached!",
                                body=(
                                    f"You hit your {metric_label} goal of "
                                    f"{target_label} today. Great work!"
                                ),
                                notification_type="goal_reached",
                                deep_link="zuralog://goals",
                                data={
                                    "metric": goal.metric,
                                    "target": str(goal.target_value),
                                    "actual": str(actual_value),
                                },
                                db=db,
                            )
                            if sent:
                                results["goals_notified"] += 1
                                logger.info(
                                    "check_user_events: goal notification sent "
                                    "user=%s metric=%s actual=%s target=%s",
                                    user_id,
                                    goal.metric,
                                    actual_value,
                                    goal.target_value,
                                )

            except Exception:
                logger.exception(
                    "check_user_events: error checking goals for user=%s", user_id
                )
                sentry_sdk.capture_exception()

        # ==================================================================
        # Check 3: Streak milestones
        # ==================================================================
        if _notifications_enabled(notification_settings, _NOTIF_KEY_STREAK):
            try:
                from sqlalchemy import select

                from app.models.user_streak import UserStreak

                async with async_session() as db:
                    streaks_result = await db.execute(
                        select(UserStreak).where(
                            UserStreak.user_id == user_id,
                            UserStreak.current_count.in_(list(_STREAK_MILESTONES)),
                        )
                    )
                    milestone_streaks = streaks_result.scalars().all()

                    for streak in milestone_streaks:
                        count = streak.current_count
                        streak_label = streak.streak_type.replace("_", " ").title()
                        sent = await push_service.send_and_persist(
                            user_id=user_id,
                            title=f"{count}-day streak!",
                            body=(
                                f"You've maintained your {streak_label} streak "
                                f"for {count} day{'s' if count != 1 else ''}. "
                                "Keep it up!"
                            ),
                            notification_type="streak_milestone",
                            deep_link="zuralog://streaks",
                            data={
                                "streak_type": streak.streak_type,
                                "current_count": str(count),
                            },
                            db=db,
                        )
                        if sent:
                            results["streaks_notified"] += 1
                            logger.info(
                                "check_user_events: streak milestone notification sent "
                                "user=%s streak_type=%s count=%d",
                                user_id,
                                streak.streak_type,
                                count,
                            )

            except Exception:
                logger.exception(
                    "check_user_events: error checking streaks for user=%s", user_id
                )
                sentry_sdk.capture_exception()

        # ==================================================================
        # Check 4: Stale integrations (24h+ since last sync)
        # ==================================================================
        if _notifications_enabled(notification_settings, _NOTIF_KEY_STALE):
            try:
                from sqlalchemy import select

                from app.models.integration import Integration

                stale_cutoff = datetime.now(timezone.utc) - timedelta(
                    hours=_INTEGRATION_STALE_HOURS
                )

                async with async_session() as db:
                    integrations_result = await db.execute(
                        select(Integration).where(
                            Integration.user_id == user_id,
                            Integration.is_active.is_(True),
                        )
                    )
                    integrations = integrations_result.scalars().all()

                    for integration in integrations:
                        last_sync = integration.last_synced_at

                        # Treat None (never synced) and old timestamps as stale
                        is_stale: bool
                        if last_sync is None:
                            is_stale = True
                        else:
                            # last_synced_at may be a datetime or a string — normalise
                            if isinstance(last_sync, str):
                                try:
                                    last_sync_dt = datetime.fromisoformat(last_sync)
                                    if last_sync_dt.tzinfo is None:
                                        last_sync_dt = last_sync_dt.replace(
                                            tzinfo=timezone.utc
                                        )
                                    is_stale = last_sync_dt < stale_cutoff
                                except ValueError:
                                    logger.warning(
                                        "check_user_events: unparseable last_synced_at "
                                        "for integration %s — skipping stale check",
                                        integration.id,
                                    )
                                    continue
                            else:
                                last_sync_dt = last_sync
                                if last_sync_dt.tzinfo is None:
                                    last_sync_dt = last_sync_dt.replace(tzinfo=timezone.utc)
                                is_stale = last_sync_dt < stale_cutoff

                        if is_stale:
                            provider_label = integration.provider.replace("_", " ").title()
                            sent = await push_service.send_and_persist(
                                user_id=user_id,
                                title=f"Sync your {provider_label}",
                                body=(
                                    f"Your {provider_label} data hasn't been synced "
                                    f"in over {_INTEGRATION_STALE_HOURS} hours. "
                                    "Open the app to refresh."
                                ),
                                notification_type="integration_stale",
                                deep_link=f"zuralog://integrations/{integration.provider}",
                                data={
                                    "provider": integration.provider,
                                    "integration_id": str(integration.id),
                                },
                                db=db,
                            )
                            if sent:
                                results["stale_integrations_notified"] += 1
                                logger.info(
                                    "check_user_events: stale integration notification sent "
                                    "user=%s provider=%s",
                                    user_id,
                                    integration.provider,
                                )

            except Exception:
                logger.exception(
                    "check_user_events: error checking integrations for user=%s", user_id
                )
                sentry_sdk.capture_exception()

        logger.info(
            "check_user_events: completed for user='%s' results=%s",
            user_id,
            results,
        )
        return results

    return asyncio.run(_run())
