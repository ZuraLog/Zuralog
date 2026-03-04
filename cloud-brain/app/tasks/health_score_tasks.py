"""
Zuralog Cloud Brain — Health Score Celery Tasks.

Provides a Celery task that recalculates the health score for a single
user after new health data has been ingested.

Because Celery tasks execute in a synchronous worker context, async
SQLAlchemy operations are run via ``asyncio.run()``.  The task also
invalidates the two ``CacheService`` keys that the health score routes
depend on, so that the next API request reflects the freshest data.

Usage (triggered by ingest pipeline)::

    from app.tasks.health_score_tasks import recalculate_health_score_task
    recalculate_health_score_task.delay(user_id="abc-123")
"""

import asyncio
import logging

import sentry_sdk

from app.database import async_session
from app.services.cache_service import CacheService
from app.services.health_score import HealthScoreCalculator
from app.worker import celery_app

logger = logging.getLogger(__name__)

# Module-level singleton — HealthScoreCalculator is stateless.
_calculator = HealthScoreCalculator()


async def _run_recalculation(user_id: str) -> None:
    """Async inner function that performs the health score recalculation.

    Opens a fresh database session, calls the calculator, and logs the
    result. Also invalidates the health score cache keys for the user.

    Args:
        user_id: The user whose health score should be recalculated.
    """
    async with async_session() as db:
        try:
            result = await _calculator.calculate(user_id=user_id, db=db)
            if result is not None:
                logger.info(
                    "health_score recalculated: user_id=%s composite=%d data_days=%d",
                    user_id,
                    result.composite_score,
                    result.data_days,
                )
            else:
                logger.debug(
                    "health_score recalculation skipped (no data): user_id=%s",
                    user_id,
                )
        except Exception:
            logger.exception(
                "health_score recalculation failed: user_id=%s",
                user_id,
            )
            raise

    # Invalidate cache keys so the API serves fresh data on next request.
    # CacheService is instantiated here; it is lightweight and stateless.
    cache = CacheService()
    if cache.enabled:
        await cache.delete(CacheService.make_key("health_score.today", user_id))
        await cache.delete(CacheService.make_key("health_score.history", user_id))
        logger.debug(
            "health_score cache invalidated for user_id=%s",
            user_id,
        )


@celery_app.task(
    name="app.tasks.health_score_tasks.recalculate_health_score_task",
    bind=True,
    max_retries=3,
    default_retry_delay=60,
)
def recalculate_health_score_task(self, user_id: str) -> None:
    """Celery task: recalculate and cache-bust the health score for a user.

    This task is triggered after new health data is ingested so that the
    next GET /api/v1/health-score request serves the latest calculation
    without waiting for the 15-minute cache TTL to expire.

    Retries up to 3 times with a 60-second delay on failure.

    Args:
        user_id: The user's unique identifier string.
    """
    logger.info("recalculate_health_score_task: starting for user_id=%s", user_id)
    sentry_sdk.set_user({"id": user_id})

    try:
        asyncio.run(_run_recalculation(user_id=user_id))
    except Exception as exc:
        logger.exception(
            "recalculate_health_score_task failed for user_id=%s, retrying",
            user_id,
        )
        raise self.retry(exc=exc)
