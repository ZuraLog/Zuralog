# tests/test_fitbit_rate_limiter.py
"""Tests for FitbitRateLimiter — per-user Redis-backed rate limiting."""

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.fitbit_rate_limiter import FitbitRateLimiter


@pytest.fixture
def limiter():
    return FitbitRateLimiter(redis_url="redis://localhost:6379/0")


class TestCheckAndIncrement:
    """Tests for the primary quota check-and-decrement flow."""

    @pytest.mark.asyncio
    async def test_allows_when_quota_available(self, limiter):
        """Returns True and decrements when quota remains."""
        mock_redis = AsyncMock()
        mock_redis.exists.return_value = True
        mock_redis.get.return_value = b"50"

        with patch("redis.asyncio.from_url") as mock_from_url:
            mock_cm = AsyncMock()
            mock_cm.__aenter__.return_value = mock_redis
            mock_cm.__aexit__.return_value = False
            mock_from_url.return_value = mock_cm

            result = await limiter.check_and_increment("user-123")

        assert result is True
        mock_redis.decr.assert_called_once()

    @pytest.mark.asyncio
    async def test_blocks_when_quota_exhausted(self, limiter):
        """Returns False when remaining count is 0."""
        mock_redis = AsyncMock()
        mock_redis.exists.return_value = True
        mock_redis.get.return_value = b"0"

        with patch("redis.asyncio.from_url") as mock_from_url:
            mock_cm = AsyncMock()
            mock_cm.__aenter__.return_value = mock_redis
            mock_cm.__aexit__.return_value = False
            mock_from_url.return_value = mock_cm

            result = await limiter.check_and_increment("user-123")

        assert result is False
        mock_redis.decr.assert_not_called()

    @pytest.mark.asyncio
    async def test_initializes_bucket_when_key_missing(self, limiter):
        """Creates bucket at 150 with TTL when the key does not exist."""
        mock_redis = AsyncMock()
        mock_redis.exists.return_value = False
        mock_redis.get.return_value = b"150"

        with patch("redis.asyncio.from_url") as mock_from_url:
            mock_cm = AsyncMock()
            mock_cm.__aenter__.return_value = mock_redis
            mock_cm.__aexit__.return_value = False
            mock_from_url.return_value = mock_cm

            result = await limiter.check_and_increment("user-new")

        assert result is True
        mock_redis.set.assert_called_once_with(
            "fitbit:rate:user-new:remaining", 150, ex=3600
        )

    @pytest.mark.asyncio
    async def test_fail_open_when_redis_unavailable(self, limiter):
        """Returns True (fail-open) when Redis raises an exception."""
        with patch("redis.asyncio.from_url", side_effect=Exception("connection refused")):
            result = await limiter.check_and_increment("user-123")

        assert result is True

    @pytest.mark.asyncio
    async def test_per_user_isolation(self, limiter):
        """Different user_ids use different Redis keys."""
        keys_checked: list[str] = []

        # Build a synchronous context manager that records which keys are checked
        def make_mock_redis():
            mock_redis = AsyncMock()

            async def fake_exists(key: str) -> int:
                keys_checked.append(key)
                return 1  # key exists

            mock_redis.exists.side_effect = fake_exists
            mock_redis.get.return_value = b"100"
            return mock_redis

        def make_context(_url: str):
            """Return a synchronous context manager (as from_url does)."""
            redis_instance = make_mock_redis()

            class SyncCtx:
                async def __aenter__(self_inner):
                    return redis_instance

                async def __aexit__(self_inner, *args):
                    return False

            return SyncCtx()

        with patch("redis.asyncio.from_url", side_effect=make_context):
            await limiter.check_and_increment("user-A")
            await limiter.check_and_increment("user-B")

        assert "fitbit:rate:user-A:remaining" in keys_checked
        assert "fitbit:rate:user-B:remaining" in keys_checked


