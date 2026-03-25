"""Tests that CacheService enforces an LRU cap on _store size."""

import pytest

from app.services.cache_service import CacheService

_LONG_TTL = 3600  # 1 hour — entries should not expire during the test


@pytest.mark.asyncio
async def test_lru_evicts_oldest_entry_when_cap_exceeded():
    """Inserting beyond _max_size evicts the least-recently-used (oldest) entry."""
    service = CacheService()
    service._max_size = 3  # override for test

    await service.set("key1", "v1", ttl=_LONG_TTL)
    await service.set("key2", "v2", ttl=_LONG_TTL)
    await service.set("key3", "v3", ttl=_LONG_TTL)
    await service.set("key4", "v4", ttl=_LONG_TTL)  # should evict key1

    assert len(service._store) == 3, (
        f"Expected 3 entries after cap exceeded, got {len(service._store)}"
    )
    assert "key1" not in service._store, "key1 (oldest) should have been evicted"
    assert "key4" in service._store, "key4 (newest) must still be present"


@pytest.mark.asyncio
async def test_lru_access_promotes_entry():
    """Accessing a key via get() promotes it so it is not the next eviction target."""
    service = CacheService()
    service._max_size = 3

    await service.set("key1", "v1", ttl=_LONG_TTL)
    await service.set("key2", "v2", ttl=_LONG_TTL)
    await service.set("key3", "v3", ttl=_LONG_TTL)

    # Access key2 — promotes it to most-recently-used
    result = await service.get("key2")
    assert result == "v2"

    # Insert key5 — now key1 is oldest (not key2), so key1 should be evicted
    await service.set("key5", "v5", ttl=_LONG_TTL)

    assert len(service._store) == 3, (
        f"Expected 3 entries after promotion + insertion, got {len(service._store)}"
    )
    assert "key2" in service._store, "key2 was recently accessed and must not be evicted"
    assert "key1" not in service._store, "key1 is now oldest and should have been evicted"
    assert "key5" in service._store, "key5 (newest) must be present"
