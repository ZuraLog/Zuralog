"""
Zuralog Cloud Brain — Fitbit Webhook Handler.

Handles Fitbit's real-time push notifications for health data changes.
Two endpoints:
- GET  /webhooks/fitbit  — Fitbit subscriber verification handshake
- POST /webhooks/fitbit  — Incoming collection change notification

Fitbit's push model differs from Strava:
- Verification uses a simple ``?verify=<code>`` query param; respond 204 on
  match or 404 on mismatch.
- Event payloads are JSON arrays of notification objects, one per changed
  collection (activities, sleep, body, foods).
- The handler MUST respond with HTTP 204 within 5 seconds. Data fetching
  is NEVER done synchronously — tasks are dispatched to Celery instead.
- Parse errors and any internal issues must NEVER propagate a non-204
  status back to Fitbit; always swallow and log.
"""

import logging

import sentry_sdk
from fastapi import APIRouter, Depends, Request
from fastapi.responses import Response
from pydantic import BaseModel, ValidationError

from app.config import settings

logger = logging.getLogger(__name__)


async def _set_sentry_module() -> None:
    sentry_sdk.set_tag("api.module", "fitbit_webhooks")


router = APIRouter(
    tags=["fitbit-webhooks"],
    dependencies=[Depends(_set_sentry_module)],
)


class FitbitWebhookNotification(BaseModel):
    """A single Fitbit push notification object.

    Fitbit sends an array of these when a collection changes for any
    subscribed user.

    Attributes:
        collectionType: The type of data that changed (e.g. "activities",
            "sleep", "body", "foods").
        date: The date of the change in ``YYYY-MM-DD`` format.
        ownerId: The Fitbit user ID that owns the changed data.
        ownerType: Always ``"user"`` for user-level subscriptions.
        subscriptionId: The subscription ID we registered with Fitbit.
    """

    collectionType: str
    date: str
    ownerId: str
    ownerType: str
    subscriptionId: str


@router.get("/webhooks/fitbit")
async def fitbit_webhook_verification(request: Request) -> Response:
    """Respond to Fitbit's webhook subscriber verification handshake.

    Fitbit sends ``GET /webhooks/fitbit?verify=<code>`` to confirm that
    the subscriber endpoint is under our control. We must respond with:
    - HTTP 204 (no body) if ``verify`` matches our configured code.
    - HTTP 404 (no body) if ``verify`` does not match.

    Args:
        request: FastAPI request used to read the ``verify`` query param.

    Returns:
        HTTP 204 on match; HTTP 404 on mismatch.
    """
    verify_code = request.query_params.get("verify", "")
    expected = settings.fitbit_webhook_verify_code

    if verify_code == expected:
        logger.info("Fitbit webhook subscriber verified successfully")
        return Response(status_code=204)

    logger.warning(
        "Fitbit webhook verification failed: received=%r, expected code does not match",
        verify_code,
    )
    return Response(status_code=404)


@router.post("/webhooks/fitbit")
async def fitbit_webhook_event(request: Request) -> Response:
    """Handle incoming Fitbit collection change notifications.

    Fitbit pushes a JSON array of :class:`FitbitWebhookNotification` objects
    whenever subscribed health data changes. We MUST respond within 5 seconds,
    so data fetching is deferred entirely to Celery tasks.

    Parse errors and any internal errors are logged but NEVER surfaced to
    Fitbit — we always respond 204 to prevent Fitbit from retrying or
    marking the subscription as failing.

    Args:
        request: FastAPI request; body is a JSON array of notification objects.

    Returns:
        HTTP 204 (no body) always — even on parse/dispatch errors.
    """
    try:
        body = await request.json()
    except Exception as exc:  # noqa: BLE001
        logger.error("Fitbit webhook: failed to parse JSON body: %s", exc)
        sentry_sdk.capture_exception(exc)
        return Response(status_code=204)

    if not isinstance(body, list):
        logger.error(
            "Fitbit webhook: expected JSON array, got %s",
            type(body).__name__,
        )
        return Response(status_code=204)

    for raw_notification in body:
        try:
            notification = FitbitWebhookNotification.model_validate(raw_notification)
        except ValidationError as exc:
            logger.error(
                "Fitbit webhook: invalid notification object %r: %s",
                raw_notification,
                exc,
            )
            continue

        try:
            # Lazy import to avoid circular imports at module load time.
            from app.tasks.fitbit_sync import sync_fitbit_collection_task  # noqa: PLC0415

            sync_fitbit_collection_task.delay(
                notification.ownerId,
                notification.collectionType,
                notification.date,
            )
            logger.info(
                "Dispatched sync_fitbit_collection_task: owner=%s collection=%s date=%s",
                notification.ownerId,
                notification.collectionType,
                notification.date,
            )
        except Exception as exc:  # noqa: BLE001
            logger.error(
                "Fitbit webhook: failed to dispatch task for owner=%s collection=%s: %s",
                notification.ownerId,
                notification.collectionType,
                exc,
            )
            sentry_sdk.capture_exception(exc)

    analytics = getattr(request.app.state, "analytics_service", None)
    if analytics:
        for raw_notif in body if isinstance(body, list) else []:
            owner_id = raw_notif.get("ownerId", "unknown") if isinstance(raw_notif, dict) else "unknown"
            collection_type = raw_notif.get("collectionType", "unknown") if isinstance(raw_notif, dict) else "unknown"
            try:
                analytics.capture(
                    distinct_id=f"fitbit:{owner_id}",  # Fitbit owner_id; no Zuralog user_id in webhook context
                    event="webhook_received",
                    properties={
                        "provider": "fitbit",
                        "event_type": collection_type,
                        "processed": True,
                    },
                )
            except Exception:  # noqa: BLE001
                pass  # Never let analytics break the 204 response

    # CRITICAL: Always return 204 — never let Fitbit see errors
    return Response(status_code=204)
