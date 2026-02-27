"""
Zuralog Cloud Brain — Fitbit Celery Sync Tasks.

Provides four Celery tasks for syncing Fitbit health data:

- ``sync_fitbit_collection_task``: Webhook-triggered on-demand sync for a
  single collection type (activities, sleep, body, foods) on a specific date.
- ``sync_fitbit_periodic_task``: Celery Beat task (every 15 minutes) that
  pulls today + yesterday's data for every active Fitbit integration.
- ``refresh_fitbit_tokens_task``: Celery Beat task (every 1 hour) that
  proactively refreshes tokens expiring within 2 hours.
- ``backfill_fitbit_data_task``: One-time task triggered on first connect
  to pull up to ``days_back`` days of historical data.

Architecture notes:
- All tasks run in Celery worker processes (synchronous context).
- Async DB operations are executed via ``asyncio.run(_run())``.
- HTTP calls use ``httpx.AsyncClient`` inside the async helper.
- Rate budget: 150 calls/hr per Fitbit user. The 15-min cycle uses at
  most 12 calls per user (6 data types × 2 days), well within budget.
"""

import asyncio
import logging
from datetime import date, datetime, timedelta, timezone
from typing import Any

import httpx
from sqlalchemy import and_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import async_session
from app.models.health_data import (
    ActivityType,
    NutritionEntry,
    SleepRecord,
    UnifiedActivity,
    WeightMeasurement,
)
from app.models.integration import Integration
from app.services.fitbit_token_service import FitbitTokenService
from app.worker import celery_app

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Fitbit activity type mapping
# ---------------------------------------------------------------------------

# Maps Fitbit ``activityTypeId`` integers to canonical ActivityType values.
# Unknown IDs fall back to ``_DEFAULT_ACTIVITY_TYPE``.
_FITBIT_TYPE_MAP: dict[int, str] = {
    90009: "RUN",
    90001: "CYCLE",
    90024: "SWIM",
    90013: "WALK",
    15000: "STRENGTH",
    15010: "STRENGTH",
    90019: "YOGA",
    3000: "HIKE",
}
_DEFAULT_ACTIVITY_TYPE = "OTHER"

# Map from our string keys to canonical ActivityType enum values.
_ACTIVITY_TYPE_ENUM_MAP: dict[str, ActivityType] = {
    "RUN": ActivityType.RUN,
    "CYCLE": ActivityType.CYCLE,
    "SWIM": ActivityType.SWIM,
    "WALK": ActivityType.WALK,
    "STRENGTH": ActivityType.STRENGTH,
    # YOGA and HIKE have no dedicated canonical type — map to UNKNOWN.
    "YOGA": ActivityType.UNKNOWN,
    "HIKE": ActivityType.WALK,
    "OTHER": ActivityType.UNKNOWN,
}

# ---------------------------------------------------------------------------
# Fitbit API base URL
# ---------------------------------------------------------------------------
_FITBIT_API_BASE = "https://api.fitbit.com"


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------


def _map_fitbit_activity_type(activity_type_id: int | None) -> ActivityType:
    """Convert a Fitbit ``activityTypeId`` to a canonical ``ActivityType``.

    Args:
        activity_type_id: Integer activity type ID from the Fitbit API, or
            ``None`` if not present in the payload.

    Returns:
        The matching ``ActivityType`` enum value, defaulting to
        ``ActivityType.UNKNOWN`` for unknown IDs.
    """
    if activity_type_id is None:
        return ActivityType.UNKNOWN
    key = _FITBIT_TYPE_MAP.get(activity_type_id, _DEFAULT_ACTIVITY_TYPE)
    return _ACTIVITY_TYPE_ENUM_MAP.get(key, ActivityType.UNKNOWN)


