"""
Tests for UserGoal model.

Validates that the UserGoal ORM model correctly stores user-defined
health and fitness goals, and that the GoalPeriod enum covers the
required time horizons (daily, weekly, long-term).
"""

from app.models.user_goal import GoalPeriod, UserGoal


def test_user_goal_creation() -> None:
    """UserGoal should store a user's target for a metric."""
    goal = UserGoal(
        user_id="user-123",
        metric="steps",
        target_value=10000,
        period=GoalPeriod.DAILY,
    )
    assert goal.metric == "steps"
    assert goal.target_value == 10000
    assert goal.period == GoalPeriod.DAILY


def test_goal_period_enum() -> None:
    """GoalPeriod should support daily, weekly, and long_term."""
    assert GoalPeriod.DAILY.value == "daily"
    assert GoalPeriod.WEEKLY.value == "weekly"
    assert GoalPeriod.LONG_TERM.value == "long_term"
