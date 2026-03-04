"""
Zuralog Cloud Brain — Insight Generation Celery Tasks.

Background tasks responsible for generating AI insight cards and persisting
them to the ``insights`` table.

Task inventory:
    generate_daily_insights_task(user_id)
        Generates insight cards for a single user after health data
        ingestion. Delegates content synthesis to the existing
        ``InsightGenerator`` (analytics module) and adds anomaly cards
        when outliers are detected. Respects data-maturity gating:
        complex analytical insights require ≥ 7 days of history.

    generate_insights_for_all_users_task()
        Beat-scheduled daily task. Fans out to
        ``generate_daily_insights_task`` for every user that has health
        data.

Duplicate prevention:
    The same ``(user_id, insight_type, calendar_date)`` combination is
    never written twice in a single day. The task checks for existing
    rows before inserting.

Architecture note:
    Celery workers are synchronous processes. All async DB operations
    are wrapped in ``asyncio.run(_async_helper())``.
"""

import asyncio
import logging
import uuid
from datetime import date, datetime, timezone

import sentry_sdk

from app.analytics.insight_generator import InsightGenerator
from app.database import async_session
from app.models.insight import Insight, InsightType
from app.worker import celery_app

logger = logging.getLogger(__name__)

# Minimum number of days of health data required before generating
# complex analytical insights (trends, correlations, anomaly detection).
_DATA_MATURITY_DAYS = 7


# ---------------------------------------------------------------------------
# Internal async helpers
# ---------------------------------------------------------------------------


async def _count_user_data_days(user_id: str) -> int:
    """Return the number of distinct calendar days with health data.

    Args:
        user_id: The user's unique identifier.

    Returns:
        Count of distinct ``date`` values in ``daily_health_metrics``.
    """
    from sqlalchemy import func, select

    from app.models.daily_metrics import DailyHealthMetrics

    async with async_session() as db:
        stmt = select(func.count(func.distinct(DailyHealthMetrics.date))).where(DailyHealthMetrics.user_id == user_id)
        result = await db.execute(stmt)
        return result.scalar_one() or 0


async def _insight_exists_today(
    user_id: str,
    insight_type: InsightType,
    today: date,
) -> bool:
    """Check whether an insight of the given type was already created today.

    Args:
        user_id: The user's unique identifier.
        insight_type: Insight category to check for.
        today: Calendar date to check against (server local date).

    Returns:
        True if a matching insight already exists for today.
    """
    from sqlalchemy import and_, cast, func, select
    from sqlalchemy import Date as SADate

    async with async_session() as db:
        stmt = (
            select(func.count())
            .select_from(Insight)
            .where(
                and_(
                    Insight.user_id == user_id,
                    Insight.type == insight_type.value,
                    cast(Insight.created_at, SADate) == today,
                )
            )
        )
        result = await db.execute(stmt)
        return (result.scalar_one() or 0) > 0


async def _save_insight(
    user_id: str,
    insight_type: InsightType,
    title: str,
    body: str,
    priority: int = 5,
    data: dict | None = None,
    reasoning: str | None = None,
) -> Insight:
    """Persist a single insight card to the database.

    Skips insertion if the same ``(user_id, type, today)`` combination
    already exists (idempotent daily generation).

    Args:
        user_id: The owner's user ID.
        insight_type: Category enum value.
        title: Short headline for the card.
        body: Full insight copy.
        priority: 1–10 priority rank (1 = most urgent). Defaults to 5.
        data: Optional structured JSON payload.
        reasoning: Optional internal AI reasoning text.

    Returns:
        The newly created Insight row (or the existing one if skipped).
    """
    today = date.today()
    if await _insight_exists_today(user_id, insight_type, today):
        logger.debug(
            "Skipping duplicate insight for user=%s type=%s date=%s",
            user_id,
            insight_type.value,
            today,
        )
        # Return a stub — callers don't need the full row in this case.
        return Insight(
            id="duplicate-skipped",
            user_id=user_id,
            type=insight_type.value,
            title=title,
            body=body,
        )

    async with async_session() as db:
        insight = Insight(
            id=str(uuid.uuid4()),
            user_id=user_id,
            type=insight_type.value,
            title=title,
            body=body,
            data=data,
            reasoning=reasoning,
            priority=priority,
            created_at=datetime.now(tz=timezone.utc),
        )
        db.add(insight)
        await db.commit()
        await db.refresh(insight)

    logger.info(
        "Saved insight user=%s type=%s id=%s",
        user_id,
        insight_type.value,
        insight.id,
    )
    return insight


