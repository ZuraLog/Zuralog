"""
Zuralog Cloud Brain — Auth API Router.

RESTful endpoints for user authentication (register, login, logout, refresh).
All auth operations proxy to Supabase Auth via httpx, and new users are
synced to the local `users` table on registration and login.
"""

from typing import TYPE_CHECKING

import sentry_sdk
from fastapi import APIRouter, Depends, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.schemas import (
    AuthResponse,
    LoginRequest,
    MessageResponse,
    RefreshRequest,
    RegisterRequest,
    SocialAuthRequest,
)
from app.api.deps import _get_auth_service
from app.database import get_db
from app.limiter import limiter
from app.services.auth_service import AuthService
from app.services.user_service import sync_user_to_db

if TYPE_CHECKING:
    from app.services.analytics import AnalyticsService


def _get_analytics(request: "Request") -> "AnalyticsService | None":
    return getattr(request.app.state, "analytics_service", None)


async def _set_sentry_module() -> None:
    sentry_sdk.set_tag("api.module", "auth")


router = APIRouter(
    prefix="/auth",
    tags=["auth"],
    dependencies=[Depends(_set_sentry_module)],
)
security = HTTPBearer()


@router.post("/register", response_model=AuthResponse)
@limiter.limit("5/minute")
async def register(
    request: Request,
    body: RegisterRequest,
    auth_service: AuthService = Depends(_get_auth_service),
    db: AsyncSession = Depends(get_db),
) -> AuthResponse:
    """Register a new user via Supabase Auth.

    Creates the user in Supabase and syncs them to the local `users`
    table. Returns session tokens for immediate use.

    Args:
        body: Email and password for registration.
        auth_service: Injected Supabase auth service.
        db: Injected async database session.

    Returns:
        AuthResponse with user_id, access_token, refresh_token, expires_in.

    Raises:
        HTTPException: 400 if registration fails (e.g., email already taken).
    """
    result = await auth_service.sign_up(body.email, body.password)
    await sync_user_to_db(db, result["user_id"], body.email)

    analytics = _get_analytics(request)
    if analytics:
        analytics.capture(
            distinct_id=result["user_id"],
            event="user_signed_up",
            properties={
                "method": "email",
                "platform": request.headers.get("x-platform", "unknown"),
            },
        )
        analytics.identify(
            distinct_id=result["user_id"],
            properties={
                "platform": request.headers.get("x-platform", "unknown"),
                "subscription_tier": "free",
                "connected_integrations": [],
            },
        )
        analytics.group_identify(
            group_type="subscription",
            group_key="free",
            properties={"tier": "free"},
        )

    return AuthResponse(
        user_id=result["user_id"],
        access_token=result["access_token"],
        refresh_token=result["refresh_token"],
        expires_in=result["expires_in"],
    )


@router.post("/login", response_model=AuthResponse)
@limiter.limit("5/minute")
async def login(
    request: Request,
    body: LoginRequest,
    auth_service: AuthService = Depends(_get_auth_service),
    db: AsyncSession = Depends(get_db),
) -> AuthResponse:
    """Log in an existing user via Supabase Auth.

    Authenticates the user with Supabase and syncs them to the local
    `users` table (idempotent upsert). Returns session tokens.

    Args:
        body: Email and password for login.
        auth_service: Injected Supabase auth service.
        db: Injected async database session.

    Returns:
        AuthResponse with user_id, access_token, refresh_token, expires_in.

    Raises:
        HTTPException: 401 if credentials are invalid.
    """
    result = await auth_service.sign_in(body.email, body.password)
    await sync_user_to_db(db, result["user_id"], body.email)

    analytics = _get_analytics(request)
    if analytics:
        analytics.identify(
            distinct_id=result["user_id"],
            properties={
                "platform": request.headers.get("x-platform", "unknown"),
                "subscription_tier": "free",
            },
        )
        analytics.capture(
            distinct_id=result["user_id"],
            event="user_logged_in",
            properties={
                "method": "email",
                "platform": request.headers.get("x-platform", "unknown"),
            },
        )

    return AuthResponse(
        user_id=result["user_id"],
        access_token=result["access_token"],
        refresh_token=result["refresh_token"],
        expires_in=result["expires_in"],
    )


