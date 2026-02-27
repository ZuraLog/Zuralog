"""
Zuralog Cloud Brain — Fitbit Integration Endpoints.

Exposes REST endpoints for initiating and completing the Fitbit OAuth 2.0
PKCE flow and managing the integration lifecycle.

The PKCE flow:
  1. Mobile app calls GET /authorize → gets auth_url + state token
  2. App opens auth_url in system browser; user authorises
  3. Fitbit redirects to zuralog://oauth/fitbit?code=XXX&state=YYY
  4. App intercepts deep link and calls POST /exchange with code + state
  5. Backend retrieves verifier from Redis, exchanges code for tokens,
     persists them, and returns the Fitbit user profile info.
"""

import logging
import secrets

import redis.asyncio as aioredis
from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.auth import _get_auth_service
from app.config import settings
from app.database import get_db
from app.limiter import limiter
from app.services.auth_service import AuthService
from app.services.fitbit_token_service import FitbitTokenService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/integrations/fitbit", tags=["fitbit"])
security = HTTPBearer()


@router.get("/authorize")
@limiter.limit("5/minute")
async def fitbit_authorize(
    request: Request,
    credentials: HTTPAuthorizationCredentials = Depends(security),
    auth_service: AuthService = Depends(_get_auth_service),
) -> dict[str, str]:
    """Return the Fitbit OAuth authorization URL for the mobile app to open.

    Generates a PKCE code_verifier / code_challenge pair and stores the
    verifier in Redis keyed by a random ``state`` UUID (anti-CSRF).

    The app opens the returned URL in the system browser. After the user
    grants access, Fitbit redirects to ``zuralog://oauth/fitbit?code=XXX&state=YYY``.
    The app intercepts the deep link and calls ``POST /exchange``.

    Args:
        request: FastAPI request — used to access ``app.state`` services.
        credentials: Bearer token for the authenticated Zuralog user.
        auth_service: Injected auth service for verifying the JWT.

    Returns:
        dict: ``{"auth_url": "<fitbit_oauth_url>", "state": "<state_uuid>"}``
    """
    # Validate the JWT (ensures user is authenticated)
    await auth_service.get_user(credentials.credentials)

    fitbit_token_service: FitbitTokenService = request.app.state.fitbit_token_service

    # Generate PKCE pair
    code_verifier, code_challenge = fitbit_token_service.generate_pkce_pair()

    # Random state UUID for CSRF protection
    state = secrets.token_urlsafe(32)

    redis_client = aioredis.from_url(settings.redis_url)

    try:
        await fitbit_token_service.store_pkce_verifier(state, code_verifier, redis_client)
    finally:
        await redis_client.aclose()

    auth_url = fitbit_token_service.build_auth_url(
        state=state,
        code_challenge=code_challenge,
        client_id=settings.fitbit_client_id,
        redirect_uri=settings.fitbit_redirect_uri,
    )

    return {"auth_url": auth_url, "state": state}


