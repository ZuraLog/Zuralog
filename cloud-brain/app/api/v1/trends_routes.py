"""
Zuralog Cloud Brain — Trends API Router.

Provides the aggregated Trends Home endpoint consumed by the Flutter
Trends tab (Tab 4). Returns AI-surfaced correlation highlights and
time-machine period summaries.
"""

import re
import statistics
import zoneinfo
from datetime import datetime
from datetime import timedelta

import sentry_sdk
from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.analytics.correlation_analyzer import CorrelationAnalyzer
from app.analytics.health_brief_builder import HealthBriefBuilder
from app.analytics.insight_signal_detector import InsightSignalDetector
from app.api.deps import get_authenticated_user_id
from app.api.v1.analytics_schemas import (
    ChartSeriesPointSchema,
    CorrelationHighlightSchema,
    PatternExpandResponse,
    TrendsHomeResponse,
)
from app.database import get_db
from app.limiter import limiter


# Maps InsightSignalDetector metric names → daily_summaries.metric_type column values
_SIGNAL_METRIC_TO_DB_TYPE: dict[str, str] = {
    "sleep_hours": "sleep_duration",
    "sleep_quality": "sleep_quality",
    "steps": "steps",
    "active_calories": "active_calories",
    "hrv_ms": "hrv_ms",
    "resting_heart_rate": "resting_heart_rate",
    "calorie_intake": "calories",
    "weight_kg": "weight_kg",
    "distance_meters": "distance",
}

_METRIC_DISPLAY_NAMES: dict[str, str] = {
    "sleep_hours": "Sleep Duration",
    "sleep_quality": "Sleep Quality",
    "steps": "Steps",
    "active_calories": "Active Calories",
    "hrv_ms": "HRV",
    "resting_heart_rate": "Resting Heart Rate",
    "calorie_intake": "Calorie Intake",
    "weight_kg": "Weight",
    "distance_meters": "Distance",
}

# (category_slug, hex_color)
_METRIC_TO_CATEGORY: dict[str, tuple[str, str]] = {
    "sleep_hours": ("sleep", "#BF5AF2"),
    "sleep_quality": ("sleep", "#BF5AF2"),
    "steps": ("activity", "#30D158"),
    "active_calories": ("activity", "#30D158"),
    "hrv_ms": ("heart", "#FF375F"),
    "resting_heart_rate": ("heart", "#FF375F"),
    "calorie_intake": ("nutrition", "#FF9F0A"),
    "weight_kg": ("body", "#64D2FF"),
    "distance_meters": ("activity", "#30D158"),
}

_MIN_MATURITY_DAYS = 7  # minimum days of data before we show anything


async def _get_user_tz(user_id: str, db: AsyncSession) -> zoneinfo.ZoneInfo:
    """Fetch the user's preferred timezone from user_preferences, defaulting to UTC."""
    row = await db.execute(
        text("SELECT timezone FROM user_preferences WHERE user_id = :uid"),
        {"uid": str(user_id)},
    )
    iana_tz = row.scalar_one_or_none() or "UTC"
    try:
        return zoneinfo.ZoneInfo(iana_tz)
    except Exception:
        return zoneinfo.ZoneInfo("UTC")


def _make_pattern_id(metric_a: str, metric_b: str) -> str:
    return f"corr_{metric_a}_{metric_b}"


def _parse_pattern_id(pattern_id: str) -> tuple[str, str] | None:
    """Parse 'corr_{a}_{b}' into (a, b). Returns None if format doesn't match."""
    if not pattern_id.startswith("corr_"):
        return None
    rest = pattern_id[5:]  # strip "corr_"
    # We need to find the split point — try all valid metric names as metric_a
    for a in sorted(_SIGNAL_METRIC_TO_DB_TYPE, key=len, reverse=True):
        if rest.startswith(a + "_"):
            b = rest[len(a) + 1:]
            if b in _SIGNAL_METRIC_TO_DB_TYPE:
                return a, b
    return None


def _make_headline(metric_a: str, metric_b: str, score: float) -> str:
    a = _METRIC_DISPLAY_NAMES.get(metric_a, metric_a.replace("_", " ").title())
    b = _METRIC_DISPLAY_NAMES.get(metric_b, metric_b.replace("_", " ").title())
    if score > 0.7:
        return f"{a} strongly predicts {b}"
    elif score > 0.4:
        return f"{a} linked to {b}"
    elif score < -0.7:
        return f"More {a}, less {b}"
    else:
        return f"{a} may affect {b}"


def _make_body(metric_a: str, metric_b: str, score: float, lag: int) -> str:
    a = _METRIC_DISPLAY_NAMES.get(metric_a, metric_a.replace("_", " ").title())
    b = _METRIC_DISPLAY_NAMES.get(metric_b, metric_b.replace("_", " ").title())
    strength = "strong" if abs(score) > 0.7 else "moderate"
    direction = "positive" if score > 0 else "inverse"
    lag_text = ""
    if lag == 1:
        lag_text = " the following day"
    elif lag > 1:
        lag_text = f" about {lag} days later"
    return (
        f"Your data shows a {strength} {direction} relationship between "
        f"{a.lower()} and {b.lower()}{lag_text}. "
        f"Correlation: {score:+.2f}."
    )


async def _set_sentry_module() -> None:
    """Tag the current Sentry scope with the trends module name."""
    sentry_sdk.set_tag("api.module", "trends")


router = APIRouter(
    prefix="/trends",
    tags=["trends"],
    dependencies=[Depends(_set_sentry_module)],
)


@limiter.limit("5/minute")
@router.get("/home", response_model=TrendsHomeResponse)
async def trends_home(
    request: Request,
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(get_authenticated_user_id),
) -> TrendsHomeResponse:
    """Return aggregated Trends Home data.

    Returns correlation highlights driven by the user's actual health data.
    Returns an empty scaffold when the user has fewer than 7 days of data.

    Args:
        user_id: Authenticated user ID from JWT.
        db: Async database session.

    Returns:
        TrendsHomeResponse with correlation highlights and metadata.
    """
    brief = await HealthBriefBuilder(user_id=user_id, db=db).build()

    if brief.data_maturity_days < _MIN_MATURITY_DAYS:
        return TrendsHomeResponse()

    corr_signals = InsightSignalDetector(brief).detect_correlations()
    corr_signals.sort(key=lambda s: abs(s.values.get("correlation", 0.0)), reverse=True)
    corr_signals = corr_signals[:10]

    highlights: list[CorrelationHighlightSchema] = []
    for s in corr_signals:
        coefficient = s.values.get("correlation", 0.0)
        direction = "positive" if coefficient > 0 else "negative" if coefficient < 0 else "neutral"
        highlights.append(
            CorrelationHighlightSchema(
                id=_make_pattern_id(s.metrics[0], s.metrics[1]),
                metric_a=_METRIC_DISPLAY_NAMES.get(s.metrics[0], s.metrics[0]),
                metric_b=_METRIC_DISPLAY_NAMES.get(s.metrics[1], s.metrics[1]),
                coefficient=coefficient,
                direction=direction,
                headline=_make_headline(s.metrics[0], s.metrics[1], coefficient),
                body=_make_body(s.metrics[0], s.metrics[1], coefficient, s.values.get("lag_days", 0)),
                category_color_hex=_METRIC_TO_CATEGORY.get(s.metrics[0], ("activity", "#30D158"))[1],
                category=_METRIC_TO_CATEGORY.get(s.metrics[0], ("activity", "#30D158"))[0],
            )
        )

    has_correlations = len(corr_signals) > 0
    return TrendsHomeResponse(
        correlation_highlights=highlights,
        has_enough_data=True,
        has_correlations=has_correlations,
        pattern_count=len(corr_signals),
    )