async def _fetch_goal_status_and_trends(user_id: str) -> tuple[list[dict], dict]:
    """Fetch goal progress snapshots and trend data for a user.

    Delegates to the existing analytics service layer so we reuse all
    caching and computation logic.

    Args:
        user_id: The user's unique identifier.

    Returns:
        A ``(goal_status, trends)`` tuple suitable for InsightGenerator.
    """
    from app.analytics.analytics_service import AnalyticsService

    svc = AnalyticsService()
    async with async_session() as db:
        goal_status = await svc.get_goal_progress(db, user_id)
        trend_result = await svc.get_weekly_trends(db, user_id)

    # Repack weekly trends dict into the {metric: {trend, percent_change}} shape
    # that InsightGenerator expects.
    trends: dict = {}
    for metric, series in trend_result.get("metrics", {}).items():
        values = [v for v in series if v is not None]
        if len(values) >= 2:
            first, last = values[0], values[-1]
            change = ((last - first) / first * 100) if first else 0.0
            trends[metric] = {
                "trend": "up" if change > 3 else "down" if change < -3 else "stable",
                "percent_change": round(change, 1),
            }

    return goal_status, trends


async def _detect_anomalies(user_id: str) -> list[dict]:
    """Run anomaly detection on recent health metrics.

    Returns a list of anomaly dicts, each with ``metric``, ``value``,
    and ``message`` keys.  Returns empty list when no anomalies found
    or when the analytics module is not available.

    Args:
        user_id: The user's unique identifier.

    Returns:
        List of anomaly descriptor dicts (may be empty).
    """
    try:
        from sqlalchemy import select

        from app.models.daily_metrics import DailyHealthMetrics

        anomalies: list[dict] = []
        async with async_session() as db:
            # Fetch last 30 days of data for z-score style detection
            stmt = (
                select(DailyHealthMetrics)
                .where(DailyHealthMetrics.user_id == user_id)
                .order_by(DailyHealthMetrics.date.desc())
                .limit(30)
            )
            rows = (await db.execute(stmt)).scalars().all()

        if len(rows) < 7:
            return []

        # Simple statistical outlier: last value > 2.5 std deviations from mean
        import statistics

        metrics_to_check = ["steps", "resting_heart_rate", "hrv_ms"]
        for metric in metrics_to_check:
            values = [getattr(r, metric) for r in rows if getattr(r, metric) is not None]
            if len(values) < 7:
                continue
            mean = statistics.mean(values)
            stdev = statistics.stdev(values)
            if stdev == 0:
                continue
            latest = values[0]
            z = abs((latest - mean) / stdev)
            if z > 2.5:
                direction = "high" if latest > mean else "low"
                anomalies.append(
                    {
                        "metric": metric,
                        "value": latest,
                        "mean": round(mean, 1),
                        "z_score": round(z, 2),
                        "message": (
                            f"Your {metric.replace('_', ' ')} today ({latest:.0f}) "
                            f"is unusually {direction} compared to your recent average "
                            f"({mean:.0f})."
                        ),
                    }
                )
        return anomalies
    except Exception:
        logger.warning("Anomaly detection failed for user=%s", user_id, exc_info=True)
        return []


async def _determine_time_of_day() -> str:
    """Return a human-readable time-of-day bucket for the current UTC hour.

    Returns:
        One of ``"morning"``, ``"afternoon"``, ``"evening"``, ``"night"``.
    """
    hour = datetime.now(tz=timezone.utc).hour
    if 5 <= hour < 11:
        return "morning"
    if 11 <= hour < 17:
        return "afternoon"
    if 17 <= hour < 22:
        return "evening"
    return "night"


