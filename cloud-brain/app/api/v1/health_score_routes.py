"""
Zuralog Cloud Brain — Health Score Endpoints.

Exposes the composite daily health score computed by
``HealthScoreCalculator``.  The score is a weighted, percentile-ranked
aggregate of sleep, HRV, resting heart rate, activity, sleep consistency,
and step count relative to the user's own 30-day history.

Cache-first strategy
--------------------
Reads today's score from the ``health_scores`` cache table first (1 query).
Falls back to live calculation only on a cache miss.  After a successful
live calculation the result is written back to cache for subsequent requests.
This reduces query load from 32 per request down to 1-3 on cache hits and
avoids the "score disappears the day after seeding" problem that affects the
demo account.
"""

import json
import logging
from datetime import datetime, timedelta, timezone

import sentry_sdk
from fastapi import APIRouter, Depends, Request
from sqlalchemy import and_, func, select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import check_rate_limit, get_current_user
from app.database import get_db
from app.models.daily_summary import DailySummary
from app.models.health_score_cache import HealthScoreCache
from app.models.user import User
from app.services.health_score import HealthScoreCalculator, HealthScoreResult
from app.services.rate_limiter import RateLimiter

logger = logging.getLogger(__name__)


async def _set_sentry_module() -> None:
    sentry_sdk.set_tag("api.module", "health_score")


router = APIRouter(
    prefix="/health-score",
    tags=["health-score"],
    dependencies=[Depends(_set_sentry_module)],
)

_calculator = HealthScoreCalculator()


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------


def _safe_json_loads(raw: str | None) -> dict:
    """Parse a JSON string to dict, returning an empty dict on any failure.

    Args:
        raw: Serialised JSON string from the cache table (may be None).

    Returns:
        Parsed dict, or ``{}`` if the input is None or malformed.
    """
    try:
        return json.loads(raw) if raw else {}
    except (json.JSONDecodeError, TypeError):
        return {}


async def _count_data_days(user_id: str, db: AsyncSession) -> int:
    """Return the number of days this user has any health data.

    Reads the ``health_scores`` cache table first (fast, indexed).  Falls
    back to counting distinct dates in ``daily_health_metrics`` when no
    cache rows exist (e.g. brand-new accounts before first sync completes).

    Args:
        user_id: Authenticated user ID.
        db: Async database session.

    Returns:
        Non-negative integer count of days with data.
    """
    # Fast path: count cached score rows (each row = one scored day).
    stmt = select(func.count(HealthScoreCache.id)).where(HealthScoreCache.user_id == user_id)
    result = await db.execute(stmt)
    cache_count: int = result.scalar() or 0

    if cache_count > 0:
        return cache_count

    # Fallback: count distinct dates with raw metric data.
    stmt = select(func.count(func.distinct(DailySummary.date))).where(DailySummary.user_id == user_id)
    result = await db.execute(stmt)
    return result.scalar() or 0


async def _get_7_day_history_from_cache(user_id: str, db: AsyncSession) -> list[dict]:
    """Read up to 7 days of scores from the cache table (1 query).

    Args:
        user_id: Authenticated user ID.
        db: Async database session.

    Returns:
        List of ``{"date": ..., "score": ...}`` dicts ordered oldest-first.
    """
    today = datetime.now(tz=timezone.utc).date()
    seven_days_ago = (today - timedelta(days=6)).isoformat()

    stmt = (
        select(HealthScoreCache)
        .where(
            and_(
                HealthScoreCache.user_id == user_id,
                HealthScoreCache.score_date >= seven_days_ago,
                HealthScoreCache.score_date <= today.isoformat(),
            )
        )
        .order_by(HealthScoreCache.score_date.asc())
    )
    result = await db.execute(stmt)
    rows = result.scalars().all()

    return [{"date": row.score_date, "score": row.score} for row in rows]


async def _upsert_cache(
    user_id: str,
    score_date: str,
    result: HealthScoreResult,
    db: AsyncSession,
) -> None:
    """Write a freshly computed score to the cache table (upsert).

    Non-fatal: logs a warning but never raises so the caller always receives
    the score even if the cache write fails.

    Args:
        user_id: Authenticated user ID.
        score_date: ISO date string (YYYY-MM-DD) for the score.
        result: The ``HealthScoreResult`` returned by the live calculator.
        db: Async database session.
    """
    try:
        stmt = (
            pg_insert(HealthScoreCache)
            .values(
                user_id=user_id,
                score_date=score_date,
                score=result.score,
                sub_scores_json=json.dumps(result.sub_scores),
                commentary=result.commentary,
            )
            .on_conflict_do_update(
                constraint="uq_health_scores_user_date",
                set_={
                    "score": result.score,
                    "sub_scores_json": json.dumps(result.sub_scores),
                    "commentary": result.commentary,
                },
            )
        )
        await db.execute(stmt)
        await db.commit()
    except Exception:
        logger.warning(
            "health_score: cache write failed for user '%s' on %s",
            user_id,
            score_date,
            exc_info=True,
        )


