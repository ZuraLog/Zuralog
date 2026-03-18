"""Tests for insight_tasks — fan-out idempotency lock.

Tests verify that fan_out_daily_insights() uses a Redis distributed lock
to prevent duplicate fan-out runs within the same UTC hour.
"""

from __future__ import annotations

from datetime import datetime, timezone
from unittest.mock import MagicMock, patch

import pytest


class TestFanOutIdempotencyLock:
    """Tests for the Redis-based deduplication lock on fan_out_daily_insights."""

    @patch("app.tasks.insight_tasks.asyncio")
    @patch("app.tasks.insight_tasks.redis")
    def test_lock_acquired_runs_fan_out(self, mock_redis_mod, mock_asyncio):
        """When the lock is available, fan-out runs and lock is deleted after."""
        from app.tasks.insight_tasks import fan_out_daily_insights

        # Redis lock succeeds (set returns True)
        mock_client = MagicMock()
        mock_redis_mod.Redis.from_url.return_value = mock_client
        mock_client.set.return_value = True

        # asyncio.run returns a normal result
        mock_asyncio.run.return_value = {"enqueued": 5}

        result = fan_out_daily_insights()

        # Verify lock was attempted with nx=True and ex=3300
        mock_client.set.assert_called_once()
        call_kwargs = mock_client.set.call_args
        assert call_kwargs.kwargs.get("nx") is True or call_kwargs[1].get("nx") is True
        assert call_kwargs.kwargs.get("ex") == 3300 or call_kwargs[1].get("ex") == 3300

        # Verify fan-out actually ran
        mock_asyncio.run.assert_called_once()
        assert result["enqueued"] == 5

        # Verify lock was deleted in finally
        mock_client.delete.assert_called_once()

    @patch("app.tasks.insight_tasks.redis")
    def test_lock_not_acquired_skips_fan_out(self, mock_redis_mod):
        """When the lock is already held, fan-out is skipped."""
        import asyncio as real_asyncio
        from app.tasks.insight_tasks import fan_out_daily_insights

        # Redis lock fails (set returns None — key already exists)
        mock_client = MagicMock()
        mock_redis_mod.Redis.from_url.return_value = mock_client
        mock_client.set.return_value = None

        result = fan_out_daily_insights()

        assert result["status"] == "skipped_lock"
        assert result["enqueued"] == 0

    @patch("app.tasks.insight_tasks.asyncio")
    @patch("app.tasks.insight_tasks.redis")
    def test_lock_deleted_even_on_exception(self, mock_redis_mod, mock_asyncio):
        """Lock is cleaned up even if the fan-out raises an exception."""
        from app.tasks.insight_tasks import fan_out_daily_insights

        mock_client = MagicMock()
        mock_redis_mod.Redis.from_url.return_value = mock_client
        mock_client.set.return_value = True

        # Fan-out raises an exception
        mock_asyncio.run.side_effect = RuntimeError("DB connection failed")

        with pytest.raises(RuntimeError, match="DB connection failed"):
            fan_out_daily_insights()

        # Lock must still be deleted
        mock_client.delete.assert_called_once()

    @patch("app.tasks.insight_tasks.asyncio")
    @patch("app.tasks.insight_tasks.redis")
    def test_lock_key_includes_utc_hour(self, mock_redis_mod, mock_asyncio):
        """The lock key includes the current UTC date and hour."""
        from app.tasks.insight_tasks import fan_out_daily_insights

        mock_client = MagicMock()
        mock_redis_mod.Redis.from_url.return_value = mock_client
        mock_client.set.return_value = True
        mock_asyncio.run.return_value = {"enqueued": 0}

        fan_out_daily_insights()

        # The lock key should start with our prefix
        call_args = mock_client.set.call_args
        lock_key = call_args[0][0]  # first positional arg
        assert lock_key.startswith("zuralog:fan_out_lock:")
        # Key format: zuralog:fan_out_lock:YYYY-MM-DDTHH
        suffix = lock_key.replace("zuralog:fan_out_lock:", "")
        # Should be parseable as a datetime
        datetime.strptime(suffix, "%Y-%m-%dT%H")
