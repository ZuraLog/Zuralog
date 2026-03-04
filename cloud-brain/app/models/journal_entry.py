"""
Zuralog Cloud Brain — Journal Entry Model.

Represents a daily wellness journal entry. Each user may have at most one
entry per calendar date (enforced by a unique constraint). Entries capture
subjective mood, energy, stress, and sleep quality scores alongside free-text
notes and user-defined tags.
"""

import uuid
from datetime import date, datetime

from sqlalchemy import Date, DateTime, Integer, String, Text, UniqueConstraint
from sqlalchemy.dialects.postgresql import JSON
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from app.database import Base


class JournalEntry(Base):
    """A single daily wellness journal entry for one user.

    Attributes:
        id: UUID primary key (auto-generated).
        user_id: Owner's user ID (indexed for per-user queries).
        date: Calendar date of the entry (indexed for range queries).
        mood: Subjective mood score 1–10 (optional).
        energy: Subjective energy score 1–10 (optional).
        stress: Subjective stress score 1–10 (optional).
        sleep_quality: Subjective sleep quality score 1–10 (optional).
        notes: Free-text notes (optional).
        tags: JSON list of string tags (optional), e.g. ``["headache", "tired"]``.
        created_at: Row creation timestamp (server-side default).
        updated_at: Timestamp of last update.
    """

    __tablename__ = "journal_entries"
    __table_args__ = (UniqueConstraint("user_id", "date", name="uq_journal_user_date"),)

    id: Mapped[str] = mapped_column(
        String,
        primary_key=True,
        default=lambda: str(uuid.uuid4()),
    )
    user_id: Mapped[str] = mapped_column(
        String,
        index=True,
        nullable=False,
    )
    date: Mapped[date] = mapped_column(
        Date,
        nullable=False,
        index=True,
    )
    mood: Mapped[int | None] = mapped_column(
        Integer,
        nullable=True,
        comment="Subjective mood score 1–10",
    )
    energy: Mapped[int | None] = mapped_column(
        Integer,
        nullable=True,
        comment="Subjective energy score 1–10",
    )
    stress: Mapped[int | None] = mapped_column(
        Integer,
        nullable=True,
        comment="Subjective stress score 1–10",
    )
    sleep_quality: Mapped[int | None] = mapped_column(
        Integer,
        nullable=True,
        comment="Subjective sleep quality score 1–10",
    )
    notes: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
    )
    tags: Mapped[list | None] = mapped_column(
        JSON,
        nullable=True,
        comment="List of string tags, e.g. ['headache', 'tired']",
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )
    updated_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        onupdate=func.now(),
        nullable=True,
    )
