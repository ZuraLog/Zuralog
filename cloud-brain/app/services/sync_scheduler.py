"""
Zuralog Cloud Brain — Background Sync Scheduler.

Implements periodic background tasks to pull data from cloud
integrations (Strava, Fitbit, Oura) without user intervention.

Architecture:
- Celery Beat triggers `sync_all_users_task` every 15 minutes.
- The master task iterates active users and dispatches per-user sync.
- Each per-user sync respects API rate limits and concurrency.
- Sync status is updated on the Integration model throughout.

Note: Apple Health and Health Connect are push-from-device via
the Edge Agent — they are NOT synced by this scheduler.
"""

import logging
from typing import Any

from app.worker import celery_app

logger = logging.getLogger(__name__)


class SyncService:
    """Orchestrates background data sync from cloud integrations.

    Stateless service class. All state (tokens, sync status) is
    managed via the database. Methods accept explicit parameters
    rather than reading from instance state.
    """

    async def sync_user_data(
        self,
        user_id: str,
        active_integrations: list[dict[str, Any]],
    ) -> dict[str, Any]:
        """Sync data from all active cloud integrations for a user.

        Iterates the user's active integrations and calls the
        appropriate sync method for each. Errors are captured
        per-integration rather than aborting the entire sync.

        Args:
            user_id: The user's ID.
            active_integrations: List of integration dicts, each with
                'provider' and 'access_token' keys.

        Returns:
            A dict with 'synced_sources' (list of provider names that
            succeeded) and 'errors' (list of error messages).
        """
        synced_sources: list[str] = []
        errors: list[str] = []

        for integration in active_integrations:
            provider = integration.get("provider", "")
            try:
                if provider == "strava":
                    await self._sync_strava(
                        user_id=user_id,
                        access_token=integration.get("access_token", ""),
                    )
                    synced_sources.append("strava")
                else:
                    logger.debug("Skipping unsupported provider '%s'", provider)
            except Exception as exc:
                error_msg = f"{provider}: {exc}"
                errors.append(error_msg)
                logger.exception("Sync failed for user '%s' provider '%s'", user_id, provider)

        return {"synced_sources": synced_sources, "errors": errors}

    async def _sync_strava(self, user_id: str, access_token: str) -> dict[str, Any]:
        """Pull recent activities from Strava API.

        Args:
            user_id: The user's ID for storing results.
            access_token: Valid Strava OAuth access token.

        Returns:
            A dict with the number of activities synced.

        Raises:
            RuntimeError: If the Strava API returns an error.
        """
        # TODO(phase-1.10): Implement actual Strava API call
        # Uses httpx to GET /api/v3/athlete/activities
        # Normalize via DataNormalizer, deduplicate via SourceOfTruth
        # Save to database
        logger.info("Syncing Strava for user '%s'", user_id)
        return {"activities": 0}


@celery_app.task(name="app.services.sync_scheduler.sync_all_users_task")
def sync_all_users_task() -> dict[str, Any]:
    """Master task: iterate active users and sync their data.

    Called by Celery Beat every 15 minutes. Dispatches per-user
    sync as sub-tasks for concurrency.

    Returns:
        A dict with the number of users processed.
    """
    # TODO(phase-1.10): Query DB for users with active integrations
    # For each user, dispatch sync_user_task.delay(user_id)
    logger.info("Running scheduled sync for all active users")
    return {"users_processed": 0}


@celery_app.task(name="app.services.sync_scheduler.refresh_tokens_task")
def refresh_tokens_task() -> dict[str, Any]:
    """Refresh OAuth tokens that are about to expire.

    Called by Celery Beat every hour. Checks for tokens expiring
    within 30 minutes and refreshes them proactively.

    Returns:
        A dict with the number of tokens refreshed.
    """
    # TODO(phase-1.10): Query Integration model for expiring tokens
    # Use provider-specific refresh endpoints
    logger.info("Checking for expiring OAuth tokens")
    return {"tokens_refreshed": 0}
