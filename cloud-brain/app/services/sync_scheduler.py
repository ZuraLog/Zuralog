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
                    if db is None:
                        errors.append("strava: db session required for Strava sync")
                        continue

                    # Derive incremental after= timestamp from last_synced_at.
                    # None triggers a full historical backfill (first connect).
                    last_synced_at: datetime | None = integration.get("last_synced_at")
                    after_ts: int | None = int(last_synced_at.timestamp()) if last_synced_at else None

                    await self._sync_strava(
                        db=db,
                        user_id=user_id,
                        access_token=integration.get("access_token", ""),
                        after_timestamp=after_ts,
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
        after_timestamp: int | None = None,
    ) -> dict[str, Any]:
        """Pull activities from Strava API and persist new ones.

        Pages through ``GET /api/v3/athlete/activities`` (up to 200 per page)
        until an empty page is returned.  Stops early if all activities on a
        page already exist in the database — this makes incremental syncs fast
        because once we hit the first duplicate we know the rest of history is
        already stored.

        When ``after_timestamp`` is supplied (a Unix epoch integer), the Strava
        API's ``after=`` filter is applied so only activities newer than that
        moment are fetched.  Callers should derive this from the integration's
        ``last_synced_at`` column for incremental syncs.  Omitting it performs
        a full historical backfill (used on first connect).

        Args:
            db: Async SQLAlchemy session used for reads and writes.
            user_id: The user's ID for associating stored activities.
            access_token: Valid Strava OAuth access token.
            after_timestamp: Optional Unix epoch; only fetch activities
                created after this time. ``None`` = fetch all history.

        Returns:
            On success: ``{"activities_synced": <int>, "pages_fetched": <int>}``.
            On API failure: ``{"error": <str>, "activities_synced": 0, "pages_fetched": 0}``.
        """
        logger.info(
            "Syncing Strava for user '%s' (after=%s)",
            user_id,
            after_timestamp,
        )

        synced_count = 0
        page = 1
        _PAGE_SIZE = 200  # Strava's maximum per-page

        async with httpx.AsyncClient(timeout=30.0) as client:
            while True:
                params: dict[str, Any] = {"per_page": _PAGE_SIZE, "page": page}
                if after_timestamp is not None:
                    params["after"] = after_timestamp

                resp = await client.get(
                    _STRAVA_ACTIVITIES_URL,
                    headers={"Authorization": f"Bearer {access_token}"},
                    params=params,
                )

                if resp.status_code != 200:
                    logger.warning(
                        "Strava API returned %d for user '%s' (page %d): %s",
                        resp.status_code,
                        user_id,
                        page,
                        resp.text,
                    )
                    if synced_count:
                        await db.commit()
                    return {"error": resp.text, "activities_synced": synced_count, "pages_fetched": page - 1}

                activities: list[dict[str, Any]] = resp.json()

                # Empty page means we have reached the end of history.
                if not activities:
                    logger.debug(
                        "Strava pagination complete for user '%s' at page %d",
                        user_id,
                        page,
                    )
                    break

                new_on_page = 0
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
                            "Strava activity %s already stored for user '%s' — stopping pagination",
                            original_id,
                            user_id,
                        )
                        # All older activities are already stored; stop paging.
                        new_on_page = -1  # sentinel: hit overlap boundary
                        break

                    # Map Strava type string to canonical ActivityType enum value.
                    strava_type: str = activity.get("type", "")
                    activity_type = _STRAVA_TYPE_MAP.get(strava_type, ActivityType.UNKNOWN)

                    # Parse ISO-8601 UTC start time.
                    # Use start_date (genuine UTC) not start_date_local (wall-clock in athlete's
                    # timezone, incorrectly suffixed with Z by Strava's API).
                    raw_start: str | None = activity.get("start_date")
                    try:
                        start_time = (
                            datetime.fromisoformat(raw_start.replace("Z", "+00:00"))
                            if raw_start
                            else datetime.now(tz=timezone.utc)
                        )
                    except ValueError:
                        logger.warning("Could not parse start_date '%s'", raw_start)
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
                    new_on_page += 1

                # If we hit an overlap boundary, stop fetching more pages.
                if new_on_page == -1:
                    break

                # If this page was completely new, commit and fetch the next page.
                await db.commit()
                logger.info(
                    "Strava sync: committed %d activities from page %d for user '%s'",
                    new_on_page,
                    page,
                    user_id,
                )
                page += 1

        if synced_count:
            # Commit any uncommitted rows from the last (potentially partial) page.
            try:
                await db.commit()
            except Exception:
                pass  # already committed above in the loop
            logger.info(
                "Strava sync complete: %d total new activities over %d page(s) for user '%s'",
                synced_count,
                page,
                user_id,
            )
        else:
            logger.info("No new Strava activities for user '%s'", user_id)

        return {"activities_synced": synced_count, "pages_fetched": page}

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


