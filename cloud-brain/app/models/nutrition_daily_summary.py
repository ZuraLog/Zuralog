"""Zuralog Cloud Brain — Nutrition Daily Summary Model.

Pre-computed daily nutrition totals per user. Updated whenever meals
are added, edited, or deleted. Serves as the fast read path for the
nutrition dashboard.
"""
import uuid
from datetime import date, datetime

import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from app.database import Base


class NutritionDailySummary(Base):
    __tablename__ = "nutrition_daily_summaries"
    __table_args__ = (
        sa.UniqueConstraint("user_id", "date", name="uix_nutrition_summary_user_date"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[str] = mapped_column(
        sa.String,
        sa.ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    date: Mapped[date] = mapped_column(sa.Date, nullable=False)
    total_calories: Mapped[float] = mapped_column(
        sa.Numeric(10, 2, asdecimal=False), nullable=False, server_default=sa.text("0")
    )
    total_protein_g: Mapped[float] = mapped_column(
        sa.Numeric(10, 2, asdecimal=False), nullable=False, server_default=sa.text("0")
    )
    total_carbs_g: Mapped[float] = mapped_column(
        sa.Numeric(10, 2, asdecimal=False), nullable=False, server_default=sa.text("0")
    )
    total_fat_g: Mapped[float] = mapped_column(
        sa.Numeric(10, 2, asdecimal=False), nullable=False, server_default=sa.text("0")
    )
    meal_count: Mapped[int] = mapped_column(
        sa.Integer, nullable=False, server_default=sa.text("0")
    )
    total_fiber_g: Mapped[float] = mapped_column(
        sa.Numeric(10, 2, asdecimal=False), nullable=False, server_default=sa.text("0")
    )
    total_sodium_mg: Mapped[float] = mapped_column(
        sa.Numeric(10, 2, asdecimal=False), nullable=False, server_default=sa.text("0")
    )
    total_sugar_g: Mapped[float] = mapped_column(
        sa.Numeric(10, 2, asdecimal=False), nullable=False, server_default=sa.text("0")
    )
    exercise_calories_burned: Mapped[int] = mapped_column(
        sa.Integer, nullable=False, server_default=sa.text("0")
    )
    updated_at: Mapped[datetime] = mapped_column(
        sa.TIMESTAMP(timezone=True), nullable=False, server_default=func.now()
    )
