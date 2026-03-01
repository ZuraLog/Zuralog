"""
Zuralog Cloud Brain — Oura Ring Celery Sync Tasks.

Provides five Celery tasks for syncing Oura Ring health data:

- ``sync_oura_webhook_task``: Webhook-triggered sync for a specific data type
  (today + yesterday) for the user identified by ``oura_user_id``.
- ``sync_oura_periodic_task``: Celery Beat task (every 15 minutes) that pulls
  today + yesterday's data for every active Oura integration.
- ``refresh_oura_tokens_task``: Celery Beat task (every 4 hours) that
  proactively refreshes tokens expiring within 6 hours.
- ``renew_oura_webhook_subscriptions_task``: Celery Beat task (every 24 hours)
  that renews webhook subscriptions expiring within 7 days.
- ``backfill_oura_data_task``: One-time task triggered on first connect to pull
  up to ``days_back`` days of historical data.

Also exports the async helper:
- ``create_oura_webhook_subscriptions``: Creates all webhook subscriptions for
  the Oura app (called during setup, not per-user).

Architecture notes:
- All tasks run in Celery worker processes (synchronous context).
- Async DB operations are executed via ``asyncio.run(_run())``.
- HTTP calls use ``httpx.AsyncClient`` inside async helpers.
- Rate limit: 5,000 req / 5-min app-level (OuraRateLimiter). Fail-open if
  Redis is unavailable so a Redis outage never blocks Oura syncs.
"""

import asyncio
import logging
from datetime import date, datetime, timedelta, timezone
from typing import Any

import httpx
import sentry_sdk
from sqlalchemy import and_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import async_session
from app.models.health_data import ActivityType, SleepRecord, UnifiedActivity
from app.models.integration import Integration
from app.services.oura_token_service import OuraTokenService
from app.worker import celery_app

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Oura activity type mapping
# ---------------------------------------------------------------------------

_OURA_ACTIVITY_TYPE_MAP: dict[str, ActivityType] = {
    "running": ActivityType.RUN,
    "cycling": ActivityType.CYCLE,
    "swimming": ActivityType.SWIM,
    "walking": ActivityType.WALK,
    "hiking": ActivityType.WALK,
    "strength_training": ActivityType.STRENGTH,
    "yoga": ActivityType.UNKNOWN,
    "high_intensity_interval_training": ActivityType.UNKNOWN,
    "stretching": ActivityType.UNKNOWN,
    "other": ActivityType.UNKNOWN,
}
_DEFAULT_ACTIVITY_TYPE = ActivityType.UNKNOWN

# Oura data types synced on every periodic cycle
_PERIODIC_DATA_TYPES = [
    "daily_sleep",
    "daily_activity",
    "daily_readiness",
    "daily_spo2",
    "daily_stress",
    "daily_resilience",
]

# Oura API base URL
_OURA_API_BASE = "https://api.ouraring.com"


# ---------------------------------------------------------------------------
# Internal async helpers
# ---------------------------------------------------------------------------


async def _fetch_oura_collection(
    access_token: str,
    collection: str,
    start_date: str,
    end_date: str,
    use_sandbox: bool = False,
    max_pages: int = 10,
) -> list[dict]:
    """Fetch all pages from an Oura collection with cursor pagination.

    Args:
        access_token: Valid Oura Bearer access token.
        collection: Collection endpoint name (e.g. ``"daily_sleep"``).
        start_date: ISO-8601 start date (``YYYY-MM-DD``).
        end_date: ISO-8601 end date (``YYYY-MM-DD``).
        use_sandbox: If True, use ``/v2/sandbox/usercollection`` prefix.
        max_pages: Maximum number of pages to fetch (safety cap).

    Returns:
        Flat list of all item dicts from all pages.
    """
    prefix = "/v2/sandbox/usercollection" if use_sandbox else "/v2/usercollection"
    url = f"{_OURA_API_BASE}{prefix}/{collection}"
    all_data: list[dict] = []
    params: dict[str, str] = {"start_date": start_date, "end_date": end_date}

    async with httpx.AsyncClient(timeout=30.0) as client:
        for _ in range(max_pages):
            resp = await client.get(
                url,
                params=params,
                headers={"Authorization": f"Bearer {access_token}"},
            )
            resp.raise_for_status()
            body = resp.json()
            all_data.extend(body.get("data", []))
            next_token = body.get("next_token")
            if not next_token:
                break
            params["next_token"] = next_token

    return all_data


