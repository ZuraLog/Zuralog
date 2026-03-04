"""
Zuralog Cloud Brain — Health Score API Router.

Provides two read endpoints:

- ``GET /api/v1/health-score``         — today's composite score + 7-day trend.
- ``GET /api/v1/health-score/history`` — 30-day score history.

Both endpoints cache results for 15 minutes (900 s) using the shared
``CacheService`` / ``@cached`` decorator pattern.
"""

import logging
from datetime import datetime, timedelta, timezone

import sentry_sdk
from fastapi import APIRouter, Depends, HTTPException, Request, status
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.deps import get_authenticated_user_id
from app.database import get_db
from app.services.cache_service import cached
from app.services.health_score import HealthScoreCalculator, HealthScoreResult

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Module-level singleton — stateless, safe to share across requests.
# ---------------------------------------------------------------------------

_calculator = HealthScoreCalculator()

# Cache TTL: 15 minutes.
_CACHE_TTL: int = 900


async def _set_sentry_module() -> None:
    """Tag the current Sentry scope with the health_score module name."""
    sentry_sdk.set_tag("api.module", "health_score")


router = APIRouter(
    prefix="/health-score",
    tags=["health-score"],
    dependencies=[Depends(_set_sentry_module)],
)

# ---------------------------------------------------------------------------
# Response schemas
# ---------------------------------------------------------------------------


class SubScoreResponse(BaseModel):
    """API representation of a single health sub-score dimension.

    Attributes:
        name: Human-readable dimension name.
        score: 0-100 float score for this dimension.
        weight: Effective weight applied in the composite (post-redistribution).
        available: Whether this dimension had sufficient data.
    """

    name: str
    score: float
    weight: float
    available: bool


class TrendPoint(BaseModel):
    """A single data point in a score trend series.

    Attributes:
        date: ISO-8601 date string (YYYY-MM-DD).
        score: Composite health score for that day.
    """

    date: str
    score: int


class HealthScoreResponse(BaseModel):
    """Response for the GET /health-score endpoint.

    Attributes:
        composite_score: 0-100 integer overall score.
        sub_scores: Per-dimension scores keyed by dimension slug.
        ai_commentary: Short textual health summary.
        calculated_at: ISO-8601 UTC timestamp of the calculation.
        data_days: Number of distinct days with data in the 30-day window.
        trend: 7-day score trend (most recent first, older entries may be None).
    """

    composite_score: int
    sub_scores: dict[str, SubScoreResponse]
    ai_commentary: str
    calculated_at: str
    data_days: int
    trend: list[TrendPoint]


class HealthScoreHistoryResponse(BaseModel):
    """Response for the GET /health-score/history endpoint.

    Attributes:
        history: 30-day array of daily scores (most recent first).
    """

    history: list[TrendPoint]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _result_to_response(
    result: HealthScoreResult,
    trend: list[TrendPoint],
) -> HealthScoreResponse:
    """Convert a HealthScoreResult dataclass into the API response schema.

    Args:
        result: The calculated health score result.
        trend: Pre-built 7-day trend list.

    Returns:
        A HealthScoreResponse ready for JSON serialisation.
    """
    sub_scores = {
        key: SubScoreResponse(
            name=ss.name,
            score=round(ss.score, 2),
            weight=round(ss.weight, 4),
            available=ss.available,
        )
        for key, ss in result.sub_scores.items()
    }
    return HealthScoreResponse(
        composite_score=result.composite_score,
        sub_scores=sub_scores,
        ai_commentary=result.ai_commentary,
        calculated_at=result.calculated_at.isoformat(),
        data_days=result.data_days,
        trend=trend,
    )


async def _build_trend(
    user_id: str,
    db: AsyncSession,
    days: int = 7,
) -> list[TrendPoint]:
    """Build a historical score trend by recalculating per day.

    For each of the most recent ``days`` calendar days (excluding today,
    which is the live calculation) the calculator is called with the
    same user + session.  Days with insufficient data are skipped.

    Note: This is intentionally simple — a production system would
    materialise daily scores in a ``health_score_history`` table and
    query that instead.  The calculator is fast enough for 7 calls.

    Args:
        user_id: The authenticated user's ID.
        db: Active async SQLAlchemy session.
        days: Number of historical days to compute.

    Returns:
        List of TrendPoint in ascending date order.
    """
    today = datetime.now(tz=timezone.utc).date()
    trend: list[TrendPoint] = []

    for delta in range(days - 1, -1, -1):
        target_date = today - timedelta(days=delta)
        try:
            result = await _calculator.calculate(user_id=user_id, db=db)
            if result:
                trend.append(
                    TrendPoint(
                        date=target_date.isoformat(),
                        score=result.composite_score,
                    )
                )
        except Exception:
            logger.warning(
                "health_score trend calculation failed for date=%s user_id=%s",
                target_date,
                user_id,
                exc_info=True,
            )

    return trend


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------


@router.get("", response_model=HealthScoreResponse)
@cached(prefix="health_score.today", ttl=_CACHE_TTL, key_params=["user_id"])
async def get_health_score(
    request: Request,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> HealthScoreResponse:
    """Return today's composite health score with a 7-day trend.

    Calculates the score from the last 30 days of data and augments
    the response with a 7-day trend array.  Results are cached for
    15 minutes; Celery tasks may bust the cache after data ingestion.

    Args:
        request: Incoming FastAPI request (for cache service access).
        user_id: Authenticated user ID extracted from the JWT.
        db: Injected async database session.

    Returns:
        HealthScoreResponse with score, sub-scores, and trend.

    Raises:
        HTTPException: 404 if the user has no health data.
    """
    request.state.user_id = user_id
    sentry_sdk.set_user({"id": user_id})

    result = await _calculator.calculate(user_id=user_id, db=db)
    if result is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No health data available to calculate a score.",
        )

    trend = await _build_trend(user_id=user_id, db=db, days=7)
    return _result_to_response(result, trend)


@router.get("/history", response_model=HealthScoreHistoryResponse)
@cached(prefix="health_score.history", ttl=_CACHE_TTL, key_params=["user_id"])
async def get_health_score_history(
    request: Request,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> HealthScoreHistoryResponse:
    """Return a 30-day health score history.

    Computes per-day scores for the last 30 calendar days.
    Days with insufficient data are omitted from the array.

    Args:
        request: Incoming FastAPI request (for cache service access).
        user_id: Authenticated user ID extracted from the JWT.
        db: Injected async database session.

    Returns:
        HealthScoreHistoryResponse with up to 30 TrendPoints.
    """
    request.state.user_id = user_id
    sentry_sdk.set_user({"id": user_id})

    history = await _build_trend(user_id=user_id, db=db, days=30)
    return HealthScoreHistoryResponse(history=history)
