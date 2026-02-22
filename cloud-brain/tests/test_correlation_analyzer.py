"""Tests for the CorrelationAnalyzer module."""

import pytest

from app.analytics.correlation_analyzer import CorrelationAnalyzer


@pytest.fixture
def analyzer():
    return CorrelationAnalyzer()


def test_calculate_correlation_strong_positive(analyzer):
    """Perfectly correlated data should return score near 1.0."""
    x = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0]
    y = [10.0, 20.0, 30.0, 40.0, 50.0, 60.0, 70.0]
    result = analyzer.calculate_correlation(x, y)
    assert result["score"] > 0.95
    assert "Strong Positive" in result["message"]


def test_calculate_correlation_strong_negative(analyzer):
    """Inversely correlated data should return score near -1.0."""
    x = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0]
    y = [70.0, 60.0, 50.0, 40.0, 30.0, 20.0, 10.0]
    result = analyzer.calculate_correlation(x, y)
    assert result["score"] < -0.95
    assert "Strong Negative" in result["message"]


def test_calculate_correlation_insufficient_data(analyzer):
    """Less than 5 data points should return insufficient data."""
    result = analyzer.calculate_correlation([1.0, 2.0], [3.0, 4.0])
    assert result["score"] == 0.0
    assert "Not enough data" in result["message"]


def test_calculate_correlation_mismatched_lengths(analyzer):
    """Mismatched array lengths should return error."""
    result = analyzer.calculate_correlation([1.0, 2.0, 3.0], [1.0, 2.0])
    assert result["score"] == 0.0


def test_calculate_correlation_no_correlation(analyzer):
    """Random-ish data should return weak/no correlation."""
    x = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0]
    y = [4.0, 7.0, 2.0, 6.0, 3.0, 5.0, 1.0]
    result = analyzer.calculate_correlation(x, y)
    assert -0.7 < result["score"] < 0.7


def test_analyze_sleep_impact_on_activity(analyzer):
    """Should return correlation result from sleep and activity data."""
    sleep_data = [
        {"date": "2026-02-01", "hours": 8.0},
        {"date": "2026-02-02", "hours": 6.0},
        {"date": "2026-02-03", "hours": 7.5},
        {"date": "2026-02-04", "hours": 5.0},
        {"date": "2026-02-05", "hours": 9.0},
    ]
    activity_data = [
        {"date": "2026-02-01", "calories": 500},
        {"date": "2026-02-02", "calories": 300},
        {"date": "2026-02-03", "calories": 450},
        {"date": "2026-02-04", "calories": 200},
        {"date": "2026-02-05", "calories": 600},
    ]
    result = analyzer.analyze_sleep_impact_on_activity(sleep_data, activity_data)
    assert "score" in result
    assert "message" in result
    assert "lag" in result


def test_analyze_sleep_impact_with_lag(analyzer):
    """Should support lag analysis (Sleep Day N vs Activity Day N+1)."""
    sleep_data = [{"date": f"2026-02-{d:02d}", "hours": h} for d, h in [(1, 8), (2, 5), (3, 9), (4, 6), (5, 7), (6, 8)]]
    activity_data = [
        {"date": f"2026-02-{d:02d}", "calories": c}
        for d, c in [(1, 300), (2, 500), (3, 200), (4, 600), (5, 350), (6, 450)]
    ]
    result = analyzer.analyze_sleep_impact_on_activity(sleep_data, activity_data, lag=1)
    assert "score" in result
    assert result["lag"] == 1
