"""
Life Logger Cloud Brain — Health Data Models.

SQLAlchemy ORM models for normalized health data produced by the
DataNormalizer (Phase 1.10). These models serve as the persistent
storage layer that the analytics engine queries against.

Models:
    - UnifiedActivity: Normalized activities from Strava, HealthKit, etc.
    - SleepRecord: Nightly sleep duration and quality metrics.
    - NutritionEntry: Daily nutrition totals (calories, macros).
    - WeightMeasurement: Body weight readings over time.
"""

import uuid
from datetime import datetime
from enum import Enum

from sqlalchemy import DateTime, Float, Integer, String, UniqueConstraint
from sqlalchemy import Enum as SAEnum
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from app.database import Base


class ActivityType(str, Enum):
    """Canonical activity types used across the entire system.

    Mirrors the ``ActivityType`` enum in ``app.analytics.normalizer``
    so that ORM models and the normalizer share the same vocabulary.

    Members:
        RUN: Running / jogging activities.
        CYCLE: Cycling / biking activities.
        WALK: Walking activities.
        SWIM: Swimming activities (pool or open water).
        STRENGTH: Weight training / resistance exercises.
        UNKNOWN: Unrecognized or unmapped activity types.
    """

    RUN = "run"
    CYCLE = "cycle"
    WALK = "walk"
    SWIM = "swim"
    STRENGTH = "strength"
    UNKNOWN = "unknown"


class UnifiedActivity(Base):
    """A normalized activity record from any connected data source.

    Stores the output of ``DataNormalizer.normalize_activity()`` so the
    analytics engine can query activities uniformly regardless of origin.

    Attributes:
        id: UUID primary key (auto-generated).
        user_id: Owner's user ID (indexed for fast lookups).
        source: Data source identifier (e.g. 'strava', 'apple_health').
        original_id: The record's ID in the source system, for dedup.
        activity_type: Canonical activity classification.
        duration_seconds: Total active duration in seconds (default 0).
        distance_meters: Distance covered in meters (nullable).
        calories: Energy expenditure in kcal (default 0).
        start_time: When the activity began (timezone-aware).
        created_at: Row creation timestamp (server-side default).
    """

    __tablename__ = "unified_activities"
    __table_args__ = (UniqueConstraint("source", "original_id", name="uq_activity_source_original"),)

    id: Mapped[str] = mapped_column(
        String,
        primary_key=True,
        default=lambda: str(uuid.uuid4()),
    )
    user_id: Mapped[str] = mapped_column(
        String,
        index=True,
    )
    source: Mapped[str] = mapped_column(String)
    original_id: Mapped[str] = mapped_column(String)
    activity_type: Mapped[ActivityType] = mapped_column(SAEnum(ActivityType))
    duration_seconds: Mapped[int] = mapped_column(Integer, default=0)
    distance_meters: Mapped[float | None] = mapped_column(Float, nullable=True)
    calories: Mapped[int] = mapped_column(Integer, default=0)
    start_time: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )


class SleepRecord(Base):
    """A nightly sleep record from a health data source.

    Captures sleep duration and an optional quality score derived from
    source-specific sleep stages or movement data.

    Attributes:
        id: UUID primary key (auto-generated).
        user_id: Owner's user ID (indexed for fast lookups).
        source: Data source identifier (e.g. 'apple_health').
        date: ISO-8601 date string (YYYY-MM-DD) for the sleep night.
        hours: Total sleep duration in fractional hours.
        quality_score: Optional 0-100 sleep quality metric (nullable).
        created_at: Row creation timestamp (server-side default).
    """

    __tablename__ = "sleep_records"
    __table_args__ = (UniqueConstraint("user_id", "source", "date", name="uq_sleep_user_source_date"),)

    id: Mapped[str] = mapped_column(
        String,
        primary_key=True,
        default=lambda: str(uuid.uuid4()),
    )
    user_id: Mapped[str] = mapped_column(
        String,
        index=True,
    )
    source: Mapped[str] = mapped_column(String)
    date: Mapped[str] = mapped_column(String)
    hours: Mapped[float] = mapped_column(Float)
    quality_score: Mapped[int | None] = mapped_column(Integer, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )


class NutritionEntry(Base):
    """A daily nutrition summary from a health data source.

    Stores total caloric intake and optional macronutrient breakdown
    for a single day.

    Attributes:
        id: UUID primary key (auto-generated).
        user_id: Owner's user ID (indexed for fast lookups).
        source: Data source identifier (e.g. 'apple_health').
        date: ISO-8601 date string (YYYY-MM-DD) for the nutrition day.
        calories: Total caloric intake in kcal.
        protein_grams: Protein intake in grams (nullable).
        carbs_grams: Carbohydrate intake in grams (nullable).
        fat_grams: Fat intake in grams (nullable).
        created_at: Row creation timestamp (server-side default).
    """

    __tablename__ = "nutrition_entries"
    __table_args__ = (UniqueConstraint("user_id", "source", "date", name="uq_nutrition_user_source_date"),)

    id: Mapped[str] = mapped_column(
        String,
        primary_key=True,
        default=lambda: str(uuid.uuid4()),
    )
    user_id: Mapped[str] = mapped_column(
        String,
        index=True,
    )
    source: Mapped[str] = mapped_column(String)
    date: Mapped[str] = mapped_column(String)
    calories: Mapped[int] = mapped_column(Integer)
    protein_grams: Mapped[float | None] = mapped_column(Float, nullable=True)
    carbs_grams: Mapped[float | None] = mapped_column(Float, nullable=True)
    fat_grams: Mapped[float | None] = mapped_column(Float, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )


class WeightMeasurement(Base):
    """A body weight reading from a health data source.

    Tracks weight over time for trend analysis and goal monitoring.

    Attributes:
        id: UUID primary key (auto-generated).
        user_id: Owner's user ID (indexed for fast lookups).
        source: Data source identifier (e.g. 'apple_health').
        date: ISO-8601 date string (YYYY-MM-DD) for the measurement.
        weight_kg: Body weight in kilograms.
        created_at: Row creation timestamp (server-side default).
    """

    __tablename__ = "weight_measurements"
    __table_args__ = (UniqueConstraint("user_id", "source", "date", name="uq_weight_user_source_date"),)

    id: Mapped[str] = mapped_column(
        String,
        primary_key=True,
        default=lambda: str(uuid.uuid4()),
    )
    user_id: Mapped[str] = mapped_column(
        String,
        index=True,
    )
    source: Mapped[str] = mapped_column(String)
    date: Mapped[str] = mapped_column(String)
    weight_kg: Mapped[float] = mapped_column(Float)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )
