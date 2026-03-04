"""
Zuralog Cloud Brain — Journal Entry Model.

Daily journal entries capture subjective wellness metrics (mood, energy,
stress, sleep quality), free-text notes, and tags. The unique constraint on
(user_id, date) enforces one entry per user per calendar day; POST upserts
into this constraint to allow idempotent updates.
"""

import uuid

from sqlalchemy import DateTime, Integer, JSON, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from app.database import Base


class JournalEntry(Base):
    """A daily wellness journal entry for a single user.

    One entry per user per calendar day (enforced by the unique constraint
    on ``user_id`` + ``date``). All rating fields are optional 1–10 integers.

    Attributes:
        id: UUID primary key.
        user_id: Supabase UID of the owning user. Indexed for list queries.
        date: Calendar date in YYYY-MM-DD format. Indexed for range queries.
        mood: Subjective mood rating 1–10. Nullable.
        energy: Subjective energy rating 1–10. Nullable.
        stress: Subjective stress rating 1–10. Nullable.
        sleep_quality: Subjective sleep quality rating 1–10. Nullable.
        notes: Free-text journal notes. Nullable.
        tags: JSON array of tag strings (e.g. ["headache", "travel"]).
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

    # Subjective wellness ratings (1–10, all optional)
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