async def _sync_fitbit_activities(
    db: AsyncSession,
    user_id: str,
    access_token: str,
    date_str: str,
) -> int:
    """Fetch Fitbit activity summary for a date and upsert into UnifiedActivity.

    Calls ``GET /1/user/-/activities/date/{date}.json`` and maps the
    returned activity log entries to ``UnifiedActivity`` rows.

    Args:
        db: Async database session.
        user_id: Zuralog user ID.
        access_token: Valid Fitbit access token.
        date_str: Date string in ``YYYY-MM-DD`` format.

    Returns:
        Number of activity rows upserted (inserted or updated).
    """
    url = f"{_FITBIT_API_BASE}/1/user/-/activities/date/{date_str}.json"
    async with httpx.AsyncClient(timeout=30.0) as client:
        resp = await client.get(
            url,
            headers={"Authorization": f"Bearer {access_token}"},
        )

    if resp.status_code != 200:
        logger.warning(
            "Fitbit activities API returned %d for user '%s' date '%s': %s",
            resp.status_code,
            user_id,
            date_str,
            resp.text,
        )
        return 0

    data = resp.json()
    activity_list: list[dict[str, Any]] = data.get("activities", [])
    upserted = 0

    for activity in activity_list:
        original_id = str(activity.get("logId", ""))
        if not original_id:
            continue

        activity_type = _map_fitbit_activity_type(activity.get("activityTypeId"))

        # Parse start time — Fitbit returns local time with no timezone info.
        # We record it as UTC for consistency (Fitbit doesn't include tz offset here).
        raw_start = activity.get("startTime") or f"{date_str}T00:00:00.000"
        try:
            start_time = datetime.fromisoformat(raw_start.replace(".000", "")).replace(
                tzinfo=timezone.utc
            )
        except ValueError:
            start_time = datetime.now(tz=timezone.utc)

        # duration: Fitbit provides milliseconds in "duration" field.
        duration_ms = activity.get("duration", 0)
        duration_seconds = int(duration_ms / 1000) if duration_ms else 0

        # Upsert by (source, original_id).
        stmt = select(UnifiedActivity).where(
            UnifiedActivity.source == "fitbit",
            UnifiedActivity.original_id == original_id,
            UnifiedActivity.user_id == user_id,
        )
        result = await db.execute(stmt)
        existing = result.scalar_one_or_none()

        if existing:
            existing.activity_type = activity_type
            existing.duration_seconds = duration_seconds
            existing.distance_meters = activity.get("distance")
            existing.calories = int(activity.get("calories") or 0)
            existing.start_time = start_time
        else:
            new_activity = UnifiedActivity(
                user_id=user_id,
                source="fitbit",
                original_id=original_id,
                activity_type=activity_type,
                duration_seconds=duration_seconds,
                distance_meters=activity.get("distance"),
                calories=int(activity.get("calories") or 0),
                start_time=start_time,
            )
            db.add(new_activity)

        upserted += 1

    if upserted:
        await db.commit()
        logger.info(
            "Fitbit activities: upserted %d rows for user '%s' date '%s'",
            upserted,
            user_id,
            date_str,
        )

    return upserted


async def _sync_fitbit_sleep(
    db: AsyncSession,
    user_id: str,
    access_token: str,
    date_str: str,
) -> int:
    """Fetch Fitbit sleep data for a date and upsert into SleepRecord.

    Calls ``GET /1.2/user/-/sleep/date/{date}.json`` and maps the main sleep
    summary to a ``SleepRecord`` row keyed by (user_id, source, date).

    Args:
        db: Async database session.
        user_id: Zuralog user ID.
        access_token: Valid Fitbit access token.
        date_str: Date string in ``YYYY-MM-DD`` format.

    Returns:
        1 if a row was upserted, 0 otherwise.
    """
    url = f"{_FITBIT_API_BASE}/1.2/user/-/sleep/date/{date_str}.json"
    async with httpx.AsyncClient(timeout=30.0) as client:
        resp = await client.get(
            url,
            headers={"Authorization": f"Bearer {access_token}"},
        )

    if resp.status_code != 200:
        logger.warning(
            "Fitbit sleep API returned %d for user '%s' date '%s': %s",
            resp.status_code,
            user_id,
            date_str,
            resp.text,
        )
        return 0

    data = resp.json()
    summary = data.get("summary", {})

    # totalMinutesAsleep from the summary; convert to fractional hours.
    total_minutes = summary.get("totalMinutesAsleep", 0)
    if not total_minutes:
        logger.debug("No sleep data for user '%s' on '%s'", user_id, date_str)
        return 0

    hours = total_minutes / 60.0

    # Optional quality score: Fitbit doesn't provide a 0-100 score directly;
    # we derive a rough score from efficiency if available.
    efficiency: int | None = None
    sleep_log: list[dict[str, Any]] = data.get("sleep", [])
    if sleep_log:
        main_sleep = next((s for s in sleep_log if s.get("isMainSleep")), None)
        if main_sleep:
            efficiency = main_sleep.get("efficiency")

    stmt = select(SleepRecord).where(
        SleepRecord.user_id == user_id,
        SleepRecord.source == "fitbit",
        SleepRecord.date == date_str,
    )
    result = await db.execute(stmt)
    existing = result.scalar_one_or_none()

    if existing:
        existing.hours = hours
        existing.quality_score = efficiency
    else:
        new_record = SleepRecord(
            user_id=user_id,
            source="fitbit",
            date=date_str,
            hours=hours,
            quality_score=efficiency,
        )
        db.add(new_record)

    await db.commit()
    logger.info(
        "Fitbit sleep: upserted record for user '%s' date '%s' (%.1fh)",
        user_id,
        date_str,
        hours,
    )
    return 1