@router.post("/exchange")
@limiter.limit("10/minute")
async def fitbit_exchange(
    request: Request,
    code: str,
    state: str,
    user_id: str,
    credentials: HTTPAuthorizationCredentials = Depends(security),
    auth_service: AuthService = Depends(_get_auth_service),
    db: AsyncSession = Depends(get_db),
) -> dict[str, object]:
    """Exchange a Fitbit authorization code for access and refresh tokens.

    Called by the mobile app after it intercepts the OAuth redirect deep link.
    The backend retrieves the stored PKCE verifier, performs the token swap
    (so the Client Secret is never exposed to the client), and persists the
    tokens.

    Args:
        request: FastAPI request — used to access ``app.state`` services.
        code: The short-lived authorization code returned by Fitbit.
        state: The OAuth state parameter used to retrieve the PKCE verifier.
        user_id: The Zuralog user ID to associate the integration with.
        credentials: Bearer token for the authenticated Zuralog user.
        auth_service: Injected auth service for verifying the JWT.
        db: Injected async database session for token persistence.

    Returns:
        dict: ``{"success": True, "fitbit_user_id": ..., "display_name": ...}``

    Raises:
        HTTPException: 400 if the state is invalid/expired (PKCE verifier not found).
        HTTPException: 400 if Fitbit rejects the code exchange.
        HTTPException: 401 if the bearer token is invalid.
        HTTPException: 503 if the Fitbit API is unreachable.
    """
    # Validate the JWT
    await auth_service.get_user(credentials.credentials)

    fitbit_token_service: FitbitTokenService = request.app.state.fitbit_token_service

    redis_client = aioredis.from_url(settings.redis_url)

    try:
        code_verifier = await fitbit_token_service.get_pkce_verifier(state, redis_client)
    finally:
        await redis_client.aclose()

    if code_verifier is None:
        raise HTTPException(status_code=400, detail="Invalid or expired state")

    import httpx  # noqa: PLC0415

    try:
        token_response = await fitbit_token_service.exchange_code(
            code=code,
            code_verifier=code_verifier,
            client_id=settings.fitbit_client_id,
            client_secret=settings.fitbit_client_secret,
            redirect_uri=settings.fitbit_redirect_uri,
        )
    except httpx.HTTPStatusError as exc:
        raise HTTPException(
            status_code=400,
            detail=f"Fitbit token exchange failed: {exc.response.text}",
        ) from exc
    except httpx.RequestError as exc:
        raise HTTPException(
            status_code=503,
            detail=f"Could not reach Fitbit API: {exc}",
        ) from exc

    # Persist tokens to the database
    integration = await fitbit_token_service.save_tokens(db, user_id, token_response)

    fitbit_user_id: str | None = (integration.provider_metadata or {}).get("fitbit_user_id")
    display_name: str | None = (integration.provider_metadata or {}).get("display_name")

    # Store token on FitbitServer for immediate MCP tool use (Task 3 wires this in)
    registry = getattr(request.app.state, "mcp_registry", None)
    if registry is not None:
        fitbit_server = registry.get("fitbit")
        if fitbit_server is not None and hasattr(fitbit_server, "_store_token"):
            access_token = token_response.get("access_token", "")
            fitbit_server._store_token(user_id, access_token)

    logger.info("Fitbit connected for user '%s' (fitbit_user_id=%s)", user_id, fitbit_user_id)

    return {
        "success": True,
        "fitbit_user_id": fitbit_user_id,
        "display_name": display_name,
    }


@router.get("/status")
async def fitbit_status(
    request: Request,
    credentials: HTTPAuthorizationCredentials = Depends(security),
    auth_service: AuthService = Depends(_get_auth_service),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Return Fitbit integration connection status for the current user.

    Args:
        request: FastAPI request — used to access ``app.state`` services.
        credentials: Bearer token for the authenticated Zuralog user.
        auth_service: Injected auth service for verifying the JWT.
        db: Injected async database session.

    Returns:
        dict: ``{"connected": False}`` when no active integration exists, or
              ``{"connected": True, "sync_status": ..., "last_synced_at": ...,
                 "fitbit_user_id": ..., "display_name": ..., "devices": [...]}``
              when the user has an active Fitbit integration.
    """
    user_data = await auth_service.get_user(credentials.credentials)
    user_id = user_data["id"]

    fitbit_token_service: FitbitTokenService = request.app.state.fitbit_token_service
    integration = await fitbit_token_service.get_integration(db, user_id)

    if integration is None or not integration.is_active:
        return {"connected": False}

    metadata: dict = integration.provider_metadata or {}

    return {
        "connected": True,
        "sync_status": integration.sync_status,
        "last_synced_at": (
            integration.last_synced_at.isoformat() if integration.last_synced_at else None
        ),
        "fitbit_user_id": metadata.get("fitbit_user_id"),
        "display_name": metadata.get("display_name"),
        "devices": metadata.get("devices", []),
    }


@router.delete("/disconnect")
async def fitbit_disconnect(
    request: Request,
    credentials: HTTPAuthorizationCredentials = Depends(security),
    auth_service: AuthService = Depends(_get_auth_service),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Disconnect the current user's Fitbit integration.

    Revokes the Fitbit token and marks the integration as inactive in the
    database via ``FitbitTokenService.disconnect``.

    Args:
        request: FastAPI request — used to access ``app.state`` services.
        credentials: Bearer token for the authenticated Zuralog user.
        auth_service: Injected auth service for verifying the JWT.
        db: Injected async database session.

    Returns:
        dict: ``{"success": True}`` if the integration was disconnected,
              ``{"success": False}`` if no active integration was found.
    """
    user_data = await auth_service.get_user(credentials.credentials)
    user_id = user_data["id"]

    fitbit_token_service: FitbitTokenService = request.app.state.fitbit_token_service
    disconnected = await fitbit_token_service.disconnect(db, user_id)
    return {"success": disconnected}
