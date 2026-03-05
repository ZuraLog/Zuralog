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
