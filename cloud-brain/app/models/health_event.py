"""HealthEvent ORM model — source of truth for all health data."""
import uuid
from datetime import date, datetime

import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from app.database import Base


class HealthEvent(Base):
    __tablename__ = "health_events"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False, index=True)
    metric_type: Mapped[str] = mapped_column(sa.Text, nullable=False)
    value: Mapped[float] = mapped_column(sa.Float(precision=53), nullable=False)
    unit: Mapped[str] = mapped_column(sa.Text, nullable=False)
    source: Mapped[str] = mapped_column(sa.Text, nullable=False)
    recorded_at: Mapped[datetime] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=False)
    local_date: Mapped[date] = mapped_column(sa.Date, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        sa.TIMESTAMP(timezone=True), nullable=False, server_default=func.now()
    )
    updated_at: Mapped[datetime | None] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=True)
    deleted_at: Mapped[datetime | None] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=True)
    granularity: Mapped[str] = mapped_column(sa.Text, nullable=False, default="point_in_time")
    session_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    idempotency_key: Mapped[str | None] = mapped_column(sa.Text, nullable=True)
    metadata_: Mapped[dict | None] = mapped_column("metadata", JSONB, nullable=True)

    def __init__(self, **kwargs: object) -> None:
        for attr, col in self.__table__.c.items():
            if (
                col.default is not None
                and not col.primary_key
                and attr not in kwargs
                and hasattr(col.default, "arg")
                and not callable(col.default.arg)
            ):
                kwargs[attr] = col.default.arg
        super().__init__(**kwargs)