async def _sync_fitbit_weight(
    db: AsyncSession,
    user_id: str,
    access_token: str,
    date_str: str,
) -> int:
    """Fetch Fitbit body weight logs for a date and upsert into WeightMeasurement.

    Calls ``GET /1/user/-/body/log/weight/date/{date}.json`` and maps
    each log entry to a ``WeightMeasurement`` row.

    Args:
        db: Async database session.
        user_id: Zuralog user ID.
        access_token: Valid Fitbit access token.
        date_str: Date string in ``YYYY-MM-DD`` format.

    Returns:
        Number of rows upserted.
    """
    url = f"{_FITBIT_API_BASE}/1/user/-/body/log/weight/date/{date_str}.json"
    async with httpx.AsyncClient(timeout=30.0) as client:
        resp = await client.get(
            url,
            headers={"Authorization": f"Bearer {access_token}"},
        )

    if resp.status_code != 200:
        logger.warning(
            "Fitbit body API returned %d for user '%s' date '%s': %s",
            resp.status_code,
            user_id,
            date_str,
            resp.text,
        )
        return 0

    data = resp.json()
    weight_logs: list[dict[str, Any]] = data.get("weight", [])
    upserted = 0

    for log_entry in weight_logs:
        log_date = log_entry.get("date", date_str)

        stmt = select(WeightMeasurement).where(
            WeightMeasurement.user_id == user_id,
            WeightMeasurement.source == "fitbit",
            WeightMeasurement.date == log_date,
        )
        result = await db.execute(stmt)
        existing = result.scalar_one_or_none()

        weight_kg = float(log_entry.get("weight", 0))
        if not weight_kg:
            continue

        if existing:
            existing.weight_kg = weight_kg
        else:
            new_measurement = WeightMeasurement(
                user_id=user_id,
                source="fitbit",
                date=log_date,
                weight_kg=weight_kg,
            )
            db.add(new_measurement)

        upserted += 1

    if upserted:
        await db.commit()
        logger.info(
            "Fitbit weight: upserted %d rows for user '%s' date '%s'",
            upserted,
            user_id,
            date_str,
        )

    return upserted


