"""
Zuralog Cloud Brain — Celery Tasks for Insight Generation.

New pipeline (replaces the old rule-based generator):
1. Date-lock check — exit immediately if today's batch already exists.
2. HealthBriefBuilder — fetches all 10 data sources in parallel.
2b. Welcome card for immature accounts (< MIN_DATA_DAYS_FOR_MATURITY) — bypasses steps 3-5.
3. InsightSignalDetector — runs all 8 signal categories.
4. SignalPrioritizer — ranks, deduplicates, enforces diversity.
5. InsightCardWriter — single LLM call with 3-level fallback chain.
6. Persist — bulk insert with generation_date + signal_type set.

Also provides fan_out_daily_insights task for the hourly Celery Beat schedule.
"""

import asyncio
import logging
import uuid
from datetime import date, datetime, timezone
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from sqlalchemy import and_, func, select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.analytics.health_brief_builder import HealthBriefBuilder
from app.analytics.insight_signal_detector import InsightSignalDetector
from app.analytics.insight_card_writer import InsightCardWriter
from app.analytics.signal_prioritizer import SignalPrioritizer
from app.analytics.user_focus_profile import UserFocusProfileBuilder
from app.constants import MIN_DATA_DAYS_FOR_MATURITY
from app.database import worker_async_session as async_session
from app.models.insight import Insight
from app.models.user_preferences import UserPreferences
from app.worker import celery_app

logger = logging.getLogger(__name__)


@celery_app.task(name="app.tasks.insight_tasks.generate_insights_for_user")
def generate_insights_for_user(user_id: str, user_timezone: str = "UTC") -> dict:
    """Generate and persist daily insight cards for a user.

    Safe to call multiple times — the date-lock prevents re-generation.

    Args:
        user_id: Zuralog user ID.
        user_timezone: IANA timezone string (e.g. "America/New_York"). Defaults to "UTC".

    Returns:
        Summary dict: user_id, insights_written, status.
    """
    logger.info("generate_insights_for_user: starting for user='%s' tz='%s'", user_id, user_timezone)
    return asyncio.run(_run_pipeline_for_celery(user_id, user_timezone))


async def _run_pipeline_for_celery(user_id: str, user_timezone: str = "UTC") -> dict:
    async with async_session() as db:
        return await _run_pipeline_async(user_id=user_id, db=db, user_timezone=user_timezone)


async def _run_pipeline_async(user_id: str, db: AsyncSession, user_timezone: str = "UTC") -> dict:
    """Testable async implementation of the 6-step insight pipeline."""

    # ── Step 1: Date-lock ────────────────────────────────────────────────────
    try:
        tz = ZoneInfo(user_timezone)
    except (ZoneInfoNotFoundError, Exception):
        tz = ZoneInfo("UTC")
    today = datetime.now(tz).date()

    # Date-lock: counts non-dismissed cards only.
    # This allows re-generation if the user has dismissed all their cards,
    # which is intentional — fresh cards give the dismissed user new content.
    # The unique constraint (uq_insights_user_signal_date) prevents true duplicates.
    lock_stmt = (
        select(func.count())
        .select_from(Insight)
        .where(
            and_(
                Insight.user_id == user_id,
                Insight.generation_date == today,
                Insight.dismissed_at.is_(None),  # matches partial index; dismissed cards don't block re-generation
            )
        )
    )
    existing_count: int = (await db.execute(lock_stmt)).scalar_one()

    if existing_count > 0:
        logger.info(
            "generate_insights_for_user: date-lock hit for user='%s' date='%s' existing=%d",
            user_id,
            today.isoformat(),
            existing_count,
        )
        return {"user_id": user_id, "insights_written": 0, "status": "skipped_date_lock"}

    # ── Step 2: Fetch health data ────────────────────────────────────────────
    brief = await HealthBriefBuilder(user_id=user_id, db=db).build()

    # ── Welcome card for immature accounts ───────────────────────────────────
    if brief.data_maturity_days < MIN_DATA_DAYS_FOR_MATURITY:
        days_remaining = max(0, MIN_DATA_DAYS_FOR_MATURITY - brief.data_maturity_days)
        welcome_cards = [
            {
                "type": "welcome",
                "title": "Building your health baseline",
                "body": (
                    f"Zuralog is learning your patterns. Keep syncing — "
                    f"personalised insights unlock in about {days_remaining} more "
                    f"day{'s' if days_remaining != 1 else ''}."
                ),
                "priority": 1,
                "reasoning": None,
                "signal_type": "first_week",
                "data_payload": {
                    "days_logged": brief.data_maturity_days,
                    "days_until_mature": days_remaining,
                },
            }
        ]
        written = await _persist_cards(user_id, welcome_cards, today, db)
        return {"user_id": user_id, "insights_written": written, "status": "ok"}

    # ── Step 3: Detect signals ───────────────────────────────────────────────
    raw_signals = InsightSignalDetector(brief).detect_all()
    logger.debug("insight pipeline: user='%s' raw_signals=%d", user_id, len(raw_signals))

    # ── Step 4: Prioritize ───────────────────────────────────────────────────
    prioritized = SignalPrioritizer(raw_signals).prioritize()
    if not prioritized:
        logger.info("insight pipeline: no signals for user='%s'", user_id)
        return {"user_id": user_id, "insights_written": 0, "status": "ok_no_signals"}

    # ── Step 5: Write cards via LLM ──────────────────────────────────────────
    focus = UserFocusProfileBuilder(
        goals=brief.preferences.goals,
        dashboard_layout=brief.preferences.dashboard_layout,
        coach_persona=brief.preferences.coach_persona,
        fitness_level=brief.preferences.fitness_level,
        units_system=brief.preferences.units_system,
    ).build()

    llm_cards = await InsightCardWriter(
        signals=prioritized,
        focus=focus,
        target_date=today.isoformat(),
    ).write_cards()

    enriched = _enrich_cards(llm_cards, prioritized)

    # ── Step 6: Persist ──────────────────────────────────────────────────────
    written = await _persist_cards(user_id, enriched, today, db)
    logger.info("insight pipeline: wrote %d card(s) for user='%s'", written, user_id)
    return {"user_id": user_id, "insights_written": written, "status": "ok"}


