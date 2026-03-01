# tests/test_polar_rate_limiter.py
"""Tests for PolarRateLimiter — dynamic dual-window app-level rate limiting.

Polar uses formula-based limits shared across all users:
- Short term (15 min): 500 + (num_users × 20)
- Long term (24 hr):   5000 + (num_users × 100)

Response headers carry the authoritative limits on every API call.
"""

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.polar_rate_limiter import (
    PolarRateLimiter,
    SHORT_WINDOW,
    LONG_WINDOW,
    SHORT_BASE,
    SHORT_PER_USER,
    LONG_BASE,
    LONG_PER_USER,
    SAFETY_MARGIN,
)


@pytest.fixture
def limiter():
    return PolarRateLimiter(redis_url="redis://localhost:6379")


def _make_mock_context(mock_redis):
    """Return a mock async context manager that yields mock_redis on __aenter__."""
    mock_cm = AsyncMock()
    mock_cm.__aenter__.return_value = mock_redis
    mock_cm.__aexit__.return_value = False
    return mock_cm


def _make_mock_pipeline(short_count=1, long_count=1):
    """Return a mock pipeline that returns (short_count, long_count) from execute."""
    mock_pipe = AsyncMock()
    mock_pipe.__aenter__ = AsyncMock(return_value=mock_pipe)
    mock_pipe.__aexit__ = AsyncMock(return_value=False)
    mock_pipe.incr = MagicMock()
    mock_pipe.expire = MagicMock()
    mock_pipe.execute = AsyncMock(return_value=[short_count, long_count])
    return mock_pipe


# ---------------------------------------------------------------------------
# TestCheckAndIncrement
# ---------------------------------------------------------------------------


