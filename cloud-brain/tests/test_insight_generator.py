"""Tests for the InsightGenerator module.

Validates the priority-based insight generation system that synthesizes
analytics data (goal progress, trends) into a single "Insight of the Day"
string for the dashboard header.
"""

import pytest

from app.analytics.insight_generator import InsightGenerator


@pytest.fixture
def generator() -> InsightGenerator:
    """Provide a fresh InsightGenerator instance for each test."""
    return InsightGenerator()


def test_insight_goal_near_miss(generator: InsightGenerator) -> None:
    """Near-miss goals should generate urgent insight."""
    goal_status = [
        {"metric": "steps", "is_met": False, "progress_pct": 85, "remaining": 1500},
    ]
    trends: dict = {}
    result = generator.generate_dashboard_insight(goal_status, trends)
    assert "1500" in result or "steps" in result.lower()


def test_insight_negative_trend(generator: InsightGenerator) -> None:
    """Negative trend should produce a motivational nudge."""
    goal_status = [
        {"metric": "steps", "is_met": False, "progress_pct": 50, "remaining": 5000},
    ]
    trends = {"steps": {"trend": "down", "percent_change": -15.0}}
    result = generator.generate_dashboard_insight(goal_status, trends)
    assert "down" in result.lower() or "trending" in result.lower() or "pick" in result.lower()


def test_insight_positive_trend(generator: InsightGenerator) -> None:
    """Positive trend should produce encouragement."""
    goal_status = [
        {"metric": "steps", "is_met": True, "progress_pct": 110, "remaining": 0},
    ]
    trends = {"steps": {"trend": "up", "percent_change": 15.0}}
    result = generator.generate_dashboard_insight(goal_status, trends)
    assert isinstance(result, str)
    assert len(result) > 10


def test_insight_default_fallback(generator: InsightGenerator) -> None:
    """With no notable events, should return a generic insight."""
    result = generator.generate_dashboard_insight([], {})
    assert isinstance(result, str)
    assert len(result) > 5


def test_insight_goal_met_celebration(generator: InsightGenerator) -> None:
    """All goals met should produce celebration."""
    goal_status = [
        {"metric": "steps", "is_met": True, "progress_pct": 120, "remaining": 0},
        {"metric": "calories_consumed", "is_met": True, "progress_pct": 95, "remaining": 0},
    ]
    trends = {"steps": {"trend": "stable", "percent_change": 2.0}}
    result = generator.generate_dashboard_insight(goal_status, trends)
    assert isinstance(result, str)


def test_insight_priority_order(generator: InsightGenerator) -> None:
    """Near-miss goals should take priority over positive trends."""
    goal_status = [
        {"metric": "steps", "is_met": False, "progress_pct": 90, "remaining": 1000},
    ]
    trends = {"calories": {"trend": "up", "percent_change": 20.0}}
    result = generator.generate_dashboard_insight(goal_status, trends)
    assert "1000" in result or "steps" in result.lower() or "close" in result.lower()
