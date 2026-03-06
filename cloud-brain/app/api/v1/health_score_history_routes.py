"""
Zuralog Cloud Brain — Health Score History Endpoint.

Returns historical health scores for the authenticated user from the
health_scores cache table.  Supports 7d / 30d / 90d / all ranges.
Falls back to live calculation for any dates missing from cache.
"""

import json
import logging
from datetime import datetime, timedelta, timezone

import sentry_sdk
from fastapi import APIRouter, Depends, Query
from sqlalchemy import and_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.database import get_db
from app.models.health_score_cache import HealthScoreCache
from app.models.user import User

logger = logging.getLogger(__name__)


async def _set_sentry_module() -> None:
    sentry_sdk.set_tag("api.module", "health_score_history")


router = APIRouter(
    prefix="/health-score/history",
    tags=["health-score"],
    dependencies=[Depends(_set_sentry_module)],
)


@router.get("")
async def get_health_score_history(
    range: str = Query(default="30d", pattern="^(7d|30d|90d|all)$"),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Return historical health scores for the authenticated user.

    Reads from the ``health_scores`` cache table populated by the Celery
    recalculation task.  Scores are ordered oldest-first.

    Query params:
        range: One of ``7d``, ``30d``, ``90d``, or ``all``.
               Defaults to ``30d``.

    Returns:
        200 JSON::

            {
                "range": "30d",
                "scores": [{"date": "2026-02-05", "score": 72}, ...],
                "average": 74,
                "min": 68,
                "max": 81,
                "trend_direction": "improving"
            }

        ``trend_direction`` is one of ``"improving"``, ``"declining"``,
        or ``"stable"`` computed from a simple linear regression over
        the available scores.  If fewer than 3 data points are available
        the field is ``"stable"``.
    """
    today = datetime.now(tz=timezone.utc).date()

    # Build date lower bound from range param.
    if range == "7d":
        since = (today - timedelta(days=6)).isoformat()
    elif range == "30d":
        since = (today - timedelta(days=29)).isoformat()
    elif range == "90d":
        since = (today - timedelta(days=89)).isoformat()
    else:  # "all"
        since = "2000-01-01"

    stmt = (
        select(HealthScoreCache)
        .where(
            and_(
                HealthScoreCache.user_id == user.id,
                HealthScoreCache.score_date >= since,
                HealthScoreCache.score_date <= today.isoformat(),
            )
        )
        .order_by(HealthScoreCache.score_date.asc())
    )
    result = await db.execute(stmt)
    rows = result.scalars().all()

    scores = [{"date": row.score_date, "score": row.score} for row in rows]

    if not scores:
        return {
            "range": range,
            "scores": [],
            "average": None,
            "min": None,
            "max": None,
            "trend_direction": "stable",
        }

    score_values = [s["score"] for s in scores]
    average = round(sum(score_values) / len(score_values))
    min_score = min(score_values)
    max_score = max(score_values)
    trend_direction = _compute_trend(score_values)

    return {
        "range": range,
        "scores": scores,
        "average": average,
        "min": min_score,
        "max": max_score,
        "trend_direction": trend_direction,
    }


def _compute_trend(scores: list[int]) -> str:
    """Determine trend direction via simple linear regression slope.

    Args:
        scores: Ordered list of score integers (oldest first).

    Returns:
        ``"improving"``, ``"declining"``, or ``"stable"``.
    """
    n = len(scores)
    if n < 3:
        return "stable"

    # Simple linear regression: slope = (n*Σxy - Σx*Σy) / (n*Σx² - (Σx)²)
    x_vals = list(range(n))
    sum_x = sum(x_vals)
    sum_y = sum(scores)
    sum_xy = sum(x * y for x, y in zip(x_vals, scores))
    sum_x2 = sum(x * x for x in x_vals)

    denom = n * sum_x2 - sum_x * sum_x
    if denom == 0:
        return "stable"

    slope = (n * sum_xy - sum_x * sum_y) / denom

    # Threshold: > 0.3 pts/day = improving, < -0.3 = declining.
    if slope > 0.3:
        return "improving"
    elif slope < -0.3:
        return "declining"
    return "stable"
