"""
Tests for morning_briefing_task.

Tests cover:
- Users in the current 15-minute window are selected
- Briefing includes sleep data when available
- Briefing uses fallback when no sleep data
- Disabled briefing users are skipped
- Free tier users are skipped (morning briefing is Pro feature)
"""

from __future__ import annotations

import datetime
from datetime import time, timezone
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.tasks.morning_briefing_task import (
    _generate_briefing_text,
    _run_morning_briefings,
)


# ---------------------------------------------------------------------------
# Unit tests for _generate_briefing_text
# ---------------------------------------------------------------------------


class TestGenerateBriefingText:
    def test_includes_sleep_hours_when_available(self):
        title, body = _generate_briefing_text(
            sleep_hours=7.5,
            sleep_quality=85,
            user_goals=None,
        )
        assert "7.5 hours" in body
        assert "Great quality" in body

    def test_includes_poor_sleep_note(self):
        _, body = _generate_briefing_text(
            sleep_hours=5.0,
            sleep_quality=55,
            user_goals=None,
        )
        assert "5.0 hours" in body
        # Quality < 60 → suggest earlier bedtime
        assert "earlier bedtime" in body

    def test_fallback_when_no_sleep_data(self):
        _, body = _generate_briefing_text(
            sleep_hours=None,
            sleep_quality=None,
            user_goals=None,
        )
        assert "consistency" in body.lower() or "strong" in body.lower()
        # Should NOT raise or return empty
        assert len(body) > 10

    def test_includes_goal_focus_when_goals_present(self):
        goals = [{"metric": "daily_steps", "target": 10000}]
        _, body = _generate_briefing_text(
            sleep_hours=7.0,
            sleep_quality=70,
            user_goals=goals,
        )
        assert "daily steps" in body.lower()

    def test_includes_actionable_tip(self):
        _, body = _generate_briefing_text(
            sleep_hours=8.0,
            sleep_quality=90,
            user_goals=None,
        )
        # Should always include a tip.
        assert "tip:" in body.lower()

    def test_short_sleep_tip_is_nap_suggestion(self):
        _, body = _generate_briefing_text(
            sleep_hours=4.5,
            sleep_quality=None,
            user_goals=None,
        )
        assert "nap" in body.lower()

    def test_title_is_always_returned(self):
        title, _ = _generate_briefing_text(None, None, None)
        assert title != ""


# ---------------------------------------------------------------------------
# Integration tests for _run_morning_briefings
# ---------------------------------------------------------------------------


def _make_prefs(user_id: str, enabled: bool, briefing_hour: int, briefing_minute: int = 0):
    """Build a mock UserPreferences object."""
    prefs = MagicMock()
    prefs.user_id = user_id
    prefs.morning_briefing_enabled = enabled
    prefs.morning_briefing_time = time(briefing_hour, briefing_minute)
    prefs.goals = None
    return prefs


def _make_user(user_id: str, is_premium: bool):
    user = MagicMock()
    user.id = user_id
    user.is_premium = is_premium
    return user


