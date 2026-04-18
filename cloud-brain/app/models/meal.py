"""Zuralog Cloud Brain — Meal Model.

A logged meal event. Each row represents one meal (breakfast, lunch,
dinner, or snack) that a user recorded. Individual food items within
the meal live in the meal_foods table.
"""
import uuid
from datetime import datetime

import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func

from app.database import Base


class Meal(Base):
    __tablename__ = "meals"
    __table_args__ = (
        sa.Index("ix_meals_user_date", "user_id", "logged_at"),
        sa.Index(
            "ix_meals_user_active",
            "user_id",
            postgresql_where=sa.text("deleted_at IS NULL"),
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[str] = mapped_column(
        sa.String,
        sa.ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    meal_type: Mapped[str] = mapped_column(sa.String(20), nullable=False)
    name: Mapped[str | None] = mapped_column(sa.String(200), nullable=True)
    logged_at: Mapped[datetime] = mapped_column(
        sa.TIMESTAMP(timezone=True), nullable=False
    )
    created_at: Mapped[datetime] = mapped_column(
        sa.TIMESTAMP(timezone=True), nullable=False, server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        sa.TIMESTAMP(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )
    deleted_at: Mapped[datetime | None] = mapped_column(
        sa.TIMESTAMP(timezone=True), nullable=True
    )

    foods: Mapped[list["MealFood"]] = relationship(
        "MealFood", back_populates="meal", lazy="selectin"
    )
