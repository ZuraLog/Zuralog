"""
Life Logger Cloud Brain — User Model.

Represents a registered Life Logger user. The primary key is the
Supabase UID, ensuring a single source of truth for identity.
"""

import uuid

from sqlalchemy import Boolean, String
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func
from sqlalchemy import DateTime

from app.database import Base


class User(Base):
    """A Life Logger user account.

    Attributes:
        id: Unique identifier, matches the Supabase Auth UID.
        email: User's email address (unique, indexed).
        created_at: Timestamp of account creation (server-side default).
        updated_at: Timestamp of last profile update.
        coach_persona: AI coach personality style. One of:
            'gentle', 'balanced', 'tough_love'.
        is_premium: Whether the user has an active Pro subscription.
    """

    __tablename__ = "users"

    id: Mapped[str] = mapped_column(
        String,
        primary_key=True,
        default=lambda: str(uuid.uuid4()),
    )
    email: Mapped[str] = mapped_column(
        String,
        unique=True,
        index=True,
    )
    created_at: Mapped[str] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )
    updated_at: Mapped[str | None] = mapped_column(
        DateTime(timezone=True),
        onupdate=func.now(),
        nullable=True,
    )
    coach_persona: Mapped[str] = mapped_column(
        String,
        default="tough_love",
    )
    is_premium: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
    )
