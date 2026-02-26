# tests/test_strava_token_service.py
"""Tests for StravaTokenService — DB-backed token lifecycle."""

from datetime import datetime, timedelta, timezone
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.strava_token_service import StravaTokenService


@pytest.fixture
def mock_db():
    """Create an AsyncMock for SQLAlchemy AsyncSession."""
    db = AsyncMock()
    db.execute = AsyncMock()
    db.commit = AsyncMock()
    db.refresh = AsyncMock()
    return db


@pytest.fixture
def service():
    return StravaTokenService()


class TestSaveTokens:
    """Tests for persisting Strava OAuth tokens."""

    @pytest.mark.asyncio
    async def test_save_tokens_creates_new_integration(self, service, mock_db):
        """When no existing integration, creates a new row."""
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = None
        mock_db.execute.return_value = mock_result

        await service.save_tokens(
            db=mock_db,
            user_id="user-123",
            access_token="at-abc",
            refresh_token="rt-xyz",
            expires_at=1740500000,
            athlete_data={"id": 12345, "firstname": "Jake"},
        )

        mock_db.commit.assert_called_once()

    @pytest.mark.asyncio
    async def test_save_tokens_updates_existing_integration(self, service, mock_db):
        """When integration exists, updates tokens in place."""
        existing = MagicMock()
        existing.access_token = "old-token"
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = existing
        mock_db.execute.return_value = mock_result

        await service.save_tokens(
            db=mock_db,
            user_id="user-123",
            access_token="new-at",
            refresh_token="new-rt",
            expires_at=1740500000,
            athlete_data=None,
        )

        assert existing.access_token == "new-at"
        assert existing.refresh_token == "new-rt"
        mock_db.commit.assert_called_once()


class TestGetAccessToken:
    """Tests for retrieving a valid access token."""

    @pytest.mark.asyncio
    async def test_returns_token_when_not_expired(self, service, mock_db):
        """Returns access_token directly when it has not expired."""
        future = datetime.now(timezone.utc) + timedelta(hours=2)
        integration = MagicMock()
        integration.access_token = "valid-token"
        integration.token_expires_at = future
        integration.is_active = True

        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = integration
        mock_db.execute.return_value = mock_result

        token = await service.get_access_token(mock_db, "user-123")
        assert token == "valid-token"

    @pytest.mark.asyncio
    async def test_returns_none_when_no_integration(self, service, mock_db):
        """Returns None when user has no Strava integration."""
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = None
        mock_db.execute.return_value = mock_result

        token = await service.get_access_token(mock_db, "user-999")
        assert token is None

    @pytest.mark.asyncio
    @patch("app.services.strava_token_service.StravaTokenService.refresh_access_token")
    async def test_refreshes_token_when_expired(self, mock_refresh, service, mock_db):
        """Calls refresh when token is within 5-minute expiry window."""
        past = datetime.now(timezone.utc) - timedelta(minutes=1)
        integration = MagicMock()
        integration.access_token = "expired-token"
        integration.refresh_token = "rt-xyz"
        integration.token_expires_at = past
        integration.is_active = True

        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = integration
        mock_db.execute.return_value = mock_result

        mock_refresh.return_value = "refreshed-token"

        token = await service.get_access_token(mock_db, "user-123")
        assert token == "refreshed-token"
        mock_refresh.assert_called_once()


class TestRefreshAccessToken:
    """Tests for the Strava token refresh flow."""

    @pytest.mark.asyncio
    @patch("httpx.AsyncClient.post")
    async def test_refresh_updates_db_on_success(self, mock_post, service, mock_db):
        """Successful refresh updates integration row with new tokens."""
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "access_token": "new-at",
            "refresh_token": "new-rt",
            "expires_at": 1740600000,
        }
        mock_post.return_value = mock_response

        integration = MagicMock()
        integration.refresh_token = "old-rt"

        result = await service.refresh_access_token(mock_db, integration)
        assert result == "new-at"
        assert integration.access_token == "new-at"
        mock_db.commit.assert_called_once()

    @pytest.mark.asyncio
    @patch("httpx.AsyncClient.post")
    async def test_refresh_returns_none_on_failure(self, mock_post, service, mock_db):
        """Returns None and marks integration error on refresh failure."""
        mock_response = MagicMock()
        mock_response.status_code = 401
        mock_response.text = "Unauthorized"
        mock_post.return_value = mock_response

        integration = MagicMock()
        integration.refresh_token = "bad-rt"

        result = await service.refresh_access_token(mock_db, integration)
        assert result is None


class TestDisconnect:
    """Tests for revoking Strava integration."""

    @pytest.mark.asyncio
    async def test_disconnect_deactivates_integration(self, service, mock_db):
        """Sets is_active=False and clears tokens."""
        integration = MagicMock()
        integration.is_active = True
        integration.access_token = "some-token"
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = integration
        mock_db.execute.return_value = mock_result

        with patch("httpx.AsyncClient.post", new_callable=AsyncMock):
            result = await service.disconnect(mock_db, "user-123")

        assert result is True
        assert integration.is_active is False
        assert integration.access_token is None
        mock_db.commit.assert_called_once()