async def _generate_for_user(user_id: str) -> int:
    """Core async logic for per-user insight generation.

    Args:
        user_id: The user's unique identifier.

    Returns:
        Number of insight cards written to the database.
    """
    written = 0
    data_days = await _count_user_data_days(user_id)

    # ------------------------------------------------------------------
    # Tier 1: Always generate — welcome insight for brand-new users
    # ------------------------------------------------------------------
    if data_days == 0:
        today = date.today()
        if not await _insight_exists_today(user_id, InsightType.WELCOME, today):
            await _save_insight(
                user_id=user_id,
                insight_type=InsightType.WELCOME,
                title="Welcome to Zuralog!",
                body=(
                    "Connect your first health source and I'll start building "
                    "personalised insights for you. The more data I have, the "
                    "smarter I get."
                ),
                priority=1,
            )
            written += 1
        return written

    # ------------------------------------------------------------------
    # Tier 2: Time-of-day morning briefing (always, regardless of data maturity)
    # ------------------------------------------------------------------
    time_slot = await _determine_time_of_day()
    if time_slot == "morning":
        today = date.today()
        if not await _insight_exists_today(user_id, InsightType.MORNING_BRIEFING, today):
            await _save_insight(
                user_id=user_id,
                insight_type=InsightType.MORNING_BRIEFING,
                title="Good morning — here's your health snapshot",
                body=(
                    "Your dashboard is ready. Check today's goals, review last "
                    "night's sleep, and set your intentions for the day."
                ),
                priority=3,
            )
            written += 1

    # ------------------------------------------------------------------
    # Tier 3: Complex analytics insights — require ≥ 7 days of data
    # ------------------------------------------------------------------
    if data_days < _DATA_MATURITY_DAYS:
        logger.info(
            "Skipping complex insights for user=%s (data_days=%d < %d)",
            user_id,
            data_days,
            _DATA_MATURITY_DAYS,
        )
        return written

    goal_status, trends = await _fetch_goal_status_and_trends(user_id)

    # Goal-nudge insight
    generator = InsightGenerator()
    insight_text = generator.generate_dashboard_insight(goal_status, trends)

    # Determine type and priority based on content
    has_near_miss = any(
        not g["is_met"] and g["progress_pct"] >= InsightGenerator.NEAR_MISS_THRESHOLD for g in goal_status
    )
    has_unmet = any(not g["is_met"] for g in goal_status)
    all_met = bool(goal_status) and all(g["is_met"] for g in goal_status)

    if has_near_miss:
        nudge_type = InsightType.GOAL_NUDGE
        nudge_priority = 2
        nudge_title = "You're almost there!"
    elif all_met:
        nudge_type = InsightType.ACTIVITY_PROGRESS
        nudge_priority = 4
        nudge_title = "All goals crushed today"
    elif has_unmet:
        nudge_type = InsightType.ACTIVITY_PROGRESS
        nudge_priority = 5
        nudge_title = "Goal progress update"
    else:
        nudge_type = InsightType.ACTIVITY_PROGRESS
        nudge_priority = 6
        nudge_title = "Today's activity overview"

    today = date.today()
    if not await _insight_exists_today(user_id, nudge_type, today):
        await _save_insight(
            user_id=user_id,
            insight_type=nudge_type,
            title=nudge_title,
            body=insight_text,
            priority=nudge_priority,
            data={"goal_count": len(goal_status)},
            reasoning=(f"Generated from {len(goal_status)} goals and {len(trends)} trend signals."),
        )
        written += 1

    # Anomaly insights
    anomalies = await _detect_anomalies(user_id)
    for anomaly in anomalies[:2]:  # Cap at 2 anomaly alerts per run
        if not await _insight_exists_today(user_id, InsightType.ANOMALY_ALERT, today):
            metric_label = anomaly["metric"].replace("_", " ").title()
            await _save_insight(
                user_id=user_id,
                insight_type=InsightType.ANOMALY_ALERT,
                title=f"Unusual {metric_label} detected",
                body=anomaly["message"],
                priority=2,
                data=anomaly,
                reasoning=(f"Z-score {anomaly['z_score']} exceeded 2.5 threshold for metric '{anomaly['metric']}'."),
            )
            written += 1

    return written