@limiter.limit("60/minute")
@router.get("/metrics")
async def trends_metrics(
    request: Request,
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(get_authenticated_user_id),
) -> dict:
    """Return available metrics for the correlation explorer picker.

    Queries the user's actual recorded metric types from the database.

    Args:
        user_id: Authenticated user ID from JWT.
        db: Async database session.

    Returns:
        dict with a 'metrics' key listing available metric type strings.
    """
    rows = await db.execute(
        text("SELECT DISTINCT metric_type FROM daily_summaries WHERE user_id = :uid ORDER BY metric_type"),
        {"uid": str(user_id)},
    )
    metric_types = [r.metric_type for r in rows.fetchall()]
    return {"metrics": metric_types}


@limiter.limit("30/minute")
@router.get("/correlations")
async def trends_correlations(
    request: Request,
    metric_a: str,
    metric_b: str,
    lag_days: int = 0,
    time_range: str = "30d",
    custom_start: str | None = None,
    custom_end: str | None = None,
    user_id: str = Depends(get_authenticated_user_id),
) -> dict:
    """Run a correlation analysis between two metrics.

    Currently returns an empty scaffold. Full computation (Pearson
    coefficient, scatter data, AI annotation) will be wired in a
    future phase.

    Args:
        metric_a: ID of the first metric.
        metric_b: ID of the second metric.
        lag_days: Offset in days to apply to metric_b (0–3).
        time_range: Time window string (e.g. ``"30d"``, ``"90d"``).
        custom_start: ISO-8601 start date when ``time_range`` is ``"custom"``.
        custom_end: ISO-8601 end date when ``time_range`` is ``"custom"``.
        user_id: Authenticated user ID from JWT.

    Returns:
        dict matching the CorrelationAnalysis model shape.
    """
    return {
        "metric_a_id": metric_a,
        "metric_b_id": metric_b,
        "lag_days": lag_days,
        "coefficient": None,
        "p_value": None,
        "interpretation": "not_enough_data",
        "ai_annotation": "Not enough data yet to compute a correlation. Keep syncing your devices.",
        "scatter_data": [],
        "sample_size": 0,
    }


@limiter.limit("30/minute")
@router.get("/correlation")
async def trends_correlation(
    request: Request,
    metric_a: str = Query(...),
    metric_b: str = Query(...),
    days: int = Query(default=90, ge=7, le=365),
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(get_authenticated_user_id),
) -> dict:
    """Correlation between two metrics over a time range."""
    valid_metrics = set(_SIGNAL_METRIC_TO_DB_TYPE.keys())
    if metric_a not in valid_metrics or metric_b not in valid_metrics:
        raise HTTPException(status_code=400, detail="Invalid metric name. Must be one of: " + ", ".join(sorted(valid_metrics)))

    user_tz = await _get_user_tz(user_id, db)
    local_date = datetime.now(tz=user_tz).date()
    start_date = local_date - timedelta(days=days)

    rows = await db.execute(
        text("""
            SELECT a.date, a.value AS metric_a_value, b.value AS metric_b_value
            FROM daily_summaries a
            JOIN daily_summaries b ON a.user_id = b.user_id AND a.date = b.date
            WHERE a.user_id = :uid
              AND a.metric_type = :ma
              AND b.metric_type = :mb
              AND a.date >= :start
            ORDER BY a.date
        """),
        {"uid": str(user_id), "ma": metric_a, "mb": metric_b, "start": start_date},
    )
    data_points = [
        {"date": str(r.date), "a_value": r.metric_a_value, "b_value": r.metric_b_value}
        for r in rows.fetchall()
    ]

    correlation = None
    if len(data_points) >= 3:
        xs = [p["a_value"] for p in data_points]
        ys = [p["b_value"] for p in data_points]
        try:
            correlation = round(statistics.correlation(xs, ys), 3)
        except statistics.StatisticsError:
            correlation = None

    return {"data_points": data_points, "correlation": correlation, "metric_a": metric_a, "metric_b": metric_b}


