"""
Zuralog Cloud Brain — Fitbit API Rate Limit Guardrails.

Fitbit enforces **per-user** limits: 150 requests per hour per user.
This service tracks each user's remaining quota via Redis and prevents
requests when the bucket is empty.

Unlike the Strava limiter (which tracks app-level sliding windows),
this limiter is per-user and reads the authoritative remaining count
directly from Fitbit response headers whenever available.

Usage:
    limiter = FitbitRateLimiter(redis_url=settings.redis_url)
    if not await limiter.check_and_increment(user_id):
        raise HTTPException(429, "Fitbit rate limit reached for this user")
"""

import logging

logger = logging.getLogger(__name__)

# Fitbit's documented per-user hourly limit
_HOURLY_LIMIT = 150
_TTL_SECONDS = 3600  # 1 hour


class FitbitRateLimiter:
    """Redis-backed per-user rate limiter for Fitbit API calls.

    Tracks each user's remaining request quota using two Redis keys:
    - ``fitbit:rate:{user_id}:remaining`` — requests left in the current window
    - ``fitbit:rate:{user_id}:reset``     — epoch seconds of the next window reset

    The ``update_from_headers`` method provides authoritative overrides
    using the ``Fitbit-Rate-Limit-Remaining`` and ``Fitbit-Rate-Limit-Reset``
    response headers returned by the Fitbit API.

    Fail-open policy: if Redis is unavailable, requests are allowed so that
    a Redis outage does not take down the integration.
    """

    def __init__(self, redis_url: str) -> None:
        """Initialize the rate limiter with a Redis URL.

        Args:
            redis_url: Redis connection URL (e.g., ``redis://localhost:6379/0``).
        """
        self._redis_url = redis_url

    def _remaining_key(self, user_id: str) -> str:
        """Return the Redis key for a user's remaining request count.

        Args:
            user_id: The Zuralog user ID.

        Returns:
            A string key like ``fitbit:rate:user-123:remaining``.
        """
        return f"fitbit:rate:{user_id}:remaining"

    def _reset_key(self, user_id: str) -> str:
        """Return the Redis key for a user's rate-limit reset epoch.

        Args:
            user_id: The Zuralog user ID.

        Returns:
            A string key like ``fitbit:rate:user-123:reset``.
        """
        return f"fitbit:rate:{user_id}:reset"

    async def check_and_increment(self, user_id: str) -> bool:
        """Check whether a Fitbit API call is allowed for a user.

        Initializes the user's quota bucket to 150 if it does not yet
        exist.  Decrements the counter and returns ``True`` when quota
        remains.  Returns ``False`` immediately (without decrementing)
        when the counter has reached zero.

        Fails open — returns ``True`` — when Redis is unavailable so
        that a Redis outage does not block all Fitbit API calls.

        Args:
            user_id: The Zuralog user ID making the request.

        Returns:
            ``True`` if the request is allowed, ``False`` if rate-limited.
        """
        try:
            import redis.asyncio as aioredis

            async with aioredis.from_url(self._redis_url) as redis:
                key = self._remaining_key(user_id)

                # Initialize bucket if key does not exist
                exists = await redis.exists(key)
                if not exists:
                    await redis.set(key, _HOURLY_LIMIT, ex=_TTL_SECONDS)

                remaining = int(await redis.get(key) or 0)
                if remaining <= 0:
                    logger.warning(
                        "Fitbit rate limit exhausted for user '%s'", user_id
                    )
                    return False

                await redis.decr(key)
                return True

        except Exception as exc:  # noqa: BLE001
            logger.warning(
                "Redis unavailable, skipping Fitbit rate limit check for user '%s': %s",
                user_id,
                exc,
            )
            return True  # fail-open

    async def update_from_headers(
        self,
        user_id: str,
        remaining: int,
        reset_seconds: int,
    ) -> None:
        """Update Redis with authoritative rate-limit data from Fitbit headers.

        Called after each successful Fitbit API response to keep the local
        counter in sync with Fitbit's server-side tracking.  The
        ``Fitbit-Rate-Limit-Remaining`` and ``Fitbit-Rate-Limit-Reset``
        headers are the source of truth.

        Args:
            user_id: The Zuralog user ID whose limits are being updated.
            remaining: The value of ``Fitbit-Rate-Limit-Remaining``.
            reset_seconds: The value of ``Fitbit-Rate-Limit-Reset``
                (seconds until the current window resets).

        Returns:
            ``None``.  Fails silently if Redis is unavailable.
        """
        try:
            import redis.asyncio as aioredis

            async with aioredis.from_url(self._redis_url) as redis:
                pipe = redis.pipeline()
                pipe.set(self._remaining_key(user_id), remaining, ex=reset_seconds or _TTL_SECONDS)
                pipe.set(self._reset_key(user_id), reset_seconds, ex=reset_seconds or _TTL_SECONDS)
                await pipe.execute()
                logger.debug(
                    "Updated Fitbit rate limits for user '%s': remaining=%d, reset=%ds",
                    user_id,
                    remaining,
                    reset_seconds,
                )
        except Exception as exc:  # noqa: BLE001
            logger.warning(
                "Redis unavailable, could not update Fitbit rate headers for user '%s': %s",
                user_id,
                exc,
            )

    async def get_remaining(self, user_id: str) -> int:
        """Return the current remaining request count for a user.

        Args:
            user_id: The Zuralog user ID.

        Returns:
            Remaining count as an integer.  Returns ``150`` if the key
            does not exist or Redis is unavailable.
        """
        try:
            import redis.asyncio as aioredis

            async with aioredis.from_url(self._redis_url) as redis:
                value = await redis.get(self._remaining_key(user_id))
                return int(value) if value is not None else _HOURLY_LIMIT
        except Exception as exc:  # noqa: BLE001
            logger.warning(
                "Redis unavailable, returning default remaining for user '%s': %s",
                user_id,
                exc,
            )
            return _HOURLY_LIMIT

    async def get_reset_seconds(self, user_id: str) -> int:
        """Return seconds until the rate-limit window resets for a user.

        Args:
            user_id: The Zuralog user ID.

        Returns:
            Seconds until reset as an integer.  Returns ``3600`` if the
            key does not exist or Redis is unavailable.
        """
        try:
            import redis.asyncio as aioredis

            async with aioredis.from_url(self._redis_url) as redis:
                value = await redis.get(self._reset_key(user_id))
                return int(value) if value is not None else _TTL_SECONDS
        except Exception as exc:  # noqa: BLE001
            logger.warning(
                "Redis unavailable, returning default reset for user '%s': %s",
                user_id,
                exc,
            )
            return _TTL_SECONDS