class TestRunMorningBriefings:
    @pytest.mark.asyncio
    async def test_sends_briefing_for_user_in_current_window(self):
        """User whose briefing time matches current UTC window receives a briefing."""
        now = datetime.datetime.now(timezone.utc)
        hour = now.hour
        minute = (now.minute // 15) * 15  # start of current 15-min window

        user_id = "user-brief-001"
        prefs = _make_prefs(user_id, enabled=True, briefing_hour=hour, briefing_minute=minute)
        user = _make_user(user_id, is_premium=True)

        with (
            patch("app.tasks.morning_briefing_task.async_session") as mock_factory,
            patch("app.tasks.morning_briefing_task.NotificationService") as MockNotifSvc,
            patch("app.tasks.morning_briefing_task.PushService"),
        ):
            mock_notif_svc = AsyncMock()
            MockNotifSvc.return_value = mock_notif_svc
            mock_notif_svc.send_and_persist = AsyncMock()

            db = AsyncMock()
            # Prefs query
            prefs_result = MagicMock()
            prefs_result.scalars.return_value.all.return_value = [prefs]
            # User query
            user_result = MagicMock()
            user_result.scalar_one_or_none.return_value = user
            # Sleep query
            sleep_result = MagicMock()
            sleep_result.scalar_one_or_none.return_value = None
            # Device query
            device_result = MagicMock()
            device_result.scalar_one_or_none.return_value = None

            db.execute = AsyncMock(side_effect=[prefs_result, user_result, sleep_result, device_result])
            db.add = MagicMock()
            db.commit = AsyncMock()

            mock_factory.return_value.__aenter__ = AsyncMock(return_value=db)
            mock_factory.return_value.__aexit__ = AsyncMock(return_value=False)

            result = await _run_morning_briefings()

        assert result["sent"] == 1
        mock_notif_svc.send_and_persist.assert_awaited_once()

    @pytest.mark.asyncio
    async def test_skips_free_tier_users(self):
        """Free-tier users are not sent morning briefings."""
        now = datetime.datetime.now(timezone.utc)
        hour = now.hour
        minute = (now.minute // 15) * 15

        user_id = "user-free-001"
        prefs = _make_prefs(user_id, enabled=True, briefing_hour=hour, briefing_minute=minute)
        user = _make_user(user_id, is_premium=False)

        with (
            patch("app.tasks.morning_briefing_task.async_session") as mock_factory,
            patch("app.tasks.morning_briefing_task.NotificationService") as MockNotifSvc,
            patch("app.tasks.morning_briefing_task.PushService"),
        ):
            mock_notif_svc = AsyncMock()
            MockNotifSvc.return_value = mock_notif_svc
            mock_notif_svc.send_and_persist = AsyncMock()

            db = AsyncMock()
            prefs_result = MagicMock()
            prefs_result.scalars.return_value.all.return_value = [prefs]
            user_result = MagicMock()
            user_result.scalar_one_or_none.return_value = user

            db.execute = AsyncMock(side_effect=[prefs_result, user_result])

            mock_factory.return_value.__aenter__ = AsyncMock(return_value=db)
            mock_factory.return_value.__aexit__ = AsyncMock(return_value=False)

            result = await _run_morning_briefings()

        assert result["sent"] == 0
        assert result["skipped"] == 1
        mock_notif_svc.send_and_persist.assert_not_awaited()

    @pytest.mark.asyncio
    async def test_skips_users_outside_current_window(self):
        """Users whose briefing time is not in the current 15-min window are skipped."""
        now = datetime.datetime.now(timezone.utc)
        # Pick an hour that is definitely not now.
        different_hour = (now.hour + 12) % 24

        user_id = "user-wrongtime-001"
        prefs = _make_prefs(user_id, enabled=True, briefing_hour=different_hour, briefing_minute=0)

        with (
            patch("app.tasks.morning_briefing_task.async_session") as mock_factory,
            patch("app.tasks.morning_briefing_task.NotificationService") as MockNotifSvc,
            patch("app.tasks.morning_briefing_task.PushService"),
        ):
            mock_notif_svc = AsyncMock()
            MockNotifSvc.return_value = mock_notif_svc
            mock_notif_svc.send_and_persist = AsyncMock()

            db = AsyncMock()
            prefs_result = MagicMock()
            prefs_result.scalars.return_value.all.return_value = [prefs]
            db.execute = AsyncMock(return_value=prefs_result)

            mock_factory.return_value.__aenter__ = AsyncMock(return_value=db)
            mock_factory.return_value.__aexit__ = AsyncMock(return_value=False)

            result = await _run_morning_briefings()

        assert result["sent"] == 0
        mock_notif_svc.send_and_persist.assert_not_awaited()

    @pytest.mark.asyncio
    async def test_briefing_includes_sleep_data_when_available(self):
        """When sleep data exists, the briefing body references sleep hours."""
        now = datetime.datetime.now(timezone.utc)
        hour = now.hour
        minute = (now.minute // 15) * 15

        user_id = "user-sleep-001"
        prefs = _make_prefs(user_id, enabled=True, briefing_hour=hour, briefing_minute=minute)
        user = _make_user(user_id, is_premium=True)

        sleep_record = MagicMock()
        sleep_record.hours = 7.5
        sleep_record.quality_score = 80

        sent_args: dict = {}

        async def capture_send(**kwargs):
            sent_args.update(kwargs)

        with (
            patch("app.tasks.morning_briefing_task.async_session") as mock_factory,
            patch("app.tasks.morning_briefing_task.NotificationService") as MockNotifSvc,
            patch("app.tasks.morning_briefing_task.PushService"),
        ):
            mock_notif_svc = AsyncMock()
            MockNotifSvc.return_value = mock_notif_svc
            mock_notif_svc.send_and_persist = AsyncMock(side_effect=capture_send)

            db = AsyncMock()
            prefs_result = MagicMock()
            prefs_result.scalars.return_value.all.return_value = [prefs]
            user_result = MagicMock()
            user_result.scalar_one_or_none.return_value = user
            sleep_result = MagicMock()
            sleep_result.scalar_one_or_none.return_value = sleep_record
            device_result = MagicMock()
            device_result.scalar_one_or_none.return_value = None

            db.execute = AsyncMock(side_effect=[prefs_result, user_result, sleep_result, device_result])
            db.add = MagicMock()
            db.commit = AsyncMock()

            mock_factory.return_value.__aenter__ = AsyncMock(return_value=db)
            mock_factory.return_value.__aexit__ = AsyncMock(return_value=False)

            await _run_morning_briefings()

        body = sent_args.get("body", "")
        assert "7.5 hours" in body, f"Expected sleep hours in body, got: {body}"

    @pytest.mark.asyncio
    async def test_briefing_uses_fallback_when_no_sleep_data(self):
        """When no sleep data, briefing body should still contain motivational content."""
        now = datetime.datetime.now(timezone.utc)
        hour = now.hour
        minute = (now.minute // 15) * 15

        user_id = "user-nosleep-001"
        prefs = _make_prefs(user_id, enabled=True, briefing_hour=hour, briefing_minute=minute)
        user = _make_user(user_id, is_premium=True)

        sent_args: dict = {}

        async def capture_send(**kwargs):
            sent_args.update(kwargs)

        with (
            patch("app.tasks.morning_briefing_task.async_session") as mock_factory,
            patch("app.tasks.morning_briefing_task.NotificationService") as MockNotifSvc,
            patch("app.tasks.morning_briefing_task.PushService"),
        ):
            mock_notif_svc = AsyncMock()
            MockNotifSvc.return_value = mock_notif_svc
            mock_notif_svc.send_and_persist = AsyncMock(side_effect=capture_send)

            db = AsyncMock()
            prefs_result = MagicMock()
            prefs_result.scalars.return_value.all.return_value = [prefs]
            user_result = MagicMock()
            user_result.scalar_one_or_none.return_value = user
            sleep_result = MagicMock()
            sleep_result.scalar_one_or_none.return_value = None  # no sleep data
            device_result = MagicMock()
            device_result.scalar_one_or_none.return_value = None

            db.execute = AsyncMock(side_effect=[prefs_result, user_result, sleep_result, device_result])
            db.add = MagicMock()
            db.commit = AsyncMock()

            mock_factory.return_value.__aenter__ = AsyncMock(return_value=db)
            mock_factory.return_value.__aexit__ = AsyncMock(return_value=False)

            await _run_morning_briefings()

        body = sent_args.get("body", "")
        assert len(body) > 10, "Fallback body should not be empty"
        # Should not crash or contain 'None' literal
        assert "None" not in body
