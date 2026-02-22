"""
Life Logger Cloud Brain — Tests for Analytics API Schemas.

Validates Pydantic models for analytics endpoint request
and response serialization, including field defaults, type
coercion, and constraint enforcement.
"""

import pytest

from app.api.v1.analytics_schemas import (
    CorrelationResponse,
    DailySummaryResponse,
    DashboardInsightResponse,
    GoalProgressResponse,
    TrendResponse,
    UserGoalRequest,
    WeeklyTrendsResponse,
)


def test_daily_summary_schema() -> None:
    """DailySummaryResponse should accept valid fields and return them."""
    response = DailySummaryResponse(
        date="2026-02-20",
        steps=8500,
        calories_consumed=1850,
        calories_burned=2450,
        workouts_count=1,
        sleep_hours=7.5,
        weight_kg=82.5,
    )
    assert response.steps == 8500
    assert response.weight_kg == 82.5


def test_daily_summary_defaults() -> None:
    """DailySummaryResponse should use defaults for omitted fields."""
    response = DailySummaryResponse(date="2026-02-20")
    assert response.steps == 0
    assert response.calories_consumed == 0
    assert response.calories_burned == 0
    assert response.workouts_count == 0
    assert response.sleep_hours == 0.0
    assert response.weight_kg is None


def test_weekly_trends_schema() -> None:
    """WeeklyTrendsResponse should accept 7-element lists."""
    response = WeeklyTrendsResponse(
        dates=["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"],
        steps=[8500, 9200, 7800, 10500, 8900, 6500, 8100],
        calories_in=[1800, 1950, 2100, 1850, 1750, 2200, 1900],
        calories_out=[2200, 2300, 2100, 2400, 2250, 2000, 2200],
        sleep_hours=[7.5, 6.0, 8.0, 7.0, 6.5, 9.0, 7.5],
    )
    assert len(response.dates) == 7
    assert len(response.steps) == 7
    assert len(response.calories_in) == 7


def test_correlation_schema() -> None:
    """CorrelationResponse should store score and metadata."""
    response = CorrelationResponse(
        metric_x="sleep_hours",
        metric_y="activity_calories",
        score=0.65,
        message="Moderate Positive Correlation",
        lag=0,
        data_points=14,
    )
    assert response.score == 0.65
    assert response.metric_x == "sleep_hours"
    assert response.data_points == 14


def test_trend_schema() -> None:
    """TrendResponse should capture direction and statistics."""
    response = TrendResponse(
        metric="steps",
        trend="up",
        percent_change=15.3,
        recent_avg=9500.0,
        previous_avg=8200.0,
    )
    assert response.trend == "up"
    assert response.percent_change == 15.3


def test_trend_schema_defaults() -> None:
    """TrendResponse should use defaults for omitted numeric fields."""
    response = TrendResponse(metric="steps", trend="insufficient_data")
    assert response.percent_change == 0.0
    assert response.recent_avg == 0.0
    assert response.previous_avg == 0.0


def test_goal_progress_schema() -> None:
    """GoalProgressResponse should reflect goal status correctly."""
    response = GoalProgressResponse(
        metric="steps",
        period="daily",
        target=10000,
        current=8500,
        progress_pct=85.0,
        is_met=False,
        remaining=1500,
    )
    assert response.is_met is False
    assert response.remaining == 1500


def test_goal_progress_met() -> None:
    """GoalProgressResponse should reflect a met goal."""
    response = GoalProgressResponse(
        metric="steps",
        period="daily",
        target=10000,
        current=12000,
        progress_pct=120.0,
        is_met=True,
        remaining=0,
    )
    assert response.is_met is True
    assert response.remaining == 0


def test_user_goal_request_validation() -> None:
    """UserGoalRequest should validate metric, target, and period."""
    goal = UserGoalRequest(metric="steps", target_value=10000, period="daily")
    assert goal.metric == "steps"
    assert goal.target_value == 10000
    assert goal.period == "daily"


def test_user_goal_request_rejects_negative_target() -> None:
    """UserGoalRequest should reject target_value <= 0."""
    with pytest.raises(Exception):
        UserGoalRequest(metric="steps", target_value=-100, period="daily")


def test_user_goal_request_rejects_zero_target() -> None:
    """UserGoalRequest should reject target_value of 0."""
    with pytest.raises(Exception):
        UserGoalRequest(metric="steps", target_value=0, period="daily")


def test_user_goal_request_rejects_invalid_period() -> None:
    """UserGoalRequest should reject periods not matching the pattern."""
    with pytest.raises(Exception):
        UserGoalRequest(metric="steps", target_value=100, period="invalid")


def test_user_goal_request_accepts_all_valid_periods() -> None:
    """UserGoalRequest should accept daily, weekly, and long_term."""
    for period in ("daily", "weekly", "long_term"):
        goal = UserGoalRequest(metric="steps", target_value=100, period=period)
        assert goal.period == period


def test_dashboard_insight_schema() -> None:
    """DashboardInsightResponse should store insight and nested data."""
    response = DashboardInsightResponse(
        insight="You're crushing it!",
        goals=[],
        trends={},
    )
    assert response.insight == "You're crushing it!"
    assert response.goals == []
    assert response.trends == {}


def test_dashboard_insight_defaults() -> None:
    """DashboardInsightResponse should use empty defaults for optional fields."""
    response = DashboardInsightResponse(insight="Keep going!")
    assert response.goals == []
    assert response.trends == {}


def test_dashboard_insight_with_nested_data() -> None:
    """DashboardInsightResponse should accept nested goal and trend models."""
    goal = GoalProgressResponse(
        metric="steps",
        period="daily",
        target=10000,
        current=8500,
        progress_pct=85.0,
        is_met=False,
        remaining=1500,
    )
    trend = TrendResponse(
        metric="steps",
        trend="up",
        percent_change=15.3,
        recent_avg=9500.0,
        previous_avg=8200.0,
    )
    response = DashboardInsightResponse(
        insight="Almost there!",
        goals=[goal],
        trends={"steps": trend},
    )
    assert len(response.goals) == 1
    assert response.goals[0].metric == "steps"
    assert "steps" in response.trends
    assert response.trends["steps"].trend == "up"
