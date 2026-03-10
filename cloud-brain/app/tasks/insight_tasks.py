"""
Zuralog Cloud Brain — Celery Tasks for Insight Generation.

Provides the ``generate_insights_for_user`` Celery task, which is invoked
after health data ingest to produce fresh AI insight cards for a user.

Pipeline overview
-----------------
1. Determine which insight types are most relevant given the current hour
   of the day (time-of-day awareness).
2. Query the ``daily_health_metrics`` table to check data maturity.  If
   fewer than 7 days of data are available, inject a ``welcome`` card so
   the user knows the AI is still learning.
3. Instantiate ``InsightGenerator`` and call ``generate_dashboard_insight``
   to obtain rule-based text, then persist one or more ``Insight`` rows.

Architecture notes
------------------
- All tasks run in the synchronous Celery worker process.
- Async DB access is bridged via ``asyncio.run(_run())``.
- The task is designed to be idempotent: duplicate calls for the same user
  on the same day will simply add more insight rows (each has a UUID PK).
  The GET endpoint's ``created_at`` filter lets the client request only
  today's cards if desired.
"""

import asyncio
import logging
from datetime import datetime, timedelta, timezone

from sqlalchemy import and_, func, or_, select

from app.analytics.insight_generator import InsightGenerator
from app.database import worker_async_session as async_session
from app.models.daily_metrics import DailyHealthMetrics
from app.models.insight import Insight
from app.models.integration import Integration
from app.worker import celery_app

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Time-of-day priority bands
# ---------------------------------------------------------------------------
# Hour ranges (UTC) → list of (insight_type, priority) tuples that should
# be emphasised during that window.  Lower priority number = more urgent.

_PRIORITY_BY_HOUR: dict[tuple[int, int], list[tuple[str, int]]] = {
    (0, 6): [("sleep_analysis", 1), ("goal_nudge", 3)],
    (6, 12): [("activity_progress", 1), ("goal_nudge", 2), ("nutrition_summary", 4)],
    (12, 18): [("nutrition_summary", 1), ("activity_progress", 2), ("goal_nudge", 3)],
    (18, 24): [("sleep_analysis", 2), ("activity_progress", 3), ("goal_nudge", 4)],
}

# Minimum number of days of data before we consider the user "mature"
_MIN_DATA_DAYS_FOR_MATURITY = 7


def _get_time_of_day_priorities(hour: int) -> list[tuple[str, int]]:
    """Return the ordered (type, priority) list for a given UTC hour.

    Args:
        hour: Current UTC hour (0–23).

    Returns:
        List of ``(insight_type, priority)`` tuples for the active band,
        or the morning band as a safe default.
    """
    for (start, end), priorities in _PRIORITY_BY_HOUR.items():
        if start <= hour < end:
            return priorities
    # Should not happen for valid hours — fall back to morning band.
    return _PRIORITY_BY_HOUR[(6, 12)]


# ---------------------------------------------------------------------------
# Celery task
# ---------------------------------------------------------------------------


@celery_app.task(name="app.tasks.insight_tasks.generate_insights_for_user")
def generate_insights_for_user(user_id: str) -> dict:
    """Generate and persist AI insight cards for a user after data ingest.

    Called by the health ingest pipeline (or manually) to synthesise the
    latest health data into actionable insight cards.  The function is
    time-of-day aware and data-maturity aware:

    - **Time-of-day**: The insight type order and priority are adjusted
      based on the current UTC hour so the most contextually relevant
      cards bubble to the top (e.g. sleep analysis in the early morning,
      nutrition in the afternoon).
    - **Data maturity**: If the user has fewer than
      ``_MIN_DATA_DAYS_FOR_MATURITY`` days of health metric records, a
      ``welcome`` insight is injected first to inform them that the AI is
      still building a baseline.

    Args:
        user_id: Zuralog user ID to generate insights for.

    Returns:
        A summary dict with ``"user_id"``, ``"insights_created"``, and
        ``"status"`` for Celery task result inspection.
    """
    logger.info("generate_insights_for_user: starting for user '%s'", user_id)

    async def _run() -> dict:
        async with async_session() as db:  # type: ignore[attr-defined]
            # ------------------------------------------------------------------
            # 1. Check data maturity
            # ------------------------------------------------------------------
            distinct_days_stmt = select(func.count(DailyHealthMetrics.date.distinct())).where(
                DailyHealthMetrics.user_id == user_id
            )
            result = await db.execute(distinct_days_stmt)
            distinct_day_count: int = result.scalar_one() or 0

            is_mature = distinct_day_count >= _MIN_DATA_DAYS_FOR_MATURITY

            logger.debug(
                "generate_insights_for_user: user='%s' distinct_days=%d mature=%s",
                user_id,
                distinct_day_count,
                is_mature,
            )

            # ------------------------------------------------------------------
            # 2. Determine time-of-day context
            # ------------------------------------------------------------------
            now_utc = datetime.now(timezone.utc)
            current_hour = now_utc.hour
            tod_priorities = _get_time_of_day_priorities(current_hour)

            # ------------------------------------------------------------------
            # 3. Generate the primary insight text via InsightGenerator
            # ------------------------------------------------------------------
            generator = InsightGenerator()

            # For now we pass empty goal_status and trends — the generator
            # falls back to generic messaging.  A richer integration would
            # pull live goal and trend data from the analytics service.
            dashboard_text = generator.generate_dashboard_insight(
                goal_status=[],
                trends={},
            )

            insights_created: list[Insight] = []

            # ------------------------------------------------------------------
            # 4. Inject welcome / building card for immature accounts
            # ------------------------------------------------------------------
            if not is_mature:
                days_remaining = max(0, _MIN_DATA_DAYS_FOR_MATURITY - distinct_day_count)
                welcome_insight = Insight(
                    user_id=user_id,
                    type="welcome",
                    title="Building your health baseline",
                    body=(
                        f"Zuralog is learning your patterns. Keep syncing — "
                        f"personalised insights unlock in about {days_remaining} more "
                        f"day{'s' if days_remaining != 1 else ''}."
                    ),
                    data={
                        "days_logged": distinct_day_count,
                        "days_until_mature": days_remaining,
                    },
                    reasoning=None,
                    priority=1,
                )
                db.add(welcome_insight)
                insights_created.append(welcome_insight)

            # ------------------------------------------------------------------
            # 5. Create time-of-day contextual insight cards
            # ------------------------------------------------------------------
            for insight_type, base_priority in tod_priorities:
                card_title, card_body = _build_card_text(
                    insight_type=insight_type,
                    dashboard_text=dashboard_text,
                    hour=current_hour,
                )
                card = Insight(
                    user_id=user_id,
                    type=insight_type,
                    title=card_title,
                    body=card_body,
                    data={
                        "generated_at": now_utc.isoformat(),
                        "hour_utc": current_hour,
                    },
                    reasoning=None,
                    priority=base_priority if is_mature else base_priority + 1,
                )
                db.add(card)
                insights_created.append(card)

            await db.commit()

            count = len(insights_created)
            logger.info(
                "generate_insights_for_user: created %d insight(s) for user '%s'",
                count,
                user_id,
            )

            return {
                "user_id": user_id,
                "insights_created": count,
                "status": "ok",
            }

    return asyncio.run(_run())


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------