async def _get_all_active_user_ids() -> list[str]:
    """Fetch all user IDs that have at least one health data row.

    Args: None

    Returns:
        List of user ID strings.
    """
    from sqlalchemy import distinct, select

    from app.models.daily_metrics import DailyHealthMetrics

    async with async_session() as db:
        stmt = select(distinct(DailyHealthMetrics.user_id))
        result = await db.execute(stmt)
        return list(result.scalars().all())


# ---------------------------------------------------------------------------
# Celery Tasks
# ---------------------------------------------------------------------------


@celery_app.task(
    name="app.tasks.insight_tasks.generate_daily_insights_task",
    bind=True,
    max_retries=3,
    default_retry_delay=60,
)
def generate_daily_insights_task(self, user_id: str) -> dict:
    """Generate daily insight cards for a single user.

    Designed to be called after a health data ingestion event (webhook
    or device sync). Safe to call multiple times per day — duplicate
    prevention is enforced at the DB level.

    Args:
        user_id: The user's unique identifier (Supabase Auth UID).

    Returns:
        Dict with ``user_id`` and ``insights_written`` count.
    """
    try:
        insights_written = asyncio.run(_generate_for_user(user_id))
        logger.info(
            "generate_daily_insights_task completed: user=%s written=%d",
            user_id,
            insights_written,
        )
        return {"user_id": user_id, "insights_written": insights_written}
    except Exception as exc:
        logger.exception("generate_daily_insights_task failed for user=%s", user_id)
        sentry_sdk.capture_exception(exc)
        raise self.retry(exc=exc)


@celery_app.task(
    name="app.tasks.insight_tasks.generate_insights_for_all_users_task",
    bind=True,
    max_retries=1,
)
def generate_insights_for_all_users_task(self) -> dict:
    """Fan-out daily insight generation to all active users.

    Intended to run once per day via Celery Beat. Enqueues a
    ``generate_daily_insights_task`` for each user that has health data
    so that per-user work is parallelised across Celery workers.

    Returns:
        Dict with ``users_queued`` count.
    """
    try:
        user_ids: list[str] = asyncio.run(_get_all_active_user_ids())
        for uid in user_ids:
            generate_daily_insights_task.delay(uid)
        logger.info(
            "generate_insights_for_all_users_task enqueued %d users",
            len(user_ids),
        )
        return {"users_queued": len(user_ids)}
    except Exception as exc:
        logger.exception("generate_insights_for_all_users_task failed")
        sentry_sdk.capture_exception(exc)
        raise self.retry(exc=exc)


# ---------------------------------------------------------------------------
# Task 2.24: Background Alert Triggers
# ---------------------------------------------------------------------------


