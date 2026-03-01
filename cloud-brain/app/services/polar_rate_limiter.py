"""
Zuralog Cloud Brain — Polar AccessLink Rate Limit Guardrails.

Polar enforces **app-level** formula-based limits shared across ALL users:
- Short term (15 min): 500 + (num_users × 20)
- Long term (24 hr):   5000 + (num_users × 100)

Polar returns authoritative limits on every API response via headers:
    RateLimit-Usage:  <short_usage>, <long_usage>
    RateLimit-Limit:  <short_limit>, <long_limit>
    RateLimit-Reset:  <short_reset_secs>, <long_reset_secs>

These headers are parsed and cached in Redis after each call so that
subsequent requests use the most up-to-date limits without a round-trip
formula calculation.

Safety margin: requests are blocked at 90% of the limit to leave headroom
for concurrent workers that may have incremented the counter before their
response is processed.

Fail-open policy: if Redis is unavailable, all requests are allowed so
that a Redis outage does not block Polar API calls.

Usage:
    limiter = PolarRateLimiter(redis_url=settings.redis_url)
    if not await limiter.check_and_increment():
        raise HTTPException(429, "Polar app-level rate limit reached")
    response = await polar_client.get(...)
    await limiter.update_from_headers(dict(response.headers))
"""

import logging

logger = logging.getLogger(__name__)

# Window durations (seconds)
SHORT_WINDOW = 900  # 15 minutes
LONG_WINDOW = 86400  # 24 hours

# Formula base constants
SHORT_BASE = 500
SHORT_PER_USER = 20
LONG_BASE = 5000
LONG_PER_USER = 100

# Block at this fraction of the limit to leave headroom for concurrency
SAFETY_MARGIN = 0.90

# Redis key names (all strings, decode_responses=True)
_KEY_SHORT_COUNTER = "polar:rate:short:counter"
_KEY_LONG_COUNTER = "polar:rate:long:counter"
_KEY_SHORT_LIMIT = "polar:rate:short:limit"
_KEY_LONG_LIMIT = "polar:rate:long:limit"
_KEY_SHORT_RESET = "polar:rate:short:reset"
_KEY_LONG_RESET = "polar:rate:long:reset"
_KEY_USER_COUNT = "polar:rate:user_count"


