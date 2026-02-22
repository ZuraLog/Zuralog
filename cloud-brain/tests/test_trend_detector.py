"""Tests for the TrendDetector module."""

import pytest

from app.analytics.trend_detector import TrendDetector


@pytest.fixture
def detector():
    return TrendDetector()


def test_detect_trend_up(detector):
    """Increasing values should show 'up' trend."""
    values = [4, 5, 6, 4, 5, 6, 5, 14, 15, 16, 14, 15, 16, 15]
    result = detector.detect_trend(values, window_size=7)
    assert result["trend"] == "up"
    assert result["percent_change"] > 10


def test_detect_trend_down(detector):
    """Decreasing values should show 'down' trend."""
    values = [14, 15, 16, 14, 15, 16, 15, 4, 5, 6, 4, 5, 6, 5]
    result = detector.detect_trend(values, window_size=7)
    assert result["trend"] == "down"
    assert result["percent_change"] < -10


def test_detect_trend_stable(detector):
    """Similar values should show 'stable' trend."""
    values = [100, 101, 99, 100, 102, 98, 100, 101, 100, 99, 101, 100, 102, 99]
    result = detector.detect_trend(values, window_size=7)
    assert result["trend"] == "stable"
    assert -10 <= result["percent_change"] <= 10


def test_detect_trend_insufficient_data(detector):
    """Too few values should return insufficient_data."""
    values = [1, 2, 3, 4, 5]
    result = detector.detect_trend(values, window_size=7)
    assert result["trend"] == "insufficient_data"


def test_detect_trend_custom_window(detector):
    """Should support custom window sizes."""
    values = [100, 100, 100, 200, 200, 200]
    result = detector.detect_trend(values, window_size=3)
    assert result["trend"] == "up"


def test_detect_trend_zero_previous(detector):
    """Zero previous average should handle division by zero."""
    values = [0, 0, 0, 0, 0, 0, 0, 10, 10, 10, 10, 10, 10, 10]
    result = detector.detect_trend(values, window_size=7)
    assert result["trend"] == "up"
    assert result["percent_change"] == 100.0


def test_detect_trend_custom_sensitivity(detector):
    """Custom sensitivity threshold should affect classification."""
    values = [100, 100, 100, 100, 100, 100, 100, 106, 106, 106, 106, 106, 106, 106]
    result_default = detector.detect_trend(values, window_size=7)
    assert result_default["trend"] == "stable"
    result_sensitive = detector.detect_trend(values, window_size=7, sensitivity_pct=5.0)
    assert result_sensitive["trend"] == "up"


def test_detect_trend_includes_averages(detector):
    """Result should include recent and previous averages."""
    values = [10, 10, 10, 10, 10, 10, 10, 20, 20, 20, 20, 20, 20, 20]
    result = detector.detect_trend(values, window_size=7)
    assert "recent_avg" in result
    assert "previous_avg" in result
    assert result["recent_avg"] == 20.0
    assert result["previous_avg"] == 10.0
