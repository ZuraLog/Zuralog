"""Supplements list management endpoints."""

import json
import logging
import uuid as _uuid
from datetime import datetime, timedelta, timezone
from fastapi import APIRouter, Depends, HTTPException, Query, Request
from pydantic import BaseModel, Field, model_validator
from sqlalchemy import delete as sa_delete
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.sql import func

from app.api.deps import get_authenticated_user_id
from app.database import get_db
from app.limiter import limiter
from app.models.quick_log import QuickLog
from app.models.user_supplement import UserSupplement

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/supplements", tags=["supplements"])


# ── Pydantic models ──────────────────────────────────────────────────────────


class SupplementItem(BaseModel):
    name: str = Field(max_length=200)
    dose: str | None = Field(default=None, max_length=100)
    timing: str | None = Field(default=None, max_length=50)
    dose_amount: float | None = Field(default=None, ge=0)
    dose_unit: str | None = Field(default=None, max_length=20)
    form: str | None = Field(default=None, max_length=20)


class SupplementListRequest(BaseModel):
    supplements: list[SupplementItem] = Field(max_length=50)


class SupplementResponse(BaseModel):
    id: str
    name: str
    dose: str | None
    timing: str | None
    dose_amount: float | None = None
    dose_unit: str | None = None
    form: str | None = None


class SupplementListResponse(BaseModel):
    supplements: list[SupplementResponse]


class TodayLogEntry(BaseModel):
    supplement_id: str
    log_id: str


class TodayLogResponse(BaseModel):
    entries: list[TodayLogEntry]


class ScanLabelRequest(BaseModel):
    image_base64: str | None = Field(default=None, max_length=2_800_000)
    barcode: str | None = Field(default=None, pattern=r'^\d{6,14}$', max_length=14)

    @model_validator(mode='after')
    def _require_one(self) -> 'ScanLabelRequest':
        if not self.image_base64 and not self.barcode:
            raise ValueError("Either image_base64 or barcode must be provided")
        return self


class ScanLabelResponse(BaseModel):
    name: str | None = None
    dose_amount: float | None = None
    dose_unit: str | None = None
    form: str | None = None
    confidence: float | None = None


class ConflictCheckRequest(BaseModel):
    name: str = Field(min_length=1, max_length=200)
    existing_names: list[str] = Field(max_length=50)
    exclude_id: str | None = Field(default=None)


class ConflictCheckResponse(BaseModel):
    has_conflict: bool
    conflict_type: str | None = None  # 'duplicate' | 'overlap'
    conflicting_name: str | None = None
    message: str | None = None


class TimingTipResponse(BaseModel):
    tip: str | None = None


class SupplementInsightItem(BaseModel):
    metric_type: str
    metric_label: str
    direction: str  # 'positive' | 'negative' | 'neutral'
    correlation: float
    insight_text: str


class SupplementInsightsResponse(BaseModel):
    insights: list[SupplementInsightItem]
    data_days: int
    has_enough_data: bool


# ── Helpers ──────────────────────────────────────────────────────────────────


def _row_to_response(row: UserSupplement) -> SupplementResponse:
    return SupplementResponse(
        id=row.id,
        name=row.name,
        dose=row.dose,
        timing=row.timing,
        dose_amount=float(row.dose_amount) if row.dose_amount is not None else None,
        dose_unit=row.dose_unit,
        form=row.form,
    )


# ── Routes ───────────────────────────────────────────────────────────────────


@limiter.limit("60/minute")
@router.get("/today-log", response_model=TodayLogResponse)
async def get_today_supplement_log(
    request: Request,
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(get_authenticated_user_id),
) -> TodayLogResponse:
    """Return supplement_id + log_id pairs for all supplements logged today (UTC day)."""
    today_start = datetime.now(timezone.utc).replace(
        hour=0, minute=0, second=0, microsecond=0
    )
    result = await db.execute(
        select(QuickLog).where(
            QuickLog.user_id == user_id,
            QuickLog.metric_type == "supplement_taken",
            QuickLog.logged_at >= today_start,
        )
    )
    rows = result.scalars().all()
    entries: list[TodayLogEntry] = []
    for row in rows:
        supplement_id = row.data.get("supplement_id")
        if supplement_id:
            entries.append(TodayLogEntry(supplement_id=supplement_id, log_id=row.id))
    return TodayLogResponse(entries=entries)


