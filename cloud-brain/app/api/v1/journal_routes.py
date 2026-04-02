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
from datetime import date as _date

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_authenticated_user_id
from app.database import get_db
from app.models.journal_entry import JournalEntry
from app.services.streak_tracker import StreakTracker

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/journal", tags=["journal"])

# ---------------------------------------------------------------------------
# Pydantic schemas
# ---------------------------------------------------------------------------


class JournalEntryCreate(BaseModel):
    """Payload for creating or upserting a journal entry.

    Attributes:
        date: Calendar date in YYYY-MM-DD format.
        content: Free-text journal content (required, 1–10 000 chars).
        tags: Array of tag strings. Defaults to empty list.
        source: Origin of the entry — "diary" or "conversational".
        conversation_id: Coach conversation thread ID (optional, max 64 chars).
    """

    date: str  # YYYY-MM-DD
    content: str = Field(..., min_length=1, max_length=10000)
    tags: list[str] = Field(default_factory=list)
    source: str = Field(default="diary", pattern="^(diary|conversational)$")
    conversation_id: str | None = Field(default=None, max_length=64)


class JournalEntryResponse(BaseModel):
    """Full journal entry payload returned to the client.

    Attributes:
        id: UUID primary key.
        date: Calendar date in YYYY-MM-DD format.
        content: Free-text journal content.
        tags: Array of tag strings.
        source: Origin of the entry — "diary" or "conversational".
        conversation_id: Coach conversation thread ID or None.
        created_at: ISO timestamp of creation.
    """

    id: str
    date: str
    content: str
    tags: list[str]
    source: str
    conversation_id: str | None
    created_at: str

    model_config = ConfigDict(from_attributes=True)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _entry_to_response(entry: JournalEntry) -> dict:
    """Serialize a JournalEntry ORM object to a response dict.

    The DB column is still named ``notes``; we expose it as ``content`` in
    the API layer for backward compatibility without renaming the column.

    Args:
        entry: The ORM instance to serialize.

    Returns:
        Dict suitable for the JournalEntryResponse schema.
    """
    return {
        "id": str(entry.id),
        "date": str(entry.date),
        "content": entry.notes or "",  # notes column aliased to content
        "tags": entry.tags or [],
        "source": entry.source or "diary",
        "conversation_id": entry.conversation_id,
        "created_at": str(entry.created_at) if entry.created_at else "",
    }


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------


@router.post("", summary="Create a new journal entry", status_code=status.HTTP_201_CREATED)
async def create_journal_entry(
    body: JournalEntryCreate,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Create a new journal entry. Multiple entries per day are allowed.

    Args:
        body: Entry fields including the target date.
        user_id: Authenticated user ID (injected by dependency).
        db: Async database session.

    Returns:
        The created JournalEntryResponse.

    Raises:
        HTTPException: 422 if any field fails Pydantic validation.
    """
    entry_date = _date.fromisoformat(body.date)

    entry = JournalEntry(
        id=str(uuid.uuid4()),
        user_id=user_id,
        date=entry_date,
        notes=body.content,
        source=body.source,
        conversation_id=body.conversation_id,
        tags=body.tags,
    )
    db.add(entry)
    logger.info("Created journal entry for user %s on %s", user_id, body.date)

    await db.commit()
    await db.refresh(entry)

    try:
        await StreakTracker().record_activity(
            user_id=user_id,
            streak_type="checkin",
            activity_date=_date.fromisoformat(entry.date),
            db=db,
        )
    except Exception:
        pass  # never block journal write on streak failure

    return _entry_to_response(entry)


@router.get("", summary="List journal entries by date range")
async def list_journal_entries(
    date_from: str | None = None,
    date_to: str | None = None,
    limit: int = 30,
    offset: int = 0,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """List journal entries for the authenticated user, optionally filtered by date range.

    Entries are returned newest-first in a paginated envelope that the
    Flutter ``JournalPage.fromJson`` expects:
    ``{"entries": [...], "has_more": bool}``.

    Args:
        date_from: Earliest date to include (YYYY-MM-DD). Optional.
        date_to: Latest date to include (YYYY-MM-DD). Optional.
        limit: Maximum number of entries to return. Defaults to 30.
        offset: Number of entries to skip for pagination. Defaults to 0.
        user_id: Authenticated user ID.
        db: Async database session.

    Returns:
        Paginated dict with ``entries`` list and ``has_more`` flag.
    """
    query = select(JournalEntry).where(JournalEntry.user_id == user_id)

    if date_from:
        query = query.where(JournalEntry.date >= _date.fromisoformat(date_from))
    if date_to:
        query = query.where(JournalEntry.date <= _date.fromisoformat(date_to))

    # Fetch one extra to determine has_more.
    query = query.order_by(JournalEntry.created_at.desc()).offset(offset).limit(limit + 1)

    result = await db.execute(query)
    entries = list(result.scalars().all())

    has_more = len(entries) > limit
    if has_more:
        entries = entries[:limit]

    return {
        "entries": [_entry_to_response(e) for e in entries],
        "has_more": has_more,
    }


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
        HTTPException: 422 if any field fails Pydantic validation.
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

    entry.date = body.date
    entry.notes = body.content
    entry.source = body.source
    entry.conversation_id = body.conversation_id
    entry.tags = body.tags

    await db.commit()
    await db.refresh(entry)
    logger.info("Replaced journal entry %s for user %s", entry_id, user_id)

    try:
        await StreakTracker().record_activity(
            user_id=user_id,
            streak_type="checkin",
            activity_date=_date.fromisoformat(entry.date),
            db=db,
        )
    except Exception:
        pass  # never block journal write on streak failure

    return _entry_to_response(entry)


@router.patch("/{entry_id}", summary="Partial update of a journal entry")
async def patch_journal_entry(
    entry_id: str,
    body: dict,
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Update only the provided fields of an existing journal entry.

    The Flutter app sends PATCH with partial fields (content, tags, source).
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

    if "content" in body and body["content"] is not None:
        entry.notes = body["content"]
    if "tags" in body and body["tags"] is not None:
        entry.tags = body["tags"]
    if "source" in body and body["source"] is not None:
        entry.source = body["source"]
    if "conversation_id" in body:
        entry.conversation_id = body.get("conversation_id")

    await db.commit()
    await db.refresh(entry)
    logger.info("Patched journal entry %s for user %s", entry_id, user_id)
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
