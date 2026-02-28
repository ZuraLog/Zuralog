"""
Zuralog Cloud Brain — Distributed Cache Service.

HTTP REST-based cache layer using the Upstash Redis async SDK.
Provides both direct get/set operations and a decorator for
automatic response caching on FastAPI route handlers.

Runs alongside the existing redis.asyncio connection used by
Celery and the RateLimiter — both share the same Upstash database
but communicate via different protocols (REST vs TCP).
"""

import hashlib
import json
import logging
from collections.abc import Callable
from functools import wraps
from typing import Any

from upstash_redis.asyncio import Redis

from app.config import settings

logger = logging.getLogger(__name__)


class CacheService:
    """Upstash Redis REST cache with JSON serialization.

    Attributes:
        _redis: Upstash Redis REST client instance.
        enabled: Whether caching is active (False when credentials missing).
    """

    def __init__(self) -> None:
        """Initialize the cache service.

        If UPSTASH_REDIS_REST_URL or UPSTASH_REDIS_REST_TOKEN is empty,
        caching is disabled (all operations become no-ops). This allows
        local development without Upstash credentials.
        """
        self.enabled = bool(settings.upstash_redis_rest_url and settings.upstash_redis_rest_token)
        if self.enabled:
            self._redis = Redis(
                url=settings.upstash_redis_rest_url,
                token=settings.upstash_redis_rest_token,
            )
            logger.info("CacheService initialized (Upstash REST)")
        else:
            self._redis = None
            logger.info("CacheService disabled (no Upstash REST credentials)")

    async def get(self, key: str) -> Any | None:
        """Retrieve a cached value by key.

        Args:
            key: The cache key.

        Returns:
            The deserialized cached value, or None if not found / disabled.
        """
        if not self.enabled:
            return None
        try:
            raw = await self._redis.get(key)
            if raw is None:
                return None
            return json.loads(raw) if isinstance(raw, str) else raw
        except Exception:
            logger.warning("Cache GET failed for key=%s", key, exc_info=True)
            return None

    async def set(self, key: str, value: Any, ttl: int | None = None) -> None:
        """Store a value in the cache.

        Args:
            key: The cache key.
            value: The value to cache (must be JSON-serializable).
            ttl: Time-to-live in seconds. None = no expiry.
        """
        if not self.enabled:
            return
        try:
            serialized = json.dumps(value, default=str)
            if ttl:
                await self._redis.setex(key, ttl, serialized)
            else:
                await self._redis.set(key, serialized)
        except Exception:
            logger.warning("Cache SET failed for key=%s", key, exc_info=True)

    async def delete(self, key: str) -> None:
        """Delete a single cache entry.

        Args:
            key: The cache key to delete.
        """
        if not self.enabled:
            return
        try:
            await self._redis.delete(key)
        except Exception:
            logger.warning("Cache DELETE failed for key=%s", key, exc_info=True)

    async def invalidate_pattern(self, pattern: str) -> int:
        """Delete all keys matching a glob pattern.

        Uses SCAN + DELETE to avoid blocking the server with KEYS.

        Args:
            pattern: Glob pattern (e.g., 'cache:analytics:user123:*').

        Returns:
            Number of keys deleted.
        """
        if not self.enabled:
            return 0
        try:
            deleted = 0
            cursor = 0
            while True:
                cursor, keys = await self._redis.scan(cursor, match=pattern, count=100)
                if keys:
                    await self._redis.delete(*keys)
                    deleted += len(keys)
                if cursor == 0:
                    break
            return deleted
        except Exception:
            logger.warning("Cache INVALIDATE failed for pattern=%s", pattern, exc_info=True)
            return 0

    @staticmethod
    def make_key(*parts: str) -> str:
        """Build a namespaced cache key.

        Args:
            *parts: Key components joined by ':'.

        Returns:
            A colon-separated cache key prefixed with 'cache:'.

        Example:
            make_key('analytics', 'daily', 'user123', '2026-02-28')
            → 'cache:analytics:daily:user123:2026-02-28'
        """
        return "cache:" + ":".join(str(p) for p in parts)


def cached(
    prefix: str,
    ttl: int | None = None,
    key_params: list[str] | None = None,
):
    """Decorator for automatic response caching on FastAPI endpoints.

    Caches the JSON-serializable return value of a route handler.
    Cache keys are built from the prefix + specified parameters.

    Args:
        prefix: Cache key namespace (e.g., 'analytics.daily_summary').
        ttl: Time-to-live in seconds. Defaults to cache_ttl_short (300s).
        key_params: List of parameter names to include in the cache key.
                    These must match argument names of the decorated function.

    Usage:
        @router.get("/daily-summary")
        @cached(prefix="analytics.daily_summary", ttl=300, key_params=["user_id", "date_str"])
        async def daily_summary(user_id: str, date_str: str, db: AsyncSession = Depends(get_db)):
            ...

    Notes:
        - The decorator accesses `request.app.state.cache_service`.
        - If cache_service is unavailable or disabled, the handler runs normally.
        - Non-serializable return values fall through to the handler.
    """
    _ttl = ttl or settings.cache_ttl_short

    def decorator(func: Callable) -> Callable:
        @wraps(func)
        async def wrapper(*args, **kwargs):
            # Build cache key from specified params
            parts = [prefix]
            for param in key_params or []:
                val = kwargs.get(param, "")
                parts.append(str(val))
            cache_key = CacheService.make_key(*parts)

            # Try to find cache_service from request.app.state
            cache_service = None
            request = kwargs.get("request") or (args[0] if args and hasattr(args[0], "app") else None)
            if request and hasattr(request, "app"):
                cache_service = getattr(request.app.state, "cache_service", None)

            # Attempt cache hit
            if cache_service:
                cached_value = await cache_service.get(cache_key)
                if cached_value is not None:
                    logger.debug("Cache HIT: %s", cache_key)
                    return cached_value

            # Cache miss — execute handler
            result = await func(*args, **kwargs)

            # Store in cache
            if cache_service and result is not None:
                try:
                    # Convert Pydantic models to dict for serialization
                    if hasattr(result, "model_dump"):
                        serializable = result.model_dump()
                    elif hasattr(result, "dict"):
                        serializable = result.dict()
                    else:
                        serializable = result
                    await cache_service.set(cache_key, serializable, _ttl)
                    logger.debug("Cache SET: %s (TTL=%ds)", cache_key, _ttl)
                except Exception:
                    logger.warning("Failed to cache result for %s", cache_key, exc_info=True)

            return result

        return wrapper

    return decorator
