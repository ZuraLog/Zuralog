"""
Zuralog Cloud Brain — User Supplement Model.

A supplement or medication saved in a user's personal list.
The list is displayed in SupplementsLogScreen as a tap-to-check-off checklist.
"""

import uuid
from datetime import datetime
from decimal import Decimal

from sqlalchemy import Boolean, DateTime, Numeric, SmallInteger, String
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from app.database import Base


class UserSupplement(Base):
    """A supplement or medication in a user's personal list.

    Soft-deleted via is_active=False rather than physical deletion, to
    preserve the integrity of past supplement logs that reference this ID.

    Attributes:
        id: Server-assigned UUID primary key.
        user_id: Supabase UID of the owning user. Indexed.
        name: Supplement or medication name. Max 200 chars.
        dose: Optional dose string (e.g. '500mg'). Max 100 chars.
        timing: Optional timing string ('morning', 'evening', 'anytime', etc.).
        sort_order: Display order within the user's list. Lower = shown first.
        is_active: False when the user removes an item (soft delete).
        created_at: When the entry was created.
        updated_at: When the entry was last modified.
    """

    __tablename__ = "user_supplements"

    id: Mapped[str] = mapped_column(
        String,
        primary_key=True,
        default=lambda: str(uuid.uuid4()),
    )
    user_id: Mapped[str] = mapped_column(
        String,
        nullable=False,
        index=True,
        comment="Supabase UID of the owning user",
    )
    name: Mapped[str] = mapped_column(
        String(200),
        nullable=False,
        comment="Supplement or medication name",
    )
    dose: Mapped[str | None] = mapped_column(
        String(100),
        nullable=True,
        comment="Optional dose string e.g. 500mg",
    )
    timing: Mapped[str | None] = mapped_column(
        String(50),
        nullable=True,
        comment="morning | evening | anytime | etc.",
    )
    dose_amount: Mapped[Decimal | None] = mapped_column(
        Numeric(8, 2),
        nullable=True,
        comment="Numeric dose quantity e.g. 5000 (for 5000 IU)",
    )
    dose_unit: Mapped[str | None] = mapped_column(
        String(20),
        nullable=True,
        comment="Unit of dose e.g. IU, mg, mcg, g, ml",
    )
    form: Mapped[str | None] = mapped_column(
        String(20),
        nullable=True,
        comment="Physical form e.g. capsule, softgel, tablet, powder",
    )
    sort_order: Mapped[int] = mapped_column(
        SmallInteger,
        default=0,
        server_default="0",
        nullable=False,
        comment="Display order within the user's list",
    )
    is_active: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
        server_default="true",
        nullable=False,
        comment="False when soft-deleted by user",
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
    updated_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
