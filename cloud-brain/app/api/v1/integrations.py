"""
Life Logger Cloud Brain — Third-Party Integration Endpoints.

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

from app.api.v1.auth import _get_auth_service
from app.config import settings
from app.limiter import limiter
from app.services.auth_service import AuthService

router = APIRouter(prefix="/integrations", tags=["integrations"])
security = HTTPBearer()

@router.get("/strava/authorize")
@limiter.limit("5/minute")
async def strava_authorize(request: Request) -> dict[str, str]:
    """Return the Strava OAuth authorization URL for the mobile app to open.

    The app opens this URL in the system browser. After the user grants
    access, Strava redirects to ``lifelogger://oauth/strava?code=XXX``.
    The app intercepts the deep link and calls ``/strava/exchange``.

    Returns:
        dict: ``{"auth_url": "<strava_oauth_url>"}``
    """
    params = {
        "client_id": settings.strava_client_id,
        "redirect_uri": settings.strava_redirect_uri,
        "response_type": "code",
        "approval_prompt": "auto",
        "scope": "read,activity:read,activity:write",
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
) -> dict[str, object]:
    """Exchange a Strava authorization code for access and refresh tokens.

    Called by the mobile app after it intercepts the OAuth redirect deep
    link. The backend performs the token swap so the Client Secret is never
    exposed to the client.

    On success, the access token is stored in the in-memory ``StravaServer``
    instance (keyed by ``user_id``) so MCP tool calls can use it immediately.
    Proper database persistence is deferred to Phase 1.7.

    Args:
        request: FastAPI request — used to access ``app.state.mcp_registry``.
        code: The short-lived authorization code returned by Strava.
        user_id: The authenticated user's ID, used to key the stored token.

    Returns:
        dict: ``{"success": True, "message": "Strava connected!"}`` on success.

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

    # Store token on the StravaServer instance for immediate MCP tool use.
    # Phase 1.7 will replace this with proper DB persistence.
    registry = request.app.state.mcp_registry
    strava_server = registry.get("strava")
    if strava_server is not None:
        strava_server.store_token(user_id, access_token)

    return {"success": True, "message": "Strava connected!"}
