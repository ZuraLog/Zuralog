"""Zuralog Cloud Brain — Meal Food Model.

An individual food item within a logged meal. Stores the food name,
portion size, and calculated macronutrient values for that portion.
"""
import uuid
from datetime import datetime

import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func

from app.database import Base


class MealFood(Base):
    __tablename__ = "meal_foods"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    meal_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        sa.ForeignKey("meals.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    food_name: Mapped[str] = mapped_column(sa.String(200), nullable=False)
    food_database_id: Mapped[str | None] = mapped_column(
        sa.String(100), nullable=True
    )
    portion_amount: Mapped[float] = mapped_column(
        sa.Numeric(10, 2, asdecimal=False), nullable=False
    )
    portion_unit: Mapped[str] = mapped_column(sa.String(20), nullable=False)
    calories: Mapped[float] = mapped_column(
        sa.Numeric(10, 2, asdecimal=False), nullable=False
    )
    protein_g: Mapped[float] = mapped_column(
        sa.Numeric(10, 2, asdecimal=False), nullable=False
    )
    carbs_g: Mapped[float] = mapped_column(
        sa.Numeric(10, 2, asdecimal=False), nullable=False
    )
    fat_g: Mapped[float] = mapped_column(
        sa.Numeric(10, 2, asdecimal=False), nullable=False
    )
    created_at: Mapped[datetime] = mapped_column(
        sa.TIMESTAMP(timezone=True), nullable=False, server_default=func.now()
    )

    meal: Mapped["Meal"] = relationship("Meal", back_populates="foods")