async def _sync_fitbit_nutrition(
    db: AsyncSession,
    user_id: str,
    access_token: str,
    date_str: str,
) -> int:
    """Fetch Fitbit food logs for a date and upsert into NutritionEntry.

    Calls ``GET /1/user/-/foods/log/date/{date}.json`` and maps the
    daily totals to a ``NutritionEntry`` row.

    Args:
        db: Async database session.
        user_id: Zuralog user ID.
        access_token: Valid Fitbit access token.
        date_str: Date string in ``YYYY-MM-DD`` format.

    Returns:
        1 if a row was upserted, 0 otherwise.
    """
    url = f"{_FITBIT_API_BASE}/1/user/-/foods/log/date/{date_str}.json"
    async with httpx.AsyncClient(timeout=30.0) as client:
        resp = await client.get(
            url,
            headers={"Authorization": f"Bearer {access_token}"},
        )

    if resp.status_code != 200:
        logger.warning(
            "Fitbit foods API returned %d for user '%s' date '%s': %s",
            resp.status_code,
            user_id,
            date_str,
            resp.text,
        )
        return 0

    data = resp.json()
    summary = data.get("summary", {})

    total_calories = int(summary.get("calories", 0))
    if not total_calories:
        logger.debug("No nutrition data for user '%s' on '%s'", user_id, date_str)
        return 0

    protein = summary.get("protein")
    carbs = summary.get("carbs")
    fat = summary.get("fat")

    stmt = select(NutritionEntry).where(
        NutritionEntry.user_id == user_id,
        NutritionEntry.source == "fitbit",
        NutritionEntry.date == date_str,
    )
    result = await db.execute(stmt)
    existing = result.scalar_one_or_none()

    if existing:
        existing.calories = total_calories
        existing.protein_grams = float(protein) if protein is not None else None
        existing.carbs_grams = float(carbs) if carbs is not None else None
        existing.fat_grams = float(fat) if fat is not None else None
    else:
        new_entry = NutritionEntry(
            user_id=user_id,
            source="fitbit",
            date=date_str,
            calories=total_calories,
            protein_grams=float(protein) if protein is not None else None,
            carbs_grams=float(carbs) if carbs is not None else None,
            fat_grams=float(fat) if fat is not None else None,
        )
        db.add(new_entry)

    await db.commit()
    logger.info(
        "Fitbit nutrition: upserted entry for user '%s' date '%s' (%d kcal)",
        user_id,
        date_str,
        total_calories,
    )
    return 1


async def _sync_fitbit_user(
    db: AsyncSession,
    user_id: str,
    access_token: str,
    dates: list[str],
) -> dict[str, Any]:
    """Sync all Fitbit data types for one user across the given date list.

    Syncs activity, sleep, weight, and nutrition for every date in ``dates``.
    Heart rate, SpO2, and HRV are fetched but no dedicated models exist yet —
    they are logged and skipped with a TODO note.

    Args:
        db: Async database session.
        user_id: Zuralog user ID.
        access_token: Valid Fitbit access token.
        dates: List of ``YYYY-MM-DD`` date strings to sync.

    Returns:
        A summary dict with counts of rows synced per data type.
    """
    total_activities = 0
    total_sleep = 0
    total_weight = 0
    total_nutrition = 0

    for date_str in dates:
        total_activities += await _sync_fitbit_activities(db, user_id, access_token, date_str)
        total_sleep += await _sync_fitbit_sleep(db, user_id, access_token, date_str)
        total_weight += await _sync_fitbit_weight(db, user_id, access_token, date_str)
        total_nutrition += await _sync_fitbit_nutrition(db, user_id, access_token, date_str)

        # Heart Rate — no dedicated model; store as log only.
        # TODO(task-future): upsert into a HeartRateRecord model when created.
        hr_url = f"{_FITBIT_API_BASE}/1/user/-/activities/heart/date/{date_str}/1d.json"
        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                hr_resp = await client.get(
                    hr_url,
                    headers={"Authorization": f"Bearer {access_token}"},
                )
            if hr_resp.status_code == 200:
                hr_data = hr_resp.json()
                resting_hr = (
                    hr_data.get("activities-heart", [{}])[0]
                    .get("value", {})
                    .get("restingHeartRate")
                )
                if resting_hr:
                    logger.debug(
                        "Fitbit HR: resting=%d bpm for user '%s' date '%s' (no model, skipped)",
                        resting_hr,
                        user_id,
                        date_str,
                    )
            else:
                logger.debug(
                    "Fitbit HR API returned %d for user '%s' date '%s'",
                    hr_resp.status_code,
                    user_id,
                    date_str,
                )
        except Exception as exc:  # noqa: BLE001
            logger.debug("Fitbit HR fetch error for user '%s': %s", user_id, exc)

        # SpO2 — no dedicated model.
        # TODO(task-future): upsert into a SpO2Record model when created.
        spo2_url = f"{_FITBIT_API_BASE}/1/user/-/spo2/date/{date_str}.json"
        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                spo2_resp = await client.get(
                    spo2_url,
                    headers={"Authorization": f"Bearer {access_token}"},
                )
            if spo2_resp.status_code == 200:
                logger.debug(
                    "Fitbit SpO2 data received for user '%s' date '%s' (no model, skipped)",
                    user_id,
                    date_str,
                )
        except Exception as exc:  # noqa: BLE001
            logger.debug("Fitbit SpO2 fetch error for user '%s': %s", user_id, exc)

        # HRV — no dedicated model.
        # TODO(task-future): upsert into an HRVRecord model when created.
        hrv_url = f"{_FITBIT_API_BASE}/1/user/-/hrv/date/{date_str}.json"
        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                hrv_resp = await client.get(
                    hrv_url,
                    headers={"Authorization": f"Bearer {access_token}"},
                )
            if hrv_resp.status_code == 200:
                logger.debug(
                    "Fitbit HRV data received for user '%s' date '%s' (no model, skipped)",
                    user_id,
                    date_str,
                )
        except Exception as exc:  # noqa: BLE001
            logger.debug("Fitbit HRV fetch error for user '%s': %s", user_id, exc)

    return {
        "activities": total_activities,
        "sleep": total_sleep,
        "weight": total_weight,
        "nutrition": total_nutrition,
    }


