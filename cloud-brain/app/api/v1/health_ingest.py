"""Health data ingest endpoint.

Receives batched health data from the Edge Agent (iOS/Android) and upserts
it into the Cloud Brain's PostgreSQL database. This is the critical
device-to-cloud pipeline for Apple Health and Google Health Connect data.

The endpoint supports all data types in a single request, enabling the
device to sync everything in one HTTP call on app launch, pull-to-refresh,
or background sync triggers.
"""

from __future__ import annotations

import logging
from datetime import datetime

from fastapi import APIRouter, Depends, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.analytics.normalizer import DataNormalizer
from app.api.v1.auth import _get_auth_service
from app.api.v1.health_ingest_schemas import (
    HealthIngestRequest,
    HealthIngestResponse,
)
from app.database import get_db
from app.models.daily_metrics import DailyHealthMetrics
from app.models.health_data import (
    NutritionEntry as NutritionModel,
)
from app.models.health_data import (
    SleepRecord,
    UnifiedActivity,
    WeightMeasurement,
)
from app.services.auth_service import AuthService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/health", tags=["health"])
security = HTTPBearer()
_normalizer = DataNormalizer()


@router.post("/ingest", response_model=HealthIngestResponse)
async def ingest_health_data(
    request: Request,
    body: HealthIngestRequest,
    credentials: HTTPAuthorizationCredentials = Depends(security),
    auth_service: AuthService = Depends(_get_auth_service),
    db: AsyncSession = Depends(get_db),
) -> HealthIngestResponse:
    """Receive batched health data from the Edge Agent and upsert into the DB.

    Upserts all data types using source + date/original_id dedup constraints.
    The device can call this endpoint multiple times safely — duplicate records
    are updated in place rather than inserted again.

    Parameters
    ----------
    request : Request
        FastAPI request — used to access ``app.state`` services.
    body : HealthIngestRequest
        Batch payload containing workouts, sleep, nutrition, weight, and
        daily scalar metrics.
    credentials : HTTPAuthorizationCredentials
        Bearer token for the authenticated Zuralog user.
    auth_service : AuthService
        Injected auth service for verifying the JWT.
    db : AsyncSession
        Injected async database session.

    Returns
    -------
    HealthIngestResponse
        Counts of upserted records per data type plus a success flag.
    """
    user_data = await auth_service.get_user(credentials.credentials)
    user_id: str = user_data["id"]
    source = body.source
    counts: dict[str, int] = {}

    # ------------------------------------------------------------------ #
    # Workouts                                                             #
    # ------------------------------------------------------------------ #
    for w in body.workouts:
        normalized = _normalizer.normalize_activity(
            source,
            {
                "workoutActivityType": w.activity_type,
                "duration": w.duration_seconds,
                "totalDistance": w.distance_meters or 0.0,
                "totalEnergyBurned": w.calories,
                "startDate": w.start_time,
            },
        )
        existing = await db.execute(
            select(UnifiedActivity).where(
                UnifiedActivity.source == source,
                UnifiedActivity.original_id == w.original_id,
            )
        )
        row = existing.scalar_one_or_none()
        if row:
            row.activity_type = normalized["type"]
            row.duration_seconds = normalized["duration_seconds"]
            row.distance_meters = normalized["distance_meters"]
            row.calories = normalized["calories"]
            if normalized.get("start_time"):
                row.start_time = datetime.fromisoformat(normalized["start_time"])
        else:
            start_dt = (
                datetime.fromisoformat(normalized["start_time"]) if normalized.get("start_time") else datetime.utcnow()
            )
            db.add(
                UnifiedActivity(
                    user_id=user_id,
                    source=source,
                    original_id=w.original_id,
                    activity_type=normalized["type"],
                    duration_seconds=normalized["duration_seconds"],
                    distance_meters=normalized["distance_meters"],
                    calories=normalized["calories"],
                    start_time=start_dt,
                )
            )
    counts["workouts"] = len(body.workouts)

    # ------------------------------------------------------------------ #
    # Sleep                                                                #
    # ------------------------------------------------------------------ #
    for s in body.sleep:
        existing = await db.execute(
            select(SleepRecord).where(
                SleepRecord.user_id == user_id,
                SleepRecord.source == source,
                SleepRecord.date == s.date,
            )
        )
        row = existing.scalar_one_or_none()
        if row:
            row.hours = s.hours
            if s.quality_score is not None:
                row.quality_score = s.quality_score
        else:
            db.add(
                SleepRecord(
                    user_id=user_id,
                    source=source,
                    date=s.date,
                    hours=s.hours,
                    quality_score=s.quality_score,
                )
            )
    counts["sleep"] = len(body.sleep)

    # ------------------------------------------------------------------ #
    # Nutrition                                                            #
    # ------------------------------------------------------------------ #
    for n in body.nutrition:
        existing = await db.execute(
            select(NutritionModel).where(
                NutritionModel.user_id == user_id,
                NutritionModel.source == source,
                NutritionModel.date == n.date,
            )
        )
        row = existing.scalar_one_or_none()
        if row:
            row.calories = n.calories
            if n.protein_grams is not None:
                row.protein_grams = n.protein_grams
            if n.carbs_grams is not None:
                row.carbs_grams = n.carbs_grams
            if n.fat_grams is not None:
                row.fat_grams = n.fat_grams
        else:
            db.add(
                NutritionModel(
                    user_id=user_id,
                    source=source,
                    date=n.date,
                    calories=n.calories,
                    protein_grams=n.protein_grams,
                    carbs_grams=n.carbs_grams,
                    fat_grams=n.fat_grams,
                )
            )
    counts["nutrition"] = len(body.nutrition)

    # ------------------------------------------------------------------ #
    # Weight                                                               #
    # ------------------------------------------------------------------ #
    for w in body.weight:
        existing = await db.execute(
            select(WeightMeasurement).where(
                WeightMeasurement.user_id == user_id,
                WeightMeasurement.source == source,
                WeightMeasurement.date == w.date,
            )
        )
        row = existing.scalar_one_or_none()
        if row:
            row.weight_kg = w.weight_kg
        else:
            db.add(
                WeightMeasurement(
                    user_id=user_id,
                    source=source,
                    date=w.date,
                    weight_kg=w.weight_kg,
                )
            )
    counts["weight"] = len(body.weight)

    # ------------------------------------------------------------------ #
    # Daily Metrics (steps, HR, HRV, VO2 max, etc.)                       #
    # ------------------------------------------------------------------ #
    for dm in body.daily_metrics:
        existing = await db.execute(
            select(DailyHealthMetrics).where(
                DailyHealthMetrics.user_id == user_id,
                DailyHealthMetrics.source == source,
                DailyHealthMetrics.date == dm.date,
            )
        )
        row = existing.scalar_one_or_none()
        if row:
            # Partial upsert: only update fields the device actually sent
            if dm.steps is not None:
                row.steps = dm.steps
            if dm.active_calories is not None:
                row.active_calories = dm.active_calories
            if dm.resting_heart_rate is not None:
                row.resting_heart_rate = dm.resting_heart_rate
            if dm.hrv_ms is not None:
                row.hrv_ms = dm.hrv_ms
            if dm.vo2_max is not None:
                row.vo2_max = dm.vo2_max
            if dm.distance_meters is not None:
                row.distance_meters = dm.distance_meters
            if dm.flights_climbed is not None:
                row.flights_climbed = dm.flights_climbed
            # Phase 6 new types
            if dm.body_fat_percentage is not None:
                row.body_fat_percentage = dm.body_fat_percentage
            if dm.respiratory_rate is not None:
                row.respiratory_rate = dm.respiratory_rate
            if dm.oxygen_saturation is not None:
                row.oxygen_saturation = dm.oxygen_saturation
            if dm.heart_rate_avg is not None:
                row.heart_rate_avg = dm.heart_rate_avg
        else:
            db.add(
                DailyHealthMetrics(
                    user_id=user_id,
                    source=source,
                    date=dm.date,
                    steps=dm.steps,
                    active_calories=dm.active_calories,
                    resting_heart_rate=dm.resting_heart_rate,
                    hrv_ms=dm.hrv_ms,
                    vo2_max=dm.vo2_max,
                    distance_meters=dm.distance_meters,
                    flights_climbed=dm.flights_climbed,
                    # Phase 6 new types
                    body_fat_percentage=dm.body_fat_percentage,
                    respiratory_rate=dm.respiratory_rate,
                    oxygen_saturation=dm.oxygen_saturation,
                    heart_rate_avg=dm.heart_rate_avg,
                )
            )
    counts["daily_metrics"] = len(body.daily_metrics)

    await db.commit()
    total = sum(counts.values())
    logger.info("Health ingest user=%s source=%s counts=%s", user_id, source, counts)

    return HealthIngestResponse(
        success=True,
        message=f"Ingested {total} records from {source}",
        counts=counts,
    )
