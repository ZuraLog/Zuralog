"""
Tests for SmartReminderEngine.

Tests cover:
- Gap reminder generated when no steps data today
- No reminder when frequency cap hit
- No reminder during quiet hours
- Deduplication: same topic not sent within 48h
- Low proactivity: max 1 reminder
- High proactivity: up to 3 reminders
"""

from __future__ import annotations

from datetime import date, time
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.smart_reminder import Reminder, ReminderType, SmartReminderEngine


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _make_prefs(
    proactivity: str = "medium",
    quiet_enabled: bool = False,
    quiet_start: time | None = None,
    quiet_end: time | None = None,
    goals: list | None = None,
):
    prefs = MagicMock()
    prefs.proactivity_level = proactivity
    prefs.quiet_hours_enabled = quiet_enabled
    prefs.quiet_hours_start = quiet_start
    prefs.quiet_hours_end = quiet_end
    prefs.goals = goals or []
    return prefs


def _make_metrics(steps: int | None = None, resting_hr: float | None = None):
    m = MagicMock()
    m.steps = steps
    m.resting_heart_rate = resting_hr
    m.hrv_ms = None
    m.date = date.today().isoformat()
    return m


# ---------------------------------------------------------------------------
# Gap reminders
# ---------------------------------------------------------------------------


class TestGapReminders:
    @pytest.mark.asyncio
    async def test_gap_reminder_when_no_steps_today(self):
        """No steps data today → steps gap reminder generated."""
        engine = SmartReminderEngine(redis_client=None)
        db = AsyncMock()
        user_id = "user-gap-001"

        with (
            patch.object(engine, "_get_preferences", return_value=_make_prefs()),
            patch.object(engine, "_is_quiet_hours", return_value=False),
            patch.object(engine, "_get_today_metrics", return_value=_make_metrics(steps=None)),
            patch.object(engine, "_celebration_reminders", return_value=[]),
        ):
            reminders = await engine.generate_reminders(user_id, db)

        gap_reminders = [r for r in reminders if r.reminder_type == ReminderType.GAP]
        steps_gaps = [r for r in gap_reminders if "steps" in r.topic_key]
        assert len(steps_gaps) >= 1, "Should generate a steps gap reminder"

    @pytest.mark.asyncio
    async def test_no_gap_reminder_when_steps_sufficient(self):
        """Steps above threshold → no steps gap reminder."""
        engine = SmartReminderEngine(redis_client=None)
        db = AsyncMock()
        user_id = "user-gap-002"

        with (
            patch.object(engine, "_get_preferences", return_value=_make_prefs()),
            patch.object(engine, "_is_quiet_hours", return_value=False),
            patch.object(engine, "_get_today_metrics", return_value=_make_metrics(steps=5000)),
            patch.object(engine, "_celebration_reminders", return_value=[]),
        ):
            reminders = await engine.generate_reminders(user_id, db)

        steps_gaps = [r for r in reminders if "steps_gap" in r.topic_key]
        assert len(steps_gaps) == 0


# ---------------------------------------------------------------------------
# Frequency cap
# ---------------------------------------------------------------------------


class TestFrequencyCap:
    @pytest.mark.asyncio
    async def test_no_reminder_when_cap_hit(self):
        """If daily cap already reached, no reminders returned."""
        engine = SmartReminderEngine(redis_client=None)
        db = AsyncMock()
        user_id = "user-cap-001"

        with (
            patch.object(engine, "_get_preferences", return_value=_make_prefs(proactivity="medium")),
            patch.object(engine, "_is_quiet_hours", return_value=False),
            patch.object(engine, "_get_daily_count", return_value=2),  # cap for medium = 2
        ):
            reminders = await engine.generate_reminders(user_id, db)

        assert reminders == []

    @pytest.mark.asyncio
    async def test_low_proactivity_max_one_reminder(self):
        """Low proactivity users get at most 1 reminder."""
        engine = SmartReminderEngine(redis_client=None)
        db = AsyncMock()
        user_id = "user-low-001"

        # Return 3 candidates; should be capped to 1.
        candidates = [
            Reminder(ReminderType.GAP, "Steps", "Walk!", user_id, priority=4, topic_key="a"),
            Reminder(ReminderType.GAP, "Check-in", "Log!", user_id, priority=6, topic_key="b"),
            Reminder(ReminderType.GOAL, "Goal", "Almost!", user_id, priority=2, topic_key="c"),
        ]

        with (
            patch.object(engine, "_get_preferences", return_value=_make_prefs(proactivity="low")),
            patch.object(engine, "_is_quiet_hours", return_value=False),
            patch.object(engine, "_get_daily_count", return_value=0),
            patch.object(engine, "_get_today_metrics", return_value=_make_metrics(steps=None)),
            patch.object(engine, "_gap_reminders", return_value=candidates[:2]),
            patch.object(engine, "_goal_reminders", return_value=candidates[2:]),
            patch.object(engine, "_celebration_reminders", return_value=[]),
        ):
            reminders = await engine.generate_reminders(user_id, db)

        assert len(reminders) <= SmartReminderEngine.MAX_REMINDERS_PER_DAY["low"]

    @pytest.mark.asyncio
    async def test_high_proactivity_up_to_three_reminders(self):
        """High proactivity users can get up to 3 reminders."""
        engine = SmartReminderEngine(redis_client=None)
        db = AsyncMock()
        user_id = "user-high-001"

        candidates = [
            Reminder(ReminderType.GAP, f"Title {i}", f"Body {i}", user_id, priority=i, topic_key=f"k{i}")
            for i in range(1, 5)
        ]

        with (
            patch.object(engine, "_get_preferences", return_value=_make_prefs(proactivity="high")),
            patch.object(engine, "_is_quiet_hours", return_value=False),
            patch.object(engine, "_get_daily_count", return_value=0),
            patch.object(engine, "_gap_reminders", return_value=candidates[:2]),
            patch.object(engine, "_goal_reminders", return_value=candidates[2:]),
            patch.object(engine, "_celebration_reminders", return_value=[]),
        ):
            reminders = await engine.generate_reminders(user_id, db)

        assert len(reminders) <= SmartReminderEngine.MAX_REMINDERS_PER_DAY["high"]
        assert len(reminders) > 0


