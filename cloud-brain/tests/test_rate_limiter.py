"""
Life Logger Cloud Brain — Rate Limiter Service Tests.

Tests the Redis-backed per-user rate limiting with tiered limits.
Uses a mocked Redis client.
"""

from unittest.mock import AsyncMock, patch

import pytest

from app.services.rate_limiter import RateLimiter


@pytest.fixture
def mock_redis():
    """Create a mocked async Redis client."""
    r = AsyncMock()
    r.incr = AsyncMock(return_value=1)
    r.expire = AsyncMock()
    return r


@pytest.fixture
def limiter(mock_redis):
    """Create a RateLimiter with mocked Redis."""
    with patch("app.services.rate_limiter.settings") as mock_settings:
        mock_settings.redis_url = "redis://localhost:6379/0"
        rl = RateLimiter()
        rl._redis = mock_redis
        yield rl


@pytest.mark.asyncio
async def test_first_request_allowed(limiter, mock_redis):
    """First request of the day should be allowed."""
    mock_redis.incr.return_value = 1
    result = await limiter.check_limit("user-1", tier="free")
    assert result.allowed is True
    assert result.remaining == 49


@pytest.mark.asyncio
async def test_free_tier_limit_exceeded(limiter, mock_redis):
    """Free tier should be blocked after 50 requests."""
    mock_redis.incr.return_value = 51
    result = await limiter.check_limit("user-1", tier="free")
    assert result.allowed is False
    assert result.remaining == 0


@pytest.mark.asyncio
async def test_premium_tier_higher_limit(limiter, mock_redis):
    """Premium tier should allow up to 500 requests."""
    mock_redis.incr.return_value = 100
    result = await limiter.check_limit("user-1", tier="premium")
    assert result.allowed is True
    assert result.remaining == 400


@pytest.mark.asyncio
async def test_premium_tier_limit_exceeded(limiter, mock_redis):
    """Premium tier should be blocked after 500 requests."""
    mock_redis.incr.return_value = 501
    result = await limiter.check_limit("user-1", tier="premium")
    assert result.allowed is False


@pytest.mark.asyncio
async def test_redis_key_expires(limiter, mock_redis):
    """First request should set TTL on the Redis key."""
    mock_redis.incr.return_value = 1
    await limiter.check_limit("user-1", tier="free")
    mock_redis.expire.assert_called_once()
