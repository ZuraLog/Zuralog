"""
Zuralog Cloud Brain — Withings Celery Sync Tasks.

Provides five Celery tasks for syncing Withings health data:

- ``sync_withings_notification_task``: Webhook-triggered sync for a specific
  notification type (appli code) for the user identified by withings_user_id.
- ``sync_withings_periodic_task``: Celery Beat task (every 15 minutes) that
  syncs today + yesterday for every active Withings integration.
- ``refresh_withings_tokens_task``: Celery Beat task (every 1 hour) that
  proactively refreshes 3-hour tokens expiring within 30 minutes.
- ``backfill_withings_data_task``: One-time task triggered on first connect
  to pull up to ``days_back`` days of historical data.
- ``create_withings_webhook_subscriptions_task``: Task triggered on first
  connect to subscribe the user to all Withings notification categories.

Architecture notes:
- All tasks run in Celery worker processes (synchronous context).
- Async DB operations are executed via ``asyncio.run(_run())``.
- HTTP calls use ``httpx.AsyncClient`` inside async helpers.
- Rate limit: 120 req / 1-min app-level (WithingsRateLimiter). Fail-open.
- Webhook subscriptions use Bearer token auth (NOT signed requests).
"""

import asyncio
import logging
from datetime import date, datetime, timedelta, timezone
from typing import Any

import httpx
import sentry_sdk
from sqlalchemy import and_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.database import async_session
from app.models.blood_pressure import BloodPressureRecord
from app.models.health_data import SleepRecord, WeightMeasurement
from app.models.integration import Integration
from app.services.withings_signature_service import WithingsSignatureService
from app.services.withings_token_service import WithingsTokenService
from app.worker import celery_app

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Measurement type → field name mapping
# ---------------------------------------------------------------------------

_MEAS_TYPE_MAP = {
    1: "weight_kg",
    5: "fat_free_mass_kg",
    6: "fat_ratio_pct",
    8: "fat_mass_kg",
    9: "diastolic_bp_mmhg",
    10: "systolic_bp_mmhg",
    11: "heart_pulse_bpm",
    12: "temperature_c",
    54: "spo2_pct",
    71: "body_temperature_c",
    73: "skin_temperature_c",
    76: "muscle_mass_kg",
    77: "hydration_kg",
    88: "bone_mass_kg",
    91: "pulse_wave_velocity_ms",
    135: "hrv_ms",
}

# Appli code → fetch config
_APPLI_FETCH_MAP = {
    1: {"endpoint": "/measure", "action": "getmeas", "meastypes": "1,5,6,8,76,77,88,91"},
    2: {"endpoint": "/measure", "action": "getmeas", "meastypes": "12,71,73"},
    4: {"endpoint": "/measure", "action": "getmeas", "meastypes": "9,10,11,54"},
    16: {"endpoint": "/v2/measure", "action": "getactivity", "meastypes": None},
    44: {"endpoint": "/v2/sleep", "action": "getsummary", "meastypes": None},
    54: {"endpoint": "/v2/heart", "action": "list", "meastypes": None},
    62: {"endpoint": "/measure", "action": "getmeas", "meastypes": "135"},
}

_WITHINGS_API_BASE = "https://wbsapi.withings.net"
_ALL_APPLI_CODES = [1, 2, 4, 16, 44, 54, 62]


def _get_webhook_callback_url() -> str:
    """Build the Withings webhook callback URL from settings.

    Reads WITHINGS_API_BASE_URL (defaults to https://api.zuralog.com) so
    staging/dev environments register a different URL instead of always
    pointing at production. The shared secret is appended as a query param
    (?token=...) — Withings does not support HMAC payload signatures.
    """
    base = settings.withings_api_base_url.rstrip("/")
    url = f"{base}/api/v1/webhooks/withings"
    secret = settings.withings_webhook_secret
    if secret:
        url = f"{url}?token={secret}"
    return url


# ---------------------------------------------------------------------------
# Internal async helpers
# ---------------------------------------------------------------------------


def _get_sig_service() -> WithingsSignatureService:
    return WithingsSignatureService(
        client_id=settings.withings_client_id,
        client_secret=settings.withings_client_secret,
    )


