"""Supplements list management endpoints."""

import logging
import uuid as _uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, Field
from sqlalchemy import delete as sa_delete, select, update
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
