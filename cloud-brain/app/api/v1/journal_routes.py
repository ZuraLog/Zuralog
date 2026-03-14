"""
Zuralog Cloud Brain — Journal Entry API.

Endpoints:
  POST   /api/v1/journal              — Create or update today's entry (upsert by date).
  GET    /api/v1/journal              — List entries by date range with pagination.
  PUT    /api/v1/journal/{entry_id}   — Full replacement of a specific entry.
  DELETE /api/v1/journal/{entry_id}   — Hard delete (returns 204 No Content).

All endpoints are auth-guarded; users can only access their own entries.
The POST upsert enforces the one-entry-per-day business rule without
relying on database exceptions.
"""

import logging
import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_authenticated_user_id
from app.database import get_db
from app.models.journal_entry import JournalEntry

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/journal", tags=["journal"])

# ---------------------------------------------------------------------------
# Pydantic schemas
# ---------------------------------------------------------------------------


class JournalEntryCreate(BaseModel):
    """Payload for creating or upserting a journal entry.

    Attributes:
        date: Calendar date in YYYY-MM-DD format.
        mood: Subjective mood rating 1–10. Optional.
        energy: Subjective energy rating 1–10. Optional.
        stress: Subjective stress rating 1–10. Optional.
        sleep_quality: Subjective sleep quality rating 1–10. Optional.
        notes: Free-text journal notes. Optional.
        tags: Array of tag strings. Defaults to empty list.
    """

    date: str = Field(..., pattern=r"^\d{4}-\d{2}-\d{2}$")  # YYYY-MM-DD
    mood: int | None = None
    energy: int | None = None
    stress: int | None = None
    sleep_quality: int | None = None
    notes: str | None = None
    tags: list[str] = []


class JournalEntryResponse(BaseModel):
    """Full journal entry payload returned to the client.

    Attributes:
        id: UUID primary key.
        user_id: Owning user's ID.
        date: Calendar date in YYYY-MM-DD format.
        mood: Mood rating 1–10 or None.
        energy: Energy rating 1–10 or None.
        stress: Stress rating 1–10 or None.
        sleep_quality: Sleep quality rating 1–10 or None.
        notes: Free-text journal notes or None.
        tags: Array of tag strings.
        created_at: ISO timestamp of creation.
        updated_at: ISO timestamp of last update or None.
    """

    id: str
    user_id: str
    date: str
    mood: int | None
    energy: int | None
    stress: int | None
    sleep_quality: int | None
    notes: str | None
    tags: list
    created_at: str
    updated_at: str | None

    model_config = ConfigDict(from_attributes=True)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _entry_to_response(entry: JournalEntry) -> dict:
    """Serialize a JournalEntry ORM object to a response dict.

    Args:
        entry: The ORM instance to serialize.

    Returns:
        Dict suitable for the JournalEntryResponse schema.
    """
    return {
        "id": entry.id,
        "user_id": entry.user_id,
        "date": entry.date,
        "mood": entry.mood,
        "energy": entry.energy,
        "stress": entry.stress,
        "sleep_quality": entry.sleep_quality,
        "notes": entry.notes,
        "tags": entry.tags or [],
        "created_at": str(entry.created_at),
        "updated_at": str(entry.updated_at) if entry.updated_at else None,
    }


def _validate_rating(value: int | None, field: str) -> None:
    """Validate that a rating field is in the 1–10 range.

    Args:
        value: The integer rating to validate, or None to skip.
        field: The field name for the error message.

    Raises:
        HTTPException: 422 if the value is outside 1–10.
    """
    if value is not None and not (1 <= value <= 10):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"'{field}' must be between 1 and 10, got {value}.",
        )


def _validate_entry_body(body: JournalEntryCreate) -> None:
    """Run all validation rules on an entry creation/update body.

    Args:
        body: The incoming request payload.

    Raises:
        HTTPException: 422 if any rating is out of range.
    """
    _validate_rating(body.mood, "mood")
    _validate_rating(body.energy, "energy")
    _validate_rating(body.stress, "stress")
    _validate_rating(body.sleep_quality, "sleep_quality")


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------


@router.post("", summary="Create or update a journal entry (upsert by date)")
async def create_journal_entry(
    body: JournalEntryCreate,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Create a journal entry for the given date, or update it if one already exists.

    The POST endpoint implements upsert semantics: if an entry already exists
    for the specified ``date`` and ``user_id``, all provided fields are
    overwritten. This allows the mobile app to call POST idempotently.

    Args:
        body: Entry fields including the target date.
        user_id: Authenticated user ID (injected by dependency).
        db: Async database session.

    Returns:
        The created or updated JournalEntryResponse.

    Raises:
        HTTPException: 422 if any rating is outside the 1–10 range.
    """
    _validate_entry_body(body)

    # Check for existing entry on this date
    result = await db.execute(
        select(JournalEntry).where(
            JournalEntry.user_id == user_id,
            JournalEntry.date == body.date,
        )
    )
    entry = result.scalar_one_or_none()

    if entry is not None:
        # Update existing entry (upsert)
        entry.mood = body.mood
        entry.energy = body.energy
        entry.stress = body.stress
        entry.sleep_quality = body.sleep_quality
        entry.notes = body.notes
        entry.tags = body.tags
        logger.info("Updated journal entry %s for user %s on %s", entry.id, user_id, body.date)
    else:
        # Create new entry
        entry = JournalEntry(
            id=str(uuid.uuid4()),
            user_id=user_id,
            date=body.date,
            mood=body.mood,
            energy=body.energy,
            stress=body.stress,
            sleep_quality=body.sleep_quality,
            notes=body.notes,
            tags=body.tags,
        )
        db.add(entry)
        logger.info("Created journal entry for user %s on %s", user_id, body.date)

    await db.commit()
    await db.refresh(entry)
    return _entry_to_response(entry)


@router.get("", summary="List journal entries by date range")
async def list_journal_entries(
    date_from: str | None = None,
    date_to: str | None = None,
    limit: int = 30,
    offset: int = 0,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> list[dict]:
    """List journal entries for the authenticated user, optionally filtered by date range.

    Entries are returned newest-first. Both ``date_from`` and ``date_to`` are
    inclusive and must be YYYY-MM-DD strings.

    Args:
        date_from: Earliest date to include (YYYY-MM-DD). Optional.
        date_to: Latest date to include (YYYY-MM-DD). Optional.
        limit: Maximum number of entries to return. Defaults to 30.
        offset: Number of entries to skip for pagination. Defaults to 0.
        user_id: Authenticated user ID.
        db: Async database session.

    Returns:
        List of JournalEntryResponse dicts.
    """
    query = select(JournalEntry).where(JournalEntry.user_id == user_id)

    if date_from:
        query = query.where(JournalEntry.date >= date_from)
    if date_to:
        query = query.where(JournalEntry.date <= date_to)

    query = query.order_by(JournalEntry.date.desc()).offset(offset).limit(limit)

    result = await db.execute(query)
    entries = result.scalars().all()
    return [_entry_to_response(e) for e in entries]


@router.put("/{entry_id}", summary="Full replacement of a journal entry")
async def update_journal_entry(
    entry_id: str,
    body: JournalEntryCreate,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Fully replace all fields of an existing journal entry.

    Args:
        entry_id: UUID of the entry to update.
        body: New entry field values.
        user_id: Authenticated user ID.
        db: Async database session.

    Returns:
        The updated JournalEntryResponse.

    Raises:
        HTTPException: 404 if the entry is not found or belongs to another user.
        HTTPException: 422 if any rating is outside the 1–10 range.
    """
    _validate_entry_body(body)

    result = await db.execute(
        select(JournalEntry).where(
            JournalEntry.id == entry_id,
            JournalEntry.user_id == user_id,
        )
    )
    entry = result.scalar_one_or_none()

    if entry is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Journal entry '{entry_id}' not found.",
        )

    entry.date = body.date
    entry.mood = body.mood
    entry.energy = body.energy
    entry.stress = body.stress
    entry.sleep_quality = body.sleep_quality
    entry.notes = body.notes
    entry.tags = body.tags

    await db.commit()
    await db.refresh(entry)
    logger.info("Replaced journal entry %s for user %s", entry_id, user_id)
    return _entry_to_response(entry)


@router.delete("/{entry_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Delete a journal entry")
async def delete_journal_entry(
    entry_id: str,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> None:
    """Hard-delete a journal entry by ID.

    Args:
        entry_id: UUID of the entry to delete.
        user_id: Authenticated user ID.
        db: Async database session.

    Returns:
        204 No Content on success.

    Raises:
        HTTPException: 404 if the entry is not found or belongs to another user.
    """
    result = await db.execute(
        select(JournalEntry).where(
            JournalEntry.id == entry_id,
            JournalEntry.user_id == user_id,
        )
    )
    entry = result.scalar_one_or_none()

    if entry is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Journal entry '{entry_id}' not found.",
        )

    await db.delete(entry)
    await db.commit()
    logger.info("Deleted journal entry %s for user %s", entry_id, user_id)