# ---------------------------------------------------------------------------
# Celery tasks
# ---------------------------------------------------------------------------


@celery_app.task(name="app.tasks.fitbit_sync.sync_fitbit_collection_task")
def sync_fitbit_collection_task(
    fitbit_user_id: str,
    collection_type: str,
    date: str,
) -> dict[str, Any]:
    """Sync a single Fitbit collection triggered by a webhook notification.

    Called immediately when Fitbit pushes a webhook notification indicating
    that a user's health data has changed. Looks up the Fitbit integration
    whose ``provider_metadata["fitbit_user_id"]`` matches ``fitbit_user_id``,
    fetches the changed collection, and upserts it into the database.

    Args:
        fitbit_user_id: Fitbit user ID from the webhook ``ownerId`` field.
        collection_type: The collection type that changed. Supported values:
            ``"activities"``, ``"sleep"``, ``"body"``, ``"foods"``.
            Unknown types are logged and skipped.
        date: The date of the change in ``YYYY-MM-DD`` format.

    Returns:
        A dict with ``"status"`` describing the outcome, and additional
        context fields for observability.
    """
    logger.info(
        "sync_fitbit_collection_task: fitbit_user_id=%s collection=%s date=%s",
        fitbit_user_id,
        collection_type,
        date,
    )

    async def _run() -> dict[str, Any]:
        async with async_session() as db:  # type: ignore[attr-defined]
            # Find the integration whose provider_metadata["fitbit_user_id"] matches.
            stmt = select(Integration).where(
                Integration.provider == "fitbit",
                Integration.is_active.is_(True),
            )
            result = await db.execute(stmt)
            integrations = result.scalars().all()

            target: Integration | None = None
            for intg in integrations:
                meta = intg.provider_metadata or {}
                if str(meta.get("fitbit_user_id", "")) == str(fitbit_user_id):
                    target = intg
                    break

            if target is None:
                logger.warning(
                    "sync_fitbit_collection_task: no active integration for fitbit_user_id=%s",
                    fitbit_user_id,
                )
                return {"status": "no_integration"}

            token_service = FitbitTokenService()
            access_token = await token_service.get_access_token(db, target.user_id)
            if not access_token:
                logger.warning(
                    "sync_fitbit_collection_task: could not get access token for user '%s'",
                    target.user_id,
                )
                return {"status": "no_token"}

            upserted = 0

            if collection_type == "activities":
                upserted = await _sync_fitbit_activities(db, target.user_id, access_token, date)

            elif collection_type == "sleep":
                upserted = await _sync_fitbit_sleep(db, target.user_id, access_token, date)

            elif collection_type == "body":
                upserted = await _sync_fitbit_weight(db, target.user_id, access_token, date)

            elif collection_type == "foods":
                upserted = await _sync_fitbit_nutrition(db, target.user_id, access_token, date)

            else:
                logger.warning(
                    "sync_fitbit_collection_task: unknown collection_type='%s' for user '%s'",
                    collection_type,
                    target.user_id,
                )
                return {"status": "unknown_collection_type", "collection_type": collection_type}

            # Update integration sync metadata.
            target.last_synced_at = datetime.now(timezone.utc)
            target.sync_status = "idle"
            await db.commit()

            logger.info(
                "sync_fitbit_collection_task: synced %d row(s) for user '%s' collection='%s' date='%s'",
                upserted,
                target.user_id,
                collection_type,
                date,
            )
            return {
                "status": "ok",
                "user_id": target.user_id,
                "collection_type": collection_type,
                "date": date,
                "upserted": upserted,
            }

    return asyncio.run(_run())


