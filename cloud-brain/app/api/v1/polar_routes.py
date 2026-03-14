"""
Zuralog Cloud Brain — Polar AccessLink Integration Endpoints.

Exposes REST endpoints for initiating and completing the Polar OAuth 2.0
authorization code flow and managing the integration lifecycle.

Flow:
  1. Mobile app calls GET /authorize → gets auth_url + state token
  2. App opens auth_url in system browser; user authorises
  3. Polar redirects to zuralog://oauth/polar?code=XXX&state=YYY
  4. App intercepts deep link and calls POST /exchange with code + state
  5. Backend validates state, exchanges code for tokens, registers user
     with Polar AccessLink (mandatory), persists tokens, triggers
     30-day backfill, and dispatches webhook creation task.

Key Polar differences from Oura:
  - No PKCE
  - No refresh tokens (~1 year access token)
  - Mandatory POST /v3/users registration after OAuth
  - Token exchange uses Basic auth (not body credentials)
  - State stores user_id (not just '1') for callback identification
"""

import logging
import secrets

import httpx
import sentry_sdk
import redis.asyncio as aioredis
from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import _get_auth_service
from app.config import settings
from app.database import get_db
from app.limiter import limiter
from app.services.auth_service import AuthService
from app.services.polar_token_service import PolarTokenService

logger = logging.getLogger(__name__)


async def _set_sentry_module() -> None:
    sentry_sdk.set_tag("api.module", "polar")


router = APIRouter(
    prefix="/integrations/polar",
    tags=["polar"],
    dependencies=[Depends(_set_sentry_module)],
)
security = HTTPBearer()


@router.get("/authorize")
@limiter.limit("5/minute")
async def polar_authorize(
    request: Request,
    credentials: HTTPAuthorizationCredentials = Depends(security),
    auth_service: AuthService = Depends(_get_auth_service),
) -> dict[str, str]:
    """Return the Polar OAuth authorization URL for the mobile app to open."""
    user_data = await auth_service.get_user(credentials.credentials)
    user_id = user_data["id"]

    polar_token_service: PolarTokenService = request.app.state.polar_token_service

    state = secrets.token_urlsafe(32)
    redis_client = aioredis.from_url(settings.redis_url)

    try:
        await polar_token_service.store_state(state, user_id, redis_client)
    finally:
        await redis_client.aclose()

    auth_url = polar_token_service.build_auth_url(state=state)

    return {"auth_url": auth_url, "state": state}


@router.post("/exchange")
@limiter.limit("10/minute")
async def polar_exchange(
    request: Request,
    code: str,
    state: str,
    credentials: HTTPAuthorizationCredentials = Depends(security),
    auth_service: AuthService = Depends(_get_auth_service),
    db: AsyncSession = Depends(get_db),
) -> dict[str, object]:
    """Exchange a Polar authorization code for an access token.

    The user ID is always derived from the verified JWT — never accepted as a
    caller-supplied parameter — to prevent IDOR attacks where an authenticated
    user could store tokens under a different account.

    The state token encodes the user_id to prevent cross-user state replay.
    """
    # user_id is always derived from the JWT, never from the request body/params.
    user_data = await auth_service.get_user(credentials.credentials)
    user_id = user_data["id"]

    polar_token_service: PolarTokenService = request.app.state.polar_token_service

    redis_client = aioredis.from_url(settings.redis_url)
    try:
        state_user_id = await polar_token_service.validate_state(state, redis_client)
    finally:
        await redis_client.aclose()

    if not state_user_id:
        raise HTTPException(status_code=400, detail="Invalid or expired state")

    # IDOR prevention: state must have been issued for this exact user
    if state_user_id != user_id:
        logger.warning(
            "Polar state user_id mismatch: state has '%s', JWT has '%s'",
            state_user_id,
            user_id,
        )
        raise HTTPException(status_code=400, detail="Invalid or expired state")

    try:
        token_response = await polar_token_service.exchange_code(code=code)
    except httpx.HTTPStatusError as exc:
        # Log full Polar response server-side; never reflect it to the caller
        # (it can contain OAuth error details, echoed client_id, etc.)
        logger.error(
            "Polar token exchange failed (%d) for user '%s': %s",
            exc.response.status_code,
            user_id,
            exc.response.text,
        )
        raise HTTPException(status_code=400, detail="Polar token exchange failed") from exc
    except httpx.RequestError as exc:
        logger.error("Could not reach Polar API for user '%s': %s", user_id, exc)
        raise HTTPException(status_code=503, detail="Could not reach Polar API") from exc

    # Register user with Polar AccessLink — mandatory step after OAuth.
    # Best-effort: swallow any exception and use empty dict on failure.
    access_token: str = token_response.get("access_token", "")
    try:
        user_info = await polar_token_service.register_user(
            access_token=access_token,
            member_id=user_id,
        )
    except Exception:
        logger.warning("Polar user registration failed for user '%s' (best-effort, continuing)", user_id)
        user_info = {}

    await polar_token_service.save_tokens(db, user_id, token_response, user_info)

    # Trigger 30-day historical backfill and webhook creation
    try:
        from app.tasks.polar_sync import backfill_polar_data_task, create_polar_webhook_task  # noqa: PLC0415

        backfill_polar_data_task.delay(user_id=user_id)
        create_polar_webhook_task.delay()
    except Exception:
        logger.warning("Could not enqueue Polar post-connect tasks for user '%s'", user_id)

    polar_user_id = token_response.get("x_user_id")
    logger.info("Polar connected for user '%s' (polar_user_id=%s)", user_id, polar_user_id)

    analytics = getattr(request.app.state, "analytics_service", None)
    if analytics:
        analytics.capture(
            distinct_id=user_id,
            event="integration_connected",
            properties={"provider": "polar"},
        )

    return {"success": True, "polar_user_id": polar_user_id}


@router.get("/status")
async def polar_status(
    request: Request,
    credentials: HTTPAuthorizationCredentials = Depends(security),
    auth_service: AuthService = Depends(_get_auth_service),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Return Polar integration connection status for the current user."""
    user_data = await auth_service.get_user(credentials.credentials)
    user_id = user_data["id"]

    polar_token_service: PolarTokenService = request.app.state.polar_token_service
    integration = await polar_token_service.get_integration(db, user_id)

    if integration is None or not integration.is_active:
        return {"connected": False}

    return {
        "connected": True,
        "sync_status": integration.sync_status,
        "last_synced_at": (integration.last_synced_at.isoformat() if integration.last_synced_at else None),
        "token_expires_at": (integration.token_expires_at.isoformat() if integration.token_expires_at else None),
        "polar_user_id": (integration.provider_metadata or {}).get("polar_user_id"),
    }


@router.delete("/disconnect")
async def polar_disconnect(
    request: Request,
    credentials: HTTPAuthorizationCredentials = Depends(security),
    auth_service: AuthService = Depends(_get_auth_service),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Disconnect the current user's Polar integration."""
    user_data = await auth_service.get_user(credentials.credentials)
    user_id = user_data["id"]

    polar_token_service: PolarTokenService = request.app.state.polar_token_service
    disconnected = await polar_token_service.disconnect(db, user_id)

    analytics = getattr(request.app.state, "analytics_service", None)
    if analytics:
        analytics.capture(
            distinct_id=user_id,
            event="integration_disconnected",
            properties={"provider": "polar"},
        )

    return {"success": disconnected}