@celery_app.task(name="app.services.sync_scheduler.sync_strava_activity_task")
def sync_strava_activity_task(
    owner_id: int,
    activity_id: int,
    aspect_type: str,
) -> dict[str, Any]:
    """Sync a single Strava activity triggered by a webhook event.

    Called immediately when Strava pushes a webhook event for an activity
    create, update, or delete.  Looks up the Strava integration for
    ``owner_id`` (the Strava athlete ID stored in ``provider_metadata``),
    fetches or removes the specific activity, and upserts / deletes it from
    ``UnifiedActivity``.

    Args:
        owner_id: Strava athlete ID from the webhook event ``owner_id`` field.
        activity_id: Strava activity ID from the webhook event ``object_id`` field.
        aspect_type: One of ``"create"``, ``"update"``, or ``"delete"``.

    Returns:
        A dict with ``"status"`` key describing the outcome.
    """
    from app.database import async_session
    from app.models.health_data import UnifiedActivity
    from app.models.integration import Integration
    from app.services.strava_token_service import StravaTokenService

    logger.info(
        "Webhook task: aspect_type=%s activity_id=%d owner_id=%d",
        aspect_type,
        activity_id,
        owner_id,
    )

    async def _run() -> dict[str, Any]:
        async with async_session() as db:
            # Look up integration by Strava athlete_id stored in provider_metadata.
            stmt = select(Integration).where(
                Integration.provider == "strava",
                Integration.is_active.is_(True),
            )
            result = await db.execute(stmt)
            integrations = result.scalars().all()

            target: Integration | None = None
            for intg in integrations:
                meta = intg.provider_metadata or {}
                if str(meta.get("athlete_id", "")) == str(owner_id):
                    target = intg
                    break

            if target is None:
                logger.warning("Webhook: no active Strava integration for athlete_id=%d", owner_id)
                return {"status": "no_integration"}

            token_service = StravaTokenService()
            access_token = await token_service.get_access_token(db, target.user_id)
            if not access_token:
                logger.warning("Webhook: could not obtain access token for user '%s'", target.user_id)
                return {"status": "no_token"}

            if aspect_type == "delete":
                # Remove the activity from UnifiedActivity if it exists.
                del_stmt = select(UnifiedActivity).where(
                    UnifiedActivity.source == "strava",
                    UnifiedActivity.original_id == str(activity_id),
                    UnifiedActivity.user_id == target.user_id,
                )
                del_result = await db.execute(del_stmt)
                existing = del_result.scalar_one_or_none()
                if existing:
                    await db.delete(existing)
                    await db.commit()
                    logger.info(
                        "Webhook: deleted activity %d for user '%s'",
                        activity_id,
                        target.user_id,
                    )
                    return {"status": "deleted"}
                return {"status": "delete_noop"}

            # For create / update: fetch the activity from Strava and upsert.
            async with httpx.AsyncClient(timeout=30.0) as client:
                resp = await client.get(
                    f"https://www.strava.com/api/v3/activities/{activity_id}",
                    headers={"Authorization": f"Bearer {access_token}"},
                )

            if resp.status_code != 200:
                logger.warning(
                    "Webhook: Strava API returned %d for activity %d: %s",
                    resp.status_code,
                    activity_id,
                    resp.text,
                )
                return {"status": f"strava_error_{resp.status_code}"}

            activity = resp.json()
            original_id = str(activity["id"])

            strava_type: str = activity.get("type", "")
            activity_type = _STRAVA_TYPE_MAP.get(strava_type, ActivityType.UNKNOWN)

            raw_start: str | None = activity.get("start_date")
            try:
                start_time = (
                    datetime.fromisoformat(raw_start.replace("Z", "+00:00"))
                    if raw_start
                    else datetime.now(tz=timezone.utc)
                )
            except ValueError:
                start_time = datetime.now(tz=timezone.utc)

            # Check for existing row (upsert: update if present, insert if not).
            upsert_stmt = select(UnifiedActivity).where(
                UnifiedActivity.source == "strava",
                UnifiedActivity.original_id == original_id,
                UnifiedActivity.user_id == target.user_id,
            )
            upsert_result = await db.execute(upsert_stmt)
            existing = upsert_result.scalar_one_or_none()

            if existing:
                existing.activity_type = activity_type
                existing.duration_seconds = int(activity.get("elapsed_time") or 0)
                existing.distance_meters = activity.get("distance")
                existing.calories = int(activity.get("calories") or 0)
                existing.start_time = start_time
                action = "updated"
            else:
                new_activity = UnifiedActivity(
                    user_id=target.user_id,
                    source="strava",
                    original_id=original_id,
                    activity_type=activity_type,
                    duration_seconds=int(activity.get("elapsed_time") or 0),
                    distance_meters=activity.get("distance"),
                    calories=int(activity.get("calories") or 0),
                    start_time=start_time,
                )
                db.add(new_activity)
                action = "created"

            await db.commit()
            logger.info(
                "Webhook: %s activity %d for user '%s'",
                action,
                activity_id,
                target.user_id,
            )
            return {"status": action}

    return asyncio.run(_run())


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