@limiter.limit("60/minute")
@router.get("", response_model=SupplementListResponse)
async def get_supplements(
    request: Request,
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(get_authenticated_user_id),
) -> SupplementListResponse:
    """Return the user's active supplement list ordered by sort_order."""
    result = await db.execute(
        select(UserSupplement)
        .where(
            UserSupplement.user_id == user_id,
            UserSupplement.is_active.is_(True),
        )
        .order_by(UserSupplement.sort_order.asc(), UserSupplement.created_at.asc())
    )
    rows = result.scalars().all()
    return SupplementListResponse(
        supplements=[_row_to_response(r) for r in rows],
    )


@limiter.limit("30/minute")
@router.post("", response_model=SupplementListResponse)
async def replace_supplements(
    request: Request,
    body: SupplementListRequest,
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(get_authenticated_user_id),
) -> SupplementListResponse:
    """Replace the user's supplement list atomically.

    1. Soft-delete all existing active rows.
    2. Insert new rows with sequential sort_order.
    """
    # Soft-delete existing active rows
    await db.execute(
        update(UserSupplement)
        .where(
            UserSupplement.user_id == user_id,
            UserSupplement.is_active.is_(True),
        )
        .values(is_active=False, updated_at=func.now())
    )

    # Insert new rows
    new_rows: list[UserSupplement] = []
    for idx, item in enumerate(body.supplements):
        row = UserSupplement(
            id=str(_uuid.uuid4()),
            user_id=user_id,
            name=item.name,
            dose=item.dose,
            timing=item.timing,
            dose_amount=item.dose_amount,
            dose_unit=item.dose_unit,
            form=item.form,
            sort_order=idx,
            is_active=True,
        )
        db.add(row)
        new_rows.append(row)

    await db.commit()

    return SupplementListResponse(
        supplements=[_row_to_response(r) for r in new_rows],
    )


@limiter.limit("30/minute")
@router.delete("/log/{log_entry_id}", status_code=204)
async def delete_supplement_log_entry(
    log_entry_id: str,
    request: Request,
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(get_authenticated_user_id),
) -> None:
    """Delete a specific supplement_taken log entry owned by the authenticated user."""
    result = await db.execute(
        select(QuickLog).where(
            QuickLog.id == log_entry_id,
            QuickLog.user_id == user_id,
            QuickLog.metric_type == "supplement_taken",
        )
    )
    if result.scalars().first() is None:
        raise HTTPException(status_code=404, detail="Log entry not found")
    await db.execute(
        sa_delete(QuickLog).where(
            QuickLog.id == log_entry_id,
            QuickLog.user_id == user_id,
            QuickLog.metric_type == "supplement_taken",
        )
    )
    await db.commit()


# ── Scan-label helpers ────────────────────────────────────────────────────────


async def _parse_supplement_barcode(barcode: str) -> ScanLabelResponse:
    """Look up a barcode via Open Food Facts and return parsed supplement fields."""
    import re  # noqa: PLC0415

    import httpx  # noqa: PLC0415
    if not re.match(r'^\d{6,14}$', barcode):
        return ScanLabelResponse()
    url = f"https://world.openfoodfacts.org/api/v2/product/{barcode}.json"
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            resp = await client.get(url)
        if resp.status_code != 200:
            return ScanLabelResponse()
        payload = resp.json()
        product = payload.get("product", {})
        name = product.get("product_name") or product.get("generic_name")
        return ScanLabelResponse(name=name or None)
    except Exception as exc:
        logger.warning("_parse_supplement_barcode failed: %s", type(exc).__name__)
        return ScanLabelResponse()


async def _parse_supplement_image(
    _image_base64: str | None,
) -> ScanLabelResponse:
    """Parse a supplement label image — AI hook reserved for future wiring."""
    return ScanLabelResponse()


# ── Scan-label route ──────────────────────────────────────────────────────────


@limiter.limit("20/minute")
@router.post("/scan-label", response_model=ScanLabelResponse)
async def scan_supplement_label(
    request: Request,
    body: ScanLabelRequest,
    user_id: str = Depends(get_authenticated_user_id),
) -> ScanLabelResponse:
    """Parse a supplement label from a barcode or image and return structured fields."""
    try:
        if body.barcode:
            return await _parse_supplement_barcode(body.barcode)
        return await _parse_supplement_image(body.image_base64)
    except Exception as exc:
        logger.warning("scan_supplement_label failed for user=%s: %s", user_id, exc)
        return ScanLabelResponse()


# ── Conflict-check helpers ────────────────────────────────────────────────────


