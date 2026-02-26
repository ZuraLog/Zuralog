"""
Zuralog Cloud Brain — Sync Scheduler Tests.

Tests periodic sync tasks that pull data from cloud integrations.
All external calls are mocked.
"""

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.sync_scheduler import SyncService


@pytest.fixture
def sync_service():
    """Create a SyncService instance."""
    return SyncService()


def test_sync_service_exists():
    """SyncService class should be importable."""
    assert SyncService is not None


@pytest.mark.asyncio
async def test_sync_user_data_no_integrations(sync_service):
    """Should handle user with no active integrations gracefully."""
    result = await sync_service.sync_user_data(
        user_id="user-123",
        active_integrations=[],
    )
    assert result["synced_sources"] == []
    assert result["errors"] == []


@pytest.mark.asyncio
async def test_sync_user_data_with_strava(sync_service):
    """Should attempt to sync Strava data when integration is active."""
    integrations = [{"provider": "strava", "access_token": "tok-123"}]
    with patch.object(sync_service, "_sync_strava", new_callable=AsyncMock) as mock_strava:
        mock_strava.return_value = {"activities": 5}
        result = await sync_service.sync_user_data(
            user_id="user-123",
            active_integrations=integrations,
        )
    assert "strava" in result["synced_sources"]
    mock_strava.assert_called_once()


@pytest.mark.asyncio
async def test_sync_user_data_strava_error_captured(sync_service):
    """Strava sync failure should be captured, not raised."""
    integrations = [{"provider": "strava", "access_token": "bad-token"}]
    with patch.object(
        sync_service,
        "_sync_strava",
        new_callable=AsyncMock,
        side_effect=RuntimeError("401 Unauthorized"),
    ):
        result = await sync_service.sync_user_data(
            user_id="user-123",
            active_integrations=integrations,
        )
    assert len(result["errors"]) == 1
    assert "strava" in result["errors"][0].lower()


class TestSyncStravaReal:
    """Tests for the real Strava sync implementation."""

    @pytest.mark.asyncio
    @patch("httpx.AsyncClient.get")
    async def test_sync_strava_fetches_and_stores_activities(self, mock_get):
        """Fetches activities from Strava and creates UnifiedActivity rows."""
        mock_resp = MagicMock()
        mock_resp.status_code = 200
        mock_resp.json.return_value = [
            {
                "id": 123,
                "name": "Morning Run",
                "type": "Run",
                "distance": 5000.0,
                "elapsed_time": 1800,
                "start_date_local": "2026-02-25T07:00:00Z",
                "calories": 350,
                "total_elevation_gain": 50.0,
            }
        ]
        mock_get.return_value = mock_resp

        service = SyncService()
        mock_db = AsyncMock()
        # Simulate "no existing activity" (upsert creates new)
        mock_db.execute.return_value = MagicMock(scalar_one_or_none=MagicMock(return_value=None))

        result = await service._sync_strava(
            db=mock_db,
            user_id="user-123",
            access_token="valid-token",
        )

        assert result["activities_synced"] > 0
        mock_db.add.assert_called()
        mock_db.commit.assert_called()

    @pytest.mark.asyncio
    @patch("httpx.AsyncClient.get")
    async def test_sync_strava_skips_existing_activities(self, mock_get):
        """Does not duplicate activities that already exist."""
        mock_resp = MagicMock()
        mock_resp.status_code = 200
        mock_resp.json.return_value = [
            {
                "id": 123,
                "name": "Morning Run",
                "type": "Run",
                "distance": 5000.0,
                "elapsed_time": 1800,
                "start_date_local": "2026-02-25T07:00:00Z",
            }
        ]
        mock_get.return_value = mock_resp

        service = SyncService()
        mock_db = AsyncMock()
        # Simulate "activity already exists"
        existing = MagicMock()
        mock_db.execute.return_value = MagicMock(scalar_one_or_none=MagicMock(return_value=existing))

        result = await service._sync_strava(
            db=mock_db,
            user_id="user-123",
            access_token="valid-token",
        )

        assert result["activities_synced"] == 0
        mock_db.add.assert_not_called()

    @pytest.mark.asyncio
    @patch("httpx.AsyncClient.get")
    async def test_sync_strava_handles_api_error(self, mock_get):
        """Returns error info when Strava API returns non-200."""
        mock_resp = MagicMock()
        mock_resp.status_code = 401
        mock_resp.text = "Unauthorized"
        mock_get.return_value = mock_resp

        service = SyncService()
        mock_db = AsyncMock()

        result = await service._sync_strava(
            db=mock_db,
            user_id="user-123",
            access_token="bad-token",
        )

        assert result.get("error") is not None


class TestRefreshTokensTask:
    """Tests for the proactive Strava token refresh task."""

    @pytest.mark.asyncio
    async def test_refresh_tokens_refreshes_expiring_tokens(self):
        """Finds integrations expiring in 30 min and refreshes them."""
        from datetime import datetime, timedelta, timezone

        # Create an integration that expires in 10 minutes
        expiring_integration = MagicMock()
        expiring_integration.user_id = "user-123"
        expiring_integration.refresh_token = "rt-xyz"
        expiring_integration.token_expires_at = datetime.now(timezone.utc) + timedelta(minutes=10)

        mock_db = AsyncMock()
        mock_db.execute.return_value = MagicMock(
            scalars=MagicMock(return_value=MagicMock(all=MagicMock(return_value=[expiring_integration])))
        )

        mock_token_service = AsyncMock()
        mock_token_service.refresh_access_token.return_value = "new-token"

        service = SyncService()
        result = await service._refresh_expiring_tokens(
            db=mock_db,
            token_service=mock_token_service,
        )

        assert result["refreshed"] == 1
        mock_token_service.refresh_access_token.assert_called_once_with(mock_db, expiring_integration)

    @pytest.mark.asyncio
    async def test_refresh_tokens_skips_non_expiring(self):
        """Does not refresh tokens that are still valid for > 30 min."""
        mock_db = AsyncMock()
        mock_db.execute.return_value = MagicMock(
            scalars=MagicMock(return_value=MagicMock(all=MagicMock(return_value=[])))
        )

        mock_token_service = AsyncMock()
        service = SyncService()

        result = await service._refresh_expiring_tokens(
            db=mock_db,
            token_service=mock_token_service,
        )

        assert result["refreshed"] == 0
        mock_token_service.refresh_access_token.assert_not_called()
