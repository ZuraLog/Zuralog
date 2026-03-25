"""Test that DateTime columns have correct Mapped[datetime] annotations."""
from sqlalchemy import DateTime

from app.models.integration import Integration
from app.models.user import User


def test_user_created_at_is_datetime_type() -> None:
    assert isinstance(User.__table__.c.created_at.type, DateTime)


def test_user_updated_at_is_datetime_type() -> None:
    assert isinstance(User.__table__.c.updated_at.type, DateTime)


def test_user_subscription_expires_at_is_datetime_type() -> None:
    assert isinstance(User.__table__.c.subscription_expires_at.type, DateTime)


def test_integration_token_expires_at_is_datetime_type() -> None:
    assert isinstance(Integration.__table__.c.token_expires_at.type, DateTime)


def test_integration_last_synced_at_is_datetime_type() -> None:
    assert isinstance(Integration.__table__.c.last_synced_at.type, DateTime)


def test_integration_created_at_is_datetime_type() -> None:
    assert isinstance(Integration.__table__.c.created_at.type, DateTime)
