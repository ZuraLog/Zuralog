"""
Life Logger Cloud Brain — User Device Model.

Stores FCM registration tokens for user devices, enabling
cloud-to-device push communication. Each user can have
multiple devices (e.g., iPhone + iPad).
"""

import uuid

from sqlalchemy import DateTime, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from app.database import Base


class UserDevice(Base):
    """A registered user device with its FCM token.

    Each row represents a single device that can receive
    push notifications and background data messages.

    Attributes:
        id: Unique identifier for this device record.
        user_id: Foreign key to the users table.
        fcm_token: Firebase Cloud Messaging registration token.
        platform: Device platform ('ios' or 'android').
        last_seen_at: Timestamp of last activity from this device.
        created_at: Timestamp of device registration.
    """

    __tablename__ = "user_devices"

    id: Mapped[str] = mapped_column(
        String,
        primary_key=True,
        default=lambda: str(uuid.uuid4()),
    )
    user_id: Mapped[str] = mapped_column(
        String,
        ForeignKey("users.id", ondelete="CASCADE"),
        index=True,
    )
    fcm_token: Mapped[str] = mapped_column(String, unique=True)
    platform: Mapped[str] = mapped_column(String)  # 'ios' or 'android'
    last_seen_at: Mapped[str | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    created_at: Mapped[str] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )
