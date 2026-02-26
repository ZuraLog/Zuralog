"""
Zuralog Cloud Brain — Strava API Rate Limit Guardrails.

Strava enforces 100 reads per 15-minute window and 1,000 reads per day.
This service tracks usage via Redis sliding window counters and prevents
requests when approaching those limits (thresholds: 90/15min, 900/daily).

Usage:
    limiter = StravaRateLimiter()
    if not await limiter.check_and_increment():
        raise HTTPException(429, "Strava rate limit reached")
"""

import logging
from datetime import datetime, timezone

from app.config import settings

logger = logging.getLogger(__name__)

# Conservative thresholds (leave 10% buffer under Strava's hard limits)
_LIMIT_15MIN = 90  # Strava hard limit: 100
_LIMIT_DAILY = 900  # Strava hard limit: 1000


class StravaRateLimiter:
    """Redis-backed sliding window rate limiter for Strava API calls.

    Tracks read request counts using two Redis keys:
    - A 15-minute window key (TTL: 15 minutes)
    - A daily window key (TTL: 24 hours)

    All increments happen AFTER the check passes to avoid blocking
    on a Redis failure.
    """

    def __init__(self, redis_url: str | None = None) -> None:
        """Initialize the rate limiter.

        Args:
            redis_url: Optional Redis connection URL. If not provided,
                uses the ``REDIS_URL`` environment variable or falls back
                to a no-op mode when Redis is unavailable.
        """
        self._redis_url = redis_url
        self.limit_15min: int = _LIMIT_15MIN
        self.limit_daily: int = _LIMIT_DAILY

    def _get_15min_key(self) -> str:
        """Generate the Redis key for the current 15-minute window.

        Returns:
            A string key like ``strava:rate:15m:20260226T0815``.
        """
        now = datetime.now(timezone.utc)
        # Round down to nearest 15-minute slot
        slot = (now.minute // 15) * 15
        return f"strava:rate:15m:{now.strftime('%Y%m%dT%H')}{slot:02d}"

    def _get_daily_key(self) -> str:
        """Generate the Redis key for the current calendar day.

        Returns:
            A string key like ``strava:rate:daily:20260226``.
        """
        return f"strava:rate:daily:{datetime.now(timezone.utc).strftime('%Y%m%d')}"

    async def _get_counts(self) -> tuple[int, int]:
        """Retrieve current 15-minute and daily counts from Redis.

        Returns:
            Tuple of (count_15min, count_daily). Returns (0, 0) if
            Redis is unavailable (fail-open: allow the request).
        """
        try:
            import redis.asyncio as aioredis

            redis_url = self._redis_url or settings.redis_url
            async with aioredis.from_url(redis_url) as redis:
                key_15m = self._get_15min_key()
                key_daily = self._get_daily_key()
                count_15m_raw, count_daily_raw = await redis.mget(key_15m, key_daily)
                count_15m = int(count_15m_raw or 0)
                count_daily = int(count_daily_raw or 0)
                return count_15m, count_daily
        except Exception as exc:  # noqa: BLE001
            logger.warning("Redis unavailable, skipping rate limit check: %s", exc)
            return 0, 0

    async def _increment(self) -> None:
        """Increment both counters in Redis.

        Sets TTL if the key is new:
        - 15-min key: TTL 900 seconds (15 minutes)
        - daily key: TTL 86400 seconds (24 hours)

        Fails silently if Redis is unavailable.
        """
        try:
            import redis.asyncio as aioredis

            redis_url = self._redis_url or settings.redis_url
            async with aioredis.from_url(redis_url) as redis:
                key_15m = self._get_15min_key()
                key_daily = self._get_daily_key()
                pipe = redis.pipeline()
                pipe.incr(key_15m)
                pipe.expire(key_15m, 900)
                pipe.incr(key_daily)
                pipe.expire(key_daily, 86400)
                await pipe.execute()
        except Exception as exc:  # noqa: BLE001
            logger.warning("Redis unavailable, could not increment rate counter: %s", exc)

    async def check_and_increment(self) -> bool:
        """Check if an API call is allowed and increment counters if so.

        Returns ``True`` and increments both counters when under limits.
        Returns ``False`` without incrementing when at or over threshold.

        Returns:
            ``True`` if the request is allowed, ``False`` if rate-limited.
        """
        count_15m, count_daily = await self._get_counts()

        if count_15m >= self.limit_15min:
            logger.warning("Strava 15-min rate limit reached (%d/%d)", count_15m, self.limit_15min)
            return False

        if count_daily >= self.limit_daily:
            logger.warning("Strava daily rate limit reached (%d/%d)", count_daily, self.limit_daily)
            return False

        await self._increment()
        return True
