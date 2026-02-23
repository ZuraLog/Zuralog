"""
Zuralog Cloud Brain — Integration Model.

Represents a connected third-party integration (e.g., Strava, Fitbit, Oura).
Stores OAuth tokens and sync metadata for each user-integration pair.
"""

import uuid
from enum import Enum as PyEnum

from sqlalchemy import JSON, Boolean, DateTime, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from app.database import Base


class SyncStatus(str, PyEnum):
    """Sync status for an integration.

    Tracks whether a background sync is idle, in progress, or failed.

    Attributes:
        IDLE: No sync in progress. Ready for next sync cycle.
        SYNCING: A sync operation is currently running.
        ERROR: The last sync attempt failed. Check sync_error for details.
    """

    IDLE = "idle"
    SYNCING = "syncing"
    ERROR = "error"


class Integration(Base):
    """A user's connected third-party integration.

    Each row represents a single user ↔ provider connection,
    storing the OAuth tokens needed to access that provider's API.

    Attributes:
        id: Unique identifier for this integration record.
        user_id: Foreign key to the users table.
        provider: Integration provider name (e.g., 'strava', 'fitbit', 'oura').
        access_token: OAuth access token for API calls.
        refresh_token: OAuth refresh token for token renewal.
        token_expires_at: When the access token expires.
        provider_metadata: Provider-specific data stored as JSON.
        is_active: Whether this integration is currently enabled.
        last_synced_at: Timestamp of the most recent data sync.
        sync_status: Current sync state ('idle', 'syncing', 'error').
        sync_error: Error message from the last failed sync attempt.
    """

    __tablename__ = "integrations"

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
    provider: Mapped[str] = mapped_column(String)
    access_token: Mapped[str | None] = mapped_column(String, nullable=True)
    refresh_token: Mapped[str | None] = mapped_column(String, nullable=True)
    token_expires_at: Mapped[str | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    provider_metadata: Mapped[dict | None] = mapped_column(
        JSON,
        nullable=True,
    )
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    last_synced_at: Mapped[str | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    sync_status: Mapped[str] = mapped_column(
        String,
        insert_default=SyncStatus.IDLE,
    )
    sync_error: Mapped[str | None] = mapped_column(
        String,
        nullable=True,
        insert_default=None,
    )
    created_at: Mapped[str] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )

    def __init__(self, **kwargs: object) -> None:
        """Initialise an Integration with Python-level defaults.

        SQLAlchemy's ``insert_default`` only fires at flush time. This
        constructor ensures ``sync_status`` is populated immediately so
        callers can inspect the value before the object is persisted.

        Args:
            **kwargs: Column values forwarded to the ORM base constructor.
        """
        if "sync_status" not in kwargs:
            kwargs["sync_status"] = SyncStatus.IDLE
        super().__init__(**kwargs)
