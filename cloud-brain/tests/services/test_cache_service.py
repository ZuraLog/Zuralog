import pytest
from unittest.mock import MagicMock
from app.services.cache_service import CacheService, cached


@pytest.fixture
def cache():
    return CacheService()


@pytest.mark.asyncio
async def test_cached_returns_hit_on_second_call(cache):
    """Normal behaviour: second call returns cached value without re-executing handler."""
    call_count = 0

    async def handler(*_args, **_kwargs):
        nonlocal call_count
        call_count += 1
        return {"value": "fresh"}

    decorated = cached(prefix="test", ttl=60, key_params=["user_id"])(handler)

    mock_request = MagicMock()
    mock_request.app.state.cache_service = cache

    await decorated(mock_request, user_id="u1")
    await decorated(mock_request, user_id="u1")

    assert call_count == 1  # second call hit cache


@pytest.mark.asyncio
async def test_cached_force_refresh_bypasses_cache(cache):
    """When force_refresh=True, the saved copy is ignored and re-populated."""
    call_count = 0

    async def handler(*_args, **_kwargs):
        nonlocal call_count
        call_count += 1
        return {"value": f"call_{call_count}"}

    decorated = cached(prefix="test", ttl=60, key_params=["user_id"])(handler)

    mock_request = MagicMock()
    mock_request.app.state.cache_service = cache

    result1 = await decorated(mock_request, user_id="u1", force_refresh=False)
    result2 = await decorated(mock_request, user_id="u1", force_refresh=True)

    assert call_count == 2
    assert result1["value"] == "call_1"
    assert result2["value"] == "call_2"
