"""
Zuralog Cloud Brain — Reasoning Engine Tests.

Tests for cross-app analytical helpers that synthesize insights
from multiple data sources.
"""

import pytest

from app.analytics.reasoning_engine import ReasoningEngine


@pytest.fixture
def engine():
    """Create a ReasoningEngine instance."""
    return ReasoningEngine()


def test_analyze_deficit_in_deficit(engine):
    """Should detect caloric deficit correctly."""
    result = engine.analyze_deficit(nutrition_calories=1500, active_burn=400, bmr=1800)
    assert result["status"] == "deficit"
    assert result["net_calories"] < 0
    assert result["net_calories"] == 1500 - (1800 + 400)


def test_analyze_deficit_in_surplus(engine):
    """Should detect caloric surplus correctly."""
    result = engine.analyze_deficit(nutrition_calories=3000, active_burn=200, bmr=1800)
    assert result["status"] == "surplus"
    assert result["net_calories"] > 0
    assert result["net_calories"] == 3000 - (1800 + 200)


def test_analyze_deficit_extreme_deficit_warning(engine):
    """Extreme deficit should produce a warning recommendation."""
    result = engine.analyze_deficit(nutrition_calories=800, active_burn=500, bmr=1800)
    assert result["status"] == "deficit"
    assert result["magnitude"] > 500
    assert "under-eating" in result["recommendation"].lower() or "eat more" in result["recommendation"].lower()


def test_analyze_deficit_balanced(engine):
    """Near-zero net should return appropriate status."""
    result = engine.analyze_deficit(nutrition_calories=2200, active_burn=400, bmr=1800)
    assert result["net_calories"] == 0
    assert result["magnitude"] == 0


def test_correlate_sleep_and_activity_empty(engine):
    """Empty data should return a no-data message."""
    result = engine.correlate_sleep_and_activity([], [])
    assert isinstance(result, str)
    assert len(result) > 0


def test_correlate_sleep_and_activity_with_data(engine):
    """With sufficient data, should return a correlation summary."""
    sleep_data = [
        {"date": "2026-02-01", "hours": 7.5},
        {"date": "2026-02-02", "hours": 6.0},
        {"date": "2026-02-03", "hours": 8.0},
        {"date": "2026-02-04", "hours": 5.5},
        {"date": "2026-02-05", "hours": 7.0},
    ]
    activity_data = [
        {"date": "2026-02-01", "calories_burned": 400},
        {"date": "2026-02-02", "calories_burned": 600},
        {"date": "2026-02-03", "calories_burned": 300},
        {"date": "2026-02-04", "calories_burned": 700},
        {"date": "2026-02-05", "calories_burned": 450},
    ]
    result = engine.correlate_sleep_and_activity(sleep_data, activity_data)
    assert isinstance(result, str)


def test_analyze_activity_trend(engine):
    """Should detect declining activity trend."""
    this_month = [
        {"date": "2026-02-01", "type": "run"},
        {"date": "2026-02-05", "type": "run"},
        {"date": "2026-02-10", "type": "run"},
    ]
    last_month = [
        {"date": "2026-01-01", "type": "run"},
        {"date": "2026-01-05", "type": "run"},
        {"date": "2026-01-10", "type": "run"},
        {"date": "2026-01-15", "type": "run"},
        {"date": "2026-01-20", "type": "run"},
        {"date": "2026-01-25", "type": "run"},
        {"date": "2026-01-28", "type": "run"},
        {"date": "2026-01-30", "type": "run"},
    ]
    result = engine.analyze_activity_trend(this_month, last_month)
    assert result["trend"] == "declining"
    assert result["this_month_count"] == 3
    assert result["last_month_count"] == 8
