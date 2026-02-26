"""
Zuralog Cloud Brain — Third-Party Integration Endpoints.

Exposes REST endpoints for initiating and completing OAuth 2.0 flows
with external services. Currently supports Strava (Phase 1.6).

The Cloud Brain handles all token exchange server-side so the Client
Secret never leaves the backend. The mobile Edge Agent initiates the
flow and intercepts the redirect URI via a custom URL scheme deep link.
"""

import urllib.parse

import httpx
from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.auth import _get_auth_service
from app.config import settings
from app.database import get_db
from app.limiter import limiter
from app.services.auth_service import AuthService
from app.services.strava_token_service import StravaTokenService

router = APIRouter(prefix="/integrations", tags=["integrations"])
security = HTTPBearer()


@router.get("/strava/authorize")
@limiter.limit("5/minute")
async def strava_authorize(request: Request) -> dict[str, str]:
    """Return the Strava OAuth authorization URL for the mobile app to open.

    The app opens this URL in the system browser. After the user grants
    access, Strava redirects to ``zuralog://oauth/strava?code=XXX``.
    The app intercepts the deep link and calls ``/strava/exchange``.

    Returns:
        dict: ``{"auth_url": "<strava_oauth_url>"}``
    """
    params = {
        "client_id": settings.strava_client_id,
        "redirect_uri": settings.strava_redirect_uri,
        "response_type": "code",
        "approval_prompt": "auto",
        "scope": "read,activity:read_all,activity:write,profile:read_all",
    }
    auth_url = f"https://www.strava.com/oauth/authorize?{urllib.parse.urlencode(params)}"
    return {"auth_url": auth_url}


@router.post("/strava/exchange")
@limiter.limit("10/minute")
async def strava_exchange(
    request: Request,
    code: str,
    credentials: HTTPAuthorizationCredentials = Depends(security),
    auth_service: AuthService = Depends(_get_auth_service),
    db: AsyncSession = Depends(get_db),
) -> dict[str, object]:
    """Exchange a Strava authorization code for access and refresh tokens.

    Called by the mobile app after it intercepts the OAuth redirect deep
    link. The backend performs the token swap so the Client Secret is never
    exposed to the client.

    On success the tokens are persisted to the database via
    ``StravaTokenService.save_tokens`` **and** stored in the in-memory
    ``StravaServer`` instance (keyed by ``user_id``) for immediate MCP use.

    Args:
        request: FastAPI request — used to access ``app.state`` services.
        code: The short-lived authorization code returned by Strava.
        credentials: Bearer token for the authenticated Zuralog user.
        auth_service: Injected auth service for verifying the JWT.
        db: Injected async database session for token persistence.

    Returns:
        dict: ``{"success": True, "message": "Strava connected!", "athlete_id": <int|None>}``

    Raises:
        HTTPException: 400 if Strava rejects the code exchange.
        HTTPException: 401 if the bearer token is invalid.
        HTTPException: 503 if the Strava API is unreachable.
    """
    user_data = await auth_service.get_user(credentials.credentials)
    user_id = user_data["id"]

    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            response = await client.post(
                "https://www.strava.com/oauth/token",
                data={
                    "client_id": settings.strava_client_id,
                    "client_secret": settings.strava_client_secret,
                    "code": code,
                    "grant_type": "authorization_code",
                },
            )
    except httpx.RequestError as exc:
        raise HTTPException(
            status_code=503,
            detail=f"Could not reach Strava API: {exc}",
        ) from exc

    if response.status_code != 200:
        raise HTTPException(
            status_code=400,
            detail=f"Strava token exchange failed: {response.text}",
        )

    token_data: dict[str, object] = response.json()
    access_token = str(token_data.get("access_token", ""))
    refresh_token = str(token_data.get("refresh_token", ""))
    expires_at = int(token_data.get("expires_at", 0))
    athlete: dict | None = token_data.get("athlete")  # type: ignore[assignment]

    # Persist tokens to the database (Phase 1.7).
    token_service: StravaTokenService = request.app.state.strava_token_service
    await token_service.save_tokens(
        db,
        user_id,
        access_token,
        refresh_token,
        expires_at,
        athlete_data=athlete,
    )

    # Also store token on the StravaServer instance for immediate MCP tool use.
    registry = request.app.state.mcp_registry
    strava_server = registry.get("strava")
    if strava_server is not None:
        strava_server.store_token(user_id, access_token)

    athlete_id: int | None = athlete.get("id") if athlete else None  # type: ignore[union-attr]
    return {"success": True, "message": "Strava connected!", "athlete_id": athlete_id}
