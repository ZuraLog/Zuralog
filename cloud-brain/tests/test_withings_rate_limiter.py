# tests/test_withings_rate_limiter.py
"""Tests for WithingsRateLimiter — app-level Redis-backed rate limiting (120/min).

Uses an atomic Lua script (INCR + cap) instead of racy GET + DECR.
"""

from unittest.mock import AsyncMock, patch

import pytest

from app.services.withings_rate_limiter import WithingsRateLimiter, _QUOTA, _WINDOW_SECONDS, _REDIS_KEY


@pytest.fixture
def limiter():
    return WithingsRateLimiter(redis_url="redis://localhost:6379")


def _make_mock_context(mock_redis):
    """Return a mock context manager that yields mock_redis on __aenter__."""
    mock_cm = AsyncMock()
    mock_cm.__aenter__.return_value = mock_redis
    mock_cm.__aexit__.return_value = False
    return mock_cm


class TestCheckAndIncrement:
    """Tests for the primary app-level quota check-and-increment (Lua) flow."""

    @pytest.mark.asyncio
    async def test_allows_when_under_limit(self, limiter):
        """Returns True when the Lua script returns a count within quota."""
        mock_redis = AsyncMock()
        mock_redis.eval.return_value = 1

        with patch("redis.asyncio.from_url") as mock_from_url:
            mock_from_url.return_value = _make_mock_context(mock_redis)
            result = await limiter.check_and_increment()

        assert result is True
        mock_redis.eval.assert_called_once()

    @pytest.mark.asyncio
    async def test_allows_at_exact_quota(self, limiter):
        """Returns True when the Lua script returns exactly the quota cap."""
        mock_redis = AsyncMock()
        mock_redis.eval.return_value = _QUOTA

        with patch("redis.asyncio.from_url") as mock_from_url:
            mock_from_url.return_value = _make_mock_context(mock_redis)
            result = await limiter.check_and_increment()

        assert result is True

    @pytest.mark.asyncio
    async def test_blocks_when_over_quota(self, limiter):
        """Returns False when the Lua script returns a count exceeding the quota."""
        mock_redis = AsyncMock()
        mock_redis.eval.return_value = _QUOTA + 1

        with patch("redis.asyncio.from_url") as mock_from_url:
            mock_from_url.return_value = _make_mock_context(mock_redis)
            result = await limiter.check_and_increment()

        assert result is False

    @pytest.mark.asyncio
    async def test_lua_script_called_with_correct_args(self, limiter):
        """Lua eval is called with the correct key, quota, and window args."""
        mock_redis = AsyncMock()
        mock_redis.eval.return_value = 42

        with patch("redis.asyncio.from_url") as mock_from_url:
            mock_from_url.return_value = _make_mock_context(mock_redis)
            await limiter.check_and_increment()

        call_args = mock_redis.eval.call_args
        assert call_args[0][1] == 1  # num_keys
        assert call_args[0][2] == _REDIS_KEY
        assert call_args[0][3] == _QUOTA
        assert call_args[0][4] == _WINDOW_SECONDS

    @pytest.mark.asyncio
    async def test_fail_open_on_redis_error(self, limiter):
        """Returns True (fail-open) when Redis raises an exception."""
        with patch("redis.asyncio.from_url", side_effect=Exception("connection refused")):
            result = await limiter.check_and_increment()

        assert result is True


class TestGetRemaining:
    """Tests for reading the current remaining app-level request count."""

    @pytest.mark.asyncio
    async def test_get_remaining_returns_current_value(self, limiter):
        """Returns the integer value stored in Redis."""
        mock_redis = AsyncMock()
        mock_redis.get.return_value = b"80"

        with patch("redis.asyncio.from_url") as mock_from_url:
            mock_from_url.return_value = _make_mock_context(mock_redis)
            result = await limiter.get_remaining()

        assert result == 80

    @pytest.mark.asyncio
    async def test_get_remaining_defaults_to_quota_when_no_key(self, limiter):
        """Returns _QUOTA (full quota) when the Redis key does not exist."""
        mock_redis = AsyncMock()
        mock_redis.get.return_value = None

        with patch("redis.asyncio.from_url") as mock_from_url:
            mock_from_url.return_value = _make_mock_context(mock_redis)
            result = await limiter.get_remaining()

        assert result == _QUOTA

    @pytest.mark.asyncio
    async def test_get_remaining_fail_open(self, limiter):
        """Returns _QUOTA on Redis error (fail-open)."""
        with patch("redis.asyncio.from_url", side_effect=Exception("redis down")):
            result = await limiter.get_remaining()

        assert result == _QUOTA


class TestGetResetSeconds:
    """Tests for reading seconds until the rate limit window resets."""

    @pytest.mark.asyncio
    async def test_get_reset_seconds_returns_ttl(self, limiter):
        """Returns the TTL value from Redis when the key exists."""
        mock_redis = AsyncMock()
        mock_redis.ttl.return_value = 45

        with patch("redis.asyncio.from_url") as mock_from_url:
            mock_from_url.return_value = _make_mock_context(mock_redis)
            result = await limiter.get_reset_seconds()

        assert result == 45

    @pytest.mark.asyncio
    async def test_get_reset_seconds_defaults_when_no_key(self, limiter):
        """Returns _WINDOW_SECONDS (full window) when TTL is 0 or key does not exist."""
        mock_redis = AsyncMock()
        mock_redis.ttl.return_value = 0

        with patch("redis.asyncio.from_url") as mock_from_url:
            mock_from_url.return_value = _make_mock_context(mock_redis)
            result = await limiter.get_reset_seconds()

        assert result == _WINDOW_SECONDS


class TestAppLevelDesign:
    """Tests that verify the app-level (not per-user) design of the limiter."""

    @pytest.mark.asyncio
    async def test_uses_app_level_key_not_user_key(self, limiter):
        """Lua eval must use 'withings:rate:counter' (no user_id component)."""
        mock_redis = AsyncMock()
        mock_redis.eval.return_value = 1

        with patch("redis.asyncio.from_url") as mock_from_url:
            mock_from_url.return_value = _make_mock_context(mock_redis)
            await limiter.check_and_increment()

        call_args = mock_redis.eval.call_args
        key_arg = call_args[0][2]
        assert key_arg == _REDIS_KEY
        assert _REDIS_KEY == "withings:rate:counter"
        assert "user" not in _REDIS_KEY

    def test_quota_is_120_per_minute(self):
        """Verify the quota constant is 120 and window is 1 minute (60s)."""
        assert _QUOTA == 120
        assert _WINDOW_SECONDS == 60
