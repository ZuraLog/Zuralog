"""Schemas for the health data ingest endpoint.

The Edge Agent (iOS/Android) pushes health data to the Cloud Brain
via these schemas. Supports batch ingest of multiple data types
in a single request, so the device can push everything in one call.

All fields are optional at the request level — the device sends whichever
data types it has available. Each entry type has its own required fields.
"""

from __future__ import annotations

from pydantic import BaseModel, Field


class WorkoutEntry(BaseModel):
    """A single workout from HealthKit / Health Connect.

    Parameters
    ----------
    original_id : str
        Unique identifier from the health platform (used for dedup).
    activity_type : str
        Short activity name, e.g. ``"running"``, ``"cycling"``.
    duration_seconds : int
        Workout duration in seconds.
    distance_meters : float | None
        Distance covered in metres (optional for strength workouts).
    calories : int
        Active calories burned.
    start_time : str
        ISO 8601 datetime string.
    """

    original_id: str = Field(..., description="Unique ID from the health platform")
    activity_type: str = Field(..., description="e.g. running, cycling, swimming")
    duration_seconds: int = Field(0)
    distance_meters: float | None = None
    calories: int = Field(0)
    start_time: str = Field(..., description="ISO 8601 datetime")


class SleepEntry(BaseModel):
    """A single nightly sleep record.

    Parameters
    ----------
    date : str
        ISO date string (YYYY-MM-DD).
    hours : float
        Total sleep duration in hours.
    quality_score : int | None
        Optional 0–100 sleep quality score.
    """

    date: str = Field(..., description="ISO date YYYY-MM-DD")
    hours: float
    quality_score: int | None = None


class NutritionEntry(BaseModel):
    """Daily nutrition summary.

    Parameters
    ----------
    date : str
        ISO date string (YYYY-MM-DD).
    calories : int
        Total calories consumed.
    protein_grams : float | None
        Protein in grams (optional).
    carbs_grams : float | None
        Carbohydrates in grams (optional).
    fat_grams : float | None
        Fat in grams (optional).
    """

    date: str = Field(..., description="ISO date YYYY-MM-DD")
    calories: int
    protein_grams: float | None = None
    carbs_grams: float | None = None
    fat_grams: float | None = None


class WeightEntry(BaseModel):
    """A single body weight measurement.

    Parameters
    ----------
    date : str
        ISO date string (YYYY-MM-DD).
    weight_kg : float
        Weight in kilograms.
    """

    date: str = Field(..., description="ISO date YYYY-MM-DD")
    weight_kg: float


class DailyMetricsEntry(BaseModel):
    """Daily scalar metrics snapshot (steps, HR, HRV, VO2 max, etc.).

    Parameters
    ----------
    date : str
        ISO date string (YYYY-MM-DD).
    steps : int | None
        Total step count for the day.
    active_calories : int | None
        Active energy burned in kcal.
    resting_heart_rate : float | None
        Resting heart rate in bpm.
    hrv_ms : float | None
        Heart rate variability (SDNN) in milliseconds.
    vo2_max : float | None
        VO2 max / cardio fitness in mL/kg/min.
    distance_meters : float | None
        Total walking + running distance in metres.
    flights_climbed : int | None
        Flights of stairs climbed.
    body_fat_percentage : float | None
        Body fat percentage (0–100).
    respiratory_rate : float | None
        Average respiratory rate in breaths/minute.
    oxygen_saturation : float | None
        Blood oxygen saturation percentage (SpO2, 0–100).
    heart_rate_avg : float | None
        Average heart rate for the day in bpm.
    """

    date: str = Field(..., description="ISO date YYYY-MM-DD")
    steps: int | None = None
    active_calories: int | None = None
    resting_heart_rate: float | None = None
    hrv_ms: float | None = None
    vo2_max: float | None = None
    distance_meters: float | None = None
    flights_climbed: int | None = None
    # Phase 6 new types
    body_fat_percentage: float | None = None
    respiratory_rate: float | None = None
    oxygen_saturation: float | None = None
    heart_rate_avg: float | None = None


class HealthIngestRequest(BaseModel):
    """Batch ingest request from the Edge Agent.

    All list fields are optional — the device sends whichever data types
    it has available. This enables incremental and partial syncs.

    Parameters
    ----------
    source : str
        Data source identifier (e.g. ``"apple_health"``).
    workouts : list[WorkoutEntry]
        Workout records to upsert.
    sleep : list[SleepEntry]
        Sleep records to upsert.
    nutrition : list[NutritionEntry]
        Nutrition records to upsert.
    weight : list[WeightEntry]
        Weight measurements to upsert.
    daily_metrics : list[DailyMetricsEntry]
        Daily scalar metric snapshots to upsert.
    """

    source: str = Field("apple_health", description="Data source identifier")
    workouts: list[WorkoutEntry] = Field(default_factory=list)
    sleep: list[SleepEntry] = Field(default_factory=list)
    nutrition: list[NutritionEntry] = Field(default_factory=list)
    weight: list[WeightEntry] = Field(default_factory=list)
    daily_metrics: list[DailyMetricsEntry] = Field(default_factory=list)


class HealthIngestResponse(BaseModel):
    """Response from the ingest endpoint.

    Parameters
    ----------
    success : bool
        Whether the ingest completed without errors.
    message : str
        Human-readable summary.
    counts : dict[str, int]
        Number of records upserted per data type.
    """

    success: bool
    message: str
    counts: dict[str, int] = Field(default_factory=dict)
