"""Sleep detail API — /api/v1/sleep

Endpoints:
  GET /summary  — today's full sleep summary for the authenticated user
  GET /trend    — daily sleep duration history for trend charting
"""

import asyncio
import logging
from datetime import date, datetime, timedelta, timezone
from typing import Annotated, Literal

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_authenticated_user_id
from app.database import get_db
from app.models.activity_session import ActivitySession
from app.models.daily_summary import DailySummary
from app.models.health_event import HealthEvent
from app.models.insight import Insight
from app.models.user_preferences import UserPreferences

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/sleep", tags=["sleep"])

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

_SLEEP_METRIC_TYPES = [
    "sleep_duration",
    "sleep_quality",
    "deep_sleep_minutes",
    "rem_sleep_minutes",
    "light_sleep_minutes",
    "awake_during_sleep_minutes",
    "sleep_efficiency",
]

_QUALITY_LABELS = {1: "Awful", 2: "Poor", 3: "Okay", 4: "Good", 5: "Great"}

_SOURCE_DISPLAY: dict[str, tuple[str, str]] = {
    "oura":           ("Oura Ring",       "#EC4899"),
    "fitbit":         ("Fitbit",          "#00B0B9"),
    "polar":          ("Polar",           "#D10019"),
    "withings":       ("Withings",        "#00B5AD"),
    "apple_health":   ("Apple Health",    "#FF375F"),
    "health_connect": ("Health Connect",  "#4CAF50"),
    "manual":         ("Manual",          "#5E5CE6"),
}

# ---------------------------------------------------------------------------
# Pydantic response schemas
# ---------------------------------------------------------------------------

class SleepSource(BaseModel):
    name: str
    icon: str
    brand_color: str


class HRPoint(BaseModel):
    time: str
    bpm: float


class SleepingHR(BaseModel):
    avg_bpm: float | None
    low_bpm: float | None
    high_bpm: float | None
    curve: list[HRPoint]


class SleepStages(BaseModel):
    deep_minutes: int | None
    rem_minutes: int | None
    light_minutes: int | None
    awake_minutes: int | None


class SleepSummaryResponse(BaseModel):
    has_data: bool
    duration_minutes: int | None
    bedtime: str | None
    wake_time: str | None
    quality_rating: int | None
    quality_label: str | None
    sleep_efficiency_pct: float | None
    avg_vs_7day_minutes: int | None
    stages: SleepStages | None
    sleeping_hr: SleepingHR | None
    factors: list[str]
    interruptions: int | None
    notes: str | None
    ai_summary: str | None
    ai_generated_at: str | None
    sources: list[SleepSource]


class SleepTrendDay(BaseModel):
    date: str
    duration_minutes: int | None
    quality_rating: int | None
    is_today: bool


class SleepTrendResponse(BaseModel):
    range: str
    days: list[SleepTrendDay]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

async def _get_user_local_date(user_id: str, db: AsyncSession) -> date:
    """Return user's current local date based on their timezone preference."""
    result = await db.execute(
        select(UserPreferences).where(UserPreferences.user_id == user_id)
    )
    prefs = result.scalars().first()
    tz_str = (prefs.timezone if prefs and hasattr(prefs, "timezone") and prefs.timezone else "UTC")
    try:
        import zoneinfo
        tz = zoneinfo.ZoneInfo(tz_str)
    except Exception:
        tz = timezone.utc
    return datetime.now(tz).date()


def _source_to_schema(source_name: str) -> SleepSource:
    display_name, brand_color = _SOURCE_DISPLAY.get(
        source_name, (source_name.replace("_", " ").title(), "#888888")
    )
    return SleepSource(name=display_name, icon=source_name, brand_color=brand_color)


# ---------------------------------------------------------------------------
# GET /api/v1/sleep/summary
# ---------------------------------------------------------------------------

