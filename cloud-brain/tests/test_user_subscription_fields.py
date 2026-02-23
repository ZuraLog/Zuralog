"""
Zuralog Cloud Brain — User Subscription Field Tests.

Validates that the User model has the required subscription fields
and that default values are correct.
"""

from datetime import datetime, timezone

from app.models.user import SubscriptionTier, User


class TestSubscriptionTier:
    """Tests for the SubscriptionTier enum."""

    def test_free_value(self):
        assert SubscriptionTier.FREE.value == "free"

    def test_pro_value(self):
        assert SubscriptionTier.PRO.value == "pro"

    def test_free_rank(self):
        assert SubscriptionTier.FREE.rank == 0

    def test_pro_rank(self):
        assert SubscriptionTier.PRO.rank == 1

    def test_tier_ordering(self):
        assert SubscriptionTier.FREE.rank < SubscriptionTier.PRO.rank


class TestUserSubscriptionFields:
    """Tests for subscription-related fields on the User model."""

    def test_default_subscription_tier_is_free(self):
        """DB-level default is 'free'; ORM init leaves it as None until flush.

        We verify the column descriptor has the correct default configured.
        """
        col = User.__table__.columns["subscription_tier"]
        assert col.default.arg == "free"

    def test_is_premium_false_for_free_tier(self):
        user = User(id="u-1", email="test@test.com", subscription_tier="free")
        assert user.is_premium is False

    def test_is_premium_true_for_pro_tier(self):
        user = User(id="u-1", email="test@test.com", subscription_tier="pro")
        assert user.is_premium is True

    def test_subscription_expires_at_nullable(self):
        user = User(id="u-1", email="test@test.com")
        assert user.subscription_expires_at is None

    def test_subscription_expires_at_can_be_set(self):
        expires = datetime(2026, 3, 1, tzinfo=timezone.utc)
        user = User(
            id="u-1",
            email="test@test.com",
            subscription_tier="pro",
            subscription_expires_at=expires,
        )
        assert user.subscription_expires_at == expires

    def test_revenuecat_customer_id_nullable(self):
        user = User(id="u-1", email="test@test.com")
        assert user.revenuecat_customer_id is None

    def test_revenuecat_customer_id_can_be_set(self):
        user = User(
            id="u-1",
            email="test@test.com",
            revenuecat_customer_id="rc_abc123",
        )
        assert user.revenuecat_customer_id == "rc_abc123"