@celery_app.task(name="app.tasks.insight.check_and_alert_task")
def check_and_alert_task(user_id: str) -> dict:
    """Post-ingestion alert check for a single user.

    Called after health data is ingested for ``user_id``. Checks for:
    1. Goal reached — step count >= daily step goal for today.
    2. Streak milestone — 7, 14, or 30 consecutive days with steps.
    3. Stale integrations — any integration that hasn't synced in 24h+.

    Respects user notification preferences (notification_settings toggles).

    Args:
        user_id: Zuralog user ID to evaluate.

    Returns:
        Dict with ``alerts_sent`` count and ``user_id``.
    """
    logger.debug("check_and_alert_task: evaluating user %s", user_id)

    async def _run() -> dict:
        from datetime import timedelta  # noqa: PLC0415
        from sqlalchemy import and_, select as _select  # noqa: PLC0415

        from app.models.daily_metrics import DailyHealthMetrics  # noqa: PLC0415
        from app.models.integration import Integration  # noqa: PLC0415
        from app.models.notification_log import NotificationType  # noqa: PLC0415
        from app.models.user import User  # noqa: PLC0415
        from app.models.user_device import UserDevice  # noqa: PLC0415
        from app.models.user_preferences import UserPreferences  # noqa: PLC0415
        from app.services.notification_service import NotificationService  # noqa: PLC0415
        from app.services.push_service import PushService  # noqa: PLC0415

        push_svc = PushService()
        notif_svc = NotificationService(push_service=push_svc, db_factory=async_session)
        alerts_sent = 0
        _STALE_HOURS = 24
        _DEFAULT_STEP_GOAL = 10_000

        async with async_session() as db:
            user_result = await db.execute(_select(User).where(User.id == user_id))
            user = user_result.scalar_one_or_none()
            if user is None:
                return {"alerts_sent": 0, "user_id": user_id}

            prefs_result = await db.execute(_select(UserPreferences).where(UserPreferences.user_id == user_id))
            prefs = prefs_result.scalar_one_or_none()

            notif_settings = (prefs.notification_settings or {}) if prefs else {}
            goals_enabled = notif_settings.get("goal_alerts", True)
            streaks_enabled = notif_settings.get("streak_alerts", True)
            integration_enabled = notif_settings.get("integration_alerts", True)

            device_result = await db.execute(
                _select(UserDevice)
                .where(UserDevice.user_id == user_id)
                .order_by(UserDevice.last_seen_at.desc())
                .limit(1)
            )
            device = device_result.scalar_one_or_none()
            device_token = device.fcm_token if device else None
            today_str = datetime.now(timezone.utc).date().isoformat()

            # 1. Goal reached
            if goals_enabled:
                try:
                    m = (
                        await db.execute(
                            _select(DailyHealthMetrics)
                            .where(
                                DailyHealthMetrics.user_id == user_id,
                                DailyHealthMetrics.date == today_str,
                                DailyHealthMetrics.steps.isnot(None),
                            )
                            .limit(1)
                        )
                    ).scalar_one_or_none()
                    step_goal = _DEFAULT_STEP_GOAL
                    if prefs and prefs.goals:
                        for g in prefs.goals:
                            if g.get("metric") == "daily_steps":
                                step_goal = int(g.get("target", _DEFAULT_STEP_GOAL))
                                break
                    if m and m.steps and m.steps >= step_goal:
                        await notif_svc.send_and_persist(
                            user_id=user_id,
                            title="Goal reached!",
                            body=f"You hit {m.steps:,} steps today!",
                            notification_type=NotificationType.ACHIEVEMENT,
                            device_token=device_token,
                            deep_link="zuralog://metrics/steps",
                            db=db,
                        )
                        alerts_sent += 1
                except Exception:  # noqa: BLE001
                    logger.exception("check_and_alert_task: goal check failed for %s", user_id)

            # 2. Streak milestone
            if streaks_enabled:
                try:
                    streak = await _count_step_streak_local(user_id, today_str, db)
                    if streak in (7, 14, 30):
                        await notif_svc.send_and_persist(
                            user_id=user_id,
                            title=f"{streak}-day streak!",
                            body=f"You've been active every day for {streak} days!",
                            notification_type=NotificationType.STREAK,
                            device_token=device_token,
                            deep_link="zuralog://streak",
                            db=db,
                        )
                        alerts_sent += 1
                except Exception:  # noqa: BLE001
                    logger.exception("check_and_alert_task: streak check failed for %s", user_id)

            # 3. Stale integration
            if integration_enabled:
                try:
                    cutoff = datetime.now(timezone.utc) - timedelta(hours=_STALE_HOURS)
                    intg_rows = (
                        (
                            await db.execute(
                                _select(Integration).where(
                                    and_(
                                        Integration.user_id == user_id,
                                        Integration.is_active.is_(True),
                                    )
                                )
                            )
                        )
                        .scalars()
                        .all()
                    )
                    for intg in intg_rows:
                        ls = intg.last_synced_at
                        if ls is None:
                            continue
                        if isinstance(ls, str):
                            try:
                                ls = datetime.fromisoformat(ls)
                            except ValueError:
                                continue
                        if ls.tzinfo is None:
                            ls = ls.replace(tzinfo=timezone.utc)
                        if ls < cutoff:
                            await notif_svc.send_and_persist(
                                user_id=user_id,
                                title=f"{intg.provider.title()} sync issue",
                                body=(
                                    f"Your {intg.provider.title()} hasn't synced in over "
                                    f"{_STALE_HOURS} hours. Tap to reconnect."
                                ),
                                notification_type=NotificationType.INTEGRATION_ALERT,
                                device_token=device_token,
                                deep_link=f"zuralog://integrations/{intg.provider}",
                                db=db,
                            )
                            alerts_sent += 1
                except Exception:  # noqa: BLE001
                    logger.exception("check_and_alert_task: integration check failed for %s", user_id)

        return {"alerts_sent": alerts_sent, "user_id": user_id}

    return asyncio.run(_run())