# ---------------------------------------------------------------------------
# Quiet hours
# ---------------------------------------------------------------------------


class TestQuietHours:
    @pytest.mark.asyncio
    async def test_no_reminder_during_quiet_hours(self):
        """Reminders suppressed when current time is inside quiet hours window."""
        from datetime import datetime, timezone

        engine = SmartReminderEngine(redis_client=None)
        db = AsyncMock()
        user_id = "user-quiet-001"

        # Mark quiet hours as active.
        with (
            patch.object(engine, "_get_preferences", return_value=_make_prefs(quiet_enabled=True)),
            patch.object(engine, "_is_quiet_hours", return_value=True),
        ):
            reminders = await engine.generate_reminders(user_id, db)

        assert reminders == []

    @pytest.mark.asyncio
    async def test_is_quiet_hours_respects_window(self):
        """_is_quiet_hours returns True when time is inside the window."""
        from datetime import datetime, timezone
        from unittest.mock import patch as p

        engine = SmartReminderEngine(redis_client=None)

        # Create prefs with quiet hours 22:00 → 07:00
        prefs = _make_prefs(quiet_enabled=True, quiet_start=time(22, 0), quiet_end=time(7, 0))

        # Mock time to 23:30 (inside overnight window)
        fake_now = datetime(2026, 3, 4, 23, 30, tzinfo=timezone.utc)
        with p("app.services.smart_reminder.datetime") as mock_dt:
            mock_dt.now.return_value = fake_now
            mock_dt.now.return_value.time.return_value = time(23, 30)
            result = await engine._is_quiet_hours(prefs)

        assert result is True

    @pytest.mark.asyncio
    async def test_is_not_quiet_hours_outside_window(self):
        """_is_quiet_hours returns False when time is outside the window."""
        from datetime import datetime, timezone
        from unittest.mock import patch as p

        engine = SmartReminderEngine(redis_client=None)

        # Quiet 22:00 → 07:00, current time 10:00
        prefs = _make_prefs(quiet_enabled=True, quiet_start=time(22, 0), quiet_end=time(7, 0))

        with p("app.services.smart_reminder.datetime") as mock_dt:
            mock_dt.now.return_value.time.return_value = time(10, 0)
            result = await engine._is_quiet_hours(prefs)

        assert result is False


# ---------------------------------------------------------------------------
# Deduplication
# ---------------------------------------------------------------------------


class TestDeduplication:
    @pytest.mark.asyncio
    async def test_deduplication_removes_already_sent_topic(self):
        """A reminder whose topic_key is in Redis is filtered out."""
        mock_redis = AsyncMock()
        # First key exists (topic already sent), second does not.
        mock_redis.exists = AsyncMock(side_effect=[True, False])

        engine = SmartReminderEngine(redis_client=mock_redis)
        user_id = "user-dedup-001"

        candidates = [
            Reminder(ReminderType.GAP, "Steps", "Walk!", user_id, topic_key="steps_gap_2026-03-04"),
            Reminder(ReminderType.GAP, "Check-in", "Log!", user_id, topic_key="checkin_gap_2026-03-04"),
        ]

        result = await engine._deduplicate(user_id, candidates)
        assert len(result) == 1
        assert result[0].topic_key == "checkin_gap_2026-03-04"

    @pytest.mark.asyncio
    async def test_mark_sent_sets_redis_keys(self):
        """mark_sent writes both dedup key and increments daily counter."""
        mock_pipe = AsyncMock()
        mock_redis = AsyncMock()
        mock_redis.pipeline.return_value = mock_pipe
        mock_pipe.set = MagicMock()
        mock_pipe.incr = MagicMock()
        mock_pipe.expire = MagicMock()
        mock_pipe.execute = AsyncMock()

        engine = SmartReminderEngine(redis_client=mock_redis)
        await engine.mark_sent("user-001", "steps_gap_2026-03-04")

        mock_pipe.set.assert_called_once()
        mock_pipe.incr.assert_called_once()
        mock_pipe.execute.assert_awaited_once()
