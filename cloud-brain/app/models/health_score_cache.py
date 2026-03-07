"""SQLAlchemy model for the health_scores cache table.

Stores one computed health score per user per day.  The Celery
recalculate task writes to this table after every data ingest so
subsequent API calls can read from cache instead of recomputing.
"""

from datetime import date

from sqlalchemy import Date, Float, Index, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class HealthScoreCache(Base):
    """One cached health score per (user_id, date)."""

    __tablename__ = "health_scores"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)

    user_id: Mapped[str] = mapped_column(String, nullable=False, index=True)

    # ISO date string YYYY-MM-DD for easy filtering without timezone issues.
    score_date: Mapped[str] = mapped_column(String(10), nullable=False)

    score: Mapped[int] = mapped_column(Integer, nullable=False)

    # JSON-serialised sub_scores dict stored as TEXT for portability.
    sub_scores_json: Mapped[str] = mapped_column(String, nullable=False, default="{}")

    # Dominant contributing metric for quick display.
    commentary: Mapped[str] = mapped_column(String, nullable=False, default="")

    __table_args__ = (
        UniqueConstraint("user_id", "score_date", name="uq_health_scores_user_date"),
        Index("ix_health_scores_user_date", "user_id", "score_date"),
    )