async def _upsert_sleep(
    db: AsyncSession,
    user_id: str,
    records: list[dict],
) -> int:
    """Map Oura daily_sleep records to SleepRecord and upsert.

    Uses the ``day`` field from Oura as the ``date`` key. Oura provides
    ``total_sleep_duration`` in seconds; we convert to fractional hours.
    The ``score`` field (0-100) maps to ``quality_score``.

    Args:
        db: Async database session.
        user_id: Zuralog user ID.
        records: List of Oura ``daily_sleep`` item dicts.

    Returns:
        Number of rows upserted.
    """
    upserted = 0
    for record in records:
        date_str: str = record.get("day") or record.get("date", "")
        if not date_str:
            continue

        # total_sleep_duration is in seconds
        total_seconds = record.get("total_sleep_duration") or record.get("contributors", {}).get("total_sleep", 0) or 0
        hours = float(total_seconds) / 3600.0 if total_seconds else 0.0

        quality_score: int | None = record.get("score")

        stmt = select(SleepRecord).where(
            SleepRecord.user_id == user_id,
            SleepRecord.source == "oura",
            SleepRecord.date == date_str,
        )
        result = await db.execute(stmt)
        existing = result.scalar_one_or_none()

        if existing:
            existing.hours = hours
            existing.quality_score = quality_score
        else:
            new_record = SleepRecord(
                user_id=user_id,
                source="oura",
                date=date_str,
                hours=hours,
                quality_score=quality_score,
            )
            db.add(new_record)

        upserted += 1

    if upserted:
        await db.commit()
        logger.info(
            "Oura sleep: upserted %d row(s) for user '%s'",
            upserted,
            user_id,
        )

    return upserted


async def _upsert_workouts(
    db: AsyncSession,
    user_id: str,
    records: list[dict],
) -> int:
    """Map Oura workout records to UnifiedActivity and upsert.

    Uses ``(source='oura', original_id=record['id'])`` as the dedup key.

    Args:
        db: Async database session.
        user_id: Zuralog user ID.
        records: List of Oura ``workout`` item dicts.

    Returns:
        Number of rows upserted.
    """
    upserted = 0
    for record in records:
        original_id = str(record.get("id", ""))
        if not original_id:
            continue

        activity_str = str(record.get("activity", "other")).lower()
        activity_type = _OURA_ACTIVITY_TYPE_MAP.get(activity_str, _DEFAULT_ACTIVITY_TYPE)

        # Duration in seconds
        duration_seconds = int(record.get("duration", 0) or 0)

        # Distance in meters (Oura may not always include it)
        distance_meters: float | None = record.get("distance")

        # Calories
        calories = int(record.get("calories", 0) or 0)

        # Parse start time
        raw_start = record.get("start_datetime") or record.get("day", "")
        try:
            if "T" in raw_start:
                start_time = datetime.fromisoformat(raw_start.replace("Z", "+00:00"))
                if start_time.tzinfo is None:
                    start_time = start_time.replace(tzinfo=timezone.utc)
            else:
                start_time = datetime(
                    *[int(x) for x in raw_start.split("-")],
                    tzinfo=timezone.utc,
                )
        except (ValueError, TypeError):
            start_time = datetime.now(tz=timezone.utc)

        stmt = select(UnifiedActivity).where(
            UnifiedActivity.source == "oura",
            UnifiedActivity.original_id == original_id,
            UnifiedActivity.user_id == user_id,
        )
        result = await db.execute(stmt)
        existing = result.scalar_one_or_none()

        if existing:
            existing.activity_type = activity_type
            existing.duration_seconds = duration_seconds
            existing.distance_meters = distance_meters
            existing.calories = calories
            existing.start_time = start_time
        else:
            new_activity = UnifiedActivity(
                user_id=user_id,
                source="oura",
                original_id=original_id,
                activity_type=activity_type,
                duration_seconds=duration_seconds,
                distance_meters=distance_meters,
                calories=calories,
                start_time=start_time,
            )
            db.add(new_activity)

        upserted += 1

    if upserted:
        await db.commit()
        logger.info(
            "Oura workouts: upserted %d row(s) for user '%s'",
            upserted,
            user_id,
        )

    return upserted