async def _fetch_withings(
    endpoint: str,
    action: str,
    access_token: str,
    extra_params: dict | None = None,
    sig_service: WithingsSignatureService | None = None,
) -> dict | None:
    """Make a signed POST request to the Withings API."""
    if sig_service is None:
        sig_service = _get_sig_service()

    try:
        signed_params = await sig_service.prepare_signed_params(
            action=action,
            extra_params=extra_params or {},
        )
        url = f"{_WITHINGS_API_BASE}{endpoint}"
        async with httpx.AsyncClient(timeout=20.0) as client:
            response = await client.post(
                url,
                data=signed_params,
                headers={"Authorization": f"Bearer {access_token}"},
            )
            response.raise_for_status()

        body = response.json()
        if body.get("status") != 0:
            logger.error(
                "Withings API error: endpoint=%s action=%s status=%s error=%s",
                endpoint,
                action,
                body.get("status"),
                body.get("error"),
            )
            return None
        return body.get("body")

    except Exception:
        logger.exception("Error fetching from Withings: endpoint=%s action=%s", endpoint, action)
        return None


def _parse_measure_value(measure: dict) -> float:
    """Convert Withings measure value + unit to float. unit is a negative power of 10."""
    value = measure.get("value", 0)
    unit = measure.get("unit", 0)
    return value * (10**unit)


async def _upsert_weight_measurements(
    db: AsyncSession,
    user_id: str,
    measure_groups: list,
) -> int:
    """Upsert body composition measurements into WeightMeasurement table."""
    upserted = 0
    for grp in measure_groups:
        grp_date = datetime.fromtimestamp(grp.get("date", 0), tz=timezone.utc)
        date_str = grp_date.strftime("%Y-%m-%d")

        weight_kg = None

        for measure in grp.get("measures", []):
            mtype = measure.get("type")
            val = _parse_measure_value(measure)
            if mtype == 1:
                weight_kg = val

        if weight_kg is None:
            continue

        result = await db.execute(
            select(WeightMeasurement).where(
                and_(
                    WeightMeasurement.user_id == user_id,
                    WeightMeasurement.source == "withings",
                    WeightMeasurement.date == date_str,
                )
            )
        )
        existing = result.scalar_one_or_none()

        if existing is None:
            import uuid

            record = WeightMeasurement(
                id=str(uuid.uuid4()),
                user_id=user_id,
                source="withings",
                date=date_str,
                weight_kg=weight_kg,
            )
            db.add(record)
            upserted += 1
        else:
            existing.weight_kg = weight_kg
            upserted += 1

    await db.commit()
    return upserted


async def _upsert_blood_pressure(
    db: AsyncSession,
    user_id: str,
    measure_groups: list,
) -> int:
    """Upsert blood pressure readings into BloodPressureRecord table."""
    upserted = 0
    for grp in measure_groups:
        measured_at = datetime.fromtimestamp(grp.get("date", 0), tz=timezone.utc)
        date_str = measured_at.strftime("%Y-%m-%d")

        systolic = None
        diastolic = None
        heart_rate = None
        grp_id = str(grp.get("grpid", ""))

        for measure in grp.get("measures", []):
            mtype = measure.get("type")
            val = _parse_measure_value(measure)
            if mtype == 10:
                systolic = val
            elif mtype == 9:
                diastolic = val
            elif mtype == 11:
                heart_rate = val

        if systolic is None or diastolic is None:
            continue

        result = await db.execute(
            select(BloodPressureRecord).where(
                and_(
                    BloodPressureRecord.user_id == user_id,
                    BloodPressureRecord.source == "withings",
                    BloodPressureRecord.measured_at == measured_at,
                )
            )
        )
        existing = result.scalar_one_or_none()

        if existing is None:
            import uuid

            record = BloodPressureRecord(
                id=str(uuid.uuid4()),
                user_id=user_id,
                source="withings",
                date=date_str,
                measured_at=measured_at,
                systolic_mmhg=systolic,
                diastolic_mmhg=diastolic,
                heart_rate_bpm=heart_rate,
                original_id=grp_id,
            )
            db.add(record)
            upserted += 1
        else:
            existing.systolic_mmhg = systolic
            existing.diastolic_mmhg = diastolic
            if heart_rate is not None:
                existing.heart_rate_bpm = heart_rate
            upserted += 1

    await db.commit()
    return upserted


