"""
Zuralog Cloud Brain — Per-User Rate Limiter Service.

Redis-backed fixed-window counter for enforcing subscription-tier
rate limits on LLM endpoints. Works alongside the existing slowapi
IP-level rate limiter for different concerns:

- slowapi: IP-level abuse prevention (brute force, DDoS)
- RateLimiter: Per-user LLM cost control (Free vs Premium tiers)
"""

import logging
import time
from dataclasses import dataclass

import redis.asyncio as redis

from app.config import settings

logger = logging.getLogger(__name__)

TIER_LIMITS: dict[str, int] = {
    "free": 50,
    "premium": 500,
}


@dataclass
class RateLimitResult:
    """Result of a rate limit check.

    Attributes:
        allowed: Whether the request is within limits.
        limit: The maximum requests allowed for the tier.
        remaining: How many requests remain in the current window.
        reset_seconds: Seconds until the window resets.
    """

    allowed: bool
    limit: int
    remaining: int
    reset_seconds: int


class RateLimiter:
    """Redis-backed fixed-window rate limiter.

    Uses daily keys (keyed by user_id + day) with atomic INCR
    to count requests. Each key auto-expires after 24 hours.
    """

    def __init__(self) -> None:
        """Initialize the rate limiter with a Redis connection."""
        self._redis: redis.Redis = redis.from_url(settings.redis_url, decode_responses=True)

    async def check_limit(self, user_id: str, tier: str = "free") -> RateLimitResult:
        """Check and increment the rate limit counter for a user.

        Args:
            user_id: The authenticated user's ID.
            tier: Subscription tier ('free' or 'premium').

        Returns:
            A RateLimitResult with the check outcome.
        """
        limit = TIER_LIMITS.get(tier, TIER_LIMITS["free"])
        day_key = int(time.time() // 86400)
        redis_key = f"rate_limit:{user_id}:{day_key}"
        reset_seconds = 86400 - int(time.time() % 86400)

        try:
            current = await self._redis.incr(redis_key)
            if current == 1:
                await self._redis.expire(redis_key, 86400)

            allowed = current <= limit
            remaining = max(0, limit - current)

            if not allowed:
                logger.warning(
                    "Rate limit exceeded: user=%s tier=%s count=%d/%d",
                    user_id,
                    tier,
                    current,
                    limit,
                )

            return RateLimitResult(
                allowed=allowed,
                limit=limit,
                remaining=remaining,
                reset_seconds=reset_seconds,
            )
        except redis.RedisError as exc:
            logger.error("Redis error in rate limiter: %s", exc)
            return RateLimitResult(
                allowed=False,
                limit=limit,
                remaining=0,
                reset_seconds=reset_seconds,
            )

    async def close(self) -> None:
        """Close the Redis connection."""
        await self._redis.aclose()
