"""
Life Logger Cloud Brain — Shared API Dependencies.

FastAPI dependencies for authentication, authorization, and rate limiting.
"""

import logging
from typing import Any

from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.user import SubscriptionTier, User
from app.services.auth_service import AuthService
from app.services.rate_limiter import RateLimiter

logger = logging.getLogger(__name__)

security = HTTPBearer()


def _get_auth_service(request: Request) -> AuthService:
    """Retrieve the shared AuthService from app state.

    Args:
        request: The incoming FastAPI request.

    Returns:
        The shared AuthService instance.
    """
    return request.app.state.auth_service


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    auth_service: AuthService = Depends(_get_auth_service),
    db: AsyncSession = Depends(get_db),
) -> User:
    """Authenticate the request and return the User ORM instance.

    Validates the Bearer token via Supabase Auth, then loads the
    corresponding User from the local database.

    Args:
        credentials: Bearer token from Authorization header.
        auth_service: Injected auth service for token validation.
        db: Injected async database session.

    Returns:
        The authenticated User ORM instance.

    Raises:
        HTTPException: 401 if the token is invalid or missing.
        HTTPException: 404 if the user exists in Supabase but not local DB.
    """
    supabase_user = await auth_service.get_user(credentials.credentials)
    user_id = supabase_user.get("id", "")

    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()

    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found in database",
        )

    return user


def require_tier(min_tier: str):
    """Dependency factory to enforce minimum subscription tier.

    Creates a FastAPI dependency that checks if the authenticated user
    meets the minimum subscription tier requirement.

    Args:
        min_tier: The minimum tier required (e.g., 'pro').

    Returns:
        An async dependency function that returns the User if authorized.
    """
    required_rank = SubscriptionTier(min_tier).rank

    async def _check_tier(user: User = Depends(get_current_user)) -> User:
        """Check if the user meets the minimum tier requirement.

        Args:
            user: The authenticated user from get_current_user.

        Returns:
            The user if they meet the tier requirement.

        Raises:
            HTTPException: 403 if tier is insufficient.
        """
        user_tier = SubscriptionTier(user.subscription_tier)
        if user_tier.rank < required_rank:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Subscription tier '{min_tier}' required. Current tier: '{user.subscription_tier}'.",
            )
        return user

    return _check_tier


async def check_rate_limit(
    user: dict[str, Any],
    limiter: RateLimiter,
    db: AsyncSession,
) -> None:
    """Enforce per-user rate limits based on subscription tier.

    Queries the user's subscription tier from the database, then
    checks the Redis rate limiter with the appropriate tier.

    Args:
        user: The authenticated user dict (must contain 'id').
        limiter: The rate limiter service.
        db: The async database session.

    Raises:
        HTTPException: 429 if the daily limit is exceeded.
    """
    user_id = user.get("id", "unknown")

    result = await db.execute(select(User.subscription_tier).where(User.id == user_id))
    subscription_tier = result.scalar_one_or_none() or "free"
    tier = "premium" if subscription_tier != "free" else "free"

    limit_result = await limiter.check_limit(user_id, tier=tier)

    if not limit_result.allowed:
        logger.warning("Rate limit hit: user=%s tier=%s", user_id, tier)
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=(
                f"Daily rate limit exceeded. Your {tier} plan allows "
                f"{limit_result.limit} requests/day. Upgrade to Premium for more."
            ),
            headers={
                "X-RateLimit-Limit": str(limit_result.limit),
                "X-RateLimit-Remaining": "0",
                "X-RateLimit-Reset": str(limit_result.reset_seconds),
                "Retry-After": str(limit_result.reset_seconds),
            },
        )