async def _upsert_sleep(
    db: AsyncSession,
    user_id: str,
    sleep_summaries: list,
) -> int:
    """Upsert sleep summaries into SleepRecord table."""
    upserted = 0
    for summary in sleep_summaries:
        date_str = summary.get("date", "")
        if not date_str:
            startdate_ts = summary.get("startdate")
            if startdate_ts:
                date_str = datetime.fromtimestamp(startdate_ts, tz=timezone.utc).strftime("%Y-%m-%d")

        data = summary.get("data", {})
        total_sleep_seconds = (
            data.get("lightsleepduration", 0) + data.get("deepsleepduration", 0) + data.get("remsleepduration", 0)
        )
        hours = total_sleep_seconds / 3600.0
        score = data.get("sleep_score")

        if not date_str or hours <= 0:
            continue

        result = await db.execute(
            select(SleepRecord).where(
                and_(
                    SleepRecord.user_id == user_id,
                    SleepRecord.source == "withings",
                    SleepRecord.date == date_str,
                )
            )
        )
        existing = result.scalar_one_or_none()

        if existing is None:
            import uuid

            record = SleepRecord(
                id=str(uuid.uuid4()),
                user_id=user_id,
                source="withings",
                date=date_str,
                hours=hours,
                quality_score=score,
            )
            db.add(record)
            upserted += 1
        else:
            existing.hours = hours
            if score is not None:
                existing.quality_score = score
            upserted += 1

    await db.commit()
    return upserted


async def _sync_by_appli(
    db: AsyncSession,
    user_id: str,
    access_token: str,
    appli: int,
    startdate: int | None,
    enddate: int | None,
) -> None:
    """Fetch and upsert data for one Withings notification appli code."""
    fetch_config = _APPLI_FETCH_MAP.get(appli)
    if not fetch_config:
        logger.warning("Unknown Withings appli code: %d", appli)
        return

    endpoint = fetch_config["endpoint"]
    action = fetch_config["action"]
    meastypes = fetch_config.get("meastypes")

    extra: dict = {}
    if startdate:
        extra["startdate"] = startdate
    if enddate:
        extra["enddate"] = enddate
    if meastypes and action == "getmeas":
        extra["meastypes"] = meastypes

    body = await _fetch_withings(endpoint, action, access_token, extra)
    if body is None:
        return

    if action == "getmeas":
        measure_groups = body.get("measuregrps", [])
        if appli == 1:
            await _upsert_weight_measurements(db, user_id, measure_groups)
        elif appli == 4:
            # Appli 4 contains both BP (types 9,10,11) and SpO2 (type 54).
            # Split groups by measurement type to avoid discarding SpO2 data.
            bp_groups = [g for g in measure_groups if any(m.get("type") in (9, 10, 11) for m in g.get("measures", []))]
            spo2_groups = [g for g in measure_groups if any(m.get("type") == 54 for m in g.get("measures", []))]
            if bp_groups:
                await _upsert_blood_pressure(db, user_id, bp_groups)
            if spo2_groups:
                # TODO(withings): upsert SpO2 into DailyHealthMetrics once
                # that model gains a spo2_avg column. For now, log so the
                # data is visible and not silently discarded.
                for grp in spo2_groups:
                    for m in grp.get("measures", []):
                        if m.get("type") == 54:
                            spo2_val = _parse_measure_value(m) * 100
                            logger.info(
                                "Withings SpO2 received (not yet persisted): user=%s spo2=%.1f%%",
                                user_id,
                                spo2_val,
                            )
        # appli 2 (temperature), 62 (HRV) — logged via Withings API; stored in future
    elif action == "getsummary":
        summaries = body.get("series", [])
        await _upsert_sleep(db, user_id, summaries)


