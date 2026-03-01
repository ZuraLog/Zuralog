"""
Zuralog Cloud Brain — Oura Ring Rate Limit Guardrails.

Oura enforces an **app-level** limit of 5,000 requests per 5-minute
sliding window — shared across ALL users. Unlike Fitbit's per-user
hourly limit, every Oura API call counts against the same bucket.

Oura does NOT return rate-limit headers. We track the quota locally
via a Redis counter with a 5-minute TTL.

Fail-open policy: if Redis is unavailable, requests are allowed so
that a Redis outage does not block all Oura API calls.

Atomicity: ``check_and_increment`` uses a Lua script to perform the
INCR-and-cap check as a single atomic Redis operation, eliminating the
TOCTOU race that would occur with separate GET + DECR calls under
concurrent Celery worker load.

Usage:
    limiter = OuraRateLimiter(redis_url=settings.redis_url)
    if not await limiter.check_and_increment():
        raise HTTPException(429, "Oura app-level rate limit reached")
"""

import logging

logger = logging.getLogger(__name__)

_QUOTA = 5000  # Max requests per window
_WINDOW_SECONDS = 300  # 5-minute sliding window
_REDIS_KEY = "oura:rate:counter"

# Atomic Lua script: increment a counter, set TTL on first use, and
# return the new value.  If the new value exceeds _QUOTA the caller
# must treat the request as rate-limited.
#
# KEYS[1] = Redis key
# ARGV[1] = quota cap (integer)
# ARGV[2] = window TTL in seconds
#
# Returns the new counter value (integer).
_LUA_INCR_AND_CAP = """
local key   = KEYS[1]
local quota = tonumber(ARGV[1])
local ttl   = tonumber(ARGV[2])
local new   = redis.call('INCR', key)
if new == 1 then
    redis.call('EXPIRE', key, ttl)
end
return new
"""


class OuraRateLimiter:
    """Redis-backed app-level rate limiter for Oura API calls (5K/5min).

    All users share a single counter. The counter is initialized on
    first use and expires after 5 minutes.

    ``check_and_increment`` is atomic — it uses a Lua script so that
    two concurrent Celery workers cannot both read ``remaining=1`` and
    both be allowed through (classic TOCTOU).

    Fail-open: returns True when Redis is unavailable.
    """

    def __init__(self, redis_url: str) -> None:
        self._redis_url = redis_url

    async def check_and_increment(self) -> bool:
        """Check whether an Oura API call is allowed (app-level).

        Atomically increments the shared counter via a Lua script and
        checks whether the new value exceeds the 5-minute quota cap.
        Returns True if the call is allowed, False if the quota is
        exhausted.

        Fails open when Redis is unavailable.
        """
        try:
            import redis.asyncio as aioredis

            async with aioredis.from_url(self._redis_url) as redis:
                new_count = await redis.eval(  # type: ignore[attr-defined]
                    _LUA_INCR_AND_CAP,
                    1,  # number of keys
                    _REDIS_KEY,
                    _QUOTA,
                    _WINDOW_SECONDS,
                )
                if new_count > _QUOTA:
                    logger.warning("Oura app-level rate limit exhausted (count=%d)", new_count)
                    return False
                return True
        except Exception as exc:  # noqa: BLE001
            logger.warning("Redis unavailable, skipping Oura rate limit check: %s", exc)
            return True  # fail-open

    async def get_remaining(self) -> int:
        """Return the current remaining app-level request count."""
        try:
            import redis.asyncio as aioredis

            async with aioredis.from_url(self._redis_url) as redis:
                value = await redis.get(_REDIS_KEY)
                return int(value) if value is not None else _QUOTA
        except Exception:  # noqa: BLE001
            return _QUOTA

    async def get_reset_seconds(self) -> int:
        """Return seconds until the current rate limit window resets."""
        try:
            import redis.asyncio as aioredis

            async with aioredis.from_url(self._redis_url) as redis:
                ttl = await redis.ttl(_REDIS_KEY)
                return max(ttl, 0) if ttl and ttl > 0 else _WINDOW_SECONDS
        except Exception:  # noqa: BLE001
            return _WINDOW_SECONDS