@router.get("/summary", response_model=SleepSummaryResponse)
async def get_sleep_summary(
    user_id: Annotated[str, Depends(get_authenticated_user_id)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> SleepSummaryResponse:
    local_date = await _get_user_local_date(user_id, db)

    (
        metrics_result,
        session_result,
        insight_result,
        week_avg_result,
        sources_result,
    ) = await asyncio.gather(
        db.execute(
            select(DailySummary).where(
                DailySummary.user_id == user_id,
                DailySummary.date == local_date,
                DailySummary.metric_type.in_(_SLEEP_METRIC_TYPES),
                DailySummary.is_stale.is_(False),
            )
        ),
        db.execute(
            select(ActivitySession)
            .where(
                ActivitySession.user_id == user_id,
                ActivitySession.activity_type == "sleep",
                func.date(ActivitySession.started_at) == local_date,
            )
            .order_by(ActivitySession.started_at.desc())
            .limit(1)
        ),
        db.execute(
            select(Insight)
            .where(
                Insight.user_id == user_id,
                Insight.generation_date == local_date,
                Insight.signal_type.in_(
                    ["sleep_analysis", "compound_sleep_debt", "anomaly_alert"]
                ),
                Insight.dismissed_at.is_(None),
            )
            .order_by(Insight.priority.asc())
            .limit(1)
        ),
        db.execute(
            select(func.avg(DailySummary.value)).where(
                DailySummary.user_id == user_id,
                DailySummary.metric_type == "sleep_duration",
                DailySummary.date >= local_date - timedelta(days=7),
                DailySummary.date < local_date,
                DailySummary.is_stale.is_(False),
            )
        ),
        db.execute(
            select(HealthEvent.source)
            .distinct()
            .where(
                HealthEvent.user_id == user_id,
                HealthEvent.local_date == local_date,
                HealthEvent.metric_type.in_(_SLEEP_METRIC_TYPES),
                HealthEvent.deleted_at.is_(None),
            )
        ),
    )

    metrics: dict[str, float] = {
        row.metric_type: row.value
        for row in metrics_result.scalars().all()
    }
    session = session_result.scalars().first()
    insight = insight_result.scalars().first()
    week_avg: float | None = week_avg_result.scalar()
    source_names: list[str] = [row[0] for row in sources_result.fetchall()]
    if session and session.source and session.source not in source_names:
        source_names.append(session.source)

    has_data = bool(metrics or session)
    if not has_data:
        return SleepSummaryResponse(
            has_data=False,
            duration_minutes=None,
            bedtime=None,
            wake_time=None,
            quality_rating=None,
            quality_label=None,
            sleep_efficiency_pct=None,
            avg_vs_7day_minutes=None,
            stages=None,
            sleeping_hr=None,
            factors=[],
            interruptions=None,
            notes=None,
            ai_summary=None,
            ai_generated_at=None,
            sources=[],
        )

    duration_min = int(metrics["sleep_duration"]) if "sleep_duration" in metrics else None
    quality = int(metrics["sleep_quality"]) if "sleep_quality" in metrics else None
    avg_vs = (
        int(duration_min - week_avg)
        if duration_min is not None and week_avg is not None
        else None
    )

    bedtime_iso = session.started_at.isoformat() if session else None
    wake_iso = (
        session.ended_at.isoformat() if session and session.ended_at else None
    )

    # Fetch HR curve only when the sleep window is known
    sleeping_hr: SleepingHR | None = None
    if session and session.ended_at:
        hr_result = await db.execute(
            select(HealthEvent)
            .where(
                HealthEvent.user_id == user_id,
                HealthEvent.metric_type == "heart_rate_avg",
                HealthEvent.recorded_at >= session.started_at,
                HealthEvent.recorded_at <= session.ended_at,
                HealthEvent.deleted_at.is_(None),
            )
            .order_by(HealthEvent.recorded_at)
        )
        hr_events = hr_result.scalars().all()
        if hr_events:
            bpms = [e.value for e in hr_events]
            sleeping_hr = SleepingHR(
                avg_bpm=round(sum(bpms) / len(bpms), 1),
                low_bpm=min(bpms),
                high_bpm=max(bpms),
                curve=[
                    HRPoint(time=e.recorded_at.isoformat(), bpm=e.value)
                    for e in hr_events
                ],
            )

    deep = int(metrics["deep_sleep_minutes"]) if "deep_sleep_minutes" in metrics else None
    rem = int(metrics["rem_sleep_minutes"]) if "rem_sleep_minutes" in metrics else None
    light = int(metrics["light_sleep_minutes"]) if "light_sleep_minutes" in metrics else None
    awake = int(metrics["awake_during_sleep_minutes"]) if "awake_during_sleep_minutes" in metrics else None
    stages = (
        SleepStages(
            deep_minutes=deep,
            rem_minutes=rem,
            light_minutes=light,
            awake_minutes=awake,
        )
        if any(v is not None for v in [deep, rem, light, awake])
        else None
    )

    session_meta: dict = (session.metadata_ or {}) if session else {}

    return SleepSummaryResponse(
        has_data=True,
        duration_minutes=duration_min,
        bedtime=bedtime_iso,
        wake_time=wake_iso,
        quality_rating=quality,
        quality_label=_QUALITY_LABELS.get(quality) if quality else None,
        sleep_efficiency_pct=metrics.get("sleep_efficiency"),
        avg_vs_7day_minutes=avg_vs,
        stages=stages,
        sleeping_hr=sleeping_hr,
        factors=session_meta.get("factors", []),
        interruptions=session_meta.get("interruptions"),
        notes=session.notes if session else None,
        ai_summary=insight.body if insight else None,
        ai_generated_at=insight.created_at.isoformat() if insight else None,  # type: ignore[attr-defined]
        sources=[_source_to_schema(s) for s in source_names],
    )


# ---------------------------------------------------------------------------
# GET /api/v1/sleep/trend
# ---------------------------------------------------------------------------

@router.get("/trend", response_model=SleepTrendResponse)
async def get_sleep_trend(
    user_id: Annotated[str, Depends(get_authenticated_user_id)],
    db: Annotated[AsyncSession, Depends(get_db)],
    range: Annotated[Literal["7d", "30d"], Query()] = "7d",
) -> SleepTrendResponse:
    local_date = await _get_user_local_date(user_id, db)
    days = 7 if range == "7d" else 30

    result = await db.execute(
        select(DailySummary)
        .where(
            DailySummary.user_id == user_id,
            DailySummary.metric_type.in_(["sleep_duration", "sleep_quality"]),
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
        SleepTrendDay(
            date=d,
            duration_minutes=(
                int(metrics["sleep_duration"])
                if "sleep_duration" in metrics
                else None
            ),
            quality_rating=(
                int(metrics["sleep_quality"])
                if "sleep_quality" in metrics
                else None
            ),
            is_today=(d == str(local_date)),
        )
        for d, metrics in sorted(by_date.items())
    ]

    return SleepTrendResponse(range=range, days=trend_days)