async def _sync_oura_user_dates(
    db: AsyncSession,
    user_id: str,
    access_token: str,
    start_date: str,
    end_date: str,
    data_types: list[str] | None = None,
    use_sandbox: bool = False,
) -> dict[str, int]:
    """Sync Oura data for a user across a date range.

    Fetches ``daily_sleep``, ``daily_activity``, ``daily_readiness``,
    ``daily_spo2``, ``daily_stress``, ``daily_resilience``, and
    ``workout`` collections. Sleep and workouts are upserted; the rest
    are logged (no dedicated models yet).

    Args:
        db: Async database session.
        user_id: Zuralog user ID.
        access_token: Valid Oura access token.
        start_date: ISO-8601 start date.
        end_date: ISO-8601 end date.
        data_types: Explicit list of data types to sync. If None, syncs
            all periodic types plus workout.
        use_sandbox: Use Oura sandbox endpoints.

    Returns:
        Dict with ``"sleep"`` and ``"workouts"`` counts.
    """
    if data_types is None:
        data_types = [*_PERIODIC_DATA_TYPES, "workout"]

    total_sleep = 0
    total_workouts = 0

    for collection in data_types:
        try:
            records = await _fetch_oura_collection(
                access_token=access_token,
                collection=collection,
                start_date=start_date,
                end_date=end_date,
                use_sandbox=use_sandbox,
            )
            logger.debug(
                "Oura %s: fetched %d record(s) for user '%s'",
                collection,
                len(records),
                user_id,
            )

            if collection in ("daily_sleep",):
                total_sleep += await _upsert_sleep(db, user_id, records)
            elif collection == "workout":
                total_workouts += await _upsert_workouts(db, user_id, records)
            else:
                # daily_activity, daily_readiness, daily_spo2, daily_stress,
                # daily_resilience — log only (no model yet).
                logger.debug(
                    "Oura %s: %d record(s) logged (no model, skipped)",
                    collection,
                    len(records),
                )
        except httpx.HTTPStatusError as exc:
            logger.warning(
                "Oura %s API returned %d for user '%s': %s",
                collection,
                exc.response.status_code,
                user_id,
                exc.response.text[:200],
            )
        except Exception as exc:  # noqa: BLE001
            logger.warning(
                "Oura %s fetch error for user '%s': %s",
                collection,
                user_id,
                exc,
            )

    return {"sleep": total_sleep, "workouts": total_workouts}


# ---------------------------------------------------------------------------
# Celery tasks
# ---------------------------------------------------------------------------


@celery_app.task(name="oura.sync_webhook", bind=True, max_retries=3)
def sync_oura_webhook_task(
    self,
    data_type: str,
    event_type: str,
    oura_user_id: str,
) -> dict[str, Any]:
    """Sync Oura data triggered by a webhook notification.

    Looks up the integration whose ``provider_metadata['oura_user_id']``
    matches ``oura_user_id``, then fetches+stores today + yesterday for the
    specified ``data_type``.

    Args:
        data_type: The Oura data type that changed (e.g. ``"daily_sleep"``).
        event_type: The event type (``"create"`` or ``"update"``).
        oura_user_id: The Oura Ring user ID from the webhook payload.

    Returns:
        Dict with status and counts.
    """
    logger.info(
        "sync_oura_webhook_task: data_type=%s event_type=%s oura_user_id=%s",
        data_type,
        event_type,
        oura_user_id,
    )

    async def _run() -> dict[str, Any]:
        with sentry_sdk.push_scope() as scope:
            scope.set_tag("task", "oura.sync_webhook")
            scope.set_tag("oura_user_id", oura_user_id)
            scope.set_tag("data_type", data_type)

            async with async_session() as db:  # type: ignore[attr-defined]
                # Find integration by provider_metadata->>'oura_user_id'
                stmt = select(Integration).where(
                    Integration.provider == "oura",
                    Integration.is_active.is_(True),
                )
                result = await db.execute(stmt)
                integrations = result.scalars().all()

                target: Integration | None = None
                for intg in integrations:
                    meta = intg.provider_metadata or {}
                    if str(meta.get("oura_user_id", "")) == str(oura_user_id):
                        target = intg
                        break

                if target is None:
                    logger.warning(
                        "sync_oura_webhook_task: no active integration for oura_user_id=%s",
                        oura_user_id,
                    )
                    return {"status": "no_integration"}

                token_service = OuraTokenService()
                access_token = await token_service.get_access_token(db, target.user_id)
                if not access_token:
                    logger.warning(
                        "sync_oura_webhook_task: no token for user '%s'",
                        target.user_id,
                    )
                    return {"status": "no_token"}

                today = date.today()
                yesterday = today - timedelta(days=1)
                start_date = yesterday.isoformat()
                end_date = today.isoformat()

                from app.config import settings as _settings  # noqa: PLC0415

                totals = await _sync_oura_user_dates(
                    db=db,
                    user_id=target.user_id,
                    access_token=access_token,
                    start_date=start_date,
                    end_date=end_date,
                    data_types=[data_type],
                    use_sandbox=_settings.oura_use_sandbox,
                )

                target.last_synced_at = datetime.now(timezone.utc)
                target.sync_status = "idle"
                await db.commit()

                logger.info(
                    "sync_oura_webhook_task: done for user '%s' data_type='%s': %s",
                    target.user_id,
                    data_type,
                    totals,
                )
                return {"status": "ok", "user_id": target.user_id, **totals}

    try:
        return asyncio.run(_run())
    except Exception as exc:  # noqa: BLE001
        logger.exception("sync_oura_webhook_task failed: %s", exc)
        sentry_sdk.capture_exception(exc)
        raise self.retry(exc=exc, countdown=60) from exc


@celery_app.task(name="oura.sync_periodic", bind=True, max_retries=3)
def sync_oura_periodic_task(self) -> dict[str, Any]:
    """Periodic task: sync today + yesterday for all active Oura users.

    Runs as a Celery Beat task every 15 minutes. Skips integrations that
    are already marked as ``sync_status='error'``.

    Returns:
        Dict with ``"users_synced"`` count.
    """
    logger.info("sync_oura_periodic_task: starting periodic Oura sync")

    async def _run() -> dict[str, Any]:
        async with async_session() as db:  # type: ignore[attr-defined]
            stmt = select(Integration).where(
                and_(
                    Integration.provider == "oura",
                    Integration.is_active.is_(True),
                    Integration.sync_status != "error",
                )
            )
            result = await db.execute(stmt)
            integrations = result.scalars().all()

            if not integrations:
                logger.info("sync_oura_periodic_task: no active Oura integrations")
                return {"users_synced": 0}

            today = date.today()
            yesterday = today - timedelta(days=1)
            start_date = yesterday.isoformat()
            end_date = today.isoformat()

            from app.config import settings as _settings  # noqa: PLC0415

            token_service = OuraTokenService()
            users_synced = 0

            for integration in integrations:
                try:
                    access_token = await token_service.get_access_token(db, integration.user_id)
                    if not access_token:
                        logger.warning(
                            "sync_oura_periodic_task: no token for user '%s', skipping",
                            integration.user_id,
                        )
                        continue

                    totals = await _sync_oura_user_dates(
                        db=db,
                        user_id=integration.user_id,
                        access_token=access_token,
                        start_date=start_date,
                        end_date=end_date,
                        use_sandbox=_settings.oura_use_sandbox,
                    )

                    integration.last_synced_at = datetime.now(timezone.utc)
                    integration.sync_status = "idle"
                    await db.commit()
                    users_synced += 1

                    logger.debug(
                        "sync_oura_periodic_task: user '%s' synced: %s",
                        integration.user_id,
                        totals,
                    )

                except Exception as exc:  # noqa: BLE001
                    logger.exception(
                        "sync_oura_periodic_task: sync failed for user '%s': %s",
                        integration.user_id,
                        exc,
                    )
                    sentry_sdk.capture_exception(exc)

            logger.info(
                "sync_oura_periodic_task: synced %d user(s)",
                users_synced,
            )
            return {"users_synced": users_synced}

    try:
        return asyncio.run(_run())
    except Exception as exc:  # noqa: BLE001
        logger.exception("sync_oura_periodic_task failed: %s", exc)
        sentry_sdk.capture_exception(exc)
        raise self.retry(exc=exc, countdown=60) from exc


