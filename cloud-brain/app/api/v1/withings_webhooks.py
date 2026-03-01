"""
Zuralog Cloud Brain — Withings Webhook Receiver.

Receives data change notifications from Withings and dispatches Celery
sync tasks. Must respond 200 OK immediately — data fetching is deferred.

Withings webhook differences from other integrations:
- Payload is form-encoded POST (NOT JSON)
- Fields: userid, appli, startdate, enddate, date
- Always return 200 OK immediately; Withings retries up to 10 times with
  exponential backoff. Auto-cancel after 20 days of continuous failure.
- Subscriptions are per-user (not per-app like Oura)

Appli codes:
  1  = weight / body composition  (getmeas: 1,5,6,8,76,77,88,91)
  2  = temperature                (getmeas: 12,71,73)
  4  = blood pressure / SpO2      (getmeas: 9,10,11,54)
  16 = activity                   (getactivity)
  44 = sleep                      (getsummary)
  54 = ECG                        (heart/list)
  62 = HRV                        (getmeas: 135)
"""

import hmac
import logging

from fastapi import APIRouter, Request, Response

from app.config import settings

logger = logging.getLogger(__name__)

webhook_router = APIRouter(tags=["withings-webhooks"])


@webhook_router.post("/webhooks/withings")
async def withings_webhook_event(request: Request) -> Response:
    """Receive Withings webhook notifications.

    Always returns 200 OK immediately. Dispatches Celery tasks for sync.
    Never lets processing errors prevent the 200 response.

    Withings sends form-encoded data, not JSON.

    Authentication: Withings does not sign webhook payloads with HMAC.
    We use a shared secret in the callback URL query string
    (?token=...) as the standard defence against spoofed requests.
    """
    # Validate shared secret to reject unauthenticated requests.
    # Withings does not support payload signing, so the secret is a
    # query parameter registered in the subscription callback URL.
    expected_secret = settings.withings_webhook_secret
    if expected_secret:
        received_token = request.query_params.get("token", "")
        if not hmac.compare_digest(received_token, expected_secret):
            logger.warning(
                "Withings webhook: invalid or missing token from %s",
                request.client.host if request.client else "unknown",
            )
            # Always return 200 to Withings so it doesn't retry unauthenticated
            # requests indefinitely. The task is simply not enqueued.
            return Response(status_code=200)

    try:
        form_data = await request.form()
        withings_user_id = str(form_data.get("userid", ""))
        appli = form_data.get("appli", "")
        startdate = form_data.get("startdate", "")
        enddate = form_data.get("enddate", "")
        date_str = str(form_data.get("date", ""))

        logger.info(
            "Withings webhook received: userid=%s appli=%s startdate=%s enddate=%s",
            withings_user_id,
            appli,
            startdate,
            enddate,
        )

        if withings_user_id and appli:
            try:
                from app.tasks.withings_sync import sync_withings_notification_task  # noqa: PLC0415

                sync_withings_notification_task.delay(
                    withings_user_id=withings_user_id,
                    appli=int(appli),
                    startdate=int(startdate) if startdate else None,
                    enddate=int(enddate) if enddate else None,
                    date_str=date_str,
                )
            except Exception:
                logger.exception("Failed to enqueue Withings webhook sync task")

    except Exception:
        logger.exception("Error processing Withings webhook body (still returning 200)")

    return Response(status_code=200)


@webhook_router.get("/webhooks/withings")
async def withings_webhook_verify(request: Request) -> Response:
    """Handle GET requests to the webhook URL.

    Withings may send a GET request to verify the endpoint is reachable
    during subscription creation. Return 200 OK.
    """
    return Response(status_code=200)
