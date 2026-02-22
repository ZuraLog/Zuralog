"""
Life Logger Cloud Brain — Health Data Models Tests.

Tests for the normalized health data SQLAlchemy ORM models:
UnifiedActivity, SleepRecord, NutritionEntry, WeightMeasurement.

These models store the output of the DataNormalizer for querying
by the analytics engine.
"""

from datetime import datetime, timezone

from app.models.health_data import (
    ActivityType,
    NutritionEntry,
    SleepRecord,
    UnifiedActivity,
    WeightMeasurement,
)


def test_unified_activity_creation():
    """UnifiedActivity should store normalized activity data."""
    activity = UnifiedActivity(
        user_id="user-123",
        source="strava",
        original_id="strava-abc",
        activity_type=ActivityType.RUN,
        duration_seconds=1800,
        distance_meters=5000.0,
        calories=350,
        start_time=datetime(2026, 2, 20, 8, 0, tzinfo=timezone.utc),
    )
    assert activity.user_id == "user-123"
    assert activity.activity_type == ActivityType.RUN
    assert activity.calories == 350


def test_sleep_record_creation():
    """SleepRecord should store sleep duration and quality."""
    sleep = SleepRecord(
        user_id="user-123",
        source="apple_health",
        date="2026-02-20",
        hours=7.5,
        quality_score=85,
    )
    assert sleep.hours == 7.5


def test_nutrition_entry_creation():
    """NutritionEntry should store daily nutrition totals."""
    entry = NutritionEntry(
        user_id="user-123",
        source="apple_health",
        date="2026-02-20",
        calories=1850,
        protein_grams=120.0,
        carbs_grams=200.0,
        fat_grams=65.0,
    )
    assert entry.calories == 1850


def test_weight_measurement_creation():
    """WeightMeasurement should store body weight readings."""
    weight = WeightMeasurement(
        user_id="user-123",
        source="apple_health",
        date="2026-02-20",
        weight_kg=82.5,
    )
    assert weight.weight_kg == 82.5


def test_activity_type_enum():
    """ActivityType enum should match DataNormalizer's ActivityType."""
    assert ActivityType.RUN.value == "run"
    assert ActivityType.CYCLE.value == "cycle"
    assert ActivityType.WALK.value == "walk"
    assert ActivityType.SWIM.value == "swim"
    assert ActivityType.STRENGTH.value == "strength"
    assert ActivityType.UNKNOWN.value == "unknown"


def test_all_models_have_uuid_default_configured():
    """All health data models should have a callable UUID default on their PK.

    SQLAlchemy column defaults are applied at INSERT time, not at Python
    construction time. We verify the default is configured on the column.
    """
    for model_cls in (UnifiedActivity, SleepRecord, NutritionEntry, WeightMeasurement):
        id_col = model_cls.__table__.c.id
        assert id_col.default is not None, f"{model_cls.__name__}.id has no default"
        assert id_col.default.is_callable, f"{model_cls.__name__}.id default is not callable"


def test_unified_activity_column_defaults():
    """UnifiedActivity should have column defaults for duration and calories."""
    table = UnifiedActivity.__table__
    assert table.c.duration_seconds.default.arg == 0
    assert table.c.calories.default.arg == 0
    assert table.c.distance_meters.nullable is True


def test_nutrition_entry_nullable_macros():
    """NutritionEntry macro fields should accept None."""
    entry = NutritionEntry(
        user_id="user-123",
        source="apple_health",
        date="2026-02-20",
        calories=1500,
    )
    assert entry.protein_grams is None
    assert entry.carbs_grams is None
    assert entry.fat_grams is None


def test_sleep_record_nullable_quality():
    """SleepRecord quality_score should accept None."""
    sleep = SleepRecord(
        user_id="user-123",
        source="apple_health",
        date="2026-02-20",
        hours=6.0,
    )
    assert sleep.quality_score is None
