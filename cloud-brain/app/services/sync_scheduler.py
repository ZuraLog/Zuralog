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

import asyncio
import logging
from datetime import datetime, timedelta, timezone
from typing import TYPE_CHECKING, Any

import httpx
from sqlalchemy import and_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.health_data import ActivityType, UnifiedActivity
from app.models.integration import Integration
from app.worker import celery_app

if TYPE_CHECKING:
    from app.services.strava_token_service import StravaTokenService

# Strava activity type string -> canonical ActivityType enum value
_STRAVA_TYPE_MAP: dict[str, ActivityType] = {
    "Run": ActivityType.RUN,
    "Ride": ActivityType.CYCLE,
    "Swim": ActivityType.SWIM,
    "Walk": ActivityType.WALK,
    "Hike": ActivityType.WALK,
    "WeightTraining": ActivityType.STRENGTH,
    "Workout": ActivityType.STRENGTH,
}

_STRAVA_ACTIVITIES_URL = "https://www.strava.com/api/v3/athlete/activities"

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
        db: AsyncSession | None = None,
    ) -> dict[str, Any]:
        """Sync data from all active cloud integrations for a user.

        Iterates the user's active integrations and calls the
        appropriate sync method for each. Errors are captured
        per-integration rather than aborting the entire sync.

        Args:
            user_id: The user's ID.
            active_integrations: List of integration dicts, each with
                'provider' and 'access_token' keys.
            db: Optional async database session. Required when a
                provider needs to persist data (e.g. Strava).

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
                        db=db,  # type: ignore[arg-type]
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

    async def _sync_strava(
        self,
        db: AsyncSession,
        user_id: str,
        access_token: str,
    ) -> dict[str, Any]:
        """Pull recent activities from Strava API and persist new ones.

        Calls ``GET /api/v3/athlete/activities`` with the supplied
        access token.  For each returned activity, checks whether a
        ``UnifiedActivity`` row already exists (matched by ``source``
        and ``original_id``).  New activities are inserted; duplicates
        are silently skipped.

        Args:
            db: Async SQLAlchemy session used for reads and writes.
            user_id: The user's ID for associating stored activities.
            access_token: Valid Strava OAuth access token.

        Returns:
            On success: ``{"activities_synced": <int>}``.
            On API failure: ``{"error": <str>, "activities_synced": 0}``.
        """
        logger.info("Syncing Strava for user '%s'", user_id)

        async with httpx.AsyncClient() as client:
            resp = await client.get(
                _STRAVA_ACTIVITIES_URL,
                headers={"Authorization": f"Bearer {access_token}"},
                params={"per_page": 30},
            )

        if resp.status_code != 200:
            logger.warning(
                "Strava API returned %d for user '%s': %s",
                resp.status_code,
                user_id,
                resp.text,
            )
            return {"error": resp.text, "activities_synced": 0}

        activities: list[dict[str, Any]] = resp.json()
        synced_count = 0

        for activity in activities:
            original_id = str(activity["id"])

            # Check for an existing record to prevent duplication.
            stmt = select(UnifiedActivity).where(
                UnifiedActivity.source == "strava",
                UnifiedActivity.original_id == original_id,
                UnifiedActivity.user_id == user_id,
            )
            result = await db.execute(stmt)
            existing = result.scalar_one_or_none()

            if existing is not None:
                logger.debug(
                    "Strava activity %s already stored for user '%s' — skipping",
                    original_id,
                    user_id,
                )
                continue

            # Map Strava type string to canonical ActivityType enum value.
            strava_type: str = activity.get("type", "")
            activity_type = _STRAVA_TYPE_MAP.get(strava_type, ActivityType.UNKNOWN)

            # Parse ISO-8601 start time; fall back to UTC now on failure.
            raw_start: str | None = activity.get("start_date_local")
            try:
                start_time = (
                    datetime.fromisoformat(raw_start.replace("Z", "+00:00"))
                    if raw_start
                    else datetime.now(tz=timezone.utc)
                )
            except ValueError:
                logger.warning("Could not parse start_date_local '%s'", raw_start)
                start_time = datetime.now(tz=timezone.utc)

            new_activity = UnifiedActivity(
                user_id=user_id,
                source="strava",
                original_id=original_id,
                activity_type=activity_type,
                duration_seconds=int(activity.get("elapsed_time") or 0),
                distance_meters=activity.get("distance"),
                calories=int(activity.get("calories") or 0),
                start_time=start_time,
            )
            db.add(new_activity)
            synced_count += 1

        if synced_count:
            await db.commit()
            logger.info(
                "Strava sync committed %d new activities for user '%s'",
                synced_count,
                user_id,
            )
        else:
            logger.info("No new Strava activities for user '%s'", user_id)

        return {"activities_synced": synced_count}

    async def _refresh_expiring_tokens(
        self,
        db: AsyncSession,
        token_service: "StravaTokenService",
    ) -> dict[str, Any]:
        """Find and refresh Strava tokens expiring within 30 minutes.

        Queries the database for active Strava integrations whose
        ``token_expires_at`` falls within the next 30 minutes, then
        calls ``StravaTokenService.refresh_access_token`` for each.

        Args:
            db: Async database session.
            token_service: ``StravaTokenService`` instance for refreshing.

        Returns:
            A dict with ``'refreshed'`` count of successfully refreshed tokens.
        """
        cutoff = datetime.now(timezone.utc) + timedelta(minutes=30)

        stmt = select(Integration).where(
            and_(
                Integration.provider == "strava",
                Integration.is_active.is_(True),
                Integration.token_expires_at <= cutoff,
            )
        )
        result = await db.execute(stmt)
        expiring = result.scalars().all()

        refreshed = 0
        for integration in expiring:
            new_token = await token_service.refresh_access_token(db, integration)
            if new_token:
                refreshed += 1
                logger.info(
                    "Proactively refreshed token for user '%s'",
                    integration.user_id,
                )
            else:
                logger.warning(
                    "Failed to refresh token for user '%s'",
                    integration.user_id,
                )

        return {"refreshed": refreshed}


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

    Creates a database session and a ``StravaTokenService`` instance,
    then delegates to ``SyncService._refresh_expiring_tokens``.

    Returns:
        A dict with the number of tokens refreshed.
    """
    from app.database import async_session
    from app.services.strava_token_service import StravaTokenService

    logger.info("Checking for expiring OAuth tokens")

    async def _run() -> dict[str, Any]:
        async with async_session() as db:
            token_service = StravaTokenService()
            service = SyncService()
            result = await service._refresh_expiring_tokens(db, token_service)
            logger.info("Token refresh complete: %s token(s) refreshed", result["refreshed"])
            return {"tokens_refreshed": result["refreshed"]}

    return asyncio.run(_run())