class TestCheckAndIncrement:
    """Tests for dual-window check-and-increment with safety margin."""

    @pytest.mark.asyncio
    async def test_allows_request_under_both_limits(self, limiter):
        """Returns True when both counters are comfortably under their limits."""
        mock_redis = AsyncMock()
        mock_redis.get = AsyncMock(return_value=None)  # no stored limits → formula
        mock_pipe = _make_mock_pipeline(short_count=10, long_count=100)
        mock_redis.pipeline = MagicMock(return_value=mock_pipe)

        with patch("redis.asyncio.from_url") as mock_from_url:
            mock_from_url.return_value = _make_mock_context(mock_redis)
            result = await limiter.check_and_increment()

        assert result is True

    @pytest.mark.asyncio
    async def test_blocks_request_when_short_limit_exceeded(self, limiter):
        """Returns False when the short-window counter exceeds 90% of the limit."""
        mock_redis = AsyncMock()
        # Stored short limit = 520; 90% = 468; count = 470 → blocked
        mock_redis.get = AsyncMock(
            side_effect=lambda key: {
                "polar:rate:short:limit": "520",
                "polar:rate:long:limit": "5100",
                "polar:rate:user_count": "0",
            }.get(key)
        )
        mock_pipe = _make_mock_pipeline(short_count=470, long_count=10)
        mock_redis.pipeline = MagicMock(return_value=mock_pipe)

        with patch("redis.asyncio.from_url") as mock_from_url:
            mock_from_url.return_value = _make_mock_context(mock_redis)
            result = await limiter.check_and_increment()

        assert result is False

    @pytest.mark.asyncio
    async def test_blocks_request_when_long_limit_exceeded(self, limiter):
        """Returns False when the long-window counter exceeds 90% of the limit."""
        mock_redis = AsyncMock()
        # Stored long limit = 5100; 90% = 4590; count = 4600 → blocked
        mock_redis.get = AsyncMock(
            side_effect=lambda key: {
                "polar:rate:short:limit": "520",
                "polar:rate:long:limit": "5100",
                "polar:rate:user_count": "0",
            }.get(key)
        )
        mock_pipe = _make_mock_pipeline(short_count=10, long_count=4600)
        mock_redis.pipeline = MagicMock(return_value=mock_pipe)

        with patch("redis.asyncio.from_url") as mock_from_url:
            mock_from_url.return_value = _make_mock_context(mock_redis)
            result = await limiter.check_and_increment()

        assert result is False

    @pytest.mark.asyncio
    async def test_increments_both_counters(self, limiter):
        """Both short and long pipeline INCR calls are made on every request."""
        mock_redis = AsyncMock()
        mock_redis.get = AsyncMock(return_value=None)
        mock_pipe = _make_mock_pipeline(short_count=1, long_count=1)
        mock_redis.pipeline = MagicMock(return_value=mock_pipe)

        with patch("redis.asyncio.from_url") as mock_from_url:
            mock_from_url.return_value = _make_mock_context(mock_redis)
            await limiter.check_and_increment()

        # incr should have been called twice (once for each counter)
        assert mock_pipe.incr.call_count == 2

    @pytest.mark.asyncio
    async def test_fail_open_on_redis_error(self, limiter):
        """Returns True (fail-open) when Redis raises an exception."""
        with patch("redis.asyncio.from_url", side_effect=Exception("connection refused")):
            result = await limiter.check_and_increment()

        assert result is True

    @pytest.mark.asyncio
    async def test_blocks_when_at_90_percent_of_short_limit(self, limiter):
        """Blocks at exactly 90% of the short limit (boundary condition)."""
        mock_redis = AsyncMock()
        # Formula: 0 users → short = 500; 90% of 500 = 450
        mock_redis.get = AsyncMock(return_value=None)
        mock_pipe = _make_mock_pipeline(short_count=451, long_count=10)
        mock_redis.pipeline = MagicMock(return_value=mock_pipe)

        with patch("redis.asyncio.from_url") as mock_from_url:
            mock_from_url.return_value = _make_mock_context(mock_redis)
            result = await limiter.check_and_increment()

        assert result is False

    @pytest.mark.asyncio
    async def test_blocks_when_at_90_percent_of_long_limit(self, limiter):
        """Blocks at exactly 90% of the long limit (boundary condition)."""
        mock_redis = AsyncMock()
        # Formula: 0 users → long = 5000; 90% of 5000 = 4500
        mock_redis.get = AsyncMock(return_value=None)
        mock_pipe = _make_mock_pipeline(short_count=10, long_count=4501)
        mock_redis.pipeline = MagicMock(return_value=mock_pipe)

        with patch("redis.asyncio.from_url") as mock_from_url:
            mock_from_url.return_value = _make_mock_context(mock_redis)
            result = await limiter.check_and_increment()

        assert result is False


# ---------------------------------------------------------------------------
# TestUpdateFromHeaders
# ---------------------------------------------------------------------------