_TIMING_TIP_SYSTEM = """You are a supplement timing expert. Given a supplement name, the user's selected timing, and optionally their meal pattern, write a single short tip (1-2 sentences, max 120 characters) that helps the user understand why or how this timing works for this supplement.

Be specific to the supplement name and timing. If meal pattern data is provided, personalize the tip to it.
Respond with valid JSON only: {"tip": "your tip here"}
If you cannot generate a meaningful tip, respond: {"tip": null}"""


_METRIC_LABELS: dict[str, str] = {
    "sleep_duration": "Sleep",
    "hrv_ms": "HRV",
    "energy": "Energy",
    "stress": "Stress",
}

_INSIGHTS_SYSTEM = """You are a health data analyst. For each supplement-health correlation, write a single clear insight sentence (max 100 characters) that a non-technical user can understand.

Format: "Your [metric] is [X]% [better/worse] on days you [fully/mostly] take your supplements."
If the correlation is near zero (|r| < 0.15), write a neutral observation.
Respond with valid JSON: {"insights": [{"metric_type": "...", "insight_text": "..."}, ...]}"""


def _pearson(x: list[float], y: list[float]) -> float | None:
    """Pearson r. Returns None if fewer than 7 shared points."""
    if len(x) < 7:
        return None
    n = len(x)
    mx, my = sum(x) / n, sum(y) / n
    num = sum((xi - mx) * (yi - my) for xi, yi in zip(x, y))
    den_x = sum((xi - mx) ** 2 for xi in x) ** 0.5
    den_y = sum((yi - my) ** 2 for yi in y) ** 0.5
    if den_x == 0 or den_y == 0:
        return None
    return num / (den_x * den_y)


_CONFLICT_SYSTEM = """You are a supplement expert. Given a new supplement name and a list of existing supplements in a user's stack, determine if the new supplement contains the same active ingredient as any existing supplement, which would create a duplicate or overlap.

Respond with valid JSON only:
{"has_overlap": true|false, "conflicting_name": "name or null", "reason": "brief reason or null"}

Be conservative — only flag clear overlaps (e.g. "Vitamin D" and "Vitamin D3" are the same; "Fish Oil" and "Omega-3" are the same; "Magnesium Glycinate" and "Magnesium Citrate" are different forms of Magnesium and DO overlap).
Do NOT flag clearly different supplements as overlaps."""


async def _check_overlap_with_ai(
    name: str,
    existing_names: list[str],
    llm_client,
) -> dict[str, object]:
    """Call LLM to detect ingredient overlap. Returns no-conflict sentinel if llm_client is None."""
    if llm_client is None:
        logger.warning("check_supplement_conflicts: llm_client not available, skipping overlap check")
        return {"has_overlap": False, "conflicting_name": None, "reason": None}
    user_content = (
        f"New supplement: {name}\n"
        f"Existing stack: {', '.join(existing_names)}"
    )
    messages = [
        {"role": "system", "content": _CONFLICT_SYSTEM},
        {"role": "user", "content": user_content},
    ]
    response = await llm_client.chat(
        messages=messages,
        temperature=0.3,
        response_format={"type": "json_object"},
        reasoning={"effort": "none"},
        plugins=[{"id": "response-healing"}],
    )
    raw = response.choices[0].message.content
    return json.loads(raw)


async def _get_meal_hour_pattern(user_id: str, db: AsyncSession) -> str | None:
    """Return a plain-English description of when the user typically eats, or None if insufficient data."""
    cutoff = datetime.now(timezone.utc) - timedelta(days=30)
    result = await db.execute(
        select(QuickLog.logged_at).where(
            QuickLog.user_id == user_id,
            QuickLog.metric_type == "meal",
            QuickLog.logged_at >= cutoff,
        ).limit(200)
    )
    rows = result.scalars().all()
    if len(rows) < 3:
        return None
    hours = [r.astimezone(timezone.utc).hour for r in rows]
    buckets: dict[str, int] = {"morning": 0, "afternoon": 0, "evening": 0}
    for h in hours:
        if 5 <= h < 11:
            buckets["morning"] += 1
        elif 11 <= h < 15:
            buckets["afternoon"] += 1
        else:
            buckets["evening"] += 1
    dominant = max(buckets, key=buckets.get)  # type: ignore[arg-type]
    total = sum(buckets.values())
    pct = int(buckets[dominant] / total * 100)
    return f"The user typically eats in the {dominant} ({pct}% of logged meals in the past 30 days)."


