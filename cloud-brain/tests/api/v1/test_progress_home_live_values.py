"""Tests that /progress/home returns live goal current_value from daily_summaries.

Verifies that AnalyticsService._get_current_metric_value is called and its
return value appears as current_value in the response goals list.
"""

from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

TEST_USER_ID = "progress-home-test-user-001"
AUTH_HEADER = {"Authorization": "Bearer test-token"}


def _make_mock_goal(
    goal_id: str = "goal-001",
    metric: str = "steps",
    period_value: str = "daily",
    target_value: float = 10000.0,
    current_value: float = 0.0,
    goal_type: str = "step_count",
) -> MagicMock:
    """Create a minimal mock UserGoal ORM object."""
    from datetime import datetime, timezone

    goal = MagicMock()
    goal.id = goal_id
    goal.user_id = TEST_USER_ID
    goal.metric = metric
    goal.type = goal_type
    goal.period = MagicMock()
    goal.period.value = period_value
    goal.title = "Daily Steps"
    goal.target_value = target_value
    goal.current_value = current_value
    goal.unit = "steps"
    goal.start_date = "2026-03-01"
    goal.deadline = None
    goal.is_completed = False
    goal.ai_commentary = None
    goal.is_active = True
    goal.created_at = datetime(2026, 3, 1, tzinfo=timezone.utc)
    return goal


# ---------------------------------------------------------------------------
# Test: progress_home returns live current_value for step_count goal
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_progress_home_returns_live_current_value_for_steps_goal():
    """progress_home enriches step_count goal with live value from daily_summaries."""
    from app.api.v1.progress_routes import progress_home

    mock_db = AsyncMock()
    mock_db.commit = AsyncMock()

    fake_goal = _make_mock_goal(metric="steps", current_value=0.0)

    # goals query result
    goals_result = MagicMock()
    goals_result.scalars.return_value.all.return_value = [fake_goal]

    # streaks query result (empty)
    streaks_result = MagicMock()
    streaks_result.scalars.return_value.all.return_value = []

    # locked achievements query result (empty)
    locked_ach_result = MagicMock()
    locked_ach_result.scalars.return_value.all.return_value = []

    # recent achievements query result (empty)
    recent_ach_result = MagicMock()
    recent_ach_result.scalars.return_value.all.return_value = []

    # WoW queries — return None averages so the metric is skipped
    wow_scalar_result = MagicMock()
    wow_scalar_result.scalar_one_or_none.return_value = None

    call_count = 0

    async def _execute_side_effect(_stmt, *_args, **_kwargs):
        nonlocal call_count
        call_count += 1
        if call_count == 1:
            return goals_result
        elif call_count == 2:
            return streaks_result
        elif call_count == 3:
            return locked_ach_result
        elif call_count == 4:
            return recent_ach_result
        else:
            return wow_scalar_result

    mock_db.execute = AsyncMock(side_effect=_execute_side_effect)

    mock_request = MagicMock()
    mock_request.headers = {"X-User-Timezone": "UTC"}

    with patch(
        "app.api.v1.progress_routes._analytics"
    ) as mock_analytics, patch(
        "app.api.v1.progress_routes.get_goal_history",
        new=AsyncMock(return_value=[]),
    ):
        mock_analytics._get_current_metric_value = AsyncMock(return_value=8500.0)

        result = await progress_home(
            request=mock_request,
            user_id=TEST_USER_ID,
            db=mock_db,
        )

    assert len(result["goals"]) == 1
    goal_out = result["goals"][0]
    assert goal_out["current_value"] == 8500.0, (
        f"Expected 8500.0 but got {goal_out['current_value']}"
    )


@pytest.mark.asyncio
async def test_progress_home_returns_progress_history_list():
    """progress_home includes non-empty progress_history from get_goal_history."""
    from app.api.v1.progress_routes import progress_home

    mock_db = AsyncMock()
    mock_db.commit = AsyncMock()

    fake_goal = _make_mock_goal(metric="steps")

    goals_result = MagicMock()
    goals_result.scalars.return_value.all.return_value = [fake_goal]
    streaks_result = MagicMock()
    streaks_result.scalars.return_value.all.return_value = []
    locked_ach_result = MagicMock()
    locked_ach_result.scalars.return_value.all.return_value = []
    recent_ach_result = MagicMock()
    recent_ach_result.scalars.return_value.all.return_value = []
    wow_scalar_result = MagicMock()
    wow_scalar_result.scalar_one_or_none.return_value = None

    call_count = 0

    async def _execute_side_effect(_stmt, *_args, **_kwargs):
        nonlocal call_count
        call_count += 1
        if call_count == 1:
            return goals_result
        elif call_count == 2:
            return streaks_result
        elif call_count == 3:
            return locked_ach_result
        elif call_count == 4:
            return recent_ach_result
        else:
            return wow_scalar_result

    mock_db.execute = AsyncMock(side_effect=_execute_side_effect)

    mock_request = MagicMock()
    mock_request.headers = {"X-User-Timezone": "UTC"}

    fake_history = [
        {"date": "2026-03-20", "value": 7200.0},
        {"date": "2026-03-21", "value": 9100.0},
    ]

    with patch(
        "app.api.v1.progress_routes._analytics"
    ) as mock_analytics, patch(
        "app.api.v1.progress_routes.get_goal_history",
        new=AsyncMock(return_value=fake_history),
    ):
        mock_analytics._get_current_metric_value = AsyncMock(return_value=8500.0)

        result = await progress_home(
            request=mock_request,
            user_id=TEST_USER_ID,
            db=mock_db,
        )

    assert result["goals"][0]["progress_history"] == fake_history
