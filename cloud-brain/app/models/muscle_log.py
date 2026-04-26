"""MuscleLog ORM model — per-muscle state logged by the user."""
import uuid
from datetime import date, time, datetime

import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from app.database import Base


class MuscleLog(Base):
    __tablename__ = "muscle_logs"
    __table_args__ = (
        sa.UniqueConstraint(
            "user_id", "log_date", "muscle_group",
            name="uq_muscle_logs_user_date_muscle",
        ),
        sa.Index("ix_muscle_logs_user_date", "user_id", "log_date"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[str] = mapped_column(sa.String(255), nullable=False)
    log_date: Mapped[date] = mapped_column(sa.Date, nullable=False)
    muscle_group: Mapped[str] = mapped_column(sa.String(50), nullable=False)
    state: Mapped[str] = mapped_column(sa.String(20), nullable=False)
    logged_at_time: Mapped[time] = mapped_column(sa.Time, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        sa.TIMESTAMP(timezone=True), nullable=False, server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        sa.TIMESTAMP(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )
