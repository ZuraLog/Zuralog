"""
Zuralog Cloud Brain — Quick Log Model.

Supports rapid, low-friction data entry for individual health metrics.
Unlike journal entries (one per day), quick logs are time-stamped events
and may have multiple entries per day for the same metric.

Models:
    - MetricType: Enum of supported quick-log metric categories.
    - QuickLog: A single logged data point.
"""

import enum
import uuid
from datetime import datetime

from sqlalchemy import DateTime, Float, String
from sqlalchemy.dialects.postgresql import JSON
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from app.database import Base


class MetricType(str, enum.Enum):
    """Supported metric categories for quick logs.

    Members:
        WATER: Water intake (value in ml or cups).
        MOOD: Momentary mood score.
        ENERGY: Momentary energy score.
        STRESS: Momentary stress score.
        SLEEP_QUALITY: Retrospective sleep quality.
        PAIN: Pain level.
        NOTES: Unstructured text note.
        SYMPTOMS: Symptom chip selection (stored in tags).
    """

    WATER = "water"
    MOOD = "mood"
    ENERGY = "energy"
    STRESS = "stress"
    SLEEP_QUALITY = "sleep_quality"
    PAIN = "pain"
    NOTES = "notes"
    SYMPTOMS = "symptoms"


class QuickLog(Base):
    """A single time-stamped health metric data point.

    Multiple logs per user per day per metric type are allowed.

    Attributes:
        id: UUID primary key (auto-generated).
        user_id: Owner's user ID (indexed for fast per-user queries).
        metric_type: The metric category (``MetricType`` value).
        value: Numeric value (optional, used for scored metrics).
        text_value: Text value (optional, used for notes/symptoms).
        tags: JSON list of symptom chip strings (optional).
        logged_at: When the metric was logged (server-side default,
            indexed for time-range queries).
        created_at: Row insertion timestamp (server-side default).
    """

    __tablename__ = "quick_logs"

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
    metric_type: Mapped[str] = mapped_column(
        String,
        nullable=False,
        comment="MetricType enum value",
    )
    value: Mapped[float | None] = mapped_column(
        Float,
        nullable=True,
        comment="Numeric value for scored metrics (mood, energy, etc.)",
    )
    text_value: Mapped[str | None] = mapped_column(
        String,
        nullable=True,
        comment="Text content for notes/symptoms metric types",
    )
    tags: Mapped[list | None] = mapped_column(
        JSON,
        nullable=True,
        comment="Symptom chip list, e.g. ['nausea', 'fatigue']",
    )
    logged_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        index=True,
        nullable=False,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )
