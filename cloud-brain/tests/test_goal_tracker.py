"""Tests for the GoalTracker module."""

import pytest

from app.analytics.goal_tracker import GoalTracker


@pytest.fixture
def tracker():
    """Provide a fresh GoalTracker instance for each test."""
    return GoalTracker()


def test_check_progress_under_goal(tracker):
    """Progress below target should show is_met=False."""
    result = tracker.check_progress(
        metric="steps",
        current_value=8500,
        target_value=10000,
        period="daily",
    )
    assert result["is_met"] is False
    assert result["progress_pct"] == 85.0
    assert result["remaining"] == 1500


def test_check_progress_met(tracker):
    """Meeting or exceeding target should show is_met=True."""
    result = tracker.check_progress(
        metric="steps",
        current_value=11000,
        target_value=10000,
        period="daily",
    )
    assert result["is_met"] is True
    assert result["progress_pct"] == 110.0
    assert result["remaining"] == 0


def test_check_progress_zero_target(tracker):
    """Zero target should handle gracefully."""
    result = tracker.check_progress(
        metric="steps",
        current_value=100,
        target_value=0,
        period="daily",
    )
    assert result["is_met"] is True
    assert result["progress_pct"] == 100.0


def test_calculate_streak(tracker):
    """Should count consecutive days meeting a goal."""
    daily_values = [10500, 11000, 9800, 10200, 10100]
    result = tracker.calculate_streak(daily_values, target=10000)
    assert result["streak_days"] == 2
    assert result["is_active"] is True


def test_calculate_streak_all_met(tracker):
    """All days meeting goal should return full streak."""
    daily_values = [10500, 11000, 10200, 10800]
    result = tracker.calculate_streak(daily_values, target=10000)
    assert result["streak_days"] == 4


def test_calculate_streak_none_met(tracker):
    """No days meeting goal should return 0."""
    daily_values = [5000, 6000, 7000]
    result = tracker.calculate_streak(daily_values, target=10000)
    assert result["streak_days"] == 0
    assert result["is_active"] is False


def test_calculate_streak_empty(tracker):
    """Empty data should return 0."""
    result = tracker.calculate_streak([], target=10000)
    assert result["streak_days"] == 0