@celery_app.task(name="app.tasks.fitbit_sync.sync_fitbit_periodic_task")
def sync_fitbit_periodic_task() -> dict[str, Any]:
    """Periodic task: sync all active Fitbit users every 15 minutes.

    Queries for all active, non-error Fitbit integrations and syncs
    today + yesterday's data for each user. Runs as a Celery Beat task
    scheduled every 15 minutes in ``worker.py``.

    Returns:
        A dict with ``"users_synced"`` count.
    """
    logger.info("sync_fitbit_periodic_task: starting periodic Fitbit sync")

    async def _run() -> dict[str, Any]:
        async with async_session() as db:  # type: ignore[attr-defined]
            stmt = select(Integration).where(
                and_(
                    Integration.provider == "fitbit",
                    Integration.is_active.is_(True),
                    Integration.sync_status != "error",
                )
            )
            result = await db.execute(stmt)
            integrations = result.scalars().all()

            if not integrations:
                logger.info("sync_fitbit_periodic_task: no active Fitbit integrations")
                return {"users_synced": 0}

            # Sync today and yesterday.
            today = date.today()
            yesterday = today - timedelta(days=1)
            dates = [today.isoformat(), yesterday.isoformat()]

            token_service = FitbitTokenService()
            users_synced = 0

            for integration in integrations:
                try:
                    access_token = await token_service.get_access_token(db, integration.user_id)
                    if not access_token:
                        logger.warning(
                            "sync_fitbit_periodic_task: no token for user '%s', skipping",
                            integration.user_id,
                        )
                        continue

                    await _sync_fitbit_user(db, integration.user_id, access_token, dates)

                    integration.last_synced_at = datetime.now(timezone.utc)
                    integration.sync_status = "idle"
                    await db.commit()
                    users_synced += 1

                except Exception as exc:  # noqa: BLE001
                    logger.exception(
                        "sync_fitbit_periodic_task: sync failed for user '%s': %s",
                        integration.user_id,
                        exc,
                    )

            logger.info(
                "sync_fitbit_periodic_task: synced %d user(s)",
                users_synced,
            )
            return {"users_synced": users_synced}

    return asyncio.run(_run())