# ── Conflict-check route ──────────────────────────────────────────────────────


@limiter.limit("30/minute")
@router.post("/check-conflicts", response_model=ConflictCheckResponse)
async def check_supplement_conflicts(
    request: Request,
    body: ConflictCheckRequest,
    user_id: str = Depends(get_authenticated_user_id),
) -> ConflictCheckResponse:
    """Check whether a supplement name conflicts with the user's existing stack.

    Exact match → immediate duplicate result, no LLM call.
    Semantic overlap → LLM call. If LLM fails, fail open (return no conflict).
    """
    lower_name = body.name.lower().strip()
    normalised_existing = [n.lower().strip() for n in body.existing_names]

    # 1. Exact-match check — no LLM needed
    for original, normalised in zip(body.existing_names, normalised_existing):
        if normalised == lower_name:
            return ConflictCheckResponse(
                has_conflict=True,
                conflict_type="duplicate",
                conflicting_name=original,
                message=f'You already have "{original}" in your stack.',
            )

    # 2. Nothing to compare against
    if not body.existing_names:
        return ConflictCheckResponse(has_conflict=False)

    # 3. Semantic overlap via LLM — fail open on any error
    llm_client = getattr(request.app.state, "llm_client", None)

    try:
        result = await _check_overlap_with_ai(body.name, body.existing_names, llm_client)
        if result.get("has_overlap"):
            conflicting = result.get("conflicting_name")
            return ConflictCheckResponse(
                has_conflict=True,
                conflict_type="overlap",
                conflicting_name=conflicting,  # type: ignore[arg-type]
                message=(
                    f'"{conflicting}" in your stack may contain the same ingredient.'
                    if conflicting
                    else "A supplement in your stack may contain the same ingredient."
                ),
            )
        return ConflictCheckResponse(has_conflict=False)
    except Exception as exc:
        logger.warning("check_supplement_conflicts: LLM call failed (%s), failing open", exc)
        return ConflictCheckResponse(has_conflict=False)


# ── Insights route ───────────────────────────────────────────────────────────


