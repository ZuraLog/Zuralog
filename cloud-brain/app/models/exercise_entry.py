"""Zuralog Cloud Brain — Exercise Entry Model.

Stores manually logged exercise burns that offset the daily calorie budget.
Allows users to record activities outside of integrated workout sessions.
"""
import uuid
from datetime import date, datetime

import sqlalchemy as sa
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from app.database import Base


class ExerciseEntry(Base):
    __tablename__ = "exercise_entries"

    id: Mapped[str] = mapped_column(sa.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(
        sa.String(255),
        sa.ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    date: Mapped[date] = mapped_column(sa.Date, nullable=False, index=True)
    activity_name: Mapped[str] = mapped_column(sa.String(200), nullable=False)
    calories_burned: Mapped[int] = mapped_column(sa.Integer, nullable=False)
    source: Mapped[str] = mapped_column(sa.String(20), nullable=False, default="manual")
    session_id: Mapped[str | None] = mapped_column(sa.String(36), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        sa.TIMESTAMP(timezone=True), nullable=False, server_default=func.now()
    )