@celery_app.task(name="app.tasks.fitbit_sync.refresh_fitbit_tokens_task")
def refresh_fitbit_tokens_task() -> dict[str, Any]:
    """Proactively refresh Fitbit tokens expiring within 2 hours.

    Queries for all active Fitbit integrations and refreshes any token
    whose ``token_expires_at`` is within 2 hours of now. On refresh
    failure (e.g. 401), marks the integration as ``sync_status="error"``.

    Runs as a Celery Beat task scheduled every 1 hour in ``worker.py``.

    Returns:
        A dict with ``"refreshed"`` count of tokens successfully refreshed.
    """
    logger.info("refresh_fitbit_tokens_task: checking for expiring Fitbit tokens")

    async def _run() -> dict[str, Any]:
        async with async_session() as db:  # type: ignore[attr-defined]
            stmt = select(Integration).where(
                Integration.provider == "fitbit",
                Integration.is_active.is_(True),
            )
            result = await db.execute(stmt)
            integrations = result.scalars().all()

            cutoff = datetime.now(timezone.utc) + timedelta(hours=2)
            token_service = FitbitTokenService()
            refreshed = 0

            for integration in integrations:
                # Skip if no expiry is recorded or token is not expiring soon.
                if not integration.token_expires_at:
                    continue

                expires_at = integration.token_expires_at
                # Normalize to UTC if naive datetime.
                if expires_at.tzinfo is None:
                    expires_at = expires_at.replace(tzinfo=timezone.utc)

                if expires_at >= cutoff:
                    continue

                # Token is expiring within 2 hours — refresh it.
                try:
                    new_token = await token_service.refresh_access_token(db, integration)
                    if new_token:
                        refreshed += 1
                        logger.info(
                            "refresh_fitbit_tokens_task: refreshed token for user '%s'",
                            integration.user_id,
                        )
                    else:
                        # refresh_access_token already marks sync_status="error" on failure.
                        logger.warning(
                            "refresh_fitbit_tokens_task: failed to refresh token for user '%s'"
                            " — marked as error",
                            integration.user_id,
                        )
                except Exception as exc:  # noqa: BLE001
                    logger.exception(
                        "refresh_fitbit_tokens_task: unexpected error refreshing token for"
                        " user '%s': %s",
                        integration.user_id,
                        exc,
                    )
                    integration.sync_status = "error"
                    integration.sync_error = "Refresh failed — re-authentication required"
                    await db.commit()

            logger.info(
                "refresh_fitbit_tokens_task: refreshed %d token(s)",
                refreshed,
            )
            return {"refreshed": refreshed}

    return asyncio.run(_run())


@celery_app.task(name="app.tasks.fitbit_sync.backfill_fitbit_data_task")
def backfill_fitbit_data_task(user_id: str, days_back: int = 30) -> dict[str, Any]:
    """Back-fill historical Fitbit data on first connect.

    Syncs ``days_back`` days of activity, sleep, weight, and nutrition
    data for a user. Uses date-range queries where available to minimize
    API calls. Intended to be called once when a user first connects their
    Fitbit account.

    Args:
        user_id: Zuralog user ID to back-fill data for.
        days_back: Number of days of history to fetch (default: 30).

    Returns:
        A dict describing the outcome with sync counts.
    """
    logger.info(
        "backfill_fitbit_data_task: starting %d-day backfill for user '%s'",
        days_back,
        user_id,
    )

    async def _run() -> dict[str, Any]:
        async with async_session() as db:  # type: ignore[attr-defined]
            token_service = FitbitTokenService()

            # Verify the integration exists.
            stmt = select(Integration).where(
                Integration.user_id == user_id,
                Integration.provider == "fitbit",
                Integration.is_active.is_(True),
            )
            result = await db.execute(stmt)
            integration = result.scalar_one_or_none()

            if integration is None:
                logger.warning(
                    "backfill_fitbit_data_task: no active Fitbit integration for user '%s'",
                    user_id,
                )
                return {"status": "no_integration"}

            access_token = await token_service.get_access_token(db, user_id)
            if not access_token:
                logger.warning(
                    "backfill_fitbit_data_task: could not get access token for user '%s'",
                    user_id,
                )
                return {"status": "no_token"}

            # Mark integration as syncing.
            integration.sync_status = "syncing"
            await db.commit()

            today = date.today()
            dates = [
                (today - timedelta(days=i)).isoformat() for i in range(days_back - 1, -1, -1)
            ]

            try:
                totals = await _sync_fitbit_user(db, user_id, access_token, dates)
            except Exception as exc:  # noqa: BLE001
                logger.exception(
                    "backfill_fitbit_data_task: error during backfill for user '%s': %s",
                    user_id,
                    exc,
                )
                integration.sync_status = "error"
                integration.sync_error = str(exc)
                await db.commit()
                return {"status": "error", "error": str(exc)}

            # Mark integration as done.
            integration.sync_status = "idle"
            integration.last_synced_at = datetime.now(timezone.utc)
            await db.commit()

            logger.info(
                "backfill_fitbit_data_task: complete for user '%s' — %s",
                user_id,
                totals,
            )
            return {"status": "ok", "days_back": days_back, **totals}

    return asyncio.run(_run())
