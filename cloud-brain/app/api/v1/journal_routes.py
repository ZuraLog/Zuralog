"""
Zuralog Cloud Brain — Journal Entry API Routes.

CRUD endpoints for daily wellness journal entries. Create uses an upsert
pattern on (user_id, date) so clients may call POST idempotently.

Endpoints:
    POST   /api/v1/journal           — Create / upsert entry for today or given date
    GET    /api/v1/journal           — List entries within a date range
    PUT    /api/v1/journal/{date}    — Update entry for a specific date (YYYY-MM-DD)
    DELETE /api/v1/journal/{date}    — Delete entry for a specific date (YYYY-MM-DD)
"""

import logging
from datetime import date as DateType
from datetime import timedelta
from typing import Any, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.deps import get_authenticated_user_id
from app.database import get_db
from app.models.journal_entry import JournalEntry

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/journal",
    tags=["journal"],
)


# ---------------------------------------------------------------------------
# Schemas
# ---------------------------------------------------------------------------


class JournalEntryRequest(BaseModel):
    """Request body for creating or updating a journal entry.

    All fields are optional to support partial updates.

    Attributes:
        date: Entry date. Defaults to today when not provided.
        mood: Mood score 1–10.
        energy: Energy score 1–10.
        stress: Stress score 1–10.
        sleep_quality: Sleep quality score 1–10.
        notes: Free-text notes.
        tags: List of string tags.
    """

    entry_date: Optional[DateType] = Field(default=None, description="Defaults to today", alias="date")
    mood: Optional[int] = Field(default=None, ge=1, le=10)
    energy: Optional[int] = Field(default=None, ge=1, le=10)
    stress: Optional[int] = Field(default=None, ge=1, le=10)
    sleep_quality: Optional[int] = Field(default=None, ge=1, le=10)
    notes: Optional[str] = None
    tags: Optional[list[str]] = None

    model_config = {"populate_by_name": True}


class JournalEntryResponse(BaseModel):
    """API response shape for a journal entry."""

    id: str
    user_id: str
    date: DateType
    mood: Optional[int]
    energy: Optional[int]
    stress: Optional[int]
    sleep_quality: Optional[int]
    notes: Optional[str]
    tags: Optional[list[str]]
    created_at: Any
    updated_at: Any

    model_config = {"from_attributes": True}


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------


@router.post("", status_code=status.HTTP_201_CREATED, response_model=JournalEntryResponse)
async def create_journal_entry(
    body: JournalEntryRequest,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> JournalEntry:
    """Create or upsert a journal entry for the given date.

    If an entry already exists for ``(user_id, date)``, all non-null
    fields from the request body are merged into the existing row
    (upsert behaviour).

    Args:
        body: Journal entry payload. ``date`` defaults to today.
        user_id: Authenticated user ID from JWT.
        db: Injected async database session.

    Returns:
        The created or updated :class:`JournalEntry`.
    """
    entry_date = body.entry_date or DateType.today()

    # Check for existing entry
    result = await db.execute(
        select(JournalEntry).where(
            JournalEntry.user_id == user_id,
            JournalEntry.date == entry_date,
        )
    )
    existing = result.scalars().first()

    if existing is not None:
        # Upsert: update non-null fields (exclude the date field alias)
        update_data = body.model_dump(exclude={"entry_date"}, exclude_none=True)
        for field, value in update_data.items():
            setattr(existing, field, value)
        await db.commit()
        await db.refresh(existing)
        return existing

    # Create new entry
    entry = JournalEntry(
        user_id=user_id,
        date=entry_date,
        mood=body.mood,
        energy=body.energy,
        stress=body.stress,
        sleep_quality=body.sleep_quality,
        notes=body.notes,
        tags=body.tags,
    )
    db.add(entry)
    await db.commit()
    await db.refresh(entry)
    return entry


@router.get("", response_model=list[JournalEntryResponse])
async def list_journal_entries(
    start_date: Optional[DateType] = Query(default=None, description="Inclusive start date"),
    end_date: Optional[DateType] = Query(default=None, description="Inclusive end date"),
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> list[JournalEntry]:
    """List journal entries within a date range.

    Defaults to the last 30 days when no range is specified.

    Args:
        start_date: Inclusive lower bound. Defaults to 30 days ago.
        end_date: Inclusive upper bound. Defaults to today.
        user_id: Authenticated user ID from JWT.
        db: Injected async database session.

    Returns:
        List of :class:`JournalEntry` rows ordered by date descending.
    """
    today = DateType.today()
    effective_end = end_date or today
    effective_start = start_date or (today - timedelta(days=30))

    result = await db.execute(
        select(JournalEntry)
        .where(
            JournalEntry.user_id == user_id,
            JournalEntry.date >= effective_start,
            JournalEntry.date <= effective_end,
        )
        .order_by(JournalEntry.date.desc())
    )
    return list(result.scalars().all())


@router.put("/{entry_date}", response_model=JournalEntryResponse)
async def update_journal_entry(
    entry_date: DateType,
    body: JournalEntryRequest,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> JournalEntry:
    """Update an existing journal entry for a specific date.

    Only non-null fields in the request body are applied.

    Args:
        entry_date: The calendar date of the entry to update (YYYY-MM-DD).
        body: Partial update payload.
        user_id: Authenticated user ID from JWT.
        db: Injected async database session.

    Returns:
        The updated :class:`JournalEntry`.

    Raises:
        HTTPException: 404 if no entry exists for the given date.
    """
    result = await db.execute(
        select(JournalEntry).where(
            JournalEntry.user_id == user_id,
            JournalEntry.date == entry_date,
        )
    )
    entry = result.scalars().first()
    if entry is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"No journal entry found for {entry_date.isoformat()}",
        )

    update_data = body.model_dump(exclude={"entry_date"}, exclude_none=True)
    if not update_data:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No fields to update",
        )
    for field, value in update_data.items():
        setattr(entry, field, value)

    await db.commit()
    await db.refresh(entry)
    return entry


@router.delete("/{entry_date}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_journal_entry(
    entry_date: DateType,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> None:
    """Delete a journal entry for a specific date.

    Args:
        entry_date: The calendar date of the entry to delete (YYYY-MM-DD).
        user_id: Authenticated user ID from JWT.
        db: Injected async database session.

    Raises:
        HTTPException: 404 if no entry exists for the given date.
    """
    result = await db.execute(
        select(JournalEntry).where(
            JournalEntry.user_id == user_id,
            JournalEntry.date == entry_date,
        )
    )
    entry = result.scalars().first()
    if entry is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"No journal entry found for {entry_date.isoformat()}",
        )

    await db.delete(entry)
    await db.commit()
