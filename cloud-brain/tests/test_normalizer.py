"""
Zuralog Cloud Brain — Data Normalizer Tests.

Tests cross-source data normalization into the unified internal schema.
"""

import pytest

from app.analytics.normalizer import ActivityType, DataNormalizer


@pytest.fixture
def normalizer():
    """Create a DataNormalizer instance."""
    return DataNormalizer()


def test_normalize_strava_run(normalizer):
    """Strava Run activity should normalize to unified format."""
    raw = {
        "id": 12345,
        "type": "Run",
        "moving_time": 1800,
        "distance": 5000.0,
        "calories": 350,
        "start_date": "2026-02-20T08:00:00Z",
    }
    result = normalizer.normalize_activity("strava", raw)
    assert result["source"] == "strava"
    assert result["original_id"] == "12345"
    assert result["type"] == ActivityType.RUN
    assert result["duration_seconds"] == 1800
    assert result["distance_meters"] == 5000.0
    assert result["calories"] == 350
    assert result["start_time"] == "2026-02-20T08:00:00Z"


def test_normalize_strava_ride(normalizer):
    """Strava Ride should map to CYCLE type."""
    raw = {
        "id": 99,
        "type": "Ride",
        "moving_time": 3600,
        "distance": 20000.0,
        "start_date": "2026-02-19T07:00:00Z",
    }
    result = normalizer.normalize_activity("strava", raw)
    assert result["type"] == ActivityType.CYCLE


def test_normalize_strava_unknown_type(normalizer):
    """Unknown Strava type should map to UNKNOWN."""
    raw = {"id": 1, "type": "Yoga", "moving_time": 600, "distance": 0}
    result = normalizer.normalize_activity("strava", raw)
    assert result["type"] == ActivityType.UNKNOWN


def test_normalize_apple_health_running(normalizer):
    """Apple Health running workout should normalize correctly."""
    raw = {
        "id": "abc-123",
        "workoutActivityType": "HKWorkoutActivityTypeRunning",
        "duration": 2400,
        "totalDistance": 7500.0,
        "totalEnergyBurned": 500.0,
        "startDate": "2026-02-20T06:30:00Z",
    }
    result = normalizer.normalize_activity("apple_health", raw)
    assert result["source"] == "apple_health"
    assert result["type"] == ActivityType.RUN
    assert result["duration_seconds"] == 2400
    assert result["distance_meters"] == 7500.0
    assert result["calories"] == 500.0
    assert result["start_time"] == "2026-02-20T06:30:00Z"


def test_normalize_health_connect_walking(normalizer):
    """Health Connect walking exercise should normalize correctly."""
    raw = {
        "id": "hc-456",
        "exerciseType": 79,
        "duration_ms": 1800000,
        "distance_meters": 3000.0,
        "energy_calories": 200.0,
        "startTime": "2026-02-20T12:00:00Z",
    }
    result = normalizer.normalize_activity("health_connect", raw)
    assert result["source"] == "health_connect"
    assert result["type"] == ActivityType.WALK
    assert result["duration_seconds"] == 1800
    assert result["distance_meters"] == 3000.0
    assert result["calories"] == 200.0


def test_normalize_health_connect_swimming(normalizer):
    """Health Connect swimming exercise should map to SWIM type."""
    raw = {
        "id": "hc-789",
        "exerciseType": 74,  # EXERCISE_TYPE_SWIMMING_POOL
        "duration_ms": 2700000,
        "distance_meters": 1500.0,
        "energy_calories": 400.0,
        "startTime": "2026-02-20T07:00:00Z",
    }
    result = normalizer.normalize_activity("health_connect", raw)
    assert result["type"] == ActivityType.SWIM
    assert result["duration_seconds"] == 2700


def test_normalize_missing_fields_defaults(normalizer):
    """Missing fields should use safe defaults."""
    raw = {"id": "empty"}
    result = normalizer.normalize_activity("strava", raw)
    assert result["type"] == ActivityType.UNKNOWN
    assert result["duration_seconds"] == 0
    assert result["distance_meters"] == 0.0
    assert result["calories"] == 0.0
    assert result["start_time"] is None


def test_normalize_unknown_source(normalizer):
    """Unknown source should still produce a valid normalized dict."""
    raw = {"id": "x", "duration": 100}
    result = normalizer.normalize_activity("fitbit", raw)
    assert result["source"] == "fitbit"
    assert result["type"] == ActivityType.UNKNOWN


def test_apple_health_type_mapping_short_names():
    """Swift bridge sends short names like 'running', not HK-prefixed strings."""
    n = DataNormalizer()
    assert n._map_apple_type("running") == ActivityType.RUN
    assert n._map_apple_type("cycling") == ActivityType.CYCLE
    assert n._map_apple_type("walking") == ActivityType.WALK
    assert n._map_apple_type("swimming") == ActivityType.SWIM
    assert n._map_apple_type("strength_training") == ActivityType.STRENGTH
    assert n._map_apple_type("hiking") == ActivityType.WALK
    assert n._map_apple_type("yoga") == ActivityType.STRENGTH
    assert n._map_apple_type("dance") == ActivityType.UNKNOWN


def test_apple_health_type_mapping_hk_prefixed():
    """Legacy HK-prefixed names should still work after the fix."""
    n = DataNormalizer()
    assert n._map_apple_type("HKWorkoutActivityTypeRunning") == ActivityType.RUN
    assert n._map_apple_type("HKWorkoutActivityTypeCycling") == ActivityType.CYCLE
    assert n._map_apple_type("HKWorkoutActivityTypeWalking") == ActivityType.WALK
    assert n._map_apple_type("HKWorkoutActivityTypeSwimming") == ActivityType.SWIM
