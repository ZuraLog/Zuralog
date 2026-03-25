"""Tests for A-1: HealthIngestRequest must reject payloads with more than 500 records.

Verifies the @model_validator that enforces the 500-record cap across all
list fields combined: workouts, sleep, nutrition, weight, daily_metrics.
"""

import pytest
from pydantic import ValidationError

from app.api.v1.health_ingest_schemas import (
    DailyMetricsEntry,
    HealthIngestRequest,
    NutritionEntry,
    SleepEntry,
    WeightEntry,
    WorkoutEntry,
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _daily_metrics(n: int) -> list[DailyMetricsEntry]:
    return [DailyMetricsEntry(date=f"2026-01-{(i % 28) + 1:02d}") for i in range(n)]


def _sleep_entries(n: int) -> list[SleepEntry]:
    return [SleepEntry(date=f"2026-01-{(i % 28) + 1:02d}", hours=8.0) for i in range(n)]


def _nutrition_entries(n: int) -> list[NutritionEntry]:
    return [NutritionEntry(date=f"2026-01-{(i % 28) + 1:02d}", calories=2000) for i in range(n)]


def _weight_entries(n: int) -> list[WeightEntry]:
    return [WeightEntry(date=f"2026-01-{(i % 28) + 1:02d}", weight_kg=70.0) for i in range(n)]


def _workout_entries(n: int) -> list[WorkoutEntry]:
    return [
        WorkoutEntry(
            original_id=f"wo-{i}",
            activity_type="running",
            duration_seconds=3600,
            calories=400,
            start_time="2026-01-01T08:00:00",
        )
        for i in range(n)
    ]


# ---------------------------------------------------------------------------
# Boundary tests — single list
# ---------------------------------------------------------------------------

def test_exactly_500_daily_metrics_passes():
    """500 daily_metrics records must be accepted."""
    req = HealthIngestRequest(daily_metrics=_daily_metrics(500))
    assert len(req.daily_metrics) == 500


def test_501_daily_metrics_raises_validation_error():
    """501 daily_metrics records must raise ValidationError."""
    with pytest.raises(ValidationError) as exc_info:
        HealthIngestRequest(daily_metrics=_daily_metrics(501))
    assert "500" in str(exc_info.value)


def test_exactly_500_workouts_passes():
    """500 workout records must be accepted."""
    req = HealthIngestRequest(workouts=_workout_entries(500))
    assert len(req.workouts) == 500


def test_501_workouts_raises_validation_error():
    """501 workout records must raise ValidationError."""
    with pytest.raises(ValidationError):
        HealthIngestRequest(workouts=_workout_entries(501))


# ---------------------------------------------------------------------------
# Combined-total tests
# ---------------------------------------------------------------------------

def test_combined_total_exactly_500_passes():
    """200 workouts + 100 sleep + 100 nutrition + 100 weight = 500 — must pass."""
    req = HealthIngestRequest(
        workouts=_workout_entries(200),
        sleep=_sleep_entries(100),
        nutrition=_nutrition_entries(100),
        weight=_weight_entries(100),
    )
    total = (
        len(req.workouts) + len(req.sleep) + len(req.nutrition) + len(req.weight)
    )
    assert total == 500


def test_combined_total_501_raises_validation_error():
    """200 workouts + 100 sleep + 100 nutrition + 100 weight + 1 daily = 501 — must fail."""
    with pytest.raises(ValidationError):
        HealthIngestRequest(
            workouts=_workout_entries(200),
            sleep=_sleep_entries(100),
            nutrition=_nutrition_entries(100),
            weight=_weight_entries(100),
            daily_metrics=_daily_metrics(1),
        )


def test_empty_payload_passes():
    """An empty payload (0 records total) must be accepted."""
    req = HealthIngestRequest()
    assert req.daily_metrics == []
    assert req.workouts == []


def test_error_message_contains_record_count():
    """The ValidationError message must mention the actual record count."""
    with pytest.raises(ValidationError) as exc_info:
        HealthIngestRequest(daily_metrics=_daily_metrics(600))
    assert "600" in str(exc_info.value)
