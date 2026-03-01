"""Blood pressure measurement model.

Withings is the first integration providing BP data.
Model designed to support future BP-capable integrations.
"""

from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import DateTime, Float, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from app.database import Base


class BloodPressureRecord(Base):
    __tablename__ = "blood_pressure_records"
    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "source",
            "measured_at",
            name="uq_bp_user_source_measured_at",
        ),
    )

    id: Mapped[str] = mapped_column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(String, index=True)
    source: Mapped[str] = mapped_column(String)  # "withings"
    date: Mapped[str] = mapped_column(String)  # YYYY-MM-DD
    measured_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    systolic_mmhg: Mapped[float] = mapped_column(Float)
    diastolic_mmhg: Mapped[float] = mapped_column(Float)
    heart_rate_bpm: Mapped[float | None] = mapped_column(Float, nullable=True)
    original_id: Mapped[str | None] = mapped_column(String, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
