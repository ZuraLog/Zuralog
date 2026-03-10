"""
Zuralog Cloud Brain — Polar AccessLink Celery Sync Tasks.

Tasks:
1. sync_polar_webhook_task    — Dispatched by webhook handler per event
2. sync_polar_periodic_task   — Celery Beat every 15 min
3. monitor_polar_token_expiry_task — Celery Beat daily, push notify 30 days before expiry
4. backfill_polar_data_task   — One-time after first connection (28 days)
5. create_polar_webhook_task  — One-time on first connection (client-level, Basic auth)
6. check_polar_webhook_status_task — Celery Beat daily, re-activate if deactivated

Architecture:
- All tasks run in Celery worker processes (synchronous context)
- Async DB operations are executed via asyncio.run(_run())
- HTTP calls use httpx.AsyncClient inside async helpers
- Rate limit: use PolarRateLimiter (optional, fail-open)
- Polar data window: last 30 days only
- Tokens last ~1 year — no refresh, just check expiry

Key Polar specifics:
- Webhook API uses Basic auth (client credentials, not Bearer)
- Polar API uses Bearer token for user data
- Webhook is per-client (one webhook covers all users)
- Webhook auto-deactivates after 7 days of failures → check daily
"""

import asyncio
import base64
import logging
from datetime import datetime, timedelta, timezone
from typing import TYPE_CHECKING

import httpx
import sentry_sdk
from sqlalchemy import select

from sqlalchemy import String, cast

from app.config import settings
from app.database import worker_async_session as async_session
from app.models.integration import Integration
from app.worker import celery_app

if TYPE_CHECKING:
    from app.services.polar_rate_limiter import PolarRateLimiter

logger = logging.getLogger(__name__)

POLAR_API_BASE = "https://www.polaraccesslink.com"


def _basic_auth_header() -> str:
    """Build Basic auth header for client-level endpoints (webhooks)."""
    credentials = base64.b64encode(f"{settings.polar_client_id}:{settings.polar_client_secret}".encode()).decode()
    return f"Basic {credentials}"


async def _fetch_polar(
    access_token: str,
    path: str,
    timeout: float = 20.0,
    rate_limiter: "PolarRateLimiter | None" = None,
) -> dict | None:
    """Make a GET request to the Polar API with Bearer token auth.

    Args:
        access_token: Valid Polar Bearer access token.
        path: API path (e.g. ``"/v3/exercises/123"``).
        timeout: Request timeout in seconds.
        rate_limiter: Optional rate limiter; when provided, checks the
            app-level quota before making the request (fail-open).

    Returns:
        Parsed JSON dict, or None on error or rate-limited.
    """
    if rate_limiter is not None:
        allowed = await rate_limiter.check_and_increment()
        if not allowed:
            logger.warning("Polar rate limit reached, skipping: path=%s", path)
            return None

    url = f"{POLAR_API_BASE}{path}"
    try:
        async with httpx.AsyncClient(timeout=timeout) as client:
            resp = await client.get(
                url,
                headers={"Authorization": f"Bearer {access_token}"},
            )
            resp.raise_for_status()
            result = resp.json()
            # Update rate limit state from authoritative response headers.
            if rate_limiter is not None:
                await rate_limiter.update_from_headers(dict(resp.headers))
            return result
    except Exception:
        logger.exception("Polar API GET failed: path=%s", path)
        return None


def _get_rate_limiter() -> "PolarRateLimiter | None":
    """Return a PolarRateLimiter instance for task-level rate limiting.

    Uses a deferred import to avoid circular imports at module load time.
    Returns None on import failure so callers degrade gracefully.
    """
    try:
        from app.services.polar_rate_limiter import PolarRateLimiter  # noqa: PLC0415

        return PolarRateLimiter(redis_url=settings.redis_url)
    except Exception:
        return None


def _is_token_expired(integration: Integration) -> bool:
    """Check if the integration's access token is expired.

    Args:
        integration: Integration model instance.

    Returns:
        True if token is expired or missing.
    """
    expires_at = integration.token_expires_at
    if not expires_at:
        return True

    if hasattr(expires_at, "tzinfo"):
        if expires_at.tzinfo is None:
            expires_at = expires_at.replace(tzinfo=timezone.utc)
    else:
        # If it's a string or something unexpected, treat as expired
        return True

    return expires_at <= datetime.now(timezone.utc)


# ---------------------------------------------------------------------------
# Celery tasks
# ---------------------------------------------------------------------------


@celery_app.task(name="polar.sync_webhook", bind=True, max_retries=3)
def sync_polar_webhook_task(
    self,
    polar_user_id: int,
    event_type: str,
    entity_id: str | None = None,
    url: str | None = None,
    date: str | None = None,
) -> None:
    """Sync Polar data triggered by a webhook notification.

    Resolves the Zuralog user from polar_user_id in provider_metadata,
    then fetches the relevant data based on the event_type.

    Args:
        polar_user_id: Polar user ID from the webhook payload.
        event_type: Polar event type (e.g. ``"EXERCISE"``, ``"SLEEP"``).
        entity_id: Entity ID for EXERCISE events.
        url: Direct resource URL (optional, fallback for some events).
        date: Date string (YYYY-MM-DD) for date-scoped events.
    """
    logger.info(
        "sync_polar_webhook_task: polar_user_id=%s event_type=%s entity_id=%s date=%s",
        polar_user_id,
        event_type,
        entity_id,
        date,
    )

    async def _run() -> None:
        # Single-query lookup by provider_metadata JSON field to avoid
        # loading all active integrations into memory.
        async with async_session() as db:
            result = await db.execute(
                select(Integration).where(
                    Integration.provider == "polar",
                    Integration.is_active.is_(True),
                    cast(Integration.provider_metadata["polar_user_id"], String) == str(polar_user_id),
                )
            )
            target = result.scalar_one_or_none()

        if target is None:
            logger.warning(
                "sync_polar_webhook_task: no active integration for polar_user_id=%s",
                polar_user_id,
            )
            return

        if _is_token_expired(target):
            logger.warning(
                "sync_polar_webhook_task: token expired for user=%s, skipping",
                target.user_id,
            )
            return

        access_token = target.access_token

        # Dispatch fetch based on event_type
        if event_type == "EXERCISE" and entity_id:
            await _fetch_polar(access_token, f"/v3/exercises/{entity_id}")
        elif event_type == "SLEEP" and date:
            await _fetch_polar(access_token, f"/v3/users/sleep-data/{date}")
        elif event_type == "CONTINUOUS_HEART_RATE" and date:
            await _fetch_polar(access_token, f"/v3/users/continuous-heart-rate/{date}")
        elif event_type == "ACTIVITY_SUMMARY" and date:
            await _fetch_polar(access_token, f"/v3/users/activity-summary/{date}")
        elif event_type == "SLEEP_WISE_ALERTNESS":
            await _fetch_polar(access_token, "/v3/users/sleepwise-alertness")
        elif event_type == "SLEEP_WISE_CIRCADIAN_BEDTIME":
            await _fetch_polar(access_token, "/v3/users/sleepwise-circadian-bedtime")
        else:
            logger.info(
                "sync_polar_webhook_task: unhandled event_type=%s for user=%s",
                event_type,
                target.user_id,
            )
            return

        # Update last_synced_at in a fresh session (single targeted update).
        async with async_session() as db:
            result = await db.execute(
                select(Integration).where(
                    Integration.provider == "polar",
                    Integration.is_active.is_(True),
                    cast(Integration.provider_metadata["polar_user_id"], String) == str(polar_user_id),
                )
            )
            db_integration = result.scalar_one_or_none()
            if db_integration:
                db_integration.last_synced_at = datetime.now(timezone.utc)
            await db.commit()

    try:
        asyncio.run(_run())
    except Exception as exc:
        logger.exception(
            "sync_polar_webhook_task failed: polar_user_id=%s event_type=%s",
            polar_user_id,
            event_type,
        )
        sentry_sdk.capture_exception(exc)
        raise self.retry(exc=exc, countdown=60)


@celery_app.task(name="polar.sync_periodic")
def sync_polar_periodic_task() -> None:
    """Periodic sync: fetch recent data for all active Polar users (every 15 min).

    Fetches exercises, activity summaries, sleep, nightly recharge, and
    continuous HR for today and yesterday for every active integration.
    """
    logger.info("sync_polar_periodic_task: starting Polar periodic sync")

    async def _run() -> None:
        async with async_session() as db:
            result = await db.execute(
                select(Integration).where(
                    Integration.provider == "polar",
                    Integration.is_active.is_(True),
                )
            )
            integrations = result.scalars().all()

        logger.info("sync_polar_periodic_task: %d active Polar integrations", len(integrations))

        today = datetime.now(timezone.utc).date()
        yesterday = today - timedelta(days=1)
        today_str = today.isoformat()
        yesterday_str = yesterday.isoformat()

        # One shared rate limiter instance for the whole task run so counters
        # are consistent across all users within this invocation.
        rate_limiter = _get_rate_limiter()

        for integration in integrations:
            if _is_token_expired(integration):
                logger.info(
                    "sync_polar_periodic_task: token expired for user=%s, skipping",
                    integration.user_id,
                )
                continue

            access_token = integration.access_token

            async with async_session() as db:
                db_integration = None
                try:
                    result = await db.execute(
                        select(Integration).where(
                            Integration.provider == "polar",
                            Integration.is_active.is_(True),
                            Integration.user_id == integration.user_id,
                        )
                    )
                    db_integration = result.scalar_one_or_none()
                    if db_integration:
                        db_integration.sync_status = "syncing"
                    await db.commit()

                    # Fetch exercises (Polar returns last 30 days automatically)
                    await _fetch_polar(access_token, "/v3/exercises", rate_limiter=rate_limiter)

                    # Fetch per-day data for today and yesterday
                    for date_str in [today_str, yesterday_str]:
                        await _fetch_polar(
                            access_token, f"/v3/users/activity-summary/{date_str}", rate_limiter=rate_limiter
                        )
                        await _fetch_polar(access_token, f"/v3/users/sleep-data/{date_str}", rate_limiter=rate_limiter)
                        await _fetch_polar(
                            access_token, f"/v3/users/nightly-recharge/{date_str}", rate_limiter=rate_limiter
                        )
                        await _fetch_polar(
                            access_token, f"/v3/users/continuous-heart-rate/{date_str}", rate_limiter=rate_limiter
                        )

                    if db_integration:
                        db_integration.sync_status = "idle"
                        db_integration.last_synced_at = datetime.now(timezone.utc)
                        db_integration.sync_error = None
                    await db.commit()

                    logger.debug(
                        "sync_polar_periodic_task: user=%s synced successfully",
                        integration.user_id,
                    )

                except Exception as exc:
                    logger.exception(
                        "sync_polar_periodic_task: error for user=%s: %s",
                        integration.user_id,
                        exc,
                    )
                    if db_integration:
                        db_integration.sync_status = "error"
                        db_integration.sync_error = str(exc)[:500]
                    try:
                        await db.commit()
                    except Exception:
                        logger.exception(
                            "sync_polar_periodic_task: failed to commit error state for user=%s",
                            integration.user_id,
                        )
                    sentry_sdk.capture_exception(exc)

    try:
        asyncio.run(_run())
    except Exception as exc:
        logger.exception("sync_polar_periodic_task failed")
        sentry_sdk.capture_exception(exc)


@celery_app.task(name="polar.monitor_token_expiry")
def monitor_polar_token_expiry_task() -> None:
    """Daily check for Polar tokens expiring within 30 days.

    Marks affected integrations as ``sync_status='expiring'`` and sends
    a push notification so the user can reconnect before the token expires.
    Polar tokens last approximately one year and cannot be refreshed.
    """
    logger.info("monitor_polar_token_expiry_task: checking for expiring Polar tokens")

    async def _run() -> None:
        now = datetime.now(timezone.utc)
        expiry_window = now + timedelta(days=30)

        async with async_session() as db:
            result = await db.execute(
                select(Integration).where(
                    Integration.provider == "polar",
                    Integration.is_active.is_(True),
                    Integration.token_expires_at <= expiry_window,
                    Integration.sync_status != "expiring",
                )
            )
            integrations = result.scalars().all()

        logger.info(
            "monitor_polar_token_expiry_task: %d integration(s) expiring within 30 days",
            len(integrations),
        )

        for integration in integrations:
            async with async_session() as db:
                result = await db.execute(
                    select(Integration).where(
                        Integration.provider == "polar",
                        Integration.is_active.is_(True),
                        Integration.user_id == integration.user_id,
                    )
                )
                db_integration = result.scalar_one_or_none()
                if db_integration:
                    db_integration.sync_status = "expiring"
                integration.sync_status = "expiring"
                await db.commit()

            # Best-effort push notification
            try:
                from app.services.push_service import PushService  # noqa: PLC0415

                push_service = PushService()
                await push_service.send_to_user(
                    user_id=integration.user_id,
                    title="Polar Connection Expiring",
                    body="Your Polar connection will expire soon. Please reconnect in the Integrations Hub.",
                    data={"action": "reconnect_polar"},
                )
                logger.info(
                    "monitor_polar_token_expiry_task: push notification sent for user=%s",
                    integration.user_id,
                )
            except Exception:
                logger.exception(
                    "monitor_polar_token_expiry_task: push notification failed for user=%s (best-effort)",
                    integration.user_id,
                )

    try:
        asyncio.run(_run())
    except Exception as exc:
        logger.exception("monitor_polar_token_expiry_task failed")
        sentry_sdk.capture_exception(exc)


@celery_app.task(name="polar.backfill", bind=True, max_retries=3)
def backfill_polar_data_task(self, user_id: str, days_back: int = 28) -> None:
    """28-day historical backfill for a newly connected Polar account.

    Fetches exercises (Polar returns last 30 days automatically) and
    per-day activity, sleep, nightly recharge, and continuous HR for
    each day in the backfill window. Called once on first OAuth connect.

    Args:
        user_id: Zuralog user ID to backfill data for.
        days_back: Number of days of history to fetch (default: 28).
    """
    logger.info(
        "backfill_polar_data_task: starting %d-day backfill for user=%s",
        days_back,
        user_id,
    )

    async def _run() -> None:
        async with async_session() as db:
            result = await db.execute(
                select(Integration).where(
                    Integration.user_id == user_id,
                    Integration.provider == "polar",
                    Integration.is_active.is_(True),
                )
            )
            integration = result.scalar_one_or_none()

        if integration is None:
            logger.warning(
                "backfill_polar_data_task: no active Polar integration for user=%s",
                user_id,
            )
            return

        if _is_token_expired(integration):
            logger.warning(
                "backfill_polar_data_task: token expired for user=%s, skipping",
                user_id,
            )
            return

        access_token = integration.access_token

        # Exercises — Polar returns last 30 days automatically
        await _fetch_polar(access_token, "/v3/exercises")

        # Per-day historical data
        today = datetime.now(timezone.utc).date()
        for i in range(days_back):
            day = today - timedelta(days=i)
            date_str = day.isoformat()
            try:
                await _fetch_polar(access_token, f"/v3/users/activity-summary/{date_str}")
            except Exception:
                logger.warning("backfill_polar_data_task: activity failed for user=%s date=%s", user_id, date_str)

            try:
                await _fetch_polar(access_token, f"/v3/users/sleep-data/{date_str}")
            except Exception:
                logger.warning("backfill_polar_data_task: sleep failed for user=%s date=%s", user_id, date_str)

            try:
                await _fetch_polar(access_token, f"/v3/users/nightly-recharge/{date_str}")
            except Exception:
                logger.warning(
                    "backfill_polar_data_task: nightly recharge failed for user=%s date=%s", user_id, date_str
                )

            try:
                await _fetch_polar(access_token, f"/v3/users/continuous-heart-rate/{date_str}")
            except Exception:
                logger.warning("backfill_polar_data_task: HR failed for user=%s date=%s", user_id, date_str)

        async with async_session() as db:
            result = await db.execute(
                select(Integration).where(
                    Integration.user_id == user_id,
                    Integration.provider == "polar",
                    Integration.is_active.is_(True),
                )
            )
            db_integration = result.scalar_one_or_none()
            if db_integration:
                db_integration.last_synced_at = datetime.now(timezone.utc)
            integration.last_synced_at = datetime.now(timezone.utc)
            await db.commit()

        logger.info(
            "backfill_polar_data_task: complete for user=%s days_back=%d",
            user_id,
            days_back,
        )

    try:
        asyncio.run(_run())
    except Exception as exc:
        logger.exception("backfill_polar_data_task failed for user=%s", user_id)
        sentry_sdk.capture_exception(exc)
        raise self.retry(exc=exc, countdown=120)


