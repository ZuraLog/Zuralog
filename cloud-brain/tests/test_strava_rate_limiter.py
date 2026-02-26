"""Tests for Strava API rate limit guardrails."""

from unittest.mock import patch

import pytest

from app.services.strava_rate_limiter import StravaRateLimiter


class TestStravaRateLimiter:
    """Tests for the Redis-backed Strava rate limiter."""

    @pytest.mark.asyncio
    async def test_allows_request_when_under_limit(self):
        """Allows API call when both 15-min and daily counts are under threshold."""
        limiter = StravaRateLimiter()

        with patch.object(limiter, "_get_counts", return_value=(50, 500)):
            allowed = await limiter.check_and_increment()
        assert allowed is True

    @pytest.mark.asyncio
    async def test_blocks_request_when_over_15min_limit(self):
        """Blocks API call when 15-min count is at or over threshold (90)."""
        limiter = StravaRateLimiter()

        with patch.object(limiter, "_get_counts", return_value=(90, 100)):
            allowed = await limiter.check_and_increment()
        assert allowed is False

    @pytest.mark.asyncio
    async def test_blocks_request_when_over_daily_limit(self):
        """Blocks API call when daily count is at or over threshold (900)."""
        limiter = StravaRateLimiter()

        with patch.object(limiter, "_get_counts", return_value=(10, 900)):
            allowed = await limiter.check_and_increment()
        assert allowed is False

    @pytest.mark.asyncio
    async def test_allows_request_at_boundary(self):
        """Allows when exactly at 89/15min and 899/daily (under threshold)."""
        limiter = StravaRateLimiter()

        with patch.object(limiter, "_get_counts", return_value=(89, 899)):
            allowed = await limiter.check_and_increment()
        assert allowed is True

    def test_limiter_has_correct_thresholds(self):
        """Rate limiter uses 90/15min and 900/daily thresholds."""
        limiter = StravaRateLimiter()
        assert limiter.limit_15min == 90
        assert limiter.limit_daily == 900
