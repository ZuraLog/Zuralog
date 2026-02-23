"""
Zuralog Cloud Brain — Subscription Service.

Business logic for processing RevenueCat webhook events and
updating user subscription status in the database.
"""

import logging
from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User

logger = logging.getLogger(__name__)

# RevenueCat event types that grant or maintain Pro access.
UPGRADE_EVENTS = {"INITIAL_PURCHASE", "RENEWAL", "UNCANCELLATION", "PRODUCT_CHANGE"}

# RevenueCat event types that revoke Pro access.
DOWNGRADE_EVENTS = {"EXPIRATION", "BILLING_ISSUE"}

# RevenueCat event types that indicate cancellation intent
# but user keeps access until expiration date.
CANCEL_INTENT_EVENTS = {"CANCELLATION"}

# RevenueCat event types for subscription transfer between accounts.
# TRANSFER moves the subscription to a new app_user_id, so the
# *old* user loses access and the *new* user gains it.
TRANSFER_EVENTS = {"TRANSFER"}


class SubscriptionService:
    """Processes RevenueCat subscription lifecycle events.

    Handles the mapping from RevenueCat event types to database
    subscription state changes on the User model.
    """

    async def process_event(
        self,
        db: AsyncSession,
        event_type: str,
        app_user_id: str,
        expiration_at_ms: int | None,
        product_id: str,
    ) -> None:
        """Process a RevenueCat webhook event.

        Looks up the user by their app_user_id (which should be our
        Supabase UID set during RevenueCat SDK initialization),
        then updates their subscription fields based on the event type.

        Args:
            db: The async database session.
            event_type: RevenueCat event type (e.g., 'INITIAL_PURCHASE').
            app_user_id: The user ID in RevenueCat (our Supabase UID).
            expiration_at_ms: Subscription expiration timestamp in ms.
                None for expiration/cancellation events.
            product_id: The RevenueCat product identifier.
        """
        result = await db.execute(select(User).where(User.id == app_user_id))
        user = result.scalar_one_or_none()

        if user is None:
            logger.warning(
                "RevenueCat event for unknown user: user_id=%s event=%s",
                app_user_id,
                event_type,
            )
            return

        if event_type in UPGRADE_EVENTS:
            user.subscription_tier = "pro"
            if expiration_at_ms:
                user.subscription_expires_at = datetime.fromtimestamp(expiration_at_ms / 1000, tz=timezone.utc)
            logger.info(
                "Subscription upgraded: user=%s tier=pro product=%s",
                app_user_id,
                product_id,
            )

        elif event_type in DOWNGRADE_EVENTS:
            user.subscription_tier = "free"
            user.subscription_expires_at = None
            logger.info(
                "Subscription downgraded: user=%s tier=free event=%s",
                app_user_id,
                event_type,
            )

        elif event_type in CANCEL_INTENT_EVENTS:
            # User cancelled but still has access until expiration.
            # Keep tier as-is, just log.
            logger.info(
                "Subscription cancellation intent: user=%s (access until %s)",
                app_user_id,
                user.subscription_expires_at,
            )

        elif event_type in TRANSFER_EVENTS:
            # TRANSFER means this user's subscription was transferred to
            # another account. RevenueCat sends the event with the *old*
            # app_user_id — so the old user loses access.
            user.subscription_tier = "free"
            user.subscription_expires_at = None
            logger.info(
                "Subscription transferred away: user=%s (downgraded to free)",
                app_user_id,
            )

        else:
            logger.debug(
                "Unhandled RevenueCat event: type=%s user=%s",
                event_type,
                app_user_id,
            )
            return

        await db.commit()
