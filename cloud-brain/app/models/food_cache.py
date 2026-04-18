"""Zuralog Cloud Brain — Food Cache Model.

Cached entries from external food databases (e.g. USDA, Nutritionix).
Shared across all users — not tied to any individual account.
"""
import uuid
from datetime import datetime

import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from app.database import Base


class FoodCache(Base):
    __tablename__ = "food_cache"
    __table_args__ = (
        sa.Index(
            "ix_food_cache_name_gin",
            "name",
            postgresql_using="gin",
            postgresql_ops={"name": "gin_trgm_ops"},
        ),
        sa.Index("ix_food_cache_fetched_at", "fetched_at"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    external_id: Mapped[str] = mapped_column(
        sa.String(100), unique=True, nullable=False
    )
    name: Mapped[str] = mapped_column(sa.String(200), nullable=False)
    brand: Mapped[str | None] = mapped_column(sa.String(200), nullable=True)
    serving_size: Mapped[float] = mapped_column(
        sa.Numeric(10, 2, asdecimal=False), nullable=False
    )
    serving_unit: Mapped[str] = mapped_column(sa.String(20), nullable=False)
    calories_per_serving: Mapped[float] = mapped_column(
        sa.Numeric(10, 2, asdecimal=False), nullable=False
    )
    protein_per_serving: Mapped[float] = mapped_column(
        sa.Numeric(10, 2, asdecimal=False), nullable=False
    )
    carbs_per_serving: Mapped[float] = mapped_column(
        sa.Numeric(10, 2, asdecimal=False), nullable=False
    )
    fat_per_serving: Mapped[float] = mapped_column(
        sa.Numeric(10, 2, asdecimal=False), nullable=False
    )
    metadata_: Mapped[dict | None] = mapped_column(
        "metadata", JSONB, nullable=True
    )
    fetched_at: Mapped[datetime] = mapped_column(
        sa.TIMESTAMP(timezone=True), nullable=False, server_default=func.now()
    )