class TestUpdateFromHeaders:
    """Tests for parsing and storing Polar response headers."""

    @pytest.mark.asyncio
    async def test_updates_limits_from_response_headers(self, limiter):
        """Stores RateLimit-Limit values into Redis as authoritative limits."""
        mock_redis = AsyncMock()
        mock_redis.ttl = AsyncMock(return_value=600)
        mock_redis.set = AsyncMock()

        with patch("redis.asyncio.from_url") as mock_from_url:
            mock_from_url.return_value = _make_mock_context(mock_redis)
            await limiter.update_from_headers(
                {
                    "RateLimit-Usage": "12, 120",
                    "RateLimit-Limit": "520, 5100",
                    "RateLimit-Reset": "784, 72000",
                }
            )

        # Verify limit keys were set
        set_calls = {call.args[0]: call.args[1] for call in mock_redis.set.call_args_list}
        assert set_calls.get("polar:rate:short:limit") == "520"
        assert set_calls.get("polar:rate:long:limit") == "5100"

    @pytest.mark.asyncio
    async def test_updates_usage_from_response_headers(self, limiter):
        """Stores RateLimit-Usage counters into Redis, preserving existing TTL."""
        mock_redis = AsyncMock()
        mock_redis.ttl = AsyncMock(return_value=750)
        mock_redis.set = AsyncMock()

        with patch("redis.asyncio.from_url") as mock_from_url:
            mock_from_url.return_value = _make_mock_context(mock_redis)
            await limiter.update_from_headers(
                {
                    "RateLimit-Usage": "12, 120",
                    "RateLimit-Limit": "520, 5100",
                    "RateLimit-Reset": "784, 72000",
                }
            )

        # Verify counter keys were set with usage values
        set_calls = {call.args[0]: call.args[1] for call in mock_redis.set.call_args_list}
        assert set_calls.get("polar:rate:short:counter") == "12"
        assert set_calls.get("polar:rate:long:counter") == "120"

    @pytest.mark.asyncio
    async def test_updates_reset_from_response_headers(self, limiter):
        """Stores RateLimit-Reset values into Redis."""
        mock_redis = AsyncMock()
        mock_redis.ttl = AsyncMock(return_value=600)
        mock_redis.set = AsyncMock()

        with patch("redis.asyncio.from_url") as mock_from_url:
            mock_from_url.return_value = _make_mock_context(mock_redis)
            await limiter.update_from_headers(
                {
                    "RateLimit-Usage": "12, 120",
                    "RateLimit-Limit": "520, 5100",
                    "RateLimit-Reset": "784, 72000",
                }
            )

        set_calls = {call.args[0]: call.args[1] for call in mock_redis.set.call_args_list}
        assert set_calls.get("polar:rate:short:reset") == "784"
        assert set_calls.get("polar:rate:long:reset") == "72000"

    @pytest.mark.asyncio
    async def test_handles_missing_headers_gracefully(self, limiter):
        """Does not raise when headers are absent — fail-open."""
        mock_redis = AsyncMock()

        with patch("redis.asyncio.from_url") as mock_from_url:
            mock_from_url.return_value = _make_mock_context(mock_redis)
            # Should not raise
            await limiter.update_from_headers({})

    @pytest.mark.asyncio
    async def test_parses_comma_separated_values(self, limiter):
        """Parses 'val1, val2' with leading/trailing whitespace correctly."""
        mock_redis = AsyncMock()
        mock_redis.ttl = AsyncMock(return_value=400)
        mock_redis.set = AsyncMock()

        with patch("redis.asyncio.from_url") as mock_from_url:
            mock_from_url.return_value = _make_mock_context(mock_redis)
            await limiter.update_from_headers(
                {
                    "RateLimit-Usage": "  50 ,  500  ",
                    "RateLimit-Limit": " 540 , 5200 ",
                    "RateLimit-Reset": " 100 , 80000 ",
                }
            )

        set_calls = {call.args[0]: call.args[1] for call in mock_redis.set.call_args_list}
        assert set_calls.get("polar:rate:short:counter") == "50"
        assert set_calls.get("polar:rate:long:counter") == "500"
        assert set_calls.get("polar:rate:short:limit") == "540"
        assert set_calls.get("polar:rate:long:limit") == "5200"


# ---------------------------------------------------------------------------
# TestDynamicLimits
# ---------------------------------------------------------------------------


