"""
Zuralog Cloud Brain — Emergency Health Card Model.

Stores critical health information that emergency responders may need.
There is at most one card per user (enforced by a unique constraint on
``user_id``). All clinical fields are JSON to support variable-length
lists without schema migrations as data grows.
"""

import uuid
from datetime import datetime

from sqlalchemy import DateTime, String, UniqueConstraint
from sqlalchemy.dialects.postgresql import JSON
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from app.database import Base


class EmergencyHealthCard(Base):
    """A user's emergency health information card.

    All list fields use JSON so the schema does not need to change as
    users add/remove items. The application layer enforces structure
    within these JSON values.

    Attributes:
        id: UUID primary key (auto-generated).
        user_id: Owner's user ID (unique — one card per user).
        blood_type: ABO/Rh blood type string (e.g. ``"A+"``, ``"O-"``).
        allergies: JSON list of allergy strings
            (e.g. ``["penicillin", "peanuts"]``).
        medications: JSON list of medication dicts, each with
            ``{name, dose, frequency}``.
        conditions: JSON list of medical condition strings
            (e.g. ``["Type 2 Diabetes", "Hypertension"]``).
        emergency_contacts: JSON list of contact dicts, each with
            ``{name, relationship, phone}``.
        updated_at: Timestamp of last update (server-side default,
            updated on every write).
        created_at: Row creation timestamp (server-side default).
    """

    __tablename__ = "emergency_health_cards"
    __table_args__ = (UniqueConstraint("user_id", name="uq_emergency_card_user"),)

    id: Mapped[str] = mapped_column(
        String,
        primary_key=True,
        default=lambda: str(uuid.uuid4()),
    )
    user_id: Mapped[str] = mapped_column(
        String,
        unique=True,
        index=True,
        nullable=False,
    )
    blood_type: Mapped[str | None] = mapped_column(
        String,
        nullable=True,
        comment="ABO/Rh blood type, e.g. 'A+', 'O-'",
    )
    allergies: Mapped[list | None] = mapped_column(
        JSON,
        nullable=True,
        comment="List of allergy strings",
    )
    medications: Mapped[list | None] = mapped_column(
        JSON,
        nullable=True,
        comment="List of {name, dose, frequency} dicts",
    )
    conditions: Mapped[list | None] = mapped_column(
        JSON,
        nullable=True,
        comment="List of medical condition strings",
    )
    emergency_contacts: Mapped[list | None] = mapped_column(
        JSON,
        nullable=True,
        comment="List of {name, relationship, phone} dicts",
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )
