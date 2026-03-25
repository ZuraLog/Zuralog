"""
In-memory TTL cache layer.

Replaces the previous Upstash Redis REST implementation.
Uses a simple dict-based store with expiry timestamps.
Concurrency-safe via asyncio.Lock for use with async FastAPI.

The public interface is identical to the previous implementation —
all consumers (analytics, integrations, users, health_ingest) work unchanged.
"""

import asyncio
import fnmatch
import json
import logging
import time
from collections import OrderedDict
from collections.abc import Callable
from functools import wraps
from typing import Any

from app.config import settings

logger = logging.getLogger(__name__)


class CacheService:
    """In-memory TTL cache with the same interface as the previous Upstash implementation.

    Keys expire automatically on read (lazy eviction).
    The store is process-local — cache is lost on restart/redeploy,
    which is acceptable since caching is a performance optimisation, not a source of truth.
    """

    def __init__(self) -> None:
        """Initialize the in-memory cache service."""
        self._store: OrderedDict[str, tuple[Any, float]] = OrderedDict()  # key -> (value, expires_at)
        self._lock = asyncio.Lock()
        self._max_size: int = 10_000
        self.enabled = True
        logger.info("CacheService initialized (in-memory TTL)")

    async def get(self, key: str) -> Any | None:
        """Retrieve a cached value by key.

        Args:
            key: The cache key.

        Returns:
            The cached value (already deserialised), or None if missing/expired.
        """
        async with self._lock:
            entry = self._store.get(key)
            if entry is None:
                return None
            value, expires_at = entry
            if time.monotonic() > expires_at:
                del self._store[key]
                return None
            self._store.move_to_end(key)  # promote to most-recently-used
            return value

    async def set(self, key: str, value: Any, ttl: int | None = None) -> None:
        """Store a value in the cache.

        Args:
            key: The cache key.
            value: The value to cache (must be JSON-serializable).
            ttl: Time-to-live in seconds. None = no expiry (stores indefinitely).
        """
        try:
            # Serialise to JSON string for consistency with previous implementation,
            # then store the deserialised form so get() returns usable objects.
            serialised = json.dumps(value, default=str)
            parsed = json.loads(serialised)
        except (TypeError, ValueError):
            parsed = value

        expires_at = time.monotonic() + ttl if ttl else float("inf")
        async with self._lock:
            self._store[key] = (parsed, expires_at)
            self._store.move_to_end(key)  # mark as most-recently-used
            if len(self._store) > self._max_size:
                self._store.popitem(last=False)  # evict least-recently-used (oldest)

    async def delete(self, key: str) -> None:
        """Delete a single cache entry.

        Args:
            key: The cache key to delete.
        """
        async with self._lock:
            self._store.pop(key, None)

    async def invalidate_pattern(self, pattern: str) -> int:
        """Delete all keys matching a glob pattern.

        Args:
            pattern: Glob pattern (e.g., 'cache:analytics:user123:*').

        Returns:
            Number of keys deleted.
        """
        async with self._lock:
            keys_to_delete = [k for k in self._store if fnmatch.fnmatch(k, pattern)]
            for k in keys_to_delete:
                del self._store[k]
        count = len(keys_to_delete)
        if count:
            logger.debug("Cache invalidated %d keys matching '%s'", count, pattern)
        return count

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

    Convention:
        If a kwarg named `force_refresh=True` is present when the wrapped
        function is called, the cache hit is skipped and the handler re-runs,
        but the fresh result is still written back to cache. Endpoints that
        want to expose this capability should declare `force_refresh` as a
        Query parameter — do not reuse this kwarg name for other purposes.

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

            # Attempt cache hit — skipped when caller passes force_refresh=True
            force_refresh = kwargs.get("force_refresh", False)
            if cache_service and not force_refresh:
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
