"""
Life Logger Cloud Brain — Deduplication / Source-of-Truth Tests.

Tests overlap detection and priority-based conflict resolution
for activities recorded by multiple sources.
"""

import pytest

from app.analytics.deduplication import SourceOfTruth


@pytest.fixture
def sot():
    """Create a SourceOfTruth instance."""
    return SourceOfTruth()


def test_no_activities(sot):
    """Empty list should return empty list."""
    assert sot.resolve_conflicts([]) == []


def test_single_activity_passes_through(sot):
    """A single activity should pass through unchanged."""
    activities = [
        {
            "source": "strava",
            "start_time": "2026-02-20T08:00:00Z",
            "duration_seconds": 1800,
            "type": "run",
        }
    ]
    result = sot.resolve_conflicts(activities)
    assert len(result) == 1
    assert result[0]["source"] == "strava"


def test_non_overlapping_activities_kept(sot):
    """Two activities at different times should both be kept."""
    activities = [
        {
            "source": "strava",
            "start_time": "2026-02-20T08:00:00Z",
            "duration_seconds": 1800,
            "type": "run",
        },
        {
            "source": "apple_health",
            "start_time": "2026-02-20T18:00:00Z",
            "duration_seconds": 2400,
            "type": "cycle",
        },
    ]
    result = sot.resolve_conflicts(activities)
    assert len(result) == 2


def test_overlapping_picks_higher_priority(sot):
    """Overlapping activities should keep the higher-priority source."""
    activities = [
        {
            "source": "strava",
            "start_time": "2026-02-20T08:00:00Z",
            "duration_seconds": 1800,
            "type": "run",
        },
        {
            "source": "apple_health",
            "start_time": "2026-02-20T08:05:00Z",
            "duration_seconds": 1800,
            "type": "run",
        },
    ]
    result = sot.resolve_conflicts(activities)
    assert len(result) == 1
    assert result[0]["source"] == "apple_health"  # priority 10 > 8


def test_overlapping_same_priority_keeps_first(sot):
    """Same-priority overlapping activities keep the first one."""
    activities = [
        {
            "source": "apple_health",
            "start_time": "2026-02-20T08:00:00Z",
            "duration_seconds": 1800,
            "type": "run",
        },
        {
            "source": "health_connect",
            "start_time": "2026-02-20T08:01:00Z",
            "duration_seconds": 1800,
            "type": "run",
        },
    ]
    result = sot.resolve_conflicts(activities)
    assert len(result) == 1
    assert result[0]["source"] == "apple_health"  # first wins on tie


def test_three_activities_partial_overlap(sot):
    """Three activities: first and second overlap, third is separate."""
    activities = [
        {
            "source": "strava",
            "start_time": "2026-02-20T08:00:00Z",
            "duration_seconds": 3600,
            "type": "run",
        },
        {
            "source": "apple_health",
            "start_time": "2026-02-20T08:10:00Z",
            "duration_seconds": 3000,
            "type": "run",
        },
        {
            "source": "strava",
            "start_time": "2026-02-20T18:00:00Z",
            "duration_seconds": 1800,
            "type": "cycle",
        },
    ]
    result = sot.resolve_conflicts(activities)
    assert len(result) == 2
    assert result[0]["source"] == "apple_health"
    assert result[1]["source"] == "strava"


def test_missing_start_time_sorted_last(sot):
    """Activities with None start_time should be placed at the end."""
    activities = [
        {
            "source": "strava",
            "start_time": None,
            "duration_seconds": 600,
            "type": "walk",
        },
        {
            "source": "apple_health",
            "start_time": "2026-02-20T08:00:00Z",
            "duration_seconds": 1800,
            "type": "run",
        },
    ]
    result = sot.resolve_conflicts(activities)
    assert len(result) == 2


def test_overlap_threshold_50_percent(sot):
    """Activities overlapping < 50% should NOT be considered duplicates."""
    activities = [
        {
            "source": "strava",
            "start_time": "2026-02-20T08:00:00Z",
            "duration_seconds": 3600,
            "type": "run",
        },
        {
            "source": "apple_health",
            "start_time": "2026-02-20T08:50:00Z",
            "duration_seconds": 2400,
            "type": "cycle",
        },
    ]
    result = sot.resolve_conflicts(activities)
    assert len(result) == 2
