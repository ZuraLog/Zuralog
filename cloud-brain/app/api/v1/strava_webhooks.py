"""
Zuralog Cloud Brain — Strava Webhook Handler.

Handles Strava's real-time event push notifications for activities.
Two endpoints:
- GET  /webhooks/strava  — Strava subscription validation challenge
- POST /webhooks/strava  — Incoming activity event (create/update/delete)
"""

import logging
from typing import Any

from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel

from app.config import settings

logger = logging.getLogger(__name__)

router = APIRouter(tags=["strava-webhooks"])


class StravaWebhookEvent(BaseModel):
    """Strava webhook event payload.

    Sent by Strava when an activity is created, updated, or deleted.
    """

    object_type: str
    aspect_type: str
    object_id: int
    owner_id: int
    subscription_id: int
    event_time: int
    updates: dict[str, Any] | None = None


@router.get("/webhooks/strava")
async def strava_webhook_validation(
    hub_mode: str = Query(alias="hub.mode", default=""),
    hub_verify_token: str = Query(alias="hub.verify_token", default=""),
    hub_challenge: str = Query(alias="hub.challenge", default=""),
) -> dict[str, str]:
    """Respond to Strava's webhook subscription validation challenge.

    Strava sends a GET request with hub.mode, hub.verify_token, and
    hub.challenge. We must verify the token and echo back the challenge.

    Args:
        hub_mode: Should be "subscribe".
        hub_verify_token: Must match our configured verify token.
        hub_challenge: Random string from Strava to echo back.

    Returns:
        JSON with ``{"hub.challenge": "<challenge>"}`` on success.

    Raises:
        HTTPException: 403 if verify_token does not match.
    """
    if not settings.strava_webhook_verify_token:
        raise HTTPException(status_code=503, detail="Webhook not configured")

    if hub_mode != "subscribe":
        raise HTTPException(status_code=400, detail="Invalid hub.mode")

    if hub_verify_token != settings.strava_webhook_verify_token:
        logger.warning(
            "Strava webhook validation rejected: token mismatch (received=%r, expected=%r)",
            hub_verify_token,
            settings.strava_webhook_verify_token,
        )
        raise HTTPException(status_code=403, detail="Invalid verify token")

    logger.info("Strava webhook subscription validated (mode=%s)", hub_mode)
    return {"hub.challenge": hub_challenge}


@router.post("/webhooks/strava")
async def strava_webhook_event(event: StravaWebhookEvent) -> dict[str, bool]:
    """Handle incoming Strava activity event.

    Strava pushes events here when a user's activity is created,
    updated, or deleted. We acknowledge immediately (200) and process
    asynchronously to avoid Strava's 2-second timeout.

    Args:
        event: The parsed Strava webhook event payload.

    Returns:
        ``{"received": True}`` on success.
    """
    logger.info(
        "Strava webhook event: object_type=%s aspect_type=%s object_id=%d owner_id=%d",
        event.object_type,
        event.aspect_type,
        event.object_id,
        event.owner_id,
    )

    # TODO(dev): Trigger async task to process the event
    # e.g., sync the specific activity for the owner's account
    # For now, log and acknowledge immediately.

    return {"received": True}
