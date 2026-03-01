"""
Zuralog Cloud Brain — Oura Ring Integration Endpoints.

Exposes REST endpoints for initiating and completing the Oura OAuth 2.0
authorization code flow (no PKCE) and managing the integration lifecycle.

Flow:
  1. Mobile app calls GET /authorize → gets auth_url + state token
  2. App opens auth_url in system browser; user authorises
  3. Oura redirects to zuralog://oauth/oura?code=XXX&state=YYY
  4. App intercepts deep link and calls POST /exchange with code + state
  5. Backend validates state, exchanges code for tokens, persists them
     under the authenticated user's ID (from JWT — never from caller),
     triggers 90-day backfill, and returns the Oura user ID.
"""

import logging
import secrets

import httpx
import sentry_sdk
import redis.asyncio as aioredis
from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.auth import _get_auth_service
from app.config import settings
from app.database import get_db
from app.limiter import limiter
from app.services.auth_service import AuthService
from app.services.oura_token_service import OuraTokenService

logger = logging.getLogger(__name__)


async def _set_sentry_module() -> None:
    sentry_sdk.set_tag("api.module", "oura")


router = APIRouter(
    prefix="/integrations/oura",
    tags=["oura"],
    dependencies=[Depends(_set_sentry_module)],
)
security = HTTPBearer()


@router.get("/authorize")
@limiter.limit("5/minute")
async def oura_authorize(
    request: Request,
    credentials: HTTPAuthorizationCredentials = Depends(security),
    auth_service: AuthService = Depends(_get_auth_service),
) -> dict[str, str]:
    """Return the Oura OAuth authorization URL for the mobile app to open."""
    await auth_service.get_user(credentials.credentials)

    oura_token_service: OuraTokenService = request.app.state.oura_token_service

    state = secrets.token_urlsafe(32)
    redis_client = aioredis.from_url(settings.redis_url)

    try:
        await oura_token_service.store_state(state, redis_client)
    finally:
        await redis_client.aclose()

    auth_url = oura_token_service.build_auth_url(state=state)

    return {"auth_url": auth_url, "state": state}


@router.post("/exchange")
@limiter.limit("10/minute")
async def oura_exchange(
    request: Request,
    code: str,
    state: str,
    credentials: HTTPAuthorizationCredentials = Depends(security),
    auth_service: AuthService = Depends(_get_auth_service),
    db: AsyncSession = Depends(get_db),
) -> dict[str, object]:
    """Exchange an Oura authorization code for access and refresh tokens.

    The user ID is always derived from the verified JWT — never accepted as a
    caller-supplied parameter — to prevent IDOR attacks where an authenticated
    user could store tokens under a different account.
    """
    # user_id is always derived from the JWT, never from the request body/params.
    user_data = await auth_service.get_user(credentials.credentials)
    user_id = user_data["id"]

    oura_token_service: OuraTokenService = request.app.state.oura_token_service

    redis_client = aioredis.from_url(settings.redis_url)
    try:
        state_valid = await oura_token_service.validate_state(state, redis_client)
    finally:
        await redis_client.aclose()

    if not state_valid:
        raise HTTPException(status_code=400, detail="Invalid or expired state")

    try:
        token_response = await oura_token_service.exchange_code(
            code=code,
            client_id=settings.oura_client_id,
            client_secret=settings.oura_client_secret,
            redirect_uri=settings.oura_redirect_uri,
        )
    except httpx.HTTPStatusError as exc:
        # Log full Oura response server-side; never reflect it to the caller
        # (it can contain OAuth error details, echoed client_id, etc.)
        logger.error(
            "Oura token exchange failed (%d) for user '%s': %s",
            exc.response.status_code,
            user_id,
            exc.response.text,
        )
        raise HTTPException(status_code=400, detail="Oura token exchange failed") from exc
    except httpx.RequestError as exc:
        logger.error("Could not reach Oura API for user '%s': %s", user_id, exc)
        raise HTTPException(status_code=503, detail="Could not reach Oura API") from exc

    integration = await oura_token_service.save_tokens(db, user_id, token_response)
    oura_user_id: str | None = (integration.provider_metadata or {}).get("oura_user_id")

    # Trigger 90-day historical backfill
    try:
        from app.tasks.oura_sync import backfill_oura_data_task  # noqa: PLC0415

        backfill_oura_data_task.delay(user_id=user_id, days_back=90)
    except Exception:
        logger.warning("Could not enqueue Oura backfill task for user '%s'", user_id)

    logger.info("Oura connected for user '%s' (oura_user_id=%s)", user_id, oura_user_id)

    analytics = getattr(request.app.state, "analytics_service", None)
    if analytics:
        analytics.capture(
            distinct_id=user_id,
            event="oura_connected",
            properties={"provider": "oura"},
        )

    return {"success": True, "oura_user_id": oura_user_id}


@router.get("/status")
async def oura_status(
    request: Request,
    credentials: HTTPAuthorizationCredentials = Depends(security),
    auth_service: AuthService = Depends(_get_auth_service),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Return Oura integration connection status for the current user."""
    user_data = await auth_service.get_user(credentials.credentials)
    user_id = user_data["id"]

    oura_token_service: OuraTokenService = request.app.state.oura_token_service
    integration = await oura_token_service.get_integration(db, user_id)

    if integration is None or not integration.is_active:
        return {"connected": False}

    metadata: dict = integration.provider_metadata or {}

    return {
        "connected": True,
        "sync_status": integration.sync_status,
        "last_synced_at": (integration.last_synced_at.isoformat() if integration.last_synced_at else None),
        "oura_user_id": metadata.get("oura_user_id"),
        "email": metadata.get("email"),
    }


@router.delete("/disconnect")
async def oura_disconnect(
    request: Request,
    credentials: HTTPAuthorizationCredentials = Depends(security),
    auth_service: AuthService = Depends(_get_auth_service),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Disconnect the current user's Oura integration."""
    user_data = await auth_service.get_user(credentials.credentials)
    user_id = user_data["id"]

    oura_token_service: OuraTokenService = request.app.state.oura_token_service
    disconnected = await oura_token_service.disconnect(db, user_id)

    analytics = getattr(request.app.state, "analytics_service", None)
    if analytics:
        analytics.capture(
            distinct_id=user_id,
            event="oura_disconnected",
            properties={"provider": "oura"},
        )

    return {"success": disconnected}