@celery_app.task(name="oura.refresh_tokens", bind=True, max_retries=3)
def refresh_oura_tokens_task(self) -> dict[str, Any]:
    """Proactively refresh Oura tokens expiring within 6 hours.

    Queries all active Oura integrations and refreshes any token whose
    ``token_expires_at`` is within 6 hours of now. On failure, marks the
    integration as ``sync_status='error'``.

    Runs as a Celery Beat task every 4 hours.

    Returns:
        Dict with ``"refreshed"`` count.
    """
    logger.info("refresh_oura_tokens_task: checking for expiring Oura tokens")

    async def _run() -> dict[str, Any]:
        async with async_session() as db:  # type: ignore[attr-defined]
            stmt = select(Integration).where(
                Integration.provider == "oura",
                Integration.is_active.is_(True),
            )
            result = await db.execute(stmt)
            integrations = result.scalars().all()

            cutoff = datetime.now(timezone.utc) + timedelta(hours=6)
            token_service = OuraTokenService()
            refreshed = 0

            for integration in integrations:
                if not integration.token_expires_at:
                    continue

                expires_at = integration.token_expires_at
                if expires_at.tzinfo is None:
                    expires_at = expires_at.replace(tzinfo=timezone.utc)

                if expires_at >= cutoff:
                    continue

                try:
                    new_token = await token_service.refresh_access_token(db, integration)
                    if new_token:
                        refreshed += 1
                        logger.info(
                            "refresh_oura_tokens_task: refreshed token for user '%s'",
                            integration.user_id,
                        )
                    else:
                        logger.warning(
                            "refresh_oura_tokens_task: failed to refresh token for user '%s' — marked as error",
                            integration.user_id,
                        )
                except Exception as exc:  # noqa: BLE001
                    logger.exception(
                        "refresh_oura_tokens_task: unexpected error for user '%s': %s",
                        integration.user_id,
                        exc,
                    )
                    sentry_sdk.capture_exception(exc)
                    integration.sync_status = "error"
                    integration.sync_error = "Refresh failed — re-authentication required"
                    await db.commit()

            logger.info(
                "refresh_oura_tokens_task: refreshed %d token(s)",
                refreshed,
            )
            return {"refreshed": refreshed}

    try:
        return asyncio.run(_run())
    except Exception as exc:  # noqa: BLE001
        logger.exception("refresh_oura_tokens_task failed: %s", exc)
        sentry_sdk.capture_exception(exc)
        raise self.retry(exc=exc, countdown=60) from exc


