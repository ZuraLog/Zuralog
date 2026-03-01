"""
Zuralog Cloud Brain — Withings Integration Endpoints.

Exposes REST endpoints for initiating and completing the Withings OAuth 2.0
authorization code flow and managing the integration lifecycle.

Key architectural difference from other integrations:
  Withings validates the redirect URI at app registration time and requires it
  to be a real HTTPS URL — deep links like zuralog:// are not accepted as the
  redirect_uri. Therefore the callback is server-side:

  1. Mobile app calls GET /authorize → gets auth_url + state token
  2. App opens auth_url in system browser; user authorises
  3. Withings redirects browser to https://api.zuralog.com/.../callback?code=XXX&state=YYY
  4. Backend validates state (which carries user_id), exchanges code immediately
     (30-second window), persists tokens, then redirects browser to
     zuralog://oauth/withings?success=true so the app is brought back to focus.
"""

import logging
import secrets

import redis.asyncio as aioredis
import sentry_sdk
from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import RedirectResponse
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.auth import _get_auth_service
from app.config import settings
from app.database import get_db
from app.limiter import limiter
from app.services.auth_service import AuthService
from app.services.withings_token_service import WithingsTokenService

logger = logging.getLogger(__name__)


async def _set_sentry_module() -> None:
    sentry_sdk.set_tag("api.module", "withings")


router = APIRouter(
    prefix="/integrations/withings",
    tags=["withings"],
    dependencies=[Depends(_set_sentry_module)],
)
security = HTTPBearer()


@router.get("/authorize")
@limiter.limit("5/minute")
async def withings_authorize(
    request: Request,
    credentials: HTTPAuthorizationCredentials = Depends(security),
    auth_service: AuthService = Depends(_get_auth_service),
) -> dict[str, str]:
    """Return the Withings OAuth authorization URL for the mobile app to open.

    Stores state → user_id in Redis (not just "1" as with Oura) so the
    server-side /callback can resolve the user without a JWT.
    """
    user_data = await auth_service.get_user(credentials.credentials)
    user_id = user_data["id"]

    withings_token_service: WithingsTokenService = request.app.state.withings_token_service

    state = secrets.token_urlsafe(32)
    redis_client = aioredis.from_url(settings.redis_url)

    try:
        await withings_token_service.store_state(state, user_id, redis_client)
    finally:
        await redis_client.aclose()

    auth_url = withings_token_service.build_auth_url(state=state)

    return {"auth_url": auth_url, "state": state}


@router.get("/callback")
async def withings_callback(
    request: Request,
    code: str = "",
    state: str = "",
    error: str = "",
    db: AsyncSession = Depends(get_db),
) -> RedirectResponse:
    """Handle Withings OAuth callback (browser redirect from Withings).

    This endpoint is called by the Withings authorization server after the
    user grants consent. No JWT is present — user_id is resolved from the
    CSRF state stored in Redis during /authorize.

    On success: redirects browser to zuralog://oauth/withings?success=true
    On failure: redirects to zuralog://oauth/withings?success=false&error=<reason>
    """
    _failure_redirect = "zuralog://oauth/withings?success=false"

    # User-facing OAuth error (user denied access, etc.)
    if error:
        logger.warning("Withings OAuth error in callback: %s", error)
        return RedirectResponse(url=f"{_failure_redirect}&error={error}", status_code=302)

    if not code or not state:
        return RedirectResponse(url=f"{_failure_redirect}&error=missing_params", status_code=302)

    withings_token_service: WithingsTokenService = request.app.state.withings_token_service
    withings_signature_service = request.app.state.withings_signature_service

    redis_client = aioredis.from_url(settings.redis_url)
    try:
        user_id = await withings_token_service.validate_state(state, redis_client)
    finally:
        await redis_client.aclose()

    if not user_id:
        logger.warning("Withings callback: invalid or expired state='%s'", state)
        return RedirectResponse(url=f"{_failure_redirect}&error=invalid_state", status_code=302)

    try:
        token_response = await withings_token_service.exchange_code(
            code=code,
            signature_service=withings_signature_service,
            redirect_uri=settings.withings_redirect_uri,
        )
    except Exception as exc:
        logger.error("Withings token exchange failed for user '%s': %s", user_id, exc)
        return RedirectResponse(url=f"{_failure_redirect}&error=exchange_failed", status_code=302)

    await withings_token_service.save_tokens(db, user_id, token_response)

    # Trigger 30-day historical backfill and webhook subscriptions
    try:
        from app.tasks.withings_sync import (  # noqa: PLC0415
            backfill_withings_data_task,
            create_withings_webhook_subscriptions_task,
        )

        backfill_withings_data_task.delay(user_id=user_id, days_back=30)
        create_withings_webhook_subscriptions_task.delay(user_id=user_id)
    except Exception:
        logger.warning("Could not enqueue Withings post-connect tasks for user '%s'", user_id)

    logger.info("Withings connected for user '%s'", user_id)

    analytics = getattr(request.app.state, "analytics_service", None)
    if analytics:
        analytics.capture(
            distinct_id=user_id,
            event="withings_connected",
            properties={"provider": "withings"},
        )

    return RedirectResponse(url="zuralog://oauth/withings?success=true", status_code=302)


@router.get("/status")
async def withings_status(
    request: Request,
    credentials: HTTPAuthorizationCredentials = Depends(security),
    auth_service: AuthService = Depends(_get_auth_service),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Return Withings integration connection status for the current user."""
    user_data = await auth_service.get_user(credentials.credentials)
    user_id = user_data["id"]

    withings_token_service: WithingsTokenService = request.app.state.withings_token_service
    integration = await withings_token_service.get_integration(db, user_id)

    if integration is None or not integration.is_active:
        return {"connected": False}

    metadata: dict = integration.provider_metadata or {}

    return {
        "connected": True,
        "sync_status": integration.sync_status,
        "last_synced_at": (integration.last_synced_at.isoformat() if integration.last_synced_at else None),
        "withings_user_id": metadata.get("withings_user_id"),
        "granted_scopes": metadata.get("granted_scopes"),
    }


@router.delete("/disconnect")
async def withings_disconnect(
    request: Request,
    credentials: HTTPAuthorizationCredentials = Depends(security),
    auth_service: AuthService = Depends(_get_auth_service),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Disconnect the current user's Withings integration."""
    user_data = await auth_service.get_user(credentials.credentials)
    user_id = user_data["id"]

    withings_token_service: WithingsTokenService = request.app.state.withings_token_service
    disconnected = await withings_token_service.disconnect(db, user_id)

    analytics = getattr(request.app.state, "analytics_service", None)
    if analytics:
        analytics.capture(
            distinct_id=user_id,
            event="withings_disconnected",
            properties={"provider": "withings"},
        )

    return {"success": disconnected}