@limiter.limit("60/minute")
@router.get("/pattern/{pattern_id}/expand", response_model=PatternExpandResponse)
async def pattern_expand(
    request: Request,
    pattern_id: str,
    time_range: str = "30d",
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(get_authenticated_user_id),
) -> PatternExpandResponse:
    """Return chart series and AI explanation for a single pattern card."""
    if time_range not in {"7d", "30d", "90d"}:
        time_range = "30d"
    if not re.match(r"^[a-zA-Z0-9_-]{1,64}$", pattern_id):
        raise HTTPException(status_code=400, detail="Invalid pattern_id")

    pair = _parse_pattern_id(pattern_id)
    if pair is None:
        raise HTTPException(status_code=404, detail="Pattern not found")

    metric_a_key, metric_b_key = pair
    db_type_a = _SIGNAL_METRIC_TO_DB_TYPE[metric_a_key]
    db_type_b = _SIGNAL_METRIC_TO_DB_TYPE[metric_b_key]

    time_range_days = {"7d": 7, "30d": 30, "90d": 90}.get(time_range, 30)

    user_tz = await _get_user_tz(user_id, db)

    start = (datetime.now(tz=user_tz).date() - timedelta(days=time_range_days)).isoformat()

    rows = await db.execute(
        text("""
            SELECT a.date, a.value AS metric_a_value, b.value AS metric_b_value
            FROM daily_summaries a
            JOIN daily_summaries b ON a.user_id = b.user_id AND a.date = b.date
            WHERE a.user_id = :uid
              AND a.metric_type = :ma
              AND b.metric_type = :mb
              AND a.date >= :start
              AND a.value IS NOT NULL
              AND b.value IS NOT NULL
            ORDER BY a.date
        """),
        {"uid": str(user_id), "ma": db_type_a, "mb": db_type_b, "start": start},
    )
    results = rows.fetchall()

    raw_a_values: list[float] = []
    raw_b_values: list[float] = []
    series_a: list[ChartSeriesPointSchema] = []
    series_b: list[ChartSeriesPointSchema] = []

    for r in results:
        date_str = str(r.date)
        val_a = float(r.metric_a_value)
        val_b = float(r.metric_b_value)

        raw_a_values.append(val_a)
        raw_b_values.append(val_b)

        # Convert sleep_duration from minutes to hours for display
        display_a = val_a / 60.0 if db_type_a == "sleep_duration" else val_a
        display_b = val_b / 60.0 if db_type_b == "sleep_duration" else val_b

        series_a.append(ChartSeriesPointSchema(date=date_str, value=display_a))
        series_b.append(ChartSeriesPointSchema(date=date_str, value=display_b))

    coeff_result = CorrelationAnalyzer().calculate_correlation(raw_a_values, raw_b_values)

    data_days = len(series_a)
    a_label = _METRIC_DISPLAY_NAMES.get(metric_a_key, metric_a_key)
    b_label = _METRIC_DISPLAY_NAMES.get(metric_b_key, metric_b_key)

    if data_days < CorrelationAnalyzer.MIN_DATA_POINTS or coeff_result.get("score", 0.0) == 0.0:
        ai_explanation = "Not enough overlapping data yet to compute this correlation. Keep logging and check back soon."
    else:
        score = coeff_result.get("score", 0.0)
        strength = "strong" if abs(score) > 0.7 else "moderate"
        direction = "positive" if score > 0 else "inverse"
        ai_explanation = (
            f"Over the past {data_days} days, your {a_label.lower()} and {b_label.lower()} "
            f"show a {strength} {direction} correlation (r = {score:+.2f}). "
            f"{'When one goes up, the other tends to follow.' if score > 0 else 'When one goes up, the other tends to go down.'}"
        )

    return PatternExpandResponse(
        id=pattern_id,
        series_a=series_a,
        series_b=series_b,
        series_a_label=a_label,
        series_b_label=b_label,
        ai_explanation=ai_explanation,
        data_days=data_days,
        time_range=time_range,
    )
