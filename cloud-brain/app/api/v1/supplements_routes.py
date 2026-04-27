"""Supplements list management endpoints."""

import json
import logging
import uuid as _uuid
from datetime import datetime, timezone
from typing import TYPE_CHECKING

from fastapi import APIRouter, Depends, HTTPException, Request
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

if TYPE_CHECKING:
    from app.agent.llm_client import LLMClient

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


_CONFLICT_SYSTEM = """You are a supplement expert. Given a new supplement name and a list of existing supplements in a user's stack, determine if the new supplement contains the same active ingredient as any existing supplement, which would create a duplicate or overlap.

Respond with valid JSON only:
{"has_overlap": true|false, "conflicting_name": "name or null", "reason": "brief reason or null"}

Be conservative — only flag clear overlaps (e.g. "Vitamin D" and "Vitamin D3" are the same; "Fish Oil" and "Omega-3" are the same; "Magnesium Glycinate" and "Magnesium Citrate" are different forms of Magnesium and DO overlap).
Do NOT flag clearly different supplements as overlaps."""


async def _check_overlap_with_ai(
    name: str,
    existing_names: list[str],
    llm_client: "LLMClient | None",
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
    return json.loads(raw)  # type: ignore[no-any-return]


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
