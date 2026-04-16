"""Zuralog Cloud Brain — Food Correction Model.

Tracks user-submitted corrections to AI-estimated nutrition values.
When enough unique users correct the same food, the correction learning
service updates the food_cache entry with averaged values.
"""
import uuid
from datetime import datetime

import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from app.database import Base


class FoodCorrection(Base):
    __tablename__ = "food_corrections"
    __table_args__ = (
        sa.Index("ix_food_corrections_food_name", "food_name"),
        sa.Index("ix_food_corrections_user_food", "user_id", "food_name"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[str] = mapped_column(
        sa.String,
        sa.ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    food_cache_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        sa.ForeignKey("food_cache.id", ondelete="SET NULL"),
        nullable=True,
    )
    food_name: Mapped[str] = mapped_column(sa.String(200), nullable=False)
    original_calories: Mapped[float] = mapped_column(
        sa.Numeric(10, 2, asdecimal=False), nullable=False
    )
    corrected_calories: Mapped[float] = mapped_column(
        sa.Numeric(10, 2, asdecimal=False), nullable=False
    )
    original_protein_g: Mapped[float] = mapped_column(
        sa.Numeric(10, 2, asdecimal=False), nullable=False
    )
    corrected_protein_g: Mapped[float] = mapped_column(
        sa.Numeric(10, 2, asdecimal=False), nullable=False
    )
    original_carbs_g: Mapped[float] = mapped_column(
        sa.Numeric(10, 2, asdecimal=False), nullable=False
    )
    corrected_carbs_g: Mapped[float] = mapped_column(
        sa.Numeric(10, 2, asdecimal=False), nullable=False
    )
    original_fat_g: Mapped[float] = mapped_column(
        sa.Numeric(10, 2, asdecimal=False), nullable=False
    )
    corrected_fat_g: Mapped[float] = mapped_column(
        sa.Numeric(10, 2, asdecimal=False), nullable=False
    )
    created_at: Mapped[datetime] = mapped_column(
        sa.TIMESTAMP(timezone=True), nullable=False, server_default=func.now()
    )