@router.post("/logout", response_model=MessageResponse)
@limiter.limit("10/minute")
async def logout(
    request: Request,
    credentials: HTTPAuthorizationCredentials = Depends(security),
    auth_service: AuthService = Depends(_get_auth_service),
) -> MessageResponse:
    """Log out the current user by invalidating their Supabase session.

    Uses the user's access token (from the Authorization header)
    to call Supabase logout — NOT the service key.

    Args:
        credentials: Bearer token from the Authorization header.
        auth_service: Injected Supabase auth service.

    Returns:
        MessageResponse confirming logout.

    Raises:
        HTTPException: 400 if logout fails.
    """
    # Extract user_id before invalidating the token so the event
    # is attributed to the correct user.
    user_id = getattr(getattr(request, "state", None), "user_id", None)

    await auth_service.sign_out(credentials.credentials)

    analytics = _get_analytics(request)
    if analytics and user_id:
        analytics.capture(
            distinct_id=user_id,
            event="user_logged_out",
            properties={
                "platform": request.headers.get("x-platform", "unknown"),
            },
        )

    return MessageResponse(message="Logged out successfully")


@router.post("/social", response_model=AuthResponse)
@limiter.limit("10/minute")
async def social_login(
    request: Request,
    body: SocialAuthRequest,
    auth_service: AuthService = Depends(_get_auth_service),
    db: AsyncSession = Depends(get_db),
) -> AuthResponse:
    """Authenticate via a native OAuth provider (Google or Apple).

    The Flutter Edge Agent obtains an ID token (and, for Google, an access
    token) directly from the provider's native SDK, then sends them here.
    The backend validates the tokens via Supabase GoTrue's id_token grant,
    which in turn verifies the token against the provider's JWKS endpoint.

    On first sign-in the user is created in Supabase Auth and then synced
    to our local `users` table (idempotent upsert). On subsequent sign-ins
    the existing user is retrieved and the local record is refreshed.

    Args:
        body: Provider, id_token, optional access_token and nonce.
        auth_service: Injected Supabase auth service.
        db: Injected async database session.

    Returns:
        AuthResponse with user_id, access_token, refresh_token, expires_in.

    Raises:
        HTTPException: 401 if the ID token is invalid or the provider is
            not enabled in the Supabase project settings.
    """
    result = await auth_service.sign_in_with_id_token(
        provider=body.provider,
        id_token=body.id_token,
        access_token=body.access_token,
        nonce=body.nonce,
    )

    # Sync the user to our local DB. email may be empty for Apple "Hide My
    # Email" users whose relay address Supabase doesn't always return; fall
    # back to the provider user_id as an identifier in that edge case.
    email = result["email"] or f"{body.provider}:{result['user_id']}"
    await sync_user_to_db(db, result["user_id"], email)

    analytics = _get_analytics(request)
    if analytics:
        platform = request.headers.get("x-platform", "unknown")
        analytics.identify(
            distinct_id=result["user_id"],
            properties={
                "platform": platform,
                "subscription_tier": "free",
                "auth_provider": body.provider,
            },
        )
        # Supabase GoTrue handles create-or-login for social providers;
        # we track as user_logged_in since we cannot reliably distinguish
        # first sign-in from returning sign-in at this layer.
        analytics.capture(
            distinct_id=result["user_id"],
            event="user_logged_in",
            properties={
                "method": body.provider,
                "platform": platform,
            },
        )

    return AuthResponse(
        user_id=result["user_id"],
        access_token=result["access_token"],
        refresh_token=result["refresh_token"],
        expires_in=result["expires_in"],
    )


@router.post("/refresh", response_model=AuthResponse)
@limiter.limit("10/minute")
async def refresh(
    request: Request,
    body: RefreshRequest,
    auth_service: AuthService = Depends(_get_auth_service),
) -> AuthResponse:
    """Exchange a refresh token for a new session.

    Args:
        body: The refresh token from a prior login.
        auth_service: Injected Supabase auth service.

    Returns:
        AuthResponse with new access_token, refresh_token, and expires_in.

    Raises:
        HTTPException: 401 if the refresh token is invalid or expired.
    """
    result = await auth_service.refresh_session(body.refresh_token)

    return AuthResponse(
        user_id=result["user_id"],
        access_token=result["access_token"],
        refresh_token=result["refresh_token"],
        expires_in=result["expires_in"],
    )