# ---------------------------------------------------------------------------
# Endpoint
# ---------------------------------------------------------------------------


@router.get("")
async def get_health_score(
    request: Request,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Return the current day's composite health score for the authenticated user.

    Cache-first: reads from ``health_scores`` table on a single indexed query.
    Falls back to live calculation on a cache miss and writes the result back
    to cache for subsequent requests.

    The score is computed from up to six metrics drawn from
    ``DailyHealthMetrics`` and ``SleepRecord``:

    - **sleep** (30 %): sleep duration percentile + optional quality blend.
    - **hrv** (20 %): HRV percentile vs 30-day personal history.
    - **resting_hr** (15 %): inverted HR percentile (lower = better).
    - **activity** (15 %): active-calorie percentile vs 30-day history.
    - **sleep_consistency** (10 %): inverted sleep-time stddev percentile.
    - **steps** (10 %): step-count percentile, capped at 100.

    Missing metrics are skipped and their weights redistributed proportionally.
    A minimum of one sleep **or** one activity record is required for a live
    calculation; the cache may have a score even when live data is absent for
    today.

    Returns:
        200 JSON with the following shape::

            {
                "score": 74,
                "sub_scores": {"sleep": 80, "hrv": 60, ...},
                "commentary": "A solid day overall ...",
                "contributing_metrics": ["sleep", "hrv", ...],
                "data_days": 21,
                "history": [{"date": "2026-02-26", "score": 68}, ...]
            }

        If insufficient data::

            {"score": null, "message": "Not enough data yet. Keep syncing your devices.", "data_days": 0}

        ``data_days`` is always present in both success and null responses so
        the Flutter client can distinguish a brand-new account (data_days == 0)
        from an account that has historical data but no score for today
        (data_days > 0, score == null).
    """
    # ── Rate limit — protect the cache-miss live-calculation path ─────────────
    rate_limiter: RateLimiter | None = getattr(request.app.state, "rate_limiter", None)
    if rate_limiter:
        await check_rate_limit(str(user.id), rate_limiter, db)

    today_str = datetime.now(tz=timezone.utc).date().isoformat()

    # ── 1. Cache hit — fastest path (1 query) ──────────────────────────────
    stmt = select(HealthScoreCache).where(
        and_(
            HealthScoreCache.user_id == user.id,
            HealthScoreCache.score_date == today_str,
        )
    )
    result = await db.execute(stmt)
    cached = result.scalars().first()

    if cached is not None:
        sub_scores = _safe_json_loads(cached.sub_scores_json)
        history = await _get_7_day_history_from_cache(user.id, db)
        data_days = await _count_data_days(user.id, db)

        logger.info(
            "health_score: cache hit score=%d for user '%s'",
            cached.score,
            user.id,
        )

        return {
            "score": cached.score,
            "sub_scores": sub_scores,
            "commentary": cached.commentary or "",
            "contributing_metrics": list(sub_scores.keys()),
            "data_days": data_days,
            "history": history,
        }

    # ── 2. Cache miss — fall back to live calculation ──────────────────────
    calc_result = await _calculator.calculate(user.id, db)

    if calc_result is None:
        # No today data available; still report historical day count so the
        # Flutter client can distinguish "no data ever" from "has data, just
        # not for today".
        data_days = await _count_data_days(user.id, db)
        logger.debug("health_score: no result for user '%s'", user.id)
        return {
            "score": None,
            "message": "Not enough data yet. Keep syncing your devices.",
            "data_days": data_days,
        }

    # ── 3. Live calculation succeeded — cache it for next time ─────────────
    await _upsert_cache(user.id, today_str, calc_result, db)

    history = await _get_7_day_history_from_cache(user.id, db)

    logger.info(
        "health_score: computed score=%d for user '%s' (metrics=%s)",
        calc_result.score,
        user.id,
        calc_result.contributing_metrics,
    )

    return {
        "score": calc_result.score,
        "sub_scores": calc_result.sub_scores,
        "commentary": calc_result.commentary,
        "contributing_metrics": calc_result.contributing_metrics,
        "data_days": calc_result.data_days,
        "history": history,
    }
