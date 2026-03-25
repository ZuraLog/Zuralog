"""Tests that CacheService uses asyncio.Lock (not threading.Lock) and is safe under concurrency."""

import asyncio
import threading

import pytest

from app.services.cache_service import CacheService


def test_cache_service_uses_asyncio_lock():
    """The internal lock must be an asyncio.Lock, not a threading.Lock."""
    service = CacheService()
    assert isinstance(service._lock, asyncio.Lock), (
        f"Expected asyncio.Lock but got {type(service._lock).__name__}. "
        "threading.Lock blocks the event loop — use asyncio.Lock instead."
    )
    assert not isinstance(service._lock, threading.Lock), (
        "CacheService._lock must not be a threading.Lock."
    )


@pytest.mark.asyncio
async def test_concurrent_set_and_get_no_corruption():
    """50 concurrent set/get calls must all complete without errors or data corruption."""
    service = CacheService()
    errors = []

    async def worker(i: int) -> None:
        try:
            key = f"key:{i % 10}"  # deliberate key collision to stress the lock
            await service.set(key, {"n": i}, ttl=60)
            result = await service.get(key)
            # result may have been overwritten by another coroutine — just check type
            assert result is None or isinstance(result, dict), (
                f"Unexpected result type for key {key!r}: {type(result)}"
            )
        except Exception as exc:  # noqa: BLE001
            errors.append(exc)

    await asyncio.gather(*(worker(i) for i in range(50)))

    assert not errors, f"Concurrent access produced {len(errors)} error(s): {errors}"
