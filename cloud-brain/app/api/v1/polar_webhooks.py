"""
Zuralog Cloud Brain — Polar AccessLink Webhook Receiver.

Receives event notifications from Polar AccessLink and dispatches Celery
sync tasks. Must respond 200 OK immediately — data fetching is deferred.

Polar webhook key facts:
- Single webhook per client (covers all registered users)
- HMAC-SHA256 signature in Polar-Webhook-Signature header
- Event type in Polar-Webhook-Event header
- JSON payload (not form-encoded)
- Always return 200 OK — Polar auto-deactivates after 7 days of failures
- PING event is sent when webhook is created (verify URL is live)

Events: EXERCISE, SLEEP, CONTINUOUS_HEART_RATE,
        SLEEP_WISE_ALERTNESS, SLEEP_WISE_CIRCADIAN_BEDTIME,
        ACTIVITY_SUMMARY, PING

Payload example:
  {
    "event": "EXERCISE",
    "user_id": 475,
    "entity_id": "aQlC83",
    "timestamp": "2018-05-15T14:22:24Z",
    "url": "https://www.polaraccesslink.com/v3/exercises/aQlC83"
  }
"""

import hashlib
import hmac as _hmac
import json
import logging

from fastapi import APIRouter, Request, Response

from app.config import settings

logger = logging.getLogger(__name__)

webhook_router = APIRouter(tags=["polar-webhooks"])


def _verify_signature(body: bytes, signature: str, secret_key: str) -> bool:
    """Verify HMAC-SHA256 signature of webhook payload."""
    expected = _hmac.new(
        secret_key.encode(),
        body,
        hashlib.sha256,
    ).hexdigest()
    return _hmac.compare_digest(expected, signature)


@webhook_router.post("/webhooks/polar")
async def polar_webhook_event(request: Request) -> Response:
    """Receive Polar AccessLink webhook notifications.

    Always returns 200 OK immediately. Dispatches Celery tasks for sync.
    Never lets processing errors prevent the 200 response.

    Polar sends JSON-encoded data with HMAC-SHA256 signature in the
    Polar-Webhook-Signature header and the event type in Polar-Webhook-Event.

    Authentication: HMAC-SHA256 signature verification using the shared
    webhook signature key configured in settings.polar_webhook_signature_key.
    When the key is not configured, signature verification is skipped.
    """
    body = await request.body()

    # Step 1: Verify HMAC-SHA256 signature if key is configured.
    # When a key is configured, the Polar-Webhook-Signature header is always
    # expected. An absent header is treated as a verification failure — the
    # payload is discarded (but we still return 200 to avoid triggering
    # Polar's 7-day auto-deactivation on consecutive non-200 responses).
    signature_key = settings.polar_webhook_signature_key
    if signature_key:
        signature = request.headers.get("Polar-Webhook-Signature", "")
        if not signature:
            logger.warning(
                "Polar webhook: signature key configured but Polar-Webhook-Signature header absent from %s — discarding",
                request.client.host if request.client else "unknown",
            )
            return Response(status_code=200)
        if not _verify_signature(body, signature, signature_key):
            logger.warning(
                "Polar webhook: invalid HMAC-SHA256 signature from %s",
                request.client.host if request.client else "unknown",
            )
            # Always return 200 — never trigger Polar's auto-deactivation
            # due to repeated non-200 responses from signature failures.
            return Response(status_code=200)

    # Step 2: Get event type from header.
    event_type = request.headers.get("Polar-Webhook-Event", "")

    # Step 3: Parse JSON body.
    try:
        payload = json.loads(body) if body else {}
    except (json.JSONDecodeError, ValueError):
        logger.warning(
            "Polar webhook: malformed JSON body (event_type=%s), ignoring",
            event_type,
        )
        return Response(status_code=200)

    # Step 4: Handle PING event — just acknowledge, no task.
    if event_type == "PING" or payload.get("event") == "PING":
        logger.info("Polar webhook: received PING event (webhook URL confirmed live)")
        return Response(status_code=200)

    # Step 5: Extract fields from payload.
    user_id = payload.get("user_id")
    entity_id = payload.get("entity_id")
    event = payload.get("event", event_type)
    url = payload.get("url")
    date = payload.get("date")

    # Step 6: Require user_id to proceed.
    if not user_id:
        logger.warning(
            "Polar webhook: missing user_id in payload (event=%s entity_id=%s), skipping",
            event,
            entity_id,
        )
        return Response(status_code=200)

    # Step 7: Dispatch Celery task for async processing.
    try:
        from app.tasks.polar_sync import sync_polar_webhook_task  # noqa: PLC0415

        sync_polar_webhook_task.delay(
            polar_user_id=user_id,
            event_type=event,
            entity_id=entity_id,
            url=url,
            date=date,
        )
    except Exception:
        logger.exception("Failed to enqueue Polar webhook sync task")

    logger.info(
        "Polar webhook received: user_id=%s event=%s entity_id=%s",
        user_id,
        event,
        entity_id,
    )

    return Response(status_code=200)
