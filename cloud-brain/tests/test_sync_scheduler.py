"""
Life Logger Cloud Brain — Sync Scheduler Tests.

Tests periodic sync tasks that pull data from cloud integrations.
All external calls are mocked.
"""

from unittest.mock import AsyncMock, patch

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