@celery_app.task(name="polar.create_webhook")
def create_polar_webhook_task() -> None:
    """Register a Polar webhook for all supported event types.

    Uses Basic auth (client credentials) since Polar webhooks are
    per-client — one webhook covers all users. Only creates the webhook
    if one does not already exist.

    Called once on application startup or when the webhook is missing.
    The ``signature_secret_key`` from the response must be saved as
    ``POLAR_WEBHOOK_SIGNATURE_KEY`` in the environment.
    """
    logger.info("create_polar_webhook_task: checking Polar webhook status")

    async def _run() -> None:
        if not settings.polar_client_id:
            logger.info("create_polar_webhook_task: polar_client_id not configured, skipping")
            return

        auth_header = _basic_auth_header()
        api_base_url = settings.polar_api_base_url.rstrip("/")
        callback_url = f"{api_base_url}/api/v1/webhooks/polar"

        async with httpx.AsyncClient(timeout=20.0) as client:
            # Check if webhook already exists
            get_resp = await client.get(
                f"{POLAR_API_BASE}/v3/webhooks",
                headers={"Authorization": auth_header},
            )

            if get_resp.status_code == 200:
                webhook_data = get_resp.json()
                if webhook_data and webhook_data.get("id"):
                    logger.info(
                        "create_polar_webhook_task: webhook already exists (id=%s), skipping",
                        webhook_data.get("id"),
                    )
                    return
            else:
                logger.warning(
                    "create_polar_webhook_task: GET /v3/webhooks returned %d, proceeding to create",
                    get_resp.status_code,
                )

            # Create webhook
            post_resp = await client.post(
                f"{POLAR_API_BASE}/v3/webhooks",
                json={
                    "events": [
                        "EXERCISE",
                        "SLEEP",
                        "CONTINUOUS_HEART_RATE",
                        "SLEEP_WISE_ALERTNESS",
                        "SLEEP_WISE_CIRCADIAN_BEDTIME",
                        "ACTIVITY_SUMMARY",
                    ],
                    "url": callback_url,
                },
                headers={"Authorization": auth_header},
            )

            if post_resp.status_code in (200, 201):
                body = post_resp.json()
                signature_key = body.get("signature_secret_key", "")
                logger.warning(
                    "create_polar_webhook_task: webhook created (id=%s). "
                    "IMPORTANT: Save this as POLAR_WEBHOOK_SIGNATURE_KEY env var: %s",
                    body.get("id"),
                    signature_key,
                )
            else:
                logger.error(
                    "create_polar_webhook_task: failed to create webhook, status=%d body=%s",
                    post_resp.status_code,
                    post_resp.text[:500],
                )

    try:
        asyncio.run(_run())
    except Exception as exc:
        logger.exception("create_polar_webhook_task failed")
        sentry_sdk.capture_exception(exc)


@celery_app.task(name="polar.check_webhook_status")
def check_polar_webhook_status_task() -> None:
    """Daily check that the Polar webhook is still active.

    Polar webhooks auto-deactivate after 7 consecutive days of delivery
    failures. This task re-activates the webhook when deactivation is
    detected. Runs as a Celery Beat task every 24 hours.
    """
    logger.info("check_polar_webhook_status_task: checking Polar webhook health")

    async def _run() -> None:
        if not settings.polar_client_id:
            logger.info("check_polar_webhook_status_task: polar_client_id not configured, skipping")
            return

        auth_header = _basic_auth_header()

        async with httpx.AsyncClient(timeout=20.0) as client:
            get_resp = await client.get(
                f"{POLAR_API_BASE}/v3/webhooks",
                headers={"Authorization": auth_header},
            )

            if get_resp.status_code != 200:
                logger.warning(
                    "check_polar_webhook_status_task: GET /v3/webhooks returned %d",
                    get_resp.status_code,
                )
                return

            webhook_data = get_resp.json()
            if not webhook_data:
                logger.info("check_polar_webhook_status_task: no webhook configured")
                return

            webhook_id = webhook_data.get("id")
            is_active = webhook_data.get("active", True)

            if is_active:
                logger.info(
                    "check_polar_webhook_status_task: webhook id=%s is active, no action needed",
                    webhook_id,
                )
                return

            if not webhook_id:
                logger.warning("check_polar_webhook_status_task: webhook found but has no id, cannot reactivate")
                return

            # Re-activate the deactivated webhook
            logger.warning(
                "check_polar_webhook_status_task: webhook id=%s is inactive, attempting re-activation",
                webhook_id,
            )
            activate_resp = await client.post(
                f"{POLAR_API_BASE}/v3/webhooks/{webhook_id}/activate",
                headers={"Authorization": auth_header},
            )

            if activate_resp.status_code in (200, 201):
                logger.info(
                    "check_polar_webhook_status_task: webhook id=%s re-activated successfully",
                    webhook_id,
                )
            else:
                logger.error(
                    "check_polar_webhook_status_task: re-activation failed for webhook id=%s, status=%d",
                    webhook_id,
                    activate_resp.status_code,
                )

    try:
        asyncio.run(_run())
    except Exception as exc:
        logger.exception("check_polar_webhook_status_task failed")
        sentry_sdk.capture_exception(exc)
