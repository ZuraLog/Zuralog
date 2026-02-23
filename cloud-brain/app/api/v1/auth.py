"""
Zuralog Cloud Brain — Auth API Router.

RESTful endpoints for user authentication (register, login, logout, refresh).
All auth operations proxy to Supabase Auth via httpx, and new users are
synced to the local `users` table on registration and login.
"""

from fastapi import APIRouter, Depends, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.schemas import (
    AuthResponse,
    LoginRequest,
    MessageResponse,
    RefreshRequest,
    RegisterRequest,
)
from app.database import get_db
from app.limiter import limiter
from app.services.auth_service import AuthService
from app.services.user_service import sync_user_to_db

router = APIRouter(prefix="/auth", tags=["auth"])
security = HTTPBearer()


def _get_auth_service(request: Request) -> AuthService:
    """FastAPI dependency that retrieves the shared AuthService.

    The AuthService is stored in `app.state` during the lifespan
    context manager, ensuring the httpx client is properly pooled
    and shut down.

    Args:
        request: The incoming FastAPI request.

    Returns:
        The shared AuthService instance.
    """
    return request.app.state.auth_service


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
    await auth_service.sign_out(credentials.credentials)
    return MessageResponse(message="Logged out successfully")


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