async def _persist_cards(
    user_id: str,
    cards: list[dict],
    generation_date: date,
    db: AsyncSession,
) -> int:
    """Bulk insert insight cards. Skips conflicts on (user_id, signal_type, generation_date)."""
    if not cards:
        return 0

    rows = [
        {
            "id": str(uuid.uuid4()),
            "user_id": user_id,
            "type": card.get("type", "welcome"),
            "title": card.get("title", "Health insight")[:200],
            "body": card.get("body", "")[:2000],
            "data": card.get("data_payload", card.get("data", {})),
            "reasoning": (lambda r: str(r)[:1000] if r else None)(card.get("reasoning")),
            "priority": int(card.get("priority", 5)),
            "generation_date": generation_date,
            "signal_type": card.get("signal_type", card.get("type", "welcome")),
        }
        for card in cards
    ]

    stmt = pg_insert(Insight).values(rows).on_conflict_do_nothing(constraint="uq_insights_user_signal_date")
    result = await db.execute(stmt)
    await db.commit()
    return result.rowcount if result.rowcount >= 0 else len(rows)


def _enrich_cards(llm_cards: list[dict], signals: list) -> list[dict]:
    """Attach signal metadata from InsightSignal instances to LLM-written cards."""
    llm_cards = llm_cards[: len(signals)]  # Prevent extra hallucinated cards from slipping through
    if len(llm_cards) < len(signals):
        logger.warning(
            "_enrich_cards: LLM returned %d cards for %d signals — %d signal(s) will have no card",
            len(llm_cards),
            len(signals),
            len(signals) - len(llm_cards),
        )
    enriched = []
    for i, card in enumerate(llm_cards):
        signal = signals[i] if i < len(signals) else None
        enriched.append(
            {
                **card,
                "signal_type": signal.signal_type if signal else card.get("type", "welcome"),
                "data_payload": signal.data_payload if signal else {},
            }
        )
    return enriched


# ── Fan-out task ─────────────────────────────────────────────────────────────


@celery_app.task(name="app.tasks.insight_tasks.fan_out_daily_insights")
def fan_out_daily_insights() -> dict:
    """Hourly fan-out: enqueue insight tasks for users whose local time is 6 AM.

    Runs at the top of every UTC hour via Celery Beat.
    """
    logger.info("fan_out_daily_insights: starting")
    return asyncio.run(_fan_out_async())


async def _fan_out_async() -> dict:
    now_utc = datetime.now(timezone.utc)
    async with async_session() as db:
        # At 1M users: replace with cursor/keyset pagination to avoid loading all rows into memory.
        # For now, a 100k LIMIT provides a safety guard against accidental OOM during rollout.
        stmt = (
            select(UserPreferences.user_id, UserPreferences.timezone).limit(
                100_000
            )  # Safety cap — revisit with cursor-based pagination at 100k+ users
        )
        result = await db.execute(stmt)
        rows = result.all()

    enqueued = 0
    for user_id, tz_str in rows:
        try:
            tz = ZoneInfo(tz_str or "UTC")
        except (ZoneInfoNotFoundError, Exception):
            tz = ZoneInfo("UTC")

        if now_utc.astimezone(tz).hour == 6:
            generate_insights_for_user.delay(user_id, tz_str or "UTC")
            enqueued += 1

    logger.info("fan_out_daily_insights: enqueued %d tasks", enqueued)
    return {"enqueued": enqueued}


# ── Stale integration check (unchanged) ──────────────────────────────────────


@celery_app.task(name="app.tasks.insight_tasks.check_stale_integrations_task")
def check_stale_integrations_task() -> dict[str, int]:
    """Check for integrations that haven't synced in 24+ hours."""
    from datetime import timedelta
    from sqlalchemy import or_
    from app.models.integration import Integration

    async def _run() -> dict[str, int]:
        async with async_session() as session:
            now = datetime.now(timezone.utc)
            cutoff = now - timedelta(hours=24)
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
                logger.warning("Found %d stale integrations (not synced in 24h)", stale_count)
            return {"stale_count": stale_count}

    return asyncio.run(_run())
