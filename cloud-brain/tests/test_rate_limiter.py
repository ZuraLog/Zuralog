"""
Zuralog Cloud Brain — Rate Limiter Service Tests.

Tests the Redis-backed per-user rate limiting with tiered limits.
Uses a mocked Redis client.
"""

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.rate_limiter import RateLimiter, ModelLimitResult
from app.config import FREE_FLASH_DAILY, FREE_ZURA_DAILY, PRO_FLASH_WEEKLY, PRO_ZURA_WEEKLY


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


class TestCheckModelLimits:
    """Tests for RateLimiter.check_model_limits()"""

    def _make_limiter(self):
        mock_redis = MagicMock()
        mock_redis.eval = AsyncMock()
        mock_redis.pipeline = MagicMock()
        limiter = RateLimiter(redis_client=mock_redis)
        return limiter, mock_redis

    @pytest.mark.asyncio
    async def test_both_available(self):
        """Both models have remaining capacity."""
        limiter, mock_redis = self._make_limiter()
        # flash_used=5, zura_used=2, burst_used=8, flash_ttl=43200, zura_ttl=43200, burst_ttl=14400
        mock_redis.eval = AsyncMock(return_value=[5, 2, 8, 43200, 43200, 14400])
        result = await limiter.check_model_limits("user1", "free")
        assert result.flash_allowed is True
        assert result.zura_allowed is True
        assert result.burst_allowed is True
        assert result.flash_remaining == FREE_FLASH_DAILY - 5
        assert result.zura_remaining == FREE_ZURA_DAILY - 2

    @pytest.mark.asyncio
    async def test_flash_exhausted(self):
        """Flash bucket is exhausted, Zura still available."""
        limiter, mock_redis = self._make_limiter()
        mock_redis.eval = AsyncMock(return_value=[20, 2, 8, 43200, 43200, 14400])
        result = await limiter.check_model_limits("user1", "free")
        assert result.flash_allowed is False
        assert result.zura_allowed is True
        assert result.flash_remaining == 0

    @pytest.mark.asyncio
    async def test_zura_exhausted(self):
        """Zura bucket is exhausted, Flash still available."""
        limiter, mock_redis = self._make_limiter()
        mock_redis.eval = AsyncMock(return_value=[5, 5, 8, 43200, 43200, 14400])
        result = await limiter.check_model_limits("user1", "free")
        assert result.flash_allowed is True
        assert result.zura_allowed is False
        assert result.zura_remaining == 0

    @pytest.mark.asyncio
    async def test_both_exhausted(self):
        """Both buckets are exhausted."""
        limiter, mock_redis = self._make_limiter()
        mock_redis.eval = AsyncMock(return_value=[20, 5, 18, 43200, 43200, 14400])
        result = await limiter.check_model_limits("user1", "free")
        assert result.flash_allowed is False
        assert result.zura_allowed is False
        assert result.flash_remaining == 0
        assert result.zura_remaining == 0

    @pytest.mark.asyncio
    async def test_burst_exhausted(self):
        """Burst window is exhausted even if individual buckets have capacity."""
        limiter, mock_redis = self._make_limiter()
        mock_redis.eval = AsyncMock(return_value=[5, 2, 20, 43200, 43200, 14400])
        result = await limiter.check_model_limits("user1", "free")
        assert result.burst_allowed is False
        assert result.burst_remaining == 0

    @pytest.mark.asyncio
    async def test_premium_weekly_limits(self):
        """Premium tier uses weekly limits (350 flash, 60 zura)."""
        limiter, mock_redis = self._make_limiter()
        mock_redis.eval = AsyncMock(return_value=[100, 30, 20, 604800, 604800, 14400])
        result = await limiter.check_model_limits("user1", "premium")
        assert result.flash_limit == PRO_FLASH_WEEKLY
        assert result.zura_limit == PRO_ZURA_WEEKLY
        assert result.flash_remaining == PRO_FLASH_WEEKLY - 100
        assert result.zura_remaining == PRO_ZURA_WEEKLY - 30

    @pytest.mark.asyncio
    async def test_redis_failure_fails_closed(self):
        """Redis error causes fail-closed: all models denied."""
        limiter, mock_redis = self._make_limiter()
        import redis.asyncio as aioredis
        mock_redis.eval = AsyncMock(side_effect=aioredis.RedisError("connection failed"))
        result = await limiter.check_model_limits("user1", "free")
        assert result.flash_allowed is False
        assert result.zura_allowed is False
        assert result.burst_allowed is False
        assert result.flash_remaining == 0

    @pytest.mark.asyncio
    async def test_increment_flash_calls_pipeline(self):
        """increment_model_usage for zura_flash increments the flash key and burst key."""
        limiter, mock_redis = self._make_limiter()
        mock_pipeline = MagicMock()
        mock_pipeline.eval = MagicMock()
        mock_pipeline.execute = AsyncMock(return_value=[1, 1])
        mock_redis.pipeline = MagicMock(return_value=mock_pipeline)
        await limiter.increment_model_usage("user1", "free", "zura_flash")
        assert mock_pipeline.eval.call_count == 2

    @pytest.mark.asyncio
    async def test_increment_zura_calls_pipeline(self):
        """increment_model_usage for zura increments the zura key and burst key."""
        limiter, mock_redis = self._make_limiter()
        mock_pipeline = MagicMock()
        mock_pipeline.eval = MagicMock()
        mock_pipeline.execute = AsyncMock(return_value=[1, 1])
        mock_redis.pipeline = MagicMock(return_value=mock_pipeline)
        await limiter.increment_model_usage("user1", "free", "zura")
        assert mock_pipeline.eval.call_count == 2

    @pytest.mark.asyncio
    async def test_increment_redis_failure_swallowed(self):
        """increment_model_usage swallows Redis errors without raising."""
        limiter, mock_redis = self._make_limiter()
        import redis.asyncio as aioredis
        mock_redis.pipeline = MagicMock(side_effect=aioredis.RedisError("down"))
        # Should not raise
        await limiter.increment_model_usage("user1", "free", "zura_flash")
