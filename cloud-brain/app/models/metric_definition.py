"""MetricDefinition ORM model — metric registry."""
from datetime import datetime

import sqlalchemy as sa
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from app.database import Base


class MetricDefinition(Base):
    __tablename__ = "metric_definitions"

    metric_type: Mapped[str] = mapped_column(sa.Text, primary_key=True)
    display_name: Mapped[str] = mapped_column(sa.Text, nullable=False)
    unit: Mapped[str] = mapped_column(sa.Text, nullable=False)
    category: Mapped[str] = mapped_column(sa.Text, nullable=False)
    aggregation_fn: Mapped[str] = mapped_column(sa.Text, nullable=False)
    data_type: Mapped[str] = mapped_column(sa.Text, nullable=False)
    min_value: Mapped[float | None] = mapped_column(sa.Float(precision=53), nullable=True)
    max_value: Mapped[float | None] = mapped_column(sa.Float(precision=53), nullable=True)
    is_active: Mapped[bool] = mapped_column(sa.Boolean, nullable=False, default=True)
    display_order: Mapped[int] = mapped_column(sa.Integer, nullable=False, default=0)
    created_at: Mapped[datetime] = mapped_column(
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
