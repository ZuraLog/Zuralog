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
from dataclasses import dataclass, field
from typing import Optional

import redis.asyncio as redis
from redis.exceptions import RedisError

from app.config import settings

logger = logging.getLogger(__name__)

# Fix 3.1 (H-6): Atomic Lua script for INCR+EXPIRE to avoid race conditions
_INCR_WITH_TTL_SCRIPT = """
local key = KEYS[1]
local ttl = tonumber(ARGV[1])
local current = redis.call('INCR', key)
if current == 1 then
    redis.call('EXPIRE', key, ttl)
end
return current
"""


@dataclass
class RateLimitResult:
    """Result of a rate limit check.

    Attributes:
        allowed: Whether the request is within limits.
        limit: The maximum requests allowed for the tier.
        remaining: How many requests remain in the current window.
        reset_seconds: Seconds until the window resets.
        reset_at: Optional Unix timestamp when the window resets.
    """

    allowed: bool
    limit: int
    remaining: int
    reset_seconds: int = 0
    reset_at: Optional[int] = field(default=None)


class RateLimiter:
    """Redis-backed fixed-window rate limiter.

    Uses daily keys (keyed by user_id + day) with atomic Lua script
    (INCR+EXPIRE in one round-trip) to count requests.
    Each key auto-expires after 24 hours.
    """

    def __init__(self) -> None:
        """Initialize the rate limiter with a Redis connection."""
        self._redis: redis.Redis = redis.from_url(settings.redis_url, decode_responses=True)
        self._script_sha: Optional[str] = None

    async def _get_script_sha(self) -> str:
        """Load the Lua script into Redis and cache the SHA."""
        if self._script_sha is None:
            self._script_sha = await self._redis.script_load(_INCR_WITH_TTL_SCRIPT)
        return self._script_sha

    @property
    def _tier_limits(self) -> dict[str, int]:
        """Fix 3.4 (M-7): Return tier limits from config instead of hardcoded values."""
        return {
            "free": settings.rate_limit_free_daily,
            "premium": settings.rate_limit_premium_daily,
        }

    async def check_limit(self, user_id: str, tier: str = "free") -> RateLimitResult:
        """Check and increment the rate limit counter for a user.

        Args:
            user_id: The authenticated user's ID.
            tier: Subscription tier ('free' or 'premium').

        Returns:
            A RateLimitResult with the check outcome.
        """
        # Fix 3.5 (M-8): Log unknown tier
        if tier not in self._tier_limits:
            logger.warning(
                f"Unknown subscription tier '{tier}' for user {user_id}, defaulting to free limits"
            )

        limit = self._tier_limits.get(tier, self._tier_limits["free"])
        day_key = int(time.time() // 86400)
        redis_key = f"rate_limit:{user_id}:{day_key}"
        reset_seconds = 86400 - int(time.time() % 86400)

        try:
            sha = await self._get_script_sha()
            # Fix 3.1 (H-6): Use atomic Lua script instead of INCR + EXPIRE
            current = await self._redis.evalsha(sha, 1, redis_key, 86400)

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
                reset_at=int(time.time()) + reset_seconds,
            )
        except RedisError as e:
            # Fix 3.2 (C-5): Fail-open on Redis error instead of denying service
            logger.warning(f"Rate limiter Redis error (fail-open): {e}")
            return RateLimitResult(allowed=True, remaining=-1, reset_at=None, limit=0)

    async def check_burst_limit(self, user_id: str) -> RateLimitResult:
        """Fix 3.3 (H-7 / H-1): Per-minute burst rate limit check.

        Args:
            user_id: The authenticated user's ID.

        Returns:
            A RateLimitResult indicating whether the burst limit is exceeded.
        """
        minute_key = f"rate_burst:{user_id}:{int(time.time() // 60)}"
        limit = settings.rate_limit_burst_per_minute  # 10
        try:
            sha = await self._get_script_sha()
            current = await self._redis.evalsha(sha, 1, minute_key, 60)
            allowed = current <= limit
            return RateLimitResult(
                allowed=allowed,
                remaining=max(0, limit - current),
                reset_at=None,
                limit=limit,
            )
        except RedisError as e:
            logger.warning(f"Burst rate limiter Redis error (fail-open): {e}")
            return RateLimitResult(allowed=True, remaining=-1, reset_at=None, limit=limit)

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
        """Close the Redis connection."""
        await self._redis.aclose()
