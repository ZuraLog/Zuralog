"""
Zuralog Cloud Brain — Report Model.

Persists generated weekly and monthly health reports. One row per
user per period (enforced by unique constraint). The ``data`` column
stores the serialized WeeklyReport or MonthlyReport dataclass as JSON.
"""

import enum
import uuid
from datetime import date, datetime

from sqlalchemy import Date, DateTime, String, UniqueConstraint
from sqlalchemy.dialects.postgresql import JSON
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from app.database import Base


class ReportType(str, enum.Enum):
    """Semantic category of a generated report.

    Attributes:
        WEEKLY: 7-day rolling report generated on Mondays.
        MONTHLY: Calendar-month report generated on the 1st.
    """

    WEEKLY = "weekly"
    MONTHLY = "monthly"


class Report(Base):
    """A persisted health summary report for a user.

    Attributes:
        id: UUID primary key (auto-generated).
        user_id: Owner's user ID — indexed for fast per-user queries.
            Not a FK; Supabase Auth manages user identity.
        type: ReportType value stored as string (``"weekly"`` or ``"monthly"``).
        period_start: First day of the reporting period (inclusive).
        period_end: Last day of the reporting period (inclusive).
        data: JSON-serialized WeeklyReport or MonthlyReport dataclass payload.
        created_at: Row creation timestamp (server default = now).
    """

    __tablename__ = "reports"
    __table_args__ = (UniqueConstraint("user_id", "type", "period_start", name="uq_report_user_type_period"),)

    id: Mapped[str] = mapped_column(
        String,
        primary_key=True,
        default=lambda: str(uuid.uuid4()),
    )
    user_id: Mapped[str] = mapped_column(
        String,
        index=True,
        nullable=False,
        comment="Supabase Auth user UID — not a FK by design",
    )
    type: Mapped[str] = mapped_column(
        String,
        nullable=False,
        comment="ReportType enum value: weekly | monthly",
    )
    period_start: Mapped[date] = mapped_column(
        Date,
        nullable=False,
        comment="First day of the reporting period (inclusive)",
    )
    period_end: Mapped[date] = mapped_column(
        Date,
        nullable=False,
        comment="Last day of the reporting period (inclusive)",
    )
    data: Mapped[dict] = mapped_column(
        JSON,
        nullable=False,
        comment="Serialized WeeklyReport or MonthlyReport as JSON",
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    # ------------------------------------------------------------------
    # Serialisation
    # ------------------------------------------------------------------

    def to_dict(self) -> dict:
        """Serialize to a JSON-safe dictionary.

        Returns:
            Dict with all report fields. Dates as ISO strings.
        """
        return {
            "id": self.id,
            "user_id": self.user_id,
            "type": self.type,
            "period_start": self.period_start.isoformat() if self.period_start else None,
            "period_end": self.period_end.isoformat() if self.period_end else None,
            "data": self.data,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }
