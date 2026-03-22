"""DailySummary ORM model — pre-aggregated read cache."""
import uuid
from datetime import date, datetime

import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from app.database import Base


class DailySummary(Base):
    __tablename__ = "daily_summaries"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    date: Mapped[date] = mapped_column(sa.Date, nullable=False)
    metric_type: Mapped[str] = mapped_column(sa.Text, nullable=False)
    value: Mapped[float] = mapped_column(sa.Float(precision=53), nullable=False)
    unit: Mapped[str] = mapped_column(sa.Text, nullable=False)
    event_count: Mapped[int] = mapped_column(sa.Integer, nullable=False, default=1)
    is_stale: Mapped[bool] = mapped_column(sa.Boolean, nullable=False, default=False)
    computed_at: Mapped[datetime] = mapped_column(
        sa.TIMESTAMP(timezone=True), nullable=False, server_default=func.now()
    )

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
