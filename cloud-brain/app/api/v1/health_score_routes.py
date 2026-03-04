"""
Zuralog Cloud Brain — Health Score Endpoints.

Exposes the composite daily health score computed by
``HealthScoreCalculator``.  The score is a weighted, percentile-ranked
aggregate of sleep, HRV, resting heart rate, activity, sleep consistency,
and step count relative to the user's own 30-day history.
"""

import logging

import sentry_sdk
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.database import get_db
from app.models.user import User
from app.services.health_score import HealthScoreCalculator

logger = logging.getLogger(__name__)


async def _set_sentry_module() -> None:
    sentry_sdk.set_tag("api.module", "health_score")


router = APIRouter(
    prefix="/health-score",
    tags=["health-score"],
    dependencies=[Depends(_set_sentry_module)],
)

_calculator = HealthScoreCalculator()


@router.get("")
async def get_health_score(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Return the current day's composite health score for the authenticated user.

    The score is computed from up to six metrics drawn from
    ``DailyHealthMetrics`` and ``SleepRecord``:

    - **sleep** (30 %): sleep duration percentile + optional quality blend.
    - **hrv** (20 %): HRV percentile vs 30-day personal history.
    - **resting_hr** (15 %): inverted HR percentile (lower = better).
    - **activity** (15 %): active-calorie percentile vs 30-day history.
    - **sleep_consistency** (10 %): inverted sleep-time stddev percentile.
    - **steps** (10 %): step-count percentile, capped at 100.

    Missing metrics are skipped and their weights redistributed proportionally.
    A minimum of one sleep **or** one activity record is required; otherwise
    a 200 response with ``score: null`` is returned.

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

            {"score": null, "message": "Not enough data yet. Keep syncing your devices."}
    """
    result = await _calculator.calculate(user.id, db)

    if result is None:
        logger.debug("health_score: no result for user '%s'", user.id)
        return {
            "score": None,
            "message": "Not enough data yet. Keep syncing your devices.",
        }

    history_raw = await _calculator.get_7_day_history(user.id, db)
    history = [{"date": entry["date"], "score": entry["score"]} for entry in history_raw]

    logger.info(
        "health_score: computed score=%d for user '%s' (metrics=%s)",
        result.score,
        user.id,
        result.contributing_metrics,
    )

    return {
        "score": result.score,
        "sub_scores": result.sub_scores,
        "commentary": result.commentary,
        "contributing_metrics": result.contributing_metrics,
        "data_days": result.data_days,
        "history": history,
    }
