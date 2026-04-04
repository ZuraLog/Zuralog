"""
Zuralog Cloud Brain — Per-User Rate Limiter Service.

Redis-backed fixed-window counter for enforcing subscription-tier
rate limits on LLM endpoints. Works alongside the existing slowapi
IP-level rate limiter for different concerns:

- slowapi: IP-level abuse prevention (brute force, DDoS)
- RateLimiter: Per-user LLM cost control (Free vs Premium tiers)
"""

import logging
import re
import time
from dataclasses import dataclass

import redis.asyncio as redis

from app.config import (
    FREE_BURST_5H, FREE_FLASH_DAILY, FREE_ZURA_DAILY,
    PRO_BURST_5H, PRO_FLASH_WEEKLY, PRO_ZURA_WEEKLY,
    BURST_WINDOW_SECONDS,
)
from app.config import settings

logger = logging.getLogger(__name__)

_UUID_RE = re.compile(
    r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$",
    re.IGNORECASE,
)


def _load_bypass_set() -> frozenset[str]:
    """Parse and validate RATE_LIMIT_BYPASS_USER_IDS at startup.

    Only accepts properly-formatted UUIDs. Any malformed entry is logged
    and dropped — it can never silently grant bypass to an unexpected ID.
    """
    raw = settings.rate_limit_bypass_user_ids.strip()
    if not raw:
        return frozenset()
    result: set[str] = set()
    for entry in raw.split(","):
        uid = entry.strip().lower()
        if not uid:
            continue
        if _UUID_RE.match(uid):
            result.add(uid)
        else:
            logger.error(
                "RATE_LIMIT_BYPASS_USER_IDS: ignored malformed entry %r — must be a UUID",
                uid,
            )
    if result:
        logger.info(
            "Rate limit bypass active for %d user ID(s). "
            "LLM quotas only — auth and IP limits remain enforced.",
            len(result),
        )
    return frozenset(result)


# Parsed once at import time from the server-side environment variable.
# Immutable after startup — cannot be changed without a redeploy.
_BYPASS_USER_IDS: frozenset[str] = _load_bypass_set()

