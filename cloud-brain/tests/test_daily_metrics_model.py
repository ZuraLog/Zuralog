"""Tests for DailyHealthMetrics ORM model."""

from datetime import date

from app.models.daily_metrics import DailyHealthMetrics


def test_daily_metrics_creation():
    """Model can be instantiated with required fields."""
    m = DailyHealthMetrics(
        user_id="user-1",
        source="apple_health",
        date=str(date.today()),
        steps=8500,
        active_calories=320,
        resting_heart_rate=62.5,
        hrv_ms=45.0,
        vo2_max=42.1,
    )
    assert m.steps == 8500
    assert m.source == "apple_health"
    assert m.resting_heart_rate == 62.5


def test_daily_metrics_nullable_fields():
    """All metric fields are nullable — partial records are valid."""
    m = DailyHealthMetrics(
        user_id="user-1",
        source="apple_health",
        date=str(date.today()),
    )
    assert m.steps is None
    assert m.active_calories is None
    assert m.resting_heart_rate is None
    assert m.hrv_ms is None
    assert m.vo2_max is None
    assert m.distance_meters is None
    assert m.flights_climbed is None


def test_daily_metrics_table_name():
    """ORM model maps to the expected table name."""
    assert DailyHealthMetrics.__tablename__ == "daily_health_metrics"


def test_daily_metrics_unique_constraint_defined():
    """Unique constraint on (user_id, source, date) is present."""
    constraints = {c.name for c in DailyHealthMetrics.__table_args__ if hasattr(c, "name")}
    assert "uq_daily_metrics_user_source_date" in constraints
