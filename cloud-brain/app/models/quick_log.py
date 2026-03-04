"""
Zuralog Cloud Brain — Quick Log Model.

Lightweight, timestamped metric snapshots for rapid logging from the
mobile app. Supports both numeric values (water intake, mood, energy) and
free-text entries (notes). Multiple logs per day are allowed — this table
is an append-only time series.
"""

import uuid

from sqlalchemy import DateTime, Float, JSON, String, Text
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from app.database import Base

# Valid metric_type values
VALID_METRIC_TYPES = frozenset(
    {"water", "mood", "energy", "stress", "sleep_quality", "pain", "notes"}
)


class QuickLog(Base):
    """A single rapid-log entry for a numeric or textual health metric.

    Multiple logs per day are permitted (no unique constraint). Indexed on
    ``user_id`` and ``logged_at`` for efficient time-range queries.

    Attributes:
        id: UUID primary key.
        user_id: Supabase UID of the owning user. Indexed.
        metric_type: One of: water, mood, energy, stress, sleep_quality, pain, notes.
        value: Numeric measurement. Nullable for text-only metrics.
        text_value: Free-text content. Nullable for numeric-only metrics.
        tags: JSON array of tag strings.
        logged_at: When the metric was recorded. Defaults to server time.
    """

    __tablename__ = "quick_logs"

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
    metric_type: Mapped[str] = mapped_column(
        String,
        nullable=False,
        comment="water | mood | energy | stress | sleep_quality | pain | notes",
    )
    value: Mapped[float | None] = mapped_column(
        Float,
        nullable=True,
        comment="Numeric measurement value",
    )
    text_value: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="Free-text content for notes or descriptive metrics",
    )
    tags: Mapped[list] = mapped_column(
        JSON,
        default=list,
        server_default="[]",
        nullable=False,
        comment="Array of tag strings",
    )
    logged_at: Mapped[str] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
        index=True,
        comment="When the metric was recorded",
    )