@celery_app.task(name="app.tasks.insight.check_stale_integrations_task")
def check_stale_integrations_task() -> dict:
    """Daily task: scan all users for stale integrations and trigger alerts.

    For each active integration that hasn't synced in 24h+, dispatches a
    ``check_and_alert_task`` for the owning user to send a notification.

    Returns:
        Dict with ``users_checked`` and ``stale_found`` counts.
    """
    logger.info("check_stale_integrations_task: starting daily stale integration scan")

    async def _run() -> dict:
        from datetime import timedelta  # noqa: PLC0415
        from sqlalchemy import select as _select  # noqa: PLC0415

        from app.models.integration import Integration  # noqa: PLC0415

        cutoff = datetime.now(timezone.utc) - timedelta(hours=24)
        stale_found = 0
        users_checked: set[str] = set()

        async with async_session() as db:
            integrations = (
                (await db.execute(_select(Integration).where(Integration.is_active.is_(True)))).scalars().all()
            )

            for intg in integrations:
                users_checked.add(intg.user_id)
                ls = intg.last_synced_at
                if ls is None:
                    continue
                if isinstance(ls, str):
                    try:
                        ls = datetime.fromisoformat(ls)
                    except ValueError:
                        continue
                if ls.tzinfo is None:
                    ls = ls.replace(tzinfo=timezone.utc)
                if ls < cutoff:
                    stale_found += 1
                    try:
                        check_and_alert_task.delay(user_id=intg.user_id)
                    except Exception:  # noqa: BLE001
                        logger.exception(
                            "check_stale_integrations_task: failed to queue for %s",
                            intg.user_id,
                        )

        logger.info(
            "check_stale_integrations_task: complete — checked=%d stale=%d",
            len(users_checked),
            stale_found,
        )
        return {"users_checked": len(users_checked), "stale_found": stale_found}

    return asyncio.run(_run())


async def _count_step_streak_local(user_id: str, today_str: str, db) -> int:
    """Count consecutive active days (steps > 500) ending today.

    Args:
        user_id: Zuralog user ID.
        today_str: Today's ISO date string.
        db: Open async session.

    Returns:
        Streak length in days.
    """
    from app.models.daily_metrics import DailyHealthMetrics  # noqa: PLC0415
    from sqlalchemy import select as _select  # noqa: PLC0415

    stmt = (
        _select(DailyHealthMetrics)
        .where(
            DailyHealthMetrics.user_id == user_id,
            DailyHealthMetrics.steps.isnot(None),
            DailyHealthMetrics.steps > 500,
        )
        .order_by(DailyHealthMetrics.date.desc())
        .limit(31)
    )
    rows = (await db.execute(stmt)).scalars().all()

    streak = 0
    prev_d = None
    for row in rows:
        try:
            row_date = date.fromisoformat(row.date)
        except (ValueError, TypeError):
            break
        if prev_d is None:
            prev_d = row_date
            streak = 1
        elif (prev_d - row_date).days == 1:
            streak += 1
            prev_d = row_date
        else:
            break
    return streak
