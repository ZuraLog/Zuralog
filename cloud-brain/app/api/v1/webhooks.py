"""
Zuralog Cloud Brain — Webhook Handlers.

Receives and processes server-to-server notifications from
RevenueCat for subscription lifecycle events.
"""

import hmac
import logging

import sentry_sdk
from fastapi import APIRouter, Depends, Header, HTTPException, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.database import get_db
from app.services.subscription_service import SubscriptionService

logger = logging.getLogger(__name__)


async def _set_sentry_module() -> None:
    sentry_sdk.set_tag("api.module", "webhooks")


router = APIRouter(
    prefix="/webhooks",
    tags=["webhooks"],
    dependencies=[Depends(_set_sentry_module)],
)


@router.post("/revenuecat")
async def revenuecat_webhook(
    request: Request,
    authorization: str | None = Header(None),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Handle RevenueCat subscription lifecycle events.

    Validates the shared secret from the Authorization header,
    parses the event payload, and delegates processing to
    the SubscriptionService.

    RevenueCat sends events for: INITIAL_PURCHASE, RENEWAL,
    CANCELLATION, UNCANCELLATION, EXPIRATION, BILLING_ISSUE,
    PRODUCT_CHANGE, TRANSFER.

    Args:
        request: The incoming FastAPI request.
        authorization: The Authorization header (Bearer <secret>).
        db: Injected async database session.

    Returns:
        A confirmation dict acknowledging receipt.

    Raises:
        HTTPException: 403 if the authorization secret is invalid.
        HTTPException: 400 if the request body is not valid JSON.
    """
    expected = f"Bearer {settings.revenuecat_webhook_secret}"
    if not authorization or not hmac.compare_digest(authorization, expected):
        logger.warning("RevenueCat webhook: invalid authorization")
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Invalid webhook authorization",
        )

    try:
        payload = await request.json()
    except Exception:
        logger.warning("RevenueCat webhook: malformed JSON payload")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid JSON payload",
        )

    event = payload.get("event", {})

    event_type = event.get("type", "UNKNOWN")
    app_user_id = event.get("app_user_id", "")
    expiration_at_ms = event.get("expiration_at_ms")
    product_id = event.get("product_id", "")

    logger.info(
        "RevenueCat webhook: type=%s user=%s product=%s",
        event_type,
        app_user_id,
        product_id,
    )

    service = SubscriptionService()
    await service.process_event(
        db=db,
        event_type=event_type,
        app_user_id=app_user_id,
        expiration_at_ms=expiration_at_ms,
        product_id=product_id,
    )

    analytics = getattr(request.app.state, "analytics_service", None)
    if analytics and app_user_id:  # Only capture when we have a real user
        try:
            analytics.capture(
                distinct_id=app_user_id,
                event="subscription_changed",
                properties={
                    "plan": product_id if product_id else "unknown",
                    "change_type": event_type if event_type else "unknown",
                },
            )
        except Exception:
            logger.warning("PostHog subscription_changed capture failed", exc_info=True)

    return {"received": True}
