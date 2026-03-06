"""
Zuralog Cloud Brain — Health Score Celery Tasks.

Provides a Celery task that recomputes the composite health score for a
single user and persists the result to the health_scores cache table.
This task is triggered after new health data is ingested so that the
score stays fresh without requiring a real-time API round-trip.
"""

import asyncio
import json
import logging
from datetime import datetime, timezone
from typing import Any

import sentry_sdk
from celery import shared_task
from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert as pg_insert

from app.database import async_session
from app.models.health_score_cache import HealthScoreCache
from app.services.health_score import HealthScoreCalculator

logger = logging.getLogger(__name__)


@shared_task(name="app.tasks.health_score_tasks.recalculate_health_score")
def recalculate_health_score(user_id: str) -> dict[str, Any]:
    """Recompute and cache the health score for a single user.

    Called automatically after new health data is ingested (e.g. at the
    end of a Fitbit, Oura, or Apple Health sync).  Runs inside the Celery
    worker process; async database operations are executed via
    ``asyncio.run``.

    Persists the computed score to the ``health_scores`` cache table via
    an upsert so repeated calls for the same day are idempotent.

    Args:
        user_id: The Zuralog user ID whose score should be recalculated.

    Returns:
        A dict with ``"status"`` and, on success, ``"score"`` and
        ``"contributing_metrics"``.
    """
    logger.info("recalculate_health_score: starting for user '%s'", user_id)

    async def _run() -> dict[str, Any]:
        async with async_session() as db:  # type: ignore[attr-defined]
            calculator = HealthScoreCalculator()
            try:
                result = await calculator.calculate(user_id, db)
            except Exception as exc:  # noqa: BLE001
                logger.exception(
                    "recalculate_health_score: calculation failed for user '%s': %s",
                    user_id,
                    exc,
                )
                sentry_sdk.capture_exception(exc)
                return {"status": "error", "error": str(exc)}

            if result is None:
                logger.info(
                    "recalculate_health_score: insufficient data for user '%s'",
                    user_id,
                )
                return {"status": "insufficient_data"}

            # Persist to cache table (upsert by user_id + date).
            today_str = datetime.now(tz=timezone.utc).date().isoformat()
            try:
                stmt = pg_insert(HealthScoreCache).values(
                    user_id=user_id,
                    score_date=today_str,
                    score=result.score,
                    sub_scores_json=json.dumps(result.sub_scores),
                    commentary=result.commentary,
                ).on_conflict_do_update(
                    constraint="uq_health_scores_user_date",
                    set_={
                        "score": result.score,
                        "sub_scores_json": json.dumps(result.sub_scores),
                        "commentary": result.commentary,
                    },
                )
                await db.execute(stmt)
                await db.commit()
                logger.debug(
                    "recalculate_health_score: cached score=%d for user '%s' on %s",
                    result.score,
                    user_id,
                    today_str,
                )
            except Exception as exc:  # noqa: BLE001
                logger.warning(
                    "recalculate_health_score: cache write failed for user '%s': %s",
                    user_id,
                    exc,
                )
                # Non-fatal — the score is still returned even if caching fails.

            logger.info(
                "recalculate_health_score: score=%d for user '%s' (metrics=%s)",
                result.score,
                user_id,
                result.contributing_metrics,
            )

            return {
                "status": "ok",
                "user_id": user_id,
                "score": result.score,
                "contributing_metrics": result.contributing_metrics,
            }

    return asyncio.run(_run())