class TestUpdateFromHeaders:
    """Tests for authoritative header-based rate limit updates."""

    @pytest.mark.asyncio
    async def test_updates_remaining_and_reset_in_redis(self, limiter):
        """update_from_headers writes both remaining and reset keys."""
        # pipeline() is synchronous in redis.asyncio — use MagicMock, not AsyncMock
        mock_pipe = MagicMock()
        mock_pipe.set = MagicMock()
        mock_pipe.execute = AsyncMock()

        mock_redis = AsyncMock()
        # pipeline() must return the pipe object directly (not a coroutine)
        mock_redis.pipeline = MagicMock(return_value=mock_pipe)

        with patch("redis.asyncio.from_url") as mock_from_url:
            mock_cm = AsyncMock()
            mock_cm.__aenter__.return_value = mock_redis
            mock_cm.__aexit__.return_value = False
            mock_from_url.return_value = mock_cm

            await limiter.update_from_headers(
                user_id="user-123", remaining=42, reset_seconds=1800
            )

        mock_redis.pipeline.assert_called_once()
        mock_pipe.set.assert_any_call(
            "fitbit:rate:user-123:remaining", 42, ex=1800
        )
        mock_pipe.set.assert_any_call(
            "fitbit:rate:user-123:reset", 1800, ex=1800
        )
        mock_pipe.execute.assert_called_once()

    @pytest.mark.asyncio
    async def test_fails_silently_when_redis_unavailable(self, limiter):
        """update_from_headers does not raise when Redis is down."""
        with patch("redis.asyncio.from_url", side_effect=Exception("redis down")):
            # Should not raise
            await limiter.update_from_headers("user-123", 100, 3600)


class TestGetRemaining:
    """Tests for reading the remaining request count."""

    @pytest.mark.asyncio
    async def test_returns_value_from_redis(self, limiter):
        """Returns the integer value stored in Redis."""
        mock_redis = AsyncMock()
        mock_redis.get.return_value = b"77"

        with patch("redis.asyncio.from_url") as mock_from_url:
            mock_cm = AsyncMock()
            mock_cm.__aenter__.return_value = mock_redis
            mock_cm.__aexit__.return_value = False
            mock_from_url.return_value = mock_cm

            result = await limiter.get_remaining("user-123")

        assert result == 77

    @pytest.mark.asyncio
    async def test_returns_150_when_key_missing(self, limiter):
        """Returns default of 150 when key does not exist."""
        mock_redis = AsyncMock()
        mock_redis.get.return_value = None

        with patch("redis.asyncio.from_url") as mock_from_url:
            mock_cm = AsyncMock()
            mock_cm.__aenter__.return_value = mock_redis
            mock_cm.__aexit__.return_value = False
            mock_from_url.return_value = mock_cm

            result = await limiter.get_remaining("user-new")

        assert result == 150

    @pytest.mark.asyncio
    async def test_returns_150_when_redis_unavailable(self, limiter):
        """Returns default of 150 on Redis error (fail-open)."""
        with patch("redis.asyncio.from_url", side_effect=Exception("down")):
            result = await limiter.get_remaining("user-123")
        assert result == 150


class TestGetResetSeconds:
    """Tests for reading the seconds-until-reset value."""

    @pytest.mark.asyncio
    async def test_returns_value_from_redis(self, limiter):
        """Returns the integer reset seconds stored in Redis."""
        mock_redis = AsyncMock()
        mock_redis.get.return_value = b"1234"

        with patch("redis.asyncio.from_url") as mock_from_url:
            mock_cm = AsyncMock()
            mock_cm.__aenter__.return_value = mock_redis
            mock_cm.__aexit__.return_value = False
            mock_from_url.return_value = mock_cm

            result = await limiter.get_reset_seconds("user-123")

        assert result == 1234

    @pytest.mark.asyncio
    async def test_returns_3600_when_key_missing(self, limiter):
        """Returns default of 3600 when key does not exist."""
        mock_redis = AsyncMock()
        mock_redis.get.return_value = None

        with patch("redis.asyncio.from_url") as mock_from_url:
            mock_cm = AsyncMock()
            mock_cm.__aenter__.return_value = mock_redis
            mock_cm.__aexit__.return_value = False
            mock_from_url.return_value = mock_cm

            result = await limiter.get_reset_seconds("user-123")

        assert result == 3600

    @pytest.mark.asyncio
    async def test_returns_3600_when_redis_unavailable(self, limiter):
        """Returns default of 3600 on Redis error (fail-open)."""
        with patch("redis.asyncio.from_url", side_effect=Exception("down")):
            result = await limiter.get_reset_seconds("user-123")
        assert result == 3600