class TestDynamicLimits:
    """Tests for dynamic limit calculation (formula + Redis override)."""

    @pytest.mark.asyncio
    async def test_default_limit_with_zero_users(self, limiter):
        """Formula with 0 users: short = SHORT_BASE, long = LONG_BASE."""
        mock_redis = AsyncMock()
        # No limits stored, no user count
        mock_redis.get = AsyncMock(return_value=None)

        with patch("redis.asyncio.from_url") as mock_from_url:
            mock_from_url.return_value = _make_mock_context(mock_redis)
            short_limit, long_limit = await limiter._get_dynamic_limits(mock_redis)

        assert short_limit == SHORT_BASE  # 500
        assert long_limit == LONG_BASE  # 5000

    @pytest.mark.asyncio
    async def test_short_limit_formula(self, limiter):
        """Short limit = SHORT_BASE + (N × SHORT_PER_USER)."""
        mock_redis = AsyncMock()
        mock_redis.get = AsyncMock(
            side_effect=lambda key: {
                "polar:rate:user_count": "10",
            }.get(key)
        )

        with patch("redis.asyncio.from_url") as mock_from_url:
            mock_from_url.return_value = _make_mock_context(mock_redis)
            short_limit, _ = await limiter._get_dynamic_limits(mock_redis)

        expected = SHORT_BASE + 10 * SHORT_PER_USER  # 500 + 200 = 700
        assert short_limit == expected

    @pytest.mark.asyncio
    async def test_long_limit_formula(self, limiter):
        """Long limit = LONG_BASE + (N × LONG_PER_USER)."""
        mock_redis = AsyncMock()
        mock_redis.get = AsyncMock(
            side_effect=lambda key: {
                "polar:rate:user_count": "10",
            }.get(key)
        )

        with patch("redis.asyncio.from_url") as mock_from_url:
            mock_from_url.return_value = _make_mock_context(mock_redis)
            _, long_limit = await limiter._get_dynamic_limits(mock_redis)

        expected = LONG_BASE + 10 * LONG_PER_USER  # 5000 + 1000 = 6000
        assert long_limit == expected

    @pytest.mark.asyncio
    async def test_update_user_count(self, limiter):
        """update_user_count stores the given integer into Redis."""
        mock_redis = AsyncMock()
        mock_redis.set = AsyncMock()

        with patch("redis.asyncio.from_url") as mock_from_url:
            mock_from_url.return_value = _make_mock_context(mock_redis)
            await limiter.update_user_count(42)

        mock_redis.set.assert_called_once_with("polar:rate:user_count", "42")


# ---------------------------------------------------------------------------
# TestGetRemaining
# ---------------------------------------------------------------------------


class TestGetRemaining:
    """Tests for reading remaining capacity across both windows."""

    @pytest.mark.asyncio
    async def test_get_remaining_returns_tuple(self, limiter):
        """Returns a 2-tuple of (short_remaining, long_remaining)."""
        mock_redis = AsyncMock()
        mock_redis.get = AsyncMock(
            side_effect=lambda key: {
                "polar:rate:short:counter": "50",
                "polar:rate:long:counter": "200",
                "polar:rate:short:limit": "520",
                "polar:rate:long:limit": "5100",
                "polar:rate:user_count": "1",
            }.get(key)
        )

        with patch("redis.asyncio.from_url") as mock_from_url:
            mock_from_url.return_value = _make_mock_context(mock_redis)
            short_rem, long_rem = await limiter.get_remaining()

        assert short_rem == 520 - 50  # 470
        assert long_rem == 5100 - 200  # 4900

    @pytest.mark.asyncio
    async def test_get_remaining_returns_fallback_on_error(self, limiter):
        """Returns (999, 9999) when Redis is unavailable."""
        with patch("redis.asyncio.from_url", side_effect=Exception("redis down")):
            short_rem, long_rem = await limiter.get_remaining()

        assert short_rem == 999
        assert long_rem == 9999


# ---------------------------------------------------------------------------
# TestGetResetSeconds
# ---------------------------------------------------------------------------


class TestGetResetSeconds:
    """Tests for reading reset seconds from both windows."""

    @pytest.mark.asyncio
    async def test_get_reset_seconds_returns_tuple(self, limiter):
        """Returns a 2-tuple of (short_reset_secs, long_reset_secs)."""
        mock_redis = AsyncMock()
        mock_redis.get = AsyncMock(
            side_effect=lambda key: {
                "polar:rate:short:reset": "784",
                "polar:rate:long:reset": "72000",
            }.get(key)
        )

        with patch("redis.asyncio.from_url") as mock_from_url:
            mock_from_url.return_value = _make_mock_context(mock_redis)
            short_reset, long_reset = await limiter.get_reset_seconds()

        assert short_reset == 784
        assert long_reset == 72000

    @pytest.mark.asyncio
    async def test_get_reset_seconds_returns_zeros_on_error(self, limiter):
        """Returns (0, 0) when Redis is unavailable."""
        with patch("redis.asyncio.from_url", side_effect=Exception("redis down")):
            short_reset, long_reset = await limiter.get_reset_seconds()

        assert short_reset == 0
        assert long_reset == 0
