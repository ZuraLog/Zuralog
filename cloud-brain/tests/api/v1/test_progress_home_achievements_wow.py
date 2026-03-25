"""Tests for /progress/home recent_achievements and WoW metrics.

Verifies:
- An unlocked achievement is returned in recent_achievements.
- Two weeks of steps data produce a non-empty wow.metrics list with delta_pct.
"""

from __future__ import annotations

from datetime import datetime, timezone
from unittest.mock import AsyncMock, MagicMock, patch

import pytest


TEST_USER_ID = "progress-ach-wow-user-001"


def _make_scalars_all(items: list) -> MagicMock:
    """Return a result mock whose .scalars().all() returns `items`."""
    m = MagicMock()
    m.scalars.return_value.all.return_value = items
    return m


def _make_scalar_one_or_none(value) -> MagicMock:
    """Return a result mock whose .scalar_one_or_none() returns `value`."""
    m = MagicMock()
    m.scalar_one_or_none.return_value = value
    return m


def _make_mock_achievement(key: str = "streak_7") -> MagicMock:
    ach = MagicMock()
    ach.id = "ach-001"
    ach.achievement_key = key
    ach.user_id = TEST_USER_ID
    ach.unlocked_at = datetime(2026, 3, 20, 12, 0, 0, tzinfo=timezone.utc)
    return ach


# ---------------------------------------------------------------------------
# Test 1: Unlocked achievement appears in recent_achievements
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_progress_home_returns_unlocked_achievement():
    """An unlocked achievement appears in recent_achievements list."""
    from app.api.v1.progress_routes import progress_home

    mock_db = AsyncMock()
    mock_db.commit = AsyncMock()

    fake_ach = _make_mock_achievement("streak_7")
    call_count = 0

    async def _execute(stmt, *a, **kw):
        nonlocal call_count
        call_count += 1
        if call_count == 1:
            # goals
            return _make_scalars_all([])
        elif call_count == 2:
            # streaks
            return _make_scalars_all([])
        elif call_count == 3:
            # locked achievements (for next_achievement)
            return _make_scalars_all([])
        elif call_count == 4:
            # recent achievements
            return _make_scalars_all([fake_ach])
        else:
            # WoW avg queries
            return _make_scalar_one_or_none(None)

    mock_db.execute = AsyncMock(side_effect=_execute)

    mock_request = MagicMock()
    mock_request.headers = {"X-User-Timezone": "UTC"}

    with patch(
        "app.api.v1.progress_routes._analytics"
    ) as mock_analytics, patch(
        "app.api.v1.progress_routes.get_goal_history",
        new=AsyncMock(return_value=[]),
    ):
        mock_analytics._get_current_metric_value = AsyncMock(return_value=0.0)

        result = await progress_home(
            request=mock_request,
            user_id=TEST_USER_ID,
            db=mock_db,
        )

    assert len(result["recent_achievements"]) == 1
    ach_out = result["recent_achievements"][0]
    assert ach_out["key"] == "streak_7"
    assert ach_out["title"] == "Streak 7"
    assert "unlocked_at" in ach_out
    assert "icon_name" in ach_out


# ---------------------------------------------------------------------------
# Test 2: WoW metrics computed from two weeks of steps data
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_progress_home_wow_metrics_has_delta_pct_for_steps():
    """When both weeks have steps data, wow.metrics has a non-None delta_pct."""
    from app.api.v1.progress_routes import progress_home

    mock_db = AsyncMock()
    mock_db.commit = AsyncMock()

    call_count = 0

    async def _execute(stmt, *a, **kw):
        nonlocal call_count
        call_count += 1
        if call_count == 1:
            return _make_scalars_all([])   # goals
        elif call_count == 2:
            return _make_scalars_all([])   # streaks
        elif call_count == 3:
            return _make_scalars_all([])   # locked achievements
        elif call_count == 4:
            return _make_scalars_all([])   # recent achievements
        else:
            # WoW: cycle through this_week/last_week for each metric.
            # Return 8000 for this week's steps (first metric pair),
            # 7000 for last week's steps, None for rest.
            wow_index = call_count - 5
            if wow_index == 0:
                return _make_scalar_one_or_none(8000.0)   # steps this week
            elif wow_index == 1:
                return _make_scalar_one_or_none(7000.0)   # steps last week
            else:
                return _make_scalar_one_or_none(None)

    mock_db.execute = AsyncMock(side_effect=_execute)

    mock_request = MagicMock()
    mock_request.headers = {"X-User-Timezone": "UTC"}

    with patch(
        "app.api.v1.progress_routes._analytics"
    ) as mock_analytics, patch(
        "app.api.v1.progress_routes.get_goal_history",
        new=AsyncMock(return_value=[]),
    ):
        mock_analytics._get_current_metric_value = AsyncMock(return_value=0.0)

        result = await progress_home(
            request=mock_request,
            user_id=TEST_USER_ID,
            db=mock_db,
        )

    wow = result["wow"]
    assert "week_label" in wow
    assert wow["week_label"].startswith("Week of ")
    assert len(wow["metrics"]) >= 1

    steps_metric = next((m for m in wow["metrics"] if m["metric"] == "steps"), None)
    assert steps_metric is not None
    # delta_pct = (8000 - 7000) / 7000 * 100 ≈ 14.3
    assert steps_metric["delta_pct"] > 0
    assert steps_metric["this_week_avg"] == 8000.0
    assert steps_metric["last_week_avg"] == 7000.0