async def create_withings_webhook_subscriptions(
    access_token: str,
    callback_url: str = "",
) -> list[int]:
    """Subscribe a user to all Withings notification categories.

    Webhook subscribe calls use Bearer token auth, NOT signed requests.
    Returns the list of appli codes successfully subscribed.

    The shared secret is embedded in callback_url as a ?token=... query
    parameter (Withings does not support HMAC payload signatures).
    """
    if not callback_url:
        callback_url = _get_webhook_callback_url()

    subscribed = []
    failed = []
    for appli in _ALL_APPLI_CODES:
        try:
            async with httpx.AsyncClient(timeout=15.0) as client:
                response = await client.post(
                    f"{_WITHINGS_API_BASE}/notify",
                    data={"action": "subscribe", "callbackurl": callback_url, "appli": appli},
                    headers={"Authorization": f"Bearer {access_token}"},
                )
                body = response.json()
                if body.get("status") == 0:
                    subscribed.append(appli)
                    logger.info("Withings webhook subscribed: appli=%d", appli)
                else:
                    failed.append(appli)
                    logger.warning(
                        "Withings webhook subscribe failed: appli=%d status=%s error=%s",
                        appli,
                        body.get("status"),
                        body.get("error"),
                    )
        except Exception:
            failed.append(appli)
            logger.exception("Failed to subscribe to Withings appli %d", appli)

    if failed:
        sentry_sdk.capture_message(
            f"Withings webhook subscriptions partially failed: appli_codes={failed}",
            level="warning",
        )

    return subscribed


# ---------------------------------------------------------------------------
# Celery tasks
# ---------------------------------------------------------------------------


@celery_app.task(name="withings.sync_notification", bind=True, max_retries=3)
def sync_withings_notification_task(
    self,
    withings_user_id: str,
    appli: int,
    startdate: int | None = None,
    enddate: int | None = None,
    date_str: str = "",
) -> None:
    """Sync Withings data for a specific notification appli code.

    Triggered by webhook delivery. Resolves the Zuralog user from
    withings_user_id, fetches the specific data type, and upserts it.
    """

    async def _run() -> None:
        token_service = WithingsTokenService()

        async with async_session() as db:
            # Filter by withings_user_id in JSONB provider_metadata column.
            # Uses Postgres JSONB containment — avoids a Python-side full scan
            # that would load all active Withings integrations into memory.
            result = await db.execute(
                select(Integration).where(
                    Integration.provider == "withings",
                    Integration.is_active.is_(True),
                    Integration.provider_metadata["withings_user_id"].astext == withings_user_id,
                )
            )
            integrations = result.scalars().all()

            if not integrations:
                logger.warning("No active Withings integration for withings_user_id=%s", withings_user_id)
                return

            for integration in integrations:
                user_id = str(integration.user_id)
                access_token = await token_service.get_access_token(db, user_id)
                if not access_token:
                    continue

                try:
                    await _sync_by_appli(
                        db=db,
                        user_id=user_id,
                        access_token=access_token,
                        appli=appli,
                        startdate=startdate,
                        enddate=enddate,
                    )
                    logger.info("Withings notification sync complete: user=%s appli=%d", user_id, appli)
                except Exception:
                    logger.exception("Error syncing Withings notification: user=%s appli=%d", user_id, appli)

    try:
        asyncio.run(_run())
    except Exception as exc:
        logger.exception("Withings notification sync task failed: withings_user_id=%s", withings_user_id)
        sentry_sdk.capture_exception(exc)
        raise self.retry(exc=exc, countdown=60)


@celery_app.task(name="withings.sync_periodic", bind=True, max_retries=3)
def sync_withings_periodic_task(self) -> None:
    """Periodic sync: today + yesterday for all active Withings users (every 15 min)."""

    async def _run() -> None:
        token_service = WithingsTokenService()

        async with async_session() as db:
            result = await db.execute(
                select(Integration).where(
                    Integration.provider == "withings",
                    Integration.is_active.is_(True),
                )
            )
            integrations = result.scalars().all()

        logger.info("Withings periodic sync: %d active users", len(integrations))

        today = date.today()
        yesterday = today - timedelta(days=1)
        startdate = int(datetime.combine(yesterday, datetime.min.time()).timestamp())
        enddate = int(datetime.combine(today, datetime.max.time()).timestamp())

        for integration in integrations:
            user_id = str(integration.user_id)
            for appli in [1, 4, 16, 44]:
                # Open a fresh session per appli so a failed commit in one appli
                # does not leave the session in a dirty/invalid state for the next.
                try:
                    async with async_session() as db:
                        access_token = await token_service.get_access_token(db, user_id)
                        if not access_token:
                            break  # No token for this user — skip remaining applis too

                        await _sync_by_appli(
                            db=db,
                            user_id=user_id,
                            access_token=access_token,
                            appli=appli,
                            startdate=startdate,
                            enddate=enddate,
                        )
                except Exception:
                    logger.exception("Withings periodic sync failed for user=%s appli=%d", user_id, appli)

    try:
        asyncio.run(_run())
    except Exception as exc:
        logger.exception("Withings periodic sync task failed")
        sentry_sdk.capture_exception(exc)