@celery_app.task(name="oura.renew_webhooks", bind=True, max_retries=3)
def renew_oura_webhook_subscriptions_task(self) -> dict[str, Any]:
    """Renew Oura webhook subscriptions expiring within 7 days.

    Lists all current Oura webhook subscriptions using app credentials
    (not per-user tokens). Any subscription with an ``expiration_time``
    within 7 days is renewed via the PUT renew endpoint.

    Runs as a Celery Beat task every 24 hours.

    Returns:
        Dict with ``"renewed"`` count and ``"failed"`` count.
    """
    logger.info("renew_oura_webhook_subscriptions_task: checking webhook expiry")

    async def _run() -> dict[str, Any]:
        from app.config import settings as _settings  # noqa: PLC0415

        client_id = _settings.oura_client_id
        client_secret = _settings.oura_client_secret

        if not client_id or not client_secret:
            logger.warning("renew_oura_webhook_subscriptions_task: missing Oura client credentials, skipping")
            return {"renewed": 0, "failed": 0}

        headers = {
            "x-client-id": client_id,
            "x-client-secret": client_secret,
        }
        cutoff = datetime.now(timezone.utc) + timedelta(days=7)
        renewed = 0
        failed = 0

        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                # List all subscriptions
                resp = await client.get(
                    f"{_OURA_API_BASE}/v2/webhook/subscription",
                    headers=headers,
                )
                if resp.status_code != 200:
                    logger.warning(
                        "renew_oura_webhook_subscriptions_task: list returned %d: %s",
                        resp.status_code,
                        resp.text[:200],
                    )
                    return {"renewed": 0, "failed": 0}

                subscriptions = resp.json()
                if isinstance(subscriptions, dict):
                    subscriptions = subscriptions.get("data", [])

                for sub in subscriptions:
                    sub_id = sub.get("id")
                    expiration_str = sub.get("expiration_time")
                    if not sub_id or not expiration_str:
                        continue

                    try:
                        expiration = datetime.fromisoformat(expiration_str.replace("Z", "+00:00"))
                        if expiration.tzinfo is None:
                            expiration = expiration.replace(tzinfo=timezone.utc)
                    except (ValueError, TypeError):
                        continue

                    if expiration >= cutoff:
                        # Not expiring soon — skip
                        continue

                    # Renew this subscription
                    try:
                        renew_resp = await client.put(
                            f"{_OURA_API_BASE}/v2/webhook/subscription/{sub_id}/renew",
                            headers=headers,
                        )
                        if renew_resp.status_code in (200, 201):
                            renewed += 1
                            logger.info(
                                "renew_oura_webhook_subscriptions_task: renewed sub %s (was expiring %s)",
                                sub_id,
                                expiration_str,
                            )
                        else:
                            failed += 1
                            logger.warning(
                                "renew_oura_webhook_subscriptions_task: renew failed for sub %s: %d",
                                sub_id,
                                renew_resp.status_code,
                            )
                    except Exception as exc:  # noqa: BLE001
                        failed += 1
                        logger.exception(
                            "renew_oura_webhook_subscriptions_task: error renewing sub %s: %s",
                            sub_id,
                            exc,
                        )

        except Exception as exc:  # noqa: BLE001
            logger.exception(
                "renew_oura_webhook_subscriptions_task: error listing subscriptions: %s",
                exc,
            )
            sentry_sdk.capture_exception(exc)
            return {"renewed": renewed, "failed": failed}

        logger.info(
            "renew_oura_webhook_subscriptions_task: renewed=%d failed=%d",
            renewed,
            failed,
        )
        return {"renewed": renewed, "failed": failed}

    try:
        return asyncio.run(_run())
    except Exception as exc:  # noqa: BLE001
        logger.exception("renew_oura_webhook_subscriptions_task failed: %s", exc)
        sentry_sdk.capture_exception(exc)
        raise self.retry(exc=exc, countdown=60) from exc


