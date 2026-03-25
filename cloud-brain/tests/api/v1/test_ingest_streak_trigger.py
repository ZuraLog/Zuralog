"""Tests that ingest_single triggers streak updates via ingest_post_processing.

Verifies:
- A "steps" metric triggers StreakTracker.record_activity with streak_type "steps"
  and streak_type "engagement".
- An unknown metric type triggers StreakTracker.record_activity with "engagement" only.
"""

from __future__ import annotations

from datetime import date
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.ingest_post_processing import trigger_streaks_for_metric


# ---------------------------------------------------------------------------
# Unit tests for trigger_streaks_for_metric directly
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_steps_metric_triggers_steps_and_engagement():
    """Steps metric triggers both 'steps' and 'engagement' streak types."""
    mock_db = AsyncMock()

    with patch(
        "app.services.ingest_post_processing.StreakTracker"
    ) as MockTracker:
        instance = AsyncMock()
        instance.record_activity = AsyncMock(return_value=MagicMock())
        MockTracker.return_value = instance

        await trigger_streaks_for_metric(
            db=mock_db,
            user_id="test-user-abc",
            metric_type="steps",
            activity_date=date(2026, 3, 25),
        )

    assert instance.record_activity.call_count == 2
    calls = instance.record_activity.call_args_list
    streak_types_called = [c.kwargs["streak_type"] for c in calls]
    assert "steps" in streak_types_called
    assert "engagement" in streak_types_called


@pytest.mark.asyncio
async def test_unknown_metric_triggers_engagement_only():
    """An unknown/unmapped metric triggers only the 'engagement' streak type."""
    mock_db = AsyncMock()

    with patch(
        "app.services.ingest_post_processing.StreakTracker"
    ) as MockTracker:
        instance = AsyncMock()
        instance.record_activity = AsyncMock(return_value=MagicMock())
        MockTracker.return_value = instance

        await trigger_streaks_for_metric(
            db=mock_db,
            user_id="test-user-abc",
            metric_type="heart_rate_variability",
            activity_date=date(2026, 3, 25),
        )

    assert instance.record_activity.call_count == 1
    call = instance.record_activity.call_args_list[0]
    assert call.kwargs["streak_type"] == "engagement"


@pytest.mark.asyncio
async def test_workout_duration_triggers_workouts_and_engagement():
    """workout_duration metric triggers 'workouts' and 'engagement'."""
    mock_db = AsyncMock()

    with patch(
        "app.services.ingest_post_processing.StreakTracker"
    ) as MockTracker:
        instance = AsyncMock()
        instance.record_activity = AsyncMock(return_value=MagicMock())
        MockTracker.return_value = instance

        await trigger_streaks_for_metric(
            db=mock_db,
            user_id="test-user-abc",
            metric_type="workout_duration",
            activity_date=date(2026, 3, 25),
        )

    streak_types_called = [
        c.kwargs["streak_type"]
        for c in instance.record_activity.call_args_list
    ]
    assert "workouts" in streak_types_called
    assert "engagement" in streak_types_called


@pytest.mark.asyncio
async def test_streak_failure_does_not_raise():
    """A StreakTracker error must be swallowed — never propagated to the caller."""
    mock_db = AsyncMock()

    with patch(
        "app.services.ingest_post_processing.StreakTracker"
    ) as MockTracker:
        instance = AsyncMock()
        instance.record_activity = AsyncMock(side_effect=RuntimeError("DB exploded"))
        MockTracker.return_value = instance

        # Should not raise
        await trigger_streaks_for_metric(
            db=mock_db,
            user_id="test-user-abc",
            metric_type="steps",
            activity_date=date(2026, 3, 25),
        )
