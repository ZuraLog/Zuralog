"""
Life Logger Cloud Brain — User Model.

Represents a registered Life Logger user. The primary key is the
Supabase UID, ensuring a single source of truth for identity.
Subscription fields track tier, expiration, and RevenueCat linkage.
"""

import enum
import uuid

from sqlalchemy import DateTime, String
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from app.database import Base


class SubscriptionTier(enum.Enum):
    """Subscription tier levels with numeric rank for comparison.

    Attributes:
        FREE: Free tier with basic features and limited API calls.
        PRO: Pro tier with unlimited chat, voice, and cross-app reasoning.
    """

    FREE = "free"
    PRO = "pro"

    @property
    def rank(self) -> int:
        """Numeric rank for tier comparison.

        Returns:
            Integer rank where higher = more access.
        """
        return {"free": 0, "pro": 1}[self.value]


class User(Base):
    """A Life Logger user account.

    Attributes:
        id: Unique identifier, matches the Supabase Auth UID.
        email: User's email address (unique, indexed).
        created_at: Timestamp of account creation (server-side default).
        updated_at: Timestamp of last profile update.
        coach_persona: AI coach personality style. One of:
            'gentle', 'balanced', 'tough_love'.
        subscription_tier: Current subscription tier ('free' or 'pro').
        subscription_expires_at: When the current subscription period ends.
            None for free-tier users.
        revenuecat_customer_id: RevenueCat customer ID linking this user
            to their payment processor identity. Indexed for webhook lookups.
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
    subscription_tier: Mapped[str] = mapped_column(
        String,
        default="free",
    )
    subscription_expires_at: Mapped[str | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    revenuecat_customer_id: Mapped[str | None] = mapped_column(
        String,
        nullable=True,
        index=True,
    )

    @property
    def is_premium(self) -> bool:
        """Whether the user has an active paid subscription.

        Returns:
            True if subscription_tier is not 'free'.
        """
        return self.subscription_tier != "free"
