"""Heart detail API — /api/v1/heart

Endpoints:
  GET /summary  — today's full heart summary for the authenticated user
  GET /trend    — daily resting HR + HRV history for trend charting
  GET /all-data — per-day rows for all 8 heart metrics, powers the All-Data screen
"""

import logging
from datetime import timedelta
from typing import Annotated, Literal

from fastapi import APIRouter, Depends, Query, Request
from pydantic import BaseModel, ConfigDict
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_authenticated_user_id
from app.database import get_db
from app.limiter import limiter
from app.models.daily_summary import DailySummary
from app.models.health_event import HealthEvent
from app.models.insight import Insight
from app.utils.user_date import get_user_local_date

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/heart", tags=["heart"])

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

_HEART_METRIC_TYPES = [
    "resting_heart_rate",
    "hrv_ms",
    "heart_rate_avg",
    "respiratory_rate",
    "vo2_max",
    "spo2",
    "blood_pressure_systolic",
    "blood_pressure_diastolic",
]

_METRIC_TO_ALL_DATA_KEY: dict[str, str] = {
    "resting_heart_rate":       "resting_hr",
    "hrv_ms":                   "hrv",
    "heart_rate_avg":           "avg_hr",
    "respiratory_rate":         "respiratory_rate",
    "vo2_max":                  "vo2_max",
    "spo2":                     "spo2",
    "blood_pressure_systolic":  "bp_systolic",
    "blood_pressure_diastolic": "bp_diastolic",
}

_ALL_DATA_RANGE_DAYS: dict[str, int] = {
    "7d": 7, "30d": 30, "3m": 90, "6m": 180, "1y": 365,
}

_SOURCE_DISPLAY: dict[str, tuple[str, str]] = {
    "oura":           ("Oura Ring",      "#EC4899"),
    "fitbit":         ("Fitbit",         "#00B0B9"),
    "polar":          ("Polar",          "#D10019"),
    "withings":       ("Withings",       "#00B5AD"),
    "apple_health":   ("Apple Health",   "#FF375F"),
    "health_connect": ("Health Connect", "#4CAF50"),
    "manual":         ("Manual",         "#5E5CE6"),
}

# ---------------------------------------------------------------------------
# Pydantic schemas
# ---------------------------------------------------------------------------


class HeartSource(BaseModel):
    name: str
    icon: str
    brand_color: str


class HeartSummaryResponse(BaseModel):
    has_data: bool
    resting_hr: float | None
    hrv_ms: float | None
    avg_hr: float | None
    respiratory_rate: float | None
    vo2_max: float | None
    spo2: float | None
    bp_systolic: float | None
    bp_diastolic: float | None
    resting_hr_vs_7day: float | None
    hrv_vs_7day: float | None
    ai_summary: str | None
    ai_generated_at: str | None
    sources: list[HeartSource]


class HeartTrendDay(BaseModel):
    date: str
    resting_hr: float | None
    hrv_ms: float | None
    is_today: bool


class HeartTrendResponse(BaseModel):
    range: str
    days: list[HeartTrendDay]


class HeartAllDataDayValues(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    resting_hr: float | None = None
    hrv: float | None = None
    avg_hr: float | None = None
    respiratory_rate: float | None = None
    vo2_max: float | None = None
    spo2: float | None = None
    bp_systolic: float | None = None
    bp_diastolic: float | None = None


class HeartAllDataDay(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    date: str
    is_today: bool = False
    values: HeartAllDataDayValues


class HeartAllDataResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    days: list[HeartAllDataDay]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _source_to_schema(source_name: str) -> HeartSource:
    display_name, brand_color = _SOURCE_DISPLAY.get(
        source_name, (source_name.replace("_", " ").title(), "#888888")
    )
    return HeartSource(name=display_name, icon=source_name, brand_color=brand_color)


# ---------------------------------------------------------------------------
# GET /api/v1/heart/summary
# ---------------------------------------------------------------------------


@router.get("/summary", response_model=HeartSummaryResponse)
@limiter.limit("120/minute")
async def get_heart_summary(
    request: Request,
    user_id: Annotated[str, Depends(get_authenticated_user_id)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> HeartSummaryResponse:
    """Today's heart summary for the authenticated user."""
    local_date = await get_user_local_date(db, user_id)

    # 1. Today's metrics
    metrics_result = await db.execute(
        select(DailySummary).where(
            DailySummary.user_id == user_id,
            DailySummary.date == local_date,
            DailySummary.metric_type.in_(_HEART_METRIC_TYPES),
            DailySummary.is_stale.is_(False),
        )
    )

    # 2. RHR 7-day average (excluding today)
    rhr_avg_result = await db.execute(
        select(func.avg(DailySummary.value)).where(
            DailySummary.user_id == user_id,
            DailySummary.metric_type == "resting_heart_rate",
            DailySummary.date >= local_date - timedelta(days=7),
            DailySummary.date < local_date,
            DailySummary.is_stale.is_(False),
        )
    )

    # 3. HRV 7-day average (excluding today)
    hrv_avg_result = await db.execute(
        select(func.avg(DailySummary.value)).where(
            DailySummary.user_id == user_id,
            DailySummary.metric_type == "hrv_ms",
            DailySummary.date >= local_date - timedelta(days=7),
            DailySummary.date < local_date,
            DailySummary.is_stale.is_(False),
        )
    )

    # 4. AI summary insight
    insight_result = await db.execute(
        select(Insight)
        .where(
            Insight.user_id == user_id,
            Insight.type == "heart_summary",
            Insight.generation_date == local_date,
            Insight.dismissed_at.is_(None),
        )
        .order_by(Insight.priority.asc())
        .limit(1)
    )

    # 5. Distinct sources
    sources_result = await db.execute(
        select(HealthEvent.source)
        .distinct()
        .where(
            HealthEvent.user_id == user_id,
            HealthEvent.local_date == local_date,
            HealthEvent.metric_type.in_(_HEART_METRIC_TYPES),
            HealthEvent.deleted_at.is_(None),
        )
    )

    metrics: dict[str, float] = {
        row.metric_type: row.value
        for row in metrics_result.scalars().all()
    }
    insight = insight_result.scalars().first()
    rhr_7day_avg: float | None = rhr_avg_result.scalar()
    hrv_7day_avg: float | None = hrv_avg_result.scalar()
    source_names: list[str] = [row[0] for row in sources_result.fetchall()]

    has_data = bool(metrics)
    if not has_data:
        return HeartSummaryResponse(
            has_data=False,
            resting_hr=None,
            hrv_ms=None,
            avg_hr=None,
            respiratory_rate=None,
            vo2_max=None,
            spo2=None,
            bp_systolic=None,
            bp_diastolic=None,
            resting_hr_vs_7day=None,
            hrv_vs_7day=None,
            ai_summary=None,
            ai_generated_at=None,
            sources=[],
        )

    resting_hr = metrics.get("resting_heart_rate")
    hrv = metrics.get("hrv_ms")

    resting_hr_vs_7day = (
        round(resting_hr - rhr_7day_avg, 1)
        if resting_hr is not None and rhr_7day_avg is not None
        else None
    )
    hrv_vs_7day = (
        round(hrv - hrv_7day_avg, 1)
        if hrv is not None and hrv_7day_avg is not None
        else None
    )

    return HeartSummaryResponse(
        has_data=True,
        resting_hr=resting_hr,
        hrv_ms=hrv,
        avg_hr=metrics.get("heart_rate_avg"),
        respiratory_rate=metrics.get("respiratory_rate"),
        vo2_max=metrics.get("vo2_max"),
        spo2=metrics.get("spo2"),
        bp_systolic=metrics.get("blood_pressure_systolic"),
        bp_diastolic=metrics.get("blood_pressure_diastolic"),
        resting_hr_vs_7day=resting_hr_vs_7day,
        hrv_vs_7day=hrv_vs_7day,
        ai_summary=insight.body if insight else None,
        ai_generated_at=insight.created_at.isoformat() if insight else None,
        sources=[_source_to_schema(s) for s in source_names],
    )


# ---------------------------------------------------------------------------
# GET /api/v1/heart/trend
# ---------------------------------------------------------------------------


@router.get("/trend", response_model=HeartTrendResponse)
@limiter.limit("120/minute")
async def get_heart_trend(
    request: Request,
    user_id: Annotated[str, Depends(get_authenticated_user_id)],
    db: Annotated[AsyncSession, Depends(get_db)],
    range: Annotated[Literal["7d", "30d"], Query()] = "7d",
) -> HeartTrendResponse:
    """Daily resting HR and HRV history for trend charting."""
    local_date = await get_user_local_date(db, user_id)
    days = 7 if range == "7d" else 30

    result = await db.execute(
        select(DailySummary)
        .where(
            DailySummary.user_id == user_id,
            DailySummary.metric_type.in_(["resting_heart_rate", "hrv_ms"]),
            DailySummary.date >= local_date - timedelta(days=days - 1),
            DailySummary.date <= local_date,
            DailySummary.is_stale.is_(False),
        )
        .order_by(DailySummary.date)
    )
    rows = result.scalars().all()

    by_date: dict[str, dict[str, float]] = {}
    for row in rows:
        by_date.setdefault(str(row.date), {})[row.metric_type] = row.value

    trend_days = [
        HeartTrendDay(
            date=d,
            resting_hr=metrics.get("resting_heart_rate"),
            hrv_ms=metrics.get("hrv_ms"),
            is_today=(d == str(local_date)),
        )
        for d, metrics in sorted(by_date.items())
    ]

    return HeartTrendResponse(range=range, days=trend_days)


# ---------------------------------------------------------------------------
# GET /api/v1/heart/all-data
# ---------------------------------------------------------------------------


@router.get("/all-data", response_model=HeartAllDataResponse)
@limiter.limit("60/minute")
async def get_heart_all_data(
    request: Request,
    user_id: Annotated[str, Depends(get_authenticated_user_id)],
    db: Annotated[AsyncSession, Depends(get_db)],
    range: Annotated[
        Literal["7d", "30d", "3m", "6m", "1y"], Query()
    ] = "7d",
) -> HeartAllDataResponse:
    """Per-day rows for every heart metric -- powers the All-Data screen."""
    local_date = await get_user_local_date(db, user_id)
    day_count = _ALL_DATA_RANGE_DAYS[range]

    result = await db.execute(
        select(DailySummary)
        .where(
            DailySummary.user_id == user_id,
            DailySummary.metric_type.in_(_METRIC_TO_ALL_DATA_KEY.keys()),
            DailySummary.date >= local_date - timedelta(days=day_count - 1),
            DailySummary.date <= local_date,
            DailySummary.is_stale.is_(False),
        )
        .order_by(DailySummary.date)
    )
    rows = result.scalars().all()

    by_date: dict[str, dict[str, float]] = {}
    for row in rows:
        key = _METRIC_TO_ALL_DATA_KEY.get(row.metric_type)
        if key:
            by_date.setdefault(str(row.date), {})[key] = row.value

    return HeartAllDataResponse(
        days=[
            HeartAllDataDay(
                date=d,
                is_today=(d == str(local_date)),
                values=HeartAllDataDayValues(
                    resting_hr=metrics.get("resting_hr"),
                    hrv=metrics.get("hrv"),
                    avg_hr=metrics.get("avg_hr"),
                    respiratory_rate=metrics.get("respiratory_rate"),
                    vo2_max=metrics.get("vo2_max"),
                    spo2=metrics.get("spo2"),
                    bp_systolic=metrics.get("bp_systolic"),
                    bp_diastolic=metrics.get("bp_diastolic"),
                ),
            )
            for d, metrics in sorted(by_date.items())
        ],
    )