@celery_app.task(name="oura.backfill", bind=True, max_retries=3)
def backfill_oura_data_task(
    self,
    user_id: str,
    days_back: int = 90,
) -> dict[str, Any]:
    """90-day historical backfill for a newly connected Oura account.

    Fetches all major collections (sleep, activity, readiness, spo2,
    stress, resilience, workout) for the date range
    ``[today - days_back, today]``. Called once on first OAuth connect.

    Args:
        user_id: Zuralog user ID to backfill data for.
        days_back: Number of days of history to fetch (default: 90).

    Returns:
        Dict with ``"status"`` and per-collection row counts.
    """
    logger.info(
        "backfill_oura_data_task: starting %d-day backfill for user '%s'",
        days_back,
        user_id,
    )

    async def _run() -> dict[str, Any]:
        async with async_session() as db:  # type: ignore[attr-defined]
            # Verify the integration exists
            stmt = select(Integration).where(
                Integration.user_id == user_id,
                Integration.provider == "oura",
                Integration.is_active.is_(True),
            )
            result = await db.execute(stmt)
            integration = result.scalar_one_or_none()

            if integration is None:
                logger.warning(
                    "backfill_oura_data_task: no active Oura integration for user '%s'",
                    user_id,
                )
                return {"status": "no_integration"}

            token_service = OuraTokenService()
            access_token = await token_service.get_access_token(db, user_id)
            if not access_token:
                logger.warning(
                    "backfill_oura_data_task: could not get access token for user '%s'",
                    user_id,
                )
                return {"status": "no_token"}

            # Mark as syncing
            integration.sync_status = "syncing"
            await db.commit()

            today = date.today()
            start_date = (today - timedelta(days=days_back)).isoformat()
            end_date = today.isoformat()

            from app.config import settings as _settings  # noqa: PLC0415

            data_types = [*_PERIODIC_DATA_TYPES, "workout"]

            try:
                totals = await _sync_oura_user_dates(
                    db=db,
                    user_id=user_id,
                    access_token=access_token,
                    start_date=start_date,
                    end_date=end_date,
                    data_types=data_types,
                    use_sandbox=_settings.oura_use_sandbox,
                )
            except Exception as exc:  # noqa: BLE001
                logger.exception(
                    "backfill_oura_data_task: error during backfill for user '%s': %s",
                    user_id,
                    exc,
                )
                sentry_sdk.capture_exception(exc)
                integration.sync_status = "error"
                integration.sync_error = str(exc)
                await db.commit()
                return {"status": "error", "error": str(exc)}

            integration.sync_status = "idle"
            integration.last_synced_at = datetime.now(timezone.utc)
            await db.commit()

            logger.info(
                "backfill_oura_data_task: complete for user '%s' — %s",
                user_id,
                totals,
            )
            return {"status": "ok", "days_back": days_back, **totals}

    try:
        return asyncio.run(_run())
    except Exception as exc:  # noqa: BLE001
        logger.exception("backfill_oura_data_task failed: %s", exc)
        sentry_sdk.capture_exception(exc)
        raise self.retry(exc=exc, countdown=120) from exc


# ---------------------------------------------------------------------------
# Webhook subscription management (Task 8)
# ---------------------------------------------------------------------------


async def create_oura_webhook_subscriptions(
    client_id: str,
    client_secret: str,
    callback_url: str,
    verification_token: str,
) -> list[str]:
    """Create Oura webhook subscriptions for all supported data types.

    Oura webhooks are app-level (not per-user). This function creates
    subscriptions for every combination of ``data_type`` × ``event_type``
    and returns the IDs of all successfully created subscriptions.

    Args:
        client_id: Oura application client ID.
        client_secret: Oura application client secret.
        callback_url: The HTTPS callback URL Oura will POST events to.
        verification_token: Opaque token used to verify the subscription.

    Returns:
        List of created subscription ID strings.
    """
    data_types = [
        "sleep",
        "daily_sleep",
        "daily_readiness",
        "daily_activity",
        "workout",
        "daily_spo2",
        "daily_stress",
        "daily_resilience",
        "daily_cardiovascular_age",
        "vo2_max",
        "session",
        "enhanced_tag",
        "sleep_time",
        "rest_mode_period",
        "ring_configuration",
    ]
    event_types = ["create", "update"]
    subscription_ids: list[str] = []

    async with httpx.AsyncClient(timeout=30.0) as client:
        for data_type in data_types:
            for event_type in event_types:
                try:
                    response = await client.post(
                        f"{_OURA_API_BASE}/v2/webhook/subscription",
                        json={
                            "callback_url": callback_url,
                            "verification_token": verification_token,
                            "event_type": event_type,
                            "data_type": data_type,
                        },
                        headers={
                            "x-client-id": client_id,
                            "x-client-secret": client_secret,
                        },
                    )
                    if response.status_code == 201:
                        sub = response.json()
                        subscription_ids.append(sub["id"])
                        logger.info(
                            "Created Oura webhook sub: %s/%s -> %s",
                            data_type,
                            event_type,
                            sub["id"],
                        )
                    else:
                        logger.warning(
                            "Failed to create Oura webhook sub %s/%s: %d",
                            data_type,
                            event_type,
                            response.status_code,
                        )
                except Exception:  # noqa: BLE001
                    logger.exception(
                        "Error creating Oura webhook subscription %s/%s",
                        data_type,
                        event_type,
                    )

    return subscription_ids