_INCR_EXPIRE_SCRIPT = """
local current = redis.call('INCR', KEYS[1])
if current == 1 then
  redis.call('EXPIRE', KEYS[1], ARGV[1])
end
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


_READ_THREE_SCRIPT = """
local v1 = redis.call('GET', KEYS[1]) or '0'
local v2 = redis.call('GET', KEYS[2]) or '0'
local v3 = redis.call('GET', KEYS[3]) or '0'
local t1 = redis.call('TTL', KEYS[1])
local t2 = redis.call('TTL', KEYS[2])
local t3 = redis.call('TTL', KEYS[3])
return {tonumber(v1), tonumber(v2), tonumber(v3), t1, t2, t3}
"""


@dataclass
class ModelLimitResult:
    """Result of a dual-model limit check."""
    flash_allowed: bool
    zura_allowed: bool
    burst_allowed: bool
    flash_remaining: int
    zura_remaining: int
    burst_remaining: int
    flash_limit: int
    zura_limit: int
    burst_limit: int
    flash_reset_seconds: int
    zura_reset_seconds: int
    burst_reset_seconds: int


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
            current = int(await self._redis.eval(_INCR_EXPIRE_SCRIPT, 1, redis_key, "86400"))  # type: ignore[misc]

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
            logger.error("Redis unavailable in rate limiter — failing closed: %s", exc)
            # reset_seconds=60: conservative retry hint; real TTL is unavailable during Redis failure
            return RateLimitResult(
                allowed=False,
                limit=limit,
                remaining=0,
                reset_seconds=60,
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
            current = int(await self._redis.eval(_INCR_EXPIRE_SCRIPT, 1, redis_key, "60"))  # type: ignore[misc]

            return RateLimitResult(
                allowed=current <= limit,
                limit=limit,
                remaining=max(0, limit - current),
                reset_seconds=reset_seconds,
            )
        except redis.RedisError as exc:
            logger.error("Redis unavailable in burst limiter — failing closed: %s", exc)
            # reset_seconds=60: conservative retry hint; real TTL is unavailable during Redis failure
            return RateLimitResult(
                allowed=False,
                limit=limit,
                remaining=0,
                reset_seconds=60,
            )

    @staticmethod
    def _resolve_model_keys(user_id: str, tier: str):
        import datetime as _dt
        burst_key = f"burst:window:{user_id}"
        burst_ttl = BURST_WINDOW_SECONDS
        if tier == "premium":
            iso = _dt.date.today().isocalendar()
            wk = f"{iso.year}-W{iso.week:02d}"
            flash_key = f"limit:flash:weekly:{user_id}:{wk}"
            zura_key = f"limit:zura:weekly:{user_id}:{wk}"
            return (flash_key, zura_key, burst_key,
                    PRO_FLASH_WEEKLY, PRO_ZURA_WEEKLY, PRO_BURST_5H,
                    7*86400, 7*86400, burst_ttl)
        day = _dt.date.today().isoformat()
        flash_key = f"limit:flash:daily:{user_id}:{day}"
        zura_key = f"limit:zura:daily:{user_id}:{day}"
        return (flash_key, zura_key, burst_key,
                FREE_FLASH_DAILY, FREE_ZURA_DAILY, FREE_BURST_5H,
                86400, 86400, burst_ttl)

    async def check_model_limits(self, user_id: str, tier: str = "free") -> ModelLimitResult:
        """Check per-model limits for a user (read-only, does not increment).

        Args:
            user_id: The authenticated user's ID.
            tier: Subscription tier ('free' or 'premium').

        Returns:
            A ModelLimitResult with the current state of all three buckets.
        """
        if (
            _BYPASS_USER_IDS
            and _UUID_RE.match(user_id)          # user_id must be a valid UUID — no exceptions
            and user_id.lower() in _BYPASS_USER_IDS
        ):
            logger.info("Rate limit bypass used by user %s", user_id[:8])
            (_, _, _, fl, zl, bl, _, _, _) = self._resolve_model_keys(user_id, tier)
            return ModelLimitResult(
                flash_allowed=True, zura_allowed=True, burst_allowed=True,
                flash_remaining=fl, zura_remaining=zl, burst_remaining=bl,
                flash_limit=fl, zura_limit=zl, burst_limit=bl,
                flash_reset_seconds=0, zura_reset_seconds=0, burst_reset_seconds=0,
            )

        (fk, zk, bk, fl, zl, bl, ft, zt, bt) = self._resolve_model_keys(user_id, tier)
        try:
            vals = await self._redis.eval(_READ_THREE_SCRIPT, 3, fk, zk, bk)  # type: ignore[misc]
            fu = int(vals[0] or 0)
            zu = int(vals[1] or 0)
            bu = int(vals[2] or 0)
            raw_ttls = [int(vals[3]), int(vals[4]), int(vals[5])]
            # TTL = -1 means key exists but has no expiry (EXPIRE failed after INCR).
            # Reactively fix it: set the correct TTL in the background.
            for key, raw_ttl, window in ((fk, raw_ttls[0], ft), (zk, raw_ttls[1], zt), (bk, raw_ttls[2], bt)):
                if raw_ttl == -1:
                    import asyncio as _asyncio

                    async def _fix_expiry(k: str, w: int) -> None:
                        try:
                            await self._redis.expire(k, w)
                        except Exception:
                            pass

                    _asyncio.create_task(_fix_expiry(key, window))
            fr = max(raw_ttls[0], 0)
            zr = max(raw_ttls[1], 0)
            br = max(raw_ttls[2], 0)
        except redis.RedisError as exc:
            logger.error("Redis unavailable in check_model_limits — failing closed: %s", exc)
            # reset_seconds=60: conservative retry hint; real TTL is unavailable during Redis failure
            return ModelLimitResult(
                flash_allowed=False, zura_allowed=False, burst_allowed=False,
                flash_remaining=0, zura_remaining=0, burst_remaining=0,
                flash_limit=fl, zura_limit=zl, burst_limit=bl,
                flash_reset_seconds=60, zura_reset_seconds=60, burst_reset_seconds=60)
        frem = max(0, fl - fu)
        zrem = max(0, zl - zu)
        brem = max(0, bl - bu)
        return ModelLimitResult(
            flash_allowed=frem > 0,
            zura_allowed=zrem > 0,
            burst_allowed=brem > 0,
            flash_remaining=frem,
            zura_remaining=zrem,
            burst_remaining=brem,
            flash_limit=fl,
            zura_limit=zl,
            burst_limit=bl,
            flash_reset_seconds=fr if fr > 0 else ft,
            zura_reset_seconds=zr if zr > 0 else zt,
            burst_reset_seconds=br if br > 0 else bt)

    async def increment_model_usage(self, user_id: str, tier: str, model_tier: str) -> None:
        """Atomically increment the model bucket and 5-hour burst window counter.

        Args:
            user_id: The authenticated user's ID.
            tier: Subscription tier ('free' or 'premium').
            model_tier: Which model was used ('zura_flash' or 'zura').
        """
        if user_id.lower() in _BYPASS_USER_IDS:
            return  # Do not count usage for bypass accounts.

        (fk, zk, bk, _, _, _, ft, zt, bt) = self._resolve_model_keys(user_id, tier)
        mk = fk if model_tier == "zura_flash" else zk
        mt = ft if model_tier == "zura_flash" else zt
        try:
            pipe = self._redis.pipeline(transaction=False)
            pipe.eval(_INCR_EXPIRE_SCRIPT, 1, mk, str(mt))
            pipe.eval(_INCR_EXPIRE_SCRIPT, 1, bk, str(bt))
            results = await pipe.execute()
            for r in results:
                if isinstance(r, Exception):
                    logger.error("Partial failure in increment_model_usage: %s", r)
        except Exception as exc:
            logger.error("Redis error in increment_model_usage: %s", exc)

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
