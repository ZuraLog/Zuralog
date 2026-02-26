"""Daily scalar health metrics aggregated from Apple Health / Health Connect.

Stores per-day, per-source metric snapshots. The unique constraint on
(user_id, source, date) ensures one record per user per source per day,
enabling upsert semantics on the ingest endpoint — the device can safely
call the ingest endpoint multiple times without creating duplicate rows.
"""

import uuid

from sqlalchemy import Column, Float, Integer, String, UniqueConstraint

from app.database import Base


class DailyHealthMetrics(Base):
    """Daily health metrics snapshot from a single data source.

    Parameters
    ----------
    user_id : str
        The authenticated user's ID.
    source : str
        Data source identifier (e.g. ``"apple_health"``, ``"health_connect"``).
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
        VO2 max / cardio fitness level in mL/kg/min.
    distance_meters : float | None
        Total walking + running distance in meters.
    flights_climbed : int | None
        Flights of stairs climbed.
    """

    __tablename__ = "daily_health_metrics"
    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "source",
            "date",
            name="uq_daily_metrics_user_source_date",
        ),
    )

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String, index=True, nullable=False)
    source = Column(String, nullable=False)
    date = Column(String, nullable=False)

    # Core daily metrics
    steps = Column(Integer, nullable=True)
    active_calories = Column(Integer, nullable=True)
    resting_heart_rate = Column(Float, nullable=True)
    hrv_ms = Column(Float, nullable=True)
    vo2_max = Column(Float, nullable=True)

    # Extended metrics (distance + floors — Phase 6 adds more)
    distance_meters = Column(Float, nullable=True)
    flights_climbed = Column(Integer, nullable=True)
    body_fat_percentage = Column(Float, nullable=True)
    respiratory_rate = Column(Float, nullable=True)
    oxygen_saturation = Column(Float, nullable=True)
    heart_rate_avg = Column(Float, nullable=True)
