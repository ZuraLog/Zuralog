"""
Zuralog Cloud Brain — Journal Entry Model.

Daily journal entries store free-text content, tags, and source tracking.
The unique constraint on (user_id, date) enforces one entry per user per
calendar day; POST upserts into this constraint to allow idempotent updates.
Active fields: notes (aliased to content in the API), source, and
conversation_id. The mood/energy/stress/sleep_quality columns are retained
in the database for backward compatibility but are not exposed in the API.
"""

import uuid

from sqlalchemy import DateTime, Integer, JSON, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from app.database import Base


class JournalEntry(Base):
    """A daily wellness journal entry for a single user.

    One entry per user per calendar day (enforced by the unique constraint
    on ``user_id`` + ``date``).

    Attributes:
        id: UUID primary key.
        user_id: Supabase UID of the owning user. Indexed for list queries.
        date: Calendar date in YYYY-MM-DD format. Indexed for range queries.
        notes: Free-text journal content (aliased to ``content`` in the API). Nullable.
        tags: JSON array of tag strings (e.g. ["headache", "travel"]).
        source: Origin of the entry — "diary" or "conversational".
        conversation_id: Coach conversation thread ID that produced this entry.
        created_at: Server-managed creation timestamp.
        updated_at: Server-managed last-update timestamp. Nullable.
    """

    __tablename__ = "journal_entries"
    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "date",
            name="uq_journal_entries_user_date",
        ),
    )

    id: Mapped[str] = mapped_column(
        String,
        primary_key=True,
        default=lambda: str(uuid.uuid4()),
    )
    user_id: Mapped[str] = mapped_column(
        String,
        nullable=False,
        index=True,
        comment="Supabase UID of the owning user",
    )
    date: Mapped[str] = mapped_column(
        String,
        nullable=False,
        index=True,
        comment="Calendar date in YYYY-MM-DD format",
    )

    # DEPRECATED — kept for backward compat, not exposed in API
    mood: Mapped[int | None] = mapped_column(
        Integer,
        nullable=True,
        comment="Subjective mood rating 1–10",
    )
    energy: Mapped[int | None] = mapped_column(
        Integer,
        nullable=True,
        comment="Subjective energy rating 1–10",
    )
    stress: Mapped[int | None] = mapped_column(
        Integer,
        nullable=True,
        comment="Subjective stress rating 1–10",
    )
    sleep_quality: Mapped[int | None] = mapped_column(
        Integer,
        nullable=True,
        comment="Subjective sleep quality rating 1–10",
    )

    # Free-text notes
    notes: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="Free-text journal notes",
    )

    # Structured metadata
    tags: Mapped[list] = mapped_column(
        JSON,
        default=list,
        server_default="[]",
        nullable=False,
        comment="Array of tag strings",
    )

    # Entry origin — "diary" for manual entries, "conversational" for AI-conversation entries
    source: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        server_default="diary",
        comment="Origin of the entry: 'diary' or 'conversational'",
    )
    conversation_id: Mapped[str | None] = mapped_column(
        String(64),
        nullable=True,
        index=True,
        comment="Coach conversation thread ID that produced this entry",
    )

    # Timestamps
    created_at: Mapped[str] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
    updated_at: Mapped[str | None] = mapped_column(
        DateTime(timezone=True),
        onupdate=func.now(),
        nullable=True,
    )