@celery_app.task(name="withings.refresh_tokens", bind=True, max_retries=3)
def refresh_withings_tokens_task(self) -> None:
    """Proactively refresh Withings tokens expiring within 30 minutes (every 1 hour).

    Withings access tokens expire in 3 hours. This task runs hourly to ensure
    tokens are always fresh before the 30-minute buffer kicks in.
    """

    async def _run() -> None:
        token_service = WithingsTokenService()
        now = datetime.now(timezone.utc)
        expiry_threshold = now + timedelta(minutes=30)

        async with async_session() as db:
            result = await db.execute(
                select(Integration).where(
                    and_(
                        Integration.provider == "withings",
                        Integration.is_active.is_(True),
                        Integration.token_expires_at <= expiry_threshold,
                    )
                )
            )
            integrations = result.scalars().all()

        logger.info("Withings token refresh: %d tokens to refresh", len(integrations))

        for integration in integrations:
            try:
                async with async_session() as db:
                    new_token = await token_service.refresh_access_token(db, integration)
                    if new_token:
                        logger.info("Withings token refreshed for user=%s", integration.user_id)
            except Exception:
                logger.exception("Withings token refresh failed for user=%s", integration.user_id)

    try:
        asyncio.run(_run())
    except Exception as exc:
        logger.exception("Withings refresh tokens task failed")
        sentry_sdk.capture_exception(exc)


@celery_app.task(name="withings.backfill", bind=True, max_retries=3)
def backfill_withings_data_task(self, user_id: str, days_back: int = 30) -> None:
    """Backfill historical Withings data for a user (triggered on connect).

    Fetches up to ``days_back`` days of body comp, blood pressure, activity,
    and sleep data.
    """

    async def _run() -> None:
        token_service = WithingsTokenService()

        today = date.today()
        start_dt = today - timedelta(days=days_back)
        startdate = int(datetime.combine(start_dt, datetime.min.time()).timestamp())
        enddate = int(datetime.combine(today, datetime.max.time()).timestamp())

        async with async_session() as db:
            access_token = await token_service.get_access_token(db, user_id)
            if not access_token:
                logger.warning("Withings backfill: no token for user=%s", user_id)
                return

            for appli in [1, 4, 16, 44]:
                try:
                    await _sync_by_appli(
                        db=db,
                        user_id=user_id,
                        access_token=access_token,
                        appli=appli,
                        startdate=startdate,
                        enddate=enddate,
                    )
                except Exception:
                    logger.exception("Withings backfill error: user=%s appli=%d", user_id, appli)

        logger.info("Withings backfill complete: user=%s days_back=%d", user_id, days_back)

    try:
        asyncio.run(_run())
    except Exception as exc:
        logger.exception("Withings backfill task failed for user=%s", user_id)
        sentry_sdk.capture_exception(exc)
        raise self.retry(exc=exc, countdown=120)


@celery_app.task(name="withings.create_webhooks", bind=True, max_retries=3)
def create_withings_webhook_subscriptions_task(self, user_id: str) -> None:
    """Create Withings webhook subscriptions for a newly connected user."""

    async def _run() -> None:
        token_service = WithingsTokenService()

        async with async_session() as db:
            access_token = await token_service.get_access_token(db, user_id)
            if not access_token:
                logger.warning("Withings webhook setup: no token for user=%s", user_id)
                return

            subscribed = await create_withings_webhook_subscriptions(access_token)
            logger.info(
                "Withings webhook subscriptions created: user=%s appli_codes=%s",
                user_id,
                subscribed,
            )

            # Store subscribed appli codes in integration metadata
            integration = await token_service.get_integration(db, user_id)
            if integration:
                metadata = dict(integration.provider_metadata or {})
                metadata["webhook_subscription_applis"] = subscribed
                integration.provider_metadata = metadata
                await db.commit()

    try:
        asyncio.run(_run())
    except Exception as exc:
        logger.exception("Withings webhook subscription task failed for user=%s", user_id)
        sentry_sdk.capture_exception(exc)
        raise self.retry(exc=exc, countdown=60)