@limiter.limit("10/minute")
@router.get("/insights", response_model=SupplementInsightsResponse)
async def get_supplement_insights(
    request: Request,
    days: int = Query(default=60, ge=14, le=90),
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(get_authenticated_user_id),
) -> SupplementInsightsResponse:
    """Return correlations between supplement consistency and health metrics."""
    from datetime import date, time as _time  # noqa: PLC0415

    cutoff = date.today() - timedelta(days=days)

    # 1. Active stack size
    stack_result = await db.execute(
        select(func.count()).select_from(UserSupplement).where(
            UserSupplement.user_id == user_id,
            UserSupplement.is_active.is_(True),
        )
    )
    stack_size: int = stack_result.scalar() or 0

    # 2. Early return if no supplements on the stack — no LLM needed
    if stack_size == 0:
        return SupplementInsightsResponse(insights=[], data_days=0, has_enough_data=False)

    # 3. LLM guard — only checked after confirming we have data to analyse
    llm_client = getattr(request.app.state, "llm_client", None)
    if llm_client is None:
        raise HTTPException(status_code=503, detail="LLM service unavailable.")

    # 4. Daily health metrics from DailySummary
    from app.models.daily_summary import DailySummary  # noqa: PLC0415

    metric_types = list(_METRIC_LABELS.keys())
    ds_result = await db.execute(
        select(DailySummary).where(
            DailySummary.user_id == user_id,
            DailySummary.metric_type.in_(metric_types),
            DailySummary.date >= cutoff,
            DailySummary.is_stale.is_(False),
        )
    )
    ds_rows = ds_result.scalars().all()

    # Build dict: metric_type → {date: value}
    health_by_metric: dict[str, dict[date, float]] = {m: {} for m in metric_types}
    for row in ds_rows:
        health_by_metric[row.metric_type][row.date] = row.value

    # 5. Supplement-taken logs from QuickLog
    cutoff_dt = datetime.combine(cutoff, _time.min, tzinfo=timezone.utc)
    ql_result = await db.execute(
        select(QuickLog).where(
            QuickLog.user_id == user_id,
            QuickLog.metric_type == "supplement_taken",
            QuickLog.logged_at >= cutoff_dt,
        )
    )
    ql_rows = ql_result.scalars().all()

    taken_by_date: dict[date, set[str]] = {}
    for row in ql_rows:
        supplement_id = (row.data or {}).get("supplement_id")
        if supplement_id:
            d = row.logged_at.astimezone(timezone.utc).date()
            taken_by_date.setdefault(d, set()).add(str(supplement_id))

    consistency_by_date: dict[date, float] = {
        d: min(1.0, len(taken_ids) / stack_size)
        for d, taken_ids in taken_by_date.items()
    }

    # 6. Early return if no consistency data
    if not consistency_by_date:
        return SupplementInsightsResponse(insights=[], data_days=0, has_enough_data=False)

    data_days = len(consistency_by_date)
    has_enough_data = data_days >= 14

    # 7. Compute Pearson correlations for each metric
    correlations: list[tuple[str, float]] = []
    for metric_type, daily_values in health_by_metric.items():
        # Find days present in BOTH datasets
        shared_dates = sorted(set(consistency_by_date.keys()) & set(daily_values.keys()))
        x = [consistency_by_date[d] for d in shared_dates]
        y = [daily_values[d] for d in shared_dates]
        r = _pearson(x, y)
        if r is not None:
            correlations.append((metric_type, r))

    if not correlations:
        return SupplementInsightsResponse(
            insights=[], data_days=data_days, has_enough_data=has_enough_data
        )

    # 8. LLM generates insight text for each correlation
    corr_payload = [
        {"metric_type": mt, "correlation": round(r, 4)}
        for mt, r in correlations
    ]
    try:
        messages = [
            {"role": "system", "content": _INSIGHTS_SYSTEM},
            {"role": "user", "content": json.dumps(corr_payload)},
        ]
        response = await llm_client.chat(
            messages=messages,
            temperature=0.3,
            response_format={"type": "json_object"},
            reasoning={"effort": "none"},
            plugins=[{"id": "response-healing"}],
        )
        llm_data: dict = json.loads(response.choices[0].message.content)
        insight_texts: dict[str, str] = {
            item["metric_type"]: item["insight_text"]
            for item in llm_data.get("insights", [])
            if "metric_type" in item and "insight_text" in item
        }
    except Exception as exc:
        logger.warning("get_supplement_insights: LLM call failed (%s), returning empty insights", exc)
        return SupplementInsightsResponse(
            insights=[], data_days=data_days, has_enough_data=has_enough_data
        )

    # 9. Build final response
    result_items: list[SupplementInsightItem] = []
    for metric_type, r in correlations:
        if abs(r) < 0.15:
            direction = "neutral"
        elif r > 0:
            direction = "positive"
        else:
            direction = "negative"
        insight_text = insight_texts.get(metric_type, "")
        if not insight_text:
            continue
        result_items.append(
            SupplementInsightItem(
                metric_type=metric_type,
                metric_label=_METRIC_LABELS.get(metric_type, metric_type),
                direction=direction,
                correlation=round(r, 4),
                insight_text=insight_text,
            )
        )

    return SupplementInsightsResponse(
        insights=result_items,
        data_days=data_days,
        has_enough_data=has_enough_data,
    )


# ── Timing-tip route ──────────────────────────────────────────────────────────


@limiter.limit("30/minute")
@router.get("/timing-tip", response_model=TimingTipResponse)
async def get_timing_tip(
    request: Request,
    supplement_name: str = Query(min_length=1, max_length=200),
    timing: str = Query(min_length=1, max_length=50),
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(get_authenticated_user_id),
) -> TimingTipResponse:
    """Return an AI-generated timing tip for the given supplement + timing combination."""
    llm_client = getattr(request.app.state, "llm_client", None)
    if llm_client is None:
        raise HTTPException(status_code=503, detail="AI service unavailable")
    try:
        meal_pattern = await _get_meal_hour_pattern(user_id, db)
        user_content = f"Supplement: {supplement_name}\nTiming: {timing}"
        if meal_pattern:
            user_content += f"\nMeal pattern: {meal_pattern}"
        messages = [
            {"role": "system", "content": _TIMING_TIP_SYSTEM},
            {"role": "user", "content": user_content},
        ]
        response = await llm_client.chat(
            messages=messages,
            temperature=0.4,
            response_format={"type": "json_object"},
            reasoning={"effort": "none"},
            plugins=[{"id": "response-healing"}],
        )
        data = json.loads(response.choices[0].message.content)
        return TimingTipResponse(tip=data.get("tip"))
    except Exception as exc:
        logger.warning("get_timing_tip failed: %s", exc)
        return TimingTipResponse()
