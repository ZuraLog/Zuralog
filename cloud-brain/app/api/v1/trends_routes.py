"""
Zuralog Cloud Brain — Trends API Router.

Provides the aggregated Trends Home endpoint consumed by the Flutter
Trends tab (Tab 4). Returns AI-surfaced correlation highlights and
time-machine period summaries.

Currently returns empty scaffolds so the client renders its designed
empty/onboarding state. Full computation will be wired in a future phase.
"""

import sentry_sdk
from fastapi import APIRouter, Depends

from app.api.v1.deps import get_authenticated_user_id


async def _set_sentry_module() -> None:
    """Tag the current Sentry scope with the trends module name."""
    sentry_sdk.set_tag("api.module", "trends")


router = APIRouter(
    prefix="/trends",
    tags=["trends"],
    dependencies=[Depends(_set_sentry_module)],
)


@router.get("/home")
async def trends_home(
    user_id: str = Depends(get_authenticated_user_id),
) -> dict:
    """Return aggregated Trends Home data.

    Returns correlation highlights and time-machine period summaries.
    Currently returns empty data with ``has_enough_data`` set to false
    so the Flutter client shows its designed onboarding state.

    Args:
        user_id: Authenticated user ID from JWT.

    Returns:
        dict matching the TrendsHomeData model shape.
    """
    return {
        "correlation_highlights": [],
        "time_periods": [],
        "has_enough_data": False,
    }


@router.get("/metrics")
async def trends_metrics(
    user_id: str = Depends(get_authenticated_user_id),
) -> dict:
    """Return available metrics for the correlation explorer picker.

    Currently returns an empty list. Full metric discovery (driven by
    which data sources the user has connected) will be wired in a
    future phase.

    Args:
        user_id: Authenticated user ID from JWT.

    Returns:
        dict matching the AvailableMetricList model shape.
    """
    return {"metrics": []}


@router.get("/correlations")
async def trends_correlations(
    metric_a: str,
    metric_b: str,
    lag_days: int = 0,
    time_range: str = "30d",
    custom_start: str | None = None,
    custom_end: str | None = None,
    user_id: str = Depends(get_authenticated_user_id),
) -> dict:
    """Run a correlation analysis between two metrics.

    Currently returns an empty scaffold. Full computation (Pearson
    coefficient, scatter data, AI annotation) will be wired in a
    future phase.

    Args:
        metric_a: ID of the first metric.
        metric_b: ID of the second metric.
        lag_days: Offset in days to apply to metric_b (0–3).
        time_range: Time window string (e.g. ``"30d"``, ``"90d"``).
        custom_start: ISO-8601 start date when ``time_range`` is ``"custom"``.
        custom_end: ISO-8601 end date when ``time_range`` is ``"custom"``.
        user_id: Authenticated user ID from JWT.

    Returns:
        dict matching the CorrelationAnalysis model shape.
    """
    return {
        "metric_a_id": metric_a,
        "metric_b_id": metric_b,
        "lag_days": lag_days,
        "coefficient": None,
        "p_value": None,
        "interpretation": "not_enough_data",
        "ai_annotation": "Not enough data yet to compute a correlation. Keep syncing your devices.",
        "scatter_data": [],
        "sample_size": 0,
    }
