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

_INCR_EXPIRE_SCRIPT = """
local current = redis.call('INCR', KEYS[1])
redis.call('EXPIRE', KEYS[1], ARGV[1])
return current
"""

TIER_LIMITS: dict[str, int] = {
    "free": 50,
    "premium": 500,
}

BURST_LIMITS: dict[str, int] = {
    "free": 10,
    "premium": 30,
}


@dataclass
class RateLimitResult:
    """Result of a rate limit check.

    Attributes:
        allowed: Whether the request is within limits.
        limit: The maximum requests allowed for the tier.
        remaining: How many requests remain in the current window.
        reset_seconds: Seconds until the window resets.
        reset_at: Unix timestamp when the window resets (0 if unknown).
    """

    allowed: bool
    limit: int
    remaining: int
    reset_seconds: int
    reset_at: int = 0


class RateLimiter:
    """Redis-backed fixed-window rate limiter.

    Uses daily keys (keyed by user_id + day) with atomic INCR
    to count requests. Each key auto-expires after 24 hours.
    """

    def __init__(self, redis_client: "redis.Redis | None" = None) -> None:
        """Initialize the rate limiter with a Redis connection.

        Args:
            redis_client: An existing Redis client to reuse. If None, a new
                connection is created from ``settings.redis_url`` and owned
                by this instance (closed on :meth:`close`).
        """
        if redis_client is not None:
            self._redis: redis.Redis = redis_client
            self._owns_connection = False
        else:
            self._redis = redis.from_url(settings.redis_url, decode_responses=True)
            self._owns_connection = True

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
            current = await self._redis.eval(_INCR_EXPIRE_SCRIPT, 1, redis_key, "86400")

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
            # Fail-open: a Redis outage should not block all users
            return RateLimitResult(
                allowed=True,
                limit=limit,
                remaining=-1,
                reset_seconds=reset_seconds,
            )

    async def check_burst_limit(self, user_id: str, tier: str = "free") -> RateLimitResult:
        """Check and increment the per-minute burst limit counter for a user.

        Args:
            user_id: The authenticated user's ID.
            tier: Subscription tier ('free' or 'premium').

        Returns:
            A RateLimitResult with the burst check outcome.
        """
        limit = BURST_LIMITS.get(tier, BURST_LIMITS["free"])
        minute_key = int(time.time() // 60)
        redis_key = f"burst:{user_id}:{minute_key}"
        reset_seconds = 60 - int(time.time() % 60)

        try:
            current = await self._redis.eval(_INCR_EXPIRE_SCRIPT, 1, redis_key, "60")

            return RateLimitResult(
                allowed=current <= limit,
                limit=limit,
                remaining=max(0, limit - current),
                reset_seconds=reset_seconds,
            )
        except redis.RedisError as exc:
            logger.error("Redis error in burst limiter: %s", exc)
            # Fail-open: a Redis outage should not block all users
            return RateLimitResult(
                allowed=True,
                limit=limit,
                remaining=-1,
                reset_seconds=reset_seconds,
            )

    @staticmethod
    def headers(result: RateLimitResult) -> dict[str, str]:
        """Generate standard X-RateLimit response headers.

        Args:
            result: The rate limit check result.

        Returns:
            Dict of header name → value pairs.
        """
        return {
            "X-RateLimit-Limit": str(result.limit),
            "X-RateLimit-Remaining": str(result.remaining),
            "X-RateLimit-Reset": str(result.reset_seconds),
        }

    async def close(self) -> None:
        """Close the Redis connection (only if owned by this instance)."""
        if self._owns_connection:
            await self._redis.aclose()
