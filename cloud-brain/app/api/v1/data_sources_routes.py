"""
Zuralog Cloud Brain — Data Sources API Router.

Provides the data sources endpoint consumed by the Flutter Trends tab
Data Sources screen. Returns the list of active integration sync sources
for the authenticated user.

Currently returns an empty scaffold so the client renders its designed
empty state. Full computation (driven by the user's connected integrations)
will be wired in a future phase.
"""

import sentry_sdk
from fastapi import APIRouter, Depends

from app.api.deps import get_authenticated_user_id


async def _set_sentry_module() -> None:
    """Tag the current Sentry scope with the data-sources module name."""
    sentry_sdk.set_tag("api.module", "data_sources")


router = APIRouter(
    prefix="/data-sources",
    tags=["data-sources"],
    dependencies=[Depends(_set_sentry_module)],
)


@router.get("")
async def list_data_sources(
    user_id: str = Depends(get_authenticated_user_id),
) -> dict:
    """Return the list of data sources for the authenticated user.

    Each source represents a connected integration and its last-sync
    metadata. Currently returns an empty list. Full computation will
    be wired in a future phase once integration sync state is surfaced
    via a dedicated service.

    Args:
        user_id: Authenticated user ID from JWT.

    Returns:
        dict matching the DataSourceList model shape.
    """
    return {"sources": []}
