"""
Tests for SmartReminderEngine.

The engine exposes a single public method:
    evaluate_and_send(user_id, db) -> int

It returns the number of reminders sent. Internally it:
- Loads user preferences (proactivity level, quiet hours)
- Counts today's reminders sent
- Generates candidates
- Deduplicates via notification_logs
- Respects quiet hours
- Sends via PushService

Tests cover:
- Returns 0 when no preferences row exists (graceful degradation)
- Returns 0 when daily cap has been reached
- Does not raise on database errors
- _in_quiet_hours helper correctness
"""

from __future__ import annotations

from datetime import datetime, timezone
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.services.smart_reminder import SmartReminderEngine, _in_quiet_hours


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _make_prefs(
    proactivity: str = "medium",
    quiet_enabled: bool = False,
    quiet_start=None,
    quiet_end=None,
) -> MagicMock:
    prefs = MagicMock()
    prefs.proactivity_level = proactivity
    prefs.quiet_hours_enabled = quiet_enabled
    prefs.quiet_hours_start = quiet_start
    prefs.quiet_hours_end = quiet_end
    prefs.goals = []
    return prefs


# ---------------------------------------------------------------------------
# Basic invocation tests
# ---------------------------------------------------------------------------


class TestEvaluateAndSend:
    @pytest.mark.asyncio
    async def test_returns_int(self):
        """evaluate_and_send always returns an int."""
        engine = SmartReminderEngine()
        db = AsyncMock()

        # No preferences row → graceful fallback
        prefs_result = MagicMock()
        prefs_result.scalar_one_or_none.return_value = None

        # Count result must return an int for 'today_sent >= daily_cap'
        count_result = MagicMock()
        count_result.scalar_one.return_value = 0

        db.execute = AsyncMock(side_effect=[prefs_result, count_result])

        result = await engine.evaluate_and_send("user-001", db)
        assert isinstance(result, int)

    @pytest.mark.asyncio
    async def test_returns_zero_when_daily_cap_reached(self):
        """When daily cap has been reached, no reminders are sent."""
        engine = SmartReminderEngine()
        db = AsyncMock()

        prefs = _make_prefs(proactivity="medium")
        prefs_result = MagicMock()
        prefs_result.scalar_one_or_none.return_value = prefs

        # Daily cap for medium = 2; return 2 (cap reached) via scalar_one()
        count_result = MagicMock()
        count_result.scalar_one.return_value = 2

        db.execute = AsyncMock(side_effect=[prefs_result, count_result])

        result = await engine.evaluate_and_send("user-001", db)
        assert result == 0

    @pytest.mark.asyncio
    async def test_does_not_raise_on_db_errors(self):
        """evaluate_and_send never raises — it degrades gracefully on DB errors."""
        engine = SmartReminderEngine()
        db = AsyncMock()
        db.execute = AsyncMock(side_effect=Exception("DB unavailable"))

        # Should not raise
        result = await engine.evaluate_and_send("user-001", db)
        assert isinstance(result, int)
        assert result == 0


# ---------------------------------------------------------------------------
# _in_quiet_hours helper
# ---------------------------------------------------------------------------


class TestInQuietHours:
    def _now(self, hour: int, minute: int) -> datetime:
        return datetime(2026, 3, 4, hour, minute, tzinfo=timezone.utc)

    def test_overnight_window_inside(self):
        """22:00 → 07:00 window: 23:30 is inside."""
        now = self._now(23, 30)
        assert _in_quiet_hours(now, (22, 0), (7, 0)) is True

    def test_overnight_window_outside(self):
        """22:00 → 07:00 window: 10:00 is outside."""
        now = self._now(10, 0)
        assert _in_quiet_hours(now, (22, 0), (7, 0)) is False

    def test_same_day_window_inside(self):
        """13:00 → 14:00 window: 13:30 is inside."""
        now = self._now(13, 30)
        assert _in_quiet_hours(now, (13, 0), (14, 0)) is True

    def test_same_day_window_outside_before(self):
        """13:00 → 14:00 window: 12:59 is outside."""
        now = self._now(12, 59)
        assert _in_quiet_hours(now, (13, 0), (14, 0)) is False

    def test_same_day_window_outside_after(self):
        """13:00 → 14:00 window: 14:01 is outside."""
        now = self._now(14, 1)
        assert _in_quiet_hours(now, (13, 0), (14, 0)) is False

    def test_overnight_early_morning_inside(self):
        """22:00 → 07:00 window: 06:00 is inside (early morning)."""
        now = self._now(6, 0)
        assert _in_quiet_hours(now, (22, 0), (7, 0)) is True
