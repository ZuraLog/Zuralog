"""
Life Logger Cloud Brain — Shared API Dependencies.

FastAPI dependencies for rate limiting and authentication.
"""

import logging
from typing import Any

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User
from app.services.rate_limiter import RateLimiter

logger = logging.getLogger(__name__)


async def check_rate_limit(
    user: dict[str, Any],
    limiter: RateLimiter,
    db: AsyncSession,
) -> None:
    """Enforce per-user rate limits based on subscription tier.

    Queries the user's premium status from the database, then
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
