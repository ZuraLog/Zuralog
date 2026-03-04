"""
Zuralog Cloud Brain — Emergency Health Card Model.

Stores a user's critical medical information for emergency responders.
One row per user (user_id is the primary key). All list fields default to
empty arrays; the card is created or fully replaced via a PUT upsert.
"""

from sqlalchemy import DateTime, JSON, String
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from app.database import Base


class EmergencyCard(Base):
    """A user's emergency health card with critical medical information.

    One row per user (user_id is the primary key). Fields covering blood
    type, allergies, current medications, medical conditions, and emergency
    contacts are all stored as JSON arrays for flexible schema evolution.

    Attributes:
        user_id: Supabase UID — primary key, one row per user.
        blood_type: ABO/Rh blood type string (e.g. "O+"). Nullable.
        allergies: JSON array of allergy description strings.
        medications: JSON array of current medication strings.
        conditions: JSON array of medical condition strings.
        emergency_contacts: JSON array of contact dicts
            (each: {name, relationship, phone}).
        updated_at: Server-managed last-update timestamp. Nullable.
    """

    __tablename__ = "emergency_health_cards"

    user_id: Mapped[str] = mapped_column(
        String,
        primary_key=True,
        comment="Supabase UID — one row per user",
    )
    blood_type: Mapped[str | None] = mapped_column(
        String,
        nullable=True,
        comment="ABO/Rh blood type, e.g. 'O+'",
    )
    allergies: Mapped[list] = mapped_column(
        JSON,
        default=list,
        server_default="[]",
        nullable=False,
        comment="Array of allergy description strings",
    )
    medications: Mapped[list] = mapped_column(
        JSON,
        default=list,
        server_default="[]",
        nullable=False,
        comment="Array of current medication strings",
    )
    conditions: Mapped[list] = mapped_column(
        JSON,
        default=list,
        server_default="[]",
        nullable=False,
        comment="Array of medical condition strings",
    )
    emergency_contacts: Mapped[list] = mapped_column(
        JSON,
        default=list,
        server_default="[]",
        nullable=False,
        comment="Array of contact dicts: {name, relationship, phone}",
    )
    updated_at: Mapped[str | None] = mapped_column(
        DateTime(timezone=True),
        onupdate=func.now(),
        nullable=True,
    )