class PolarRateLimiter:
    """Redis-backed dual-window app-level rate limiter for Polar AccessLink.

    All users share two counters (15-min and 24-hr). Limits are dynamically
    computed from the user count formula, but are overridden by authoritative
    values returned in Polar response headers.

    ``check_and_increment`` uses a pipeline to atomically increment both
    counters, then checks each against its safety threshold.

    Fail-open: returns True when Redis is unavailable.
    """

    def __init__(self, redis_url: str) -> None:
        self._redis_url = redis_url

    async def check_and_increment(self) -> bool:
        """Check whether a Polar API call is allowed and increment counters.

        Returns True if allowed, False if rate-limited.
        Fails open when Redis is unavailable.

        Logic:
          1. Get dynamic limits (from Redis headers cache, or formula fallback)
          2. INCR both counters in a pipeline
          3. Set TTL on first increment (count == 1)
          4. Check if short_count > short_limit * SAFETY_MARGIN → return False
          5. Check if long_count > long_limit * SAFETY_MARGIN → return False
          6. Return True
        """
        try:
            import redis.asyncio as aioredis

            async with aioredis.from_url(self._redis_url, decode_responses=True) as r:
                short_limit, long_limit = await self._get_dynamic_limits(r)

                async with r.pipeline() as pipe:
                    pipe.incr(_KEY_SHORT_COUNTER)
                    pipe.incr(_KEY_LONG_COUNTER)
                    results = await pipe.execute()

                short_count, long_count = results[0], results[1]

                # Set TTL only on the very first increment (avoids resetting existing windows)
                if short_count == 1:
                    await r.expire(_KEY_SHORT_COUNTER, SHORT_WINDOW)
                if long_count == 1:
                    await r.expire(_KEY_LONG_COUNTER, LONG_WINDOW)

                short_threshold = short_limit * SAFETY_MARGIN
                if short_count > short_threshold:
                    logger.warning(
                        "Polar short-window rate limit threshold reached (count=%d, limit=%d, threshold=%.0f)",
                        short_count,
                        short_limit,
                        short_threshold,
                    )
                    return False

                long_threshold = long_limit * SAFETY_MARGIN
                if long_count > long_threshold:
                    logger.warning(
                        "Polar long-window rate limit threshold reached (count=%d, limit=%d, threshold=%.0f)",
                        long_count,
                        long_limit,
                        long_threshold,
                    )
                    return False

                return True

        except Exception as exc:  # noqa: BLE001
            logger.warning("Redis unavailable, skipping Polar rate limit check: %s", exc)
            return True  # fail-open

    async def update_from_headers(self, headers: dict) -> None:
        """Update rate limit state from Polar response headers.

        Parses RateLimit-Usage, RateLimit-Limit, and RateLimit-Reset
        (each a comma-separated pair of short/long values).

        Stores limits as authoritative overrides for future requests.
        Preserves existing TTL when updating usage counters.
        Fails open on any error.
        """
        try:
            import redis.asyncio as aioredis

            usage_header = headers.get("RateLimit-Usage")
            limit_header = headers.get("RateLimit-Limit")
            reset_header = headers.get("RateLimit-Reset")

            if not any([usage_header, limit_header, reset_header]):
                return  # nothing to update

            async with aioredis.from_url(self._redis_url, decode_responses=True) as r:
                if usage_header:
                    parts = [v.strip() for v in usage_header.split(",")]
                    if len(parts) == 2:
                        short_usage, long_usage = parts[0], parts[1]

                        # Preserve existing TTL; default to window duration on first write
                        short_ttl = await r.ttl(_KEY_SHORT_COUNTER)
                        long_ttl = await r.ttl(_KEY_LONG_COUNTER)

                        await r.set(
                            _KEY_SHORT_COUNTER,
                            short_usage,
                            ex=max(short_ttl, 1) if short_ttl > 0 else SHORT_WINDOW,
                        )
                        await r.set(
                            _KEY_LONG_COUNTER,
                            long_usage,
                            ex=max(long_ttl, 1) if long_ttl > 0 else LONG_WINDOW,
                        )

                if limit_header:
                    parts = [v.strip() for v in limit_header.split(",")]
                    if len(parts) == 2:
                        await r.set(_KEY_SHORT_LIMIT, parts[0])
                        await r.set(_KEY_LONG_LIMIT, parts[1])

                if reset_header:
                    parts = [v.strip() for v in reset_header.split(",")]
                    if len(parts) == 2:
                        await r.set(_KEY_SHORT_RESET, parts[0], ex=SHORT_WINDOW)
                        await r.set(_KEY_LONG_RESET, parts[1], ex=LONG_WINDOW)

        except Exception as exc:  # noqa: BLE001
            logger.warning("Failed to update Polar rate limit state from headers: %s", exc)

    async def get_remaining(self) -> tuple[int, int]:
        """Get (short_remaining, long_remaining). Returns (999, 9999) on error."""
        try:
            import redis.asyncio as aioredis

            async with aioredis.from_url(self._redis_url, decode_responses=True) as r:
                short_limit, long_limit = await self._get_dynamic_limits(r)

                short_count_str = await r.get(_KEY_SHORT_COUNTER)
                long_count_str = await r.get(_KEY_LONG_COUNTER)

                short_count = int(short_count_str) if short_count_str is not None else 0
                long_count = int(long_count_str) if long_count_str is not None else 0

                return (
                    max(short_limit - short_count, 0),
                    max(long_limit - long_count, 0),
                )

        except Exception:  # noqa: BLE001
            return (999, 9999)

    async def get_reset_seconds(self) -> tuple[int, int]:
        """Get (short_reset_secs, long_reset_secs). Returns (0, 0) on error."""
        try:
            import redis.asyncio as aioredis

            async with aioredis.from_url(self._redis_url, decode_responses=True) as r:
                short_reset_str = await r.get(_KEY_SHORT_RESET)
                long_reset_str = await r.get(_KEY_LONG_RESET)

                short_reset = int(short_reset_str) if short_reset_str is not None else 0
                long_reset = int(long_reset_str) if long_reset_str is not None else 0

                return (short_reset, long_reset)

        except Exception:  # noqa: BLE001
            return (0, 0)

    async def update_user_count(self, count: int) -> None:
        """Update registered user count for dynamic limit calculation. Fail-open."""
        try:
            import redis.asyncio as aioredis

            async with aioredis.from_url(self._redis_url, decode_responses=True) as r:
                await r.set(_KEY_USER_COUNT, str(count))

        except Exception as exc:  # noqa: BLE001
            logger.warning("Failed to update Polar user count in Redis: %s", exc)

    async def _get_dynamic_limits(self, r) -> tuple[int, int]:
        """Return (short_limit, long_limit), preferring authoritative Redis values.

        If Polar has returned header-based limits, those are used. Otherwise
        the formula (BASE + N × PER_USER) is applied using the stored user count.
        """
        try:
            short_limit_str = await r.get(_KEY_SHORT_LIMIT)
            long_limit_str = await r.get(_KEY_LONG_LIMIT)

            if short_limit_str is not None and long_limit_str is not None:
                return (int(short_limit_str), int(long_limit_str))

            # Fall back to formula
            user_count_str = await r.get(_KEY_USER_COUNT)
            user_count = int(user_count_str) if user_count_str is not None else 0

            return (
                SHORT_BASE + user_count * SHORT_PER_USER,
                LONG_BASE + user_count * LONG_PER_USER,
            )

        except Exception:  # noqa: BLE001
            return (SHORT_BASE, LONG_BASE)
