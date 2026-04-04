"""Tests for RateLimiter fail-closed behaviour on Redis errors."""

from __future__ import annotations

import pytest
import redis.asyncio as aioredis
from unittest.mock import AsyncMock

from app.services.rate_limiter import RateLimiter


def _limiter_with_failing_redis() -> RateLimiter:
    limiter = RateLimiter.__new__(RateLimiter)
    mock_redis = AsyncMock()
    mock_redis.eval.side_effect = aioredis.RedisError("connection refused")
    limiter._redis = mock_redis
    limiter._owns_connection = False
    return limiter


class TestRateLimiterFailClosed:
    @pytest.mark.asyncio
    async def test_check_limit_fails_closed_on_redis_error(self):
        limiter = _limiter_with_failing_redis()
        result = await limiter.check_limit("user-abc", tier="free")
        assert result.allowed is False, "Should fail-closed when Redis is unavailable"
        assert result.remaining == 0
        assert result.reset_seconds == 60

    @pytest.mark.asyncio
    async def test_check_burst_limit_fails_closed_on_redis_error(self):
        limiter = _limiter_with_failing_redis()
        result = await limiter.check_burst_limit("user-abc", tier="free")
        assert result.allowed is False
        assert result.remaining == 0
        assert result.reset_seconds == 60

    @pytest.mark.asyncio
    async def test_check_model_limits_fails_closed_on_redis_error(self):
        limiter = _limiter_with_failing_redis()
        result = await limiter.check_model_limits("user-abc", tier="free")
        assert result.flash_allowed is False
        assert result.zura_allowed is False
        assert result.burst_allowed is False
        assert result.flash_remaining == 0
        assert result.zura_remaining == 0
        assert result.burst_remaining == 0
        assert result.flash_reset_seconds == 60
        assert result.zura_reset_seconds == 60
        assert result.burst_reset_seconds == 60

    @pytest.mark.asyncio
    async def test_check_limit_succeeds_when_redis_works(self):
        limiter = RateLimiter.__new__(RateLimiter)
        mock_redis = AsyncMock()
        mock_redis.eval.return_value = 1  # first request of the day
        limiter._redis = mock_redis
        limiter._owns_connection = False
        result = await limiter.check_limit("user-abc", tier="free")
        assert result.allowed is True
        assert result.remaining > 0