def _build_card_text(
    insight_type: str,
    dashboard_text: str,
    hour: int,
) -> tuple[str, str]:
    """Produce (title, body) strings for a given insight type and hour.

    For the MVP these are rule-based templates.  An LLM-backed variant can
    replace this function without changing the task signature.

    Args:
        insight_type: One of the canonical ``INSIGHT_TYPES``.
        dashboard_text: Primary insight string from ``InsightGenerator``.
        hour: Current UTC hour (used for contextual phrasing).

    Returns:
        A ``(title, body)`` tuple of strings.
    """
    _time_label: str
    if 0 <= hour < 6:
        _time_label = "last night"
    elif 6 <= hour < 12:
        _time_label = "this morning"
    elif 12 <= hour < 18:
        _time_label = "today"
    else:
        _time_label = "this evening"

    _templates: dict[str, tuple[str, str]] = {
        "sleep_analysis": (
            "Sleep summary",
            f"Here's how you slept {_time_label}. {dashboard_text}",
        ),
        "activity_progress": (
            "Activity update",
            f"Your activity progress {_time_label}: {dashboard_text}",
        ),
        "nutrition_summary": (
            "Nutrition overview",
            f"A quick look at your nutrition {_time_label}. {dashboard_text}",
        ),
        "anomaly_alert": (
            "Something looks unusual",
            dashboard_text,
        ),
        "goal_nudge": (
            "Goal check-in",
            dashboard_text,
        ),
        "correlation_discovery": (
            "Pattern detected",
            dashboard_text,
        ),
        "streak_milestone": (
            "Streak milestone",
            dashboard_text,
        ),
        "welcome": (
            "Welcome to Zuralog",
            dashboard_text,
        ),
    }

    return _templates.get(insight_type, ("Health insight", dashboard_text))


# ---------------------------------------------------------------------------
# Stale integration check task
# ---------------------------------------------------------------------------


@celery_app.task(name="app.tasks.insight_tasks.check_stale_integrations_task")
def check_stale_integrations_task() -> dict[str, int]:
    """Check for integrations that haven't synced in 24+ hours.

    Logs warnings for stale integrations. Runs daily via Beat.

    Returns:
        dict with 'stale_count' key indicating number of stale integrations found.
    """

    async def _run() -> dict[str, int]:
        async with async_session() as session:
            now = datetime.now(timezone.utc)
            cutoff = now - timedelta(hours=24)

            # Use COUNT — never load ORM objects just to count rows.
            # At 1M users × 5 integrations = 5M rows; a full fetch would OOM the worker.
            stmt = (
                select(func.count())
                .select_from(Integration)
                .where(
                    Integration.is_active == True,  # noqa: E712
                    or_(
                        Integration.last_synced_at < cutoff,
                        and_(
                            Integration.last_synced_at.is_(None),
                            Integration.created_at < cutoff,
                        ),
                    ),
                )
            )
            stale_count: int = (await session.execute(stmt)).scalar_one()

            if stale_count > 0:
                logger.warning(
                    "Found %d stale integrations (not synced in 24h)",
                    stale_count,
                )

            return {"stale_count": stale_count}

    return asyncio.run(_run())
