"""
Zuralog Cloud Brain — Progress API Router.

Provides the aggregated Progress Home endpoint consumed by the Flutter
Progress tab (Tab 3). Returns goals, streaks, week-over-week summary,
and recent achievements.

Currently returns empty scaffolds so the client renders its designed
empty state. Full computation will be wired in a future phase.
"""

import sentry_sdk
from fastapi import APIRouter, Depends

from app.api.v1.deps import get_authenticated_user_id


async def _set_sentry_module() -> None:
    """Tag the current Sentry scope with the progress module name."""
    sentry_sdk.set_tag("api.module", "progress")


router = APIRouter(
    prefix="/progress",
    tags=["progress"],
    dependencies=[Depends(_set_sentry_module)],
)


@router.get("/home")
async def progress_home(
    user_id: str = Depends(get_authenticated_user_id),
) -> dict:
    """Return aggregated Progress Home data.

    Returns goals, streaks, week-over-week comparison, and recent
    achievements. Currently returns empty data so the Flutter client
    shows its designed empty state.

    Args:
        user_id: Authenticated user ID from JWT.

    Returns:
        dict matching the ProgressHomeData model shape.
    """
    return {
        "goals": [],
        "streaks": [],
        "wow": {
            "week_label": "",
            "metrics": [],
        },
        "recent_achievements": [],
    }
