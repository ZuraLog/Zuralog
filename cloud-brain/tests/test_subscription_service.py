"""
Life Logger Cloud Brain — Subscription Service Tests.

Tests the business logic for processing RevenueCat webhook events
and updating user subscription status.
"""

from unittest.mock import AsyncMock, MagicMock

import pytest

from app.services.subscription_service import SubscriptionService


@pytest.fixture
def mock_db():
    """Create a mock async database session."""
    return AsyncMock()


@pytest.fixture
def service():
    """Create a SubscriptionService instance."""
    return SubscriptionService()


def _mock_user(tier="free"):
    """Create a mock user with given tier."""
    user = MagicMock()
    user.subscription_tier = tier
    user.subscription_expires_at = None
    return user


def _db_returns_user(mock_db, user):
    """Configure mock DB to return a user."""
    mock_result = MagicMock()
    mock_result.scalar_one_or_none.return_value = user
    mock_db.execute.return_value = mock_result


def _db_returns_none(mock_db):
    """Configure mock DB to return no user."""
    mock_result = MagicMock()
    mock_result.scalar_one_or_none.return_value = None
    mock_db.execute.return_value = mock_result


class TestInitialPurchase:
    """Tests for INITIAL_PURCHASE events."""

    @pytest.mark.asyncio
    async def test_upgrades_to_pro(self, service, mock_db):
        """INITIAL_PURCHASE should upgrade user to pro tier."""
        user = _mock_user("free")
        _db_returns_user(mock_db, user)

        await service.process_event(
            db=mock_db,
            event_type="INITIAL_PURCHASE",
            app_user_id="u-1",
            expiration_at_ms=1740000000000,
            product_id="pro_monthly",
        )

        assert user.subscription_tier == "pro"
        assert user.subscription_expires_at is not None
        mock_db.commit.assert_awaited_once()

    @pytest.mark.asyncio
    async def test_ignores_unknown_user(self, service, mock_db):
        """INITIAL_PURCHASE for unknown user should be a no-op."""
        _db_returns_none(mock_db)

        await service.process_event(
            db=mock_db,
            event_type="INITIAL_PURCHASE",
            app_user_id="u-missing",
            expiration_at_ms=1740000000000,
            product_id="pro_monthly",
        )

        mock_db.commit.assert_not_awaited()


class TestRenewal:
    """Tests for RENEWAL events."""

    @pytest.mark.asyncio
    async def test_updates_expiration(self, service, mock_db):
        """RENEWAL should maintain pro tier and update expiration."""
        user = _mock_user("pro")
        _db_returns_user(mock_db, user)

        await service.process_event(
            db=mock_db,
            event_type="RENEWAL",
            app_user_id="u-1",
            expiration_at_ms=1743000000000,
            product_id="pro_monthly",
        )

        assert user.subscription_tier == "pro"
        assert user.subscription_expires_at is not None
        mock_db.commit.assert_awaited_once()


class TestExpiration:
    """Tests for EXPIRATION events."""

    @pytest.mark.asyncio
    async def test_downgrades_to_free(self, service, mock_db):
        """EXPIRATION should downgrade user to free tier."""
        user = _mock_user("pro")
        _db_returns_user(mock_db, user)

        await service.process_event(
            db=mock_db,
            event_type="EXPIRATION",
            app_user_id="u-1",
            expiration_at_ms=None,
            product_id="pro_monthly",
        )

        assert user.subscription_tier == "free"
        assert user.subscription_expires_at is None
        mock_db.commit.assert_awaited_once()


class TestBillingIssue:
    """Tests for BILLING_ISSUE events."""

    @pytest.mark.asyncio
    async def test_downgrades_to_free(self, service, mock_db):
        """BILLING_ISSUE should downgrade user to free tier."""
        user = _mock_user("pro")
        _db_returns_user(mock_db, user)

        await service.process_event(
            db=mock_db,
            event_type="BILLING_ISSUE",
            app_user_id="u-1",
            expiration_at_ms=None,
            product_id="pro_monthly",
        )

        assert user.subscription_tier == "free"
        mock_db.commit.assert_awaited_once()


class TestCancellation:
    """Tests for CANCELLATION events (intent only)."""

    @pytest.mark.asyncio
    async def test_keeps_pro_on_cancel_intent(self, service, mock_db):
        """CANCELLATION should keep pro tier (access until expiration)."""
        user = _mock_user("pro")
        _db_returns_user(mock_db, user)

        await service.process_event(
            db=mock_db,
            event_type="CANCELLATION",
            app_user_id="u-1",
            expiration_at_ms=None,
            product_id="pro_monthly",
        )

        assert user.subscription_tier == "pro"
        mock_db.commit.assert_awaited_once()


class TestTransfer:
    """Tests for TRANSFER events."""

    @pytest.mark.asyncio
    async def test_transfer_downgrades_old_user(self, service, mock_db):
        """TRANSFER should downgrade the old user (subscription moved away)."""
        user = _mock_user("pro")
        _db_returns_user(mock_db, user)

        await service.process_event(
            db=mock_db,
            event_type="TRANSFER",
            app_user_id="u-old",
            expiration_at_ms=None,
            product_id="pro_monthly",
        )

        assert user.subscription_tier == "free"
        assert user.subscription_expires_at is None
        mock_db.commit.assert_awaited_once()


class TestUnhandledEvent:
    """Tests for unrecognized event types."""

    @pytest.mark.asyncio
    async def test_unhandled_event_no_commit(self, service, mock_db):
        """Unrecognized event types should not trigger a commit."""
        user = _mock_user("free")
        _db_returns_user(mock_db, user)

        await service.process_event(
            db=mock_db,
            event_type="SOME_FUTURE_EVENT",
            app_user_id="u-1",
            expiration_at_ms=None,
            product_id="pro_monthly",
        )

        mock_db.commit.assert_not_awaited()
