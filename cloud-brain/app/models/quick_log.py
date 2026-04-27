"""
Zuralog Cloud Brain — Quick Log Model.

Lightweight, timestamped metric snapshots for rapid logging from the
mobile app. Supports both numeric values (water intake, mood, energy) and
free-text entries (notes). Multiple logs per day are allowed — this table
is an append-only time series.
"""

import uuid
from datetime import datetime

import sqlalchemy as sa
from sqlalchemy import DateTime, Float, JSON, String, Text
from sqlalchemy.dialects import postgresql
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from app.database import Base

# Valid metric_type values
VALID_METRIC_TYPES = frozenset(
    {
        "water",
        "mood",
        "energy",
        "stress",
        "sleep_quality",
        "pain",
        "notes",
        "sleep",
        "run",
        "meal",
        "supplement",
        "supplement_taken",
        "symptom",
        "workout",
        "weight",
        "steps",
    }
)


class QuickLog(Base):
    """A single rapid-log entry for a numeric or textual health metric.

    Multiple logs per day are permitted (no unique constraint). Composite
    indexes on ``(user_id, logged_at)`` and ``(user_id, metric_type, logged_at)``
    cover today's-logs and latest-per-type query patterns.

    Attributes:
        id: UUID primary key.
        user_id: Supabase UID of the owning user. Indexed.
        metric_type: One of the values in VALID_METRIC_TYPES. See that frozenset for the canonical list.
        value: Numeric measurement. Nullable for text-only metrics.
        text_value: Free-text content. Nullable for numeric-only metrics.
        tags: JSON array of tag strings.
        data: JSONB payload with structured per-type details.
        updated_at: When the entry was last modified. Nullable.
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
        comment="See VALID_METRIC_TYPES for all accepted values",
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
    data: Mapped[dict] = mapped_column(
        postgresql.JSONB(astext_type=sa.Text()),
        default=dict,
        server_default="{}",
        nullable=False,
        comment="Structured per-type payload (sleep details, run stats, meal info, etc.)",
    )
    updated_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        comment="Last modification timestamp",
    )
    logged_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
        index=True,
        comment="When the metric was recorded",
    )
