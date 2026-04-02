"""
Zuralog Cloud Brain — Oura Ring Webhook Receiver.

Receives data change notifications from Oura and dispatches Celery
sync tasks. Must respond 200 OK immediately — data fetching is deferred.

Oura webhook differences from Fitbit:
- No per-delivery authentication headers. Oura authenticates using
  ``x-client-id`` + ``x-client-secret`` only during subscription
  **creation** (via the Oura API). Webhook delivery events do not carry
  auth headers — Oura's security model relies on the subscription URL
  being kept private.
- Subscriptions are per-app (not per-user).
- Subscriptions expire — renewal handled by a daily Celery beat task.

Oura webhook payload format:
  {
    "event_type": "create" | "update" | "delete",
    "data_type": "daily_sleep" | "sleep" | "daily_activity" | ...,
    "object_id": "<string>",
    "user_id": "<oura_user_id>"
  }
"""

import hmac
import logging

from fastapi import APIRouter, Request, Response

from app.config import settings

logger = logging.getLogger(__name__)

webhook_router = APIRouter(tags=["oura-webhooks"])


@webhook_router.post("/webhooks/oura/{path_token}")
async def oura_webhook_event(request: Request, path_token: str) -> Response:
    """Receive Oura webhook notifications.

    Always returns 200 OK immediately. Dispatches Celery tasks for sync.
    Never lets processing errors prevent the 200 response.

    Authentication: Oura does not sign webhook deliveries. Security relies on
    the URL being kept private. We embed a configurable secret token in the
    path to make the URL hard to guess. Returns 404 (not 401) on mismatch to
    avoid confirming the endpoint exists.
    """
    expected = settings.oura_webhook_path_token
    if expected and not hmac.compare_digest(path_token, expected):
        logger.warning("Oura webhook: invalid path token, rejecting request")
        return Response(status_code=404)  # 404 — don't confirm endpoint exists
    try:
        body = await request.json()
        logger.info(
            "Oura webhook received: event_type=%s data_type=%s",
            body.get("event_type"),
            body.get("data_type"),
        )

        data_type = body.get("data_type", "")
        event_type = body.get("event_type", "")
        oura_user_id = body.get("user_id", "")

        if data_type and event_type:
            try:
                from app.tasks.oura_sync import sync_oura_webhook_task  # noqa: PLC0415

                sync_oura_webhook_task.delay(
                    data_type=data_type,
                    event_type=event_type,
                    oura_user_id=oura_user_id,
                )
            except Exception:
                logger.exception("Failed to enqueue Oura webhook sync task")

    except Exception:
        logger.exception("Error processing Oura webhook body (still returning 200)")

    return Response(status_code=200)
