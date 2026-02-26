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
    mock_db = AsyncMock()
    with patch.object(sync_service, "_sync_strava", new_callable=AsyncMock) as mock_strava:
        mock_strava.return_value = {"activities": 5}
        result = await sync_service.sync_user_data(
            user_id="user-123",
            active_integrations=integrations,
            db=mock_db,
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
    async def test_sync_strava_fetches_and_stores_activities(self):
        """Fetches activities from Strava and creates UnifiedActivity rows.

        The mock returns one page of activities then an empty page to terminate
        pagination.
        """
        page1_resp = MagicMock()
        page1_resp.status_code = 200
        page1_resp.json.return_value = [
            {
                "id": 123,
                "name": "Morning Run",
                "type": "Run",
                "distance": 5000.0,
                "elapsed_time": 1800,
                "start_date": "2026-02-25T07:00:00Z",
                "calories": 350,
                "total_elevation_gain": 50.0,
            }
        ]
        empty_resp = MagicMock()
        empty_resp.status_code = 200
        empty_resp.json.return_value = []

        service = SyncService()
        mock_db = AsyncMock()
        mock_db.execute.return_value = MagicMock(scalar_one_or_none=MagicMock(return_value=None))

        with patch("httpx.AsyncClient") as mock_client_cls:
            mock_client = AsyncMock()
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=False)
            mock_client.get = AsyncMock(side_effect=[page1_resp, empty_resp])
            mock_client_cls.return_value = mock_client

            result = await service._sync_strava(
                db=mock_db,
                user_id="user-123",
                access_token="valid-token",
            )

        assert result["activities_synced"] == 1
        assert result["pages_fetched"] >= 1
        mock_db.add.assert_called()
        mock_db.commit.assert_called()

    @pytest.mark.asyncio
    async def test_sync_strava_skips_existing_activities(self):
        """Does not duplicate activities that already exist.

        When the first activity on page 1 already exists in the DB, pagination
        stops immediately (early-exit optimisation).
        """
        page1_resp = MagicMock()
        page1_resp.status_code = 200
        page1_resp.json.return_value = [
            {
                "id": 123,
                "name": "Morning Run",
                "type": "Run",
                "distance": 5000.0,
                "elapsed_time": 1800,
                "start_date": "2026-02-25T07:00:00Z",
            }
        ]

        service = SyncService()
        mock_db = AsyncMock()
        existing = MagicMock()
        mock_db.execute.return_value = MagicMock(scalar_one_or_none=MagicMock(return_value=existing))

        with patch("httpx.AsyncClient") as mock_client_cls:
            mock_client = AsyncMock()
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=False)
            mock_client.get = AsyncMock(return_value=page1_resp)
            mock_client_cls.return_value = mock_client

            result = await service._sync_strava(
                db=mock_db,
                user_id="user-123",
                access_token="valid-token",
            )

        assert result["activities_synced"] == 0
        mock_db.add.assert_not_called()

    @pytest.mark.asyncio
    async def test_sync_strava_handles_api_error(self):
        """Returns error info when Strava API returns non-200."""
        error_resp = MagicMock()
        error_resp.status_code = 401
        error_resp.text = "Unauthorized"

        service = SyncService()
        mock_db = AsyncMock()

        with patch("httpx.AsyncClient") as mock_client_cls:
            mock_client = AsyncMock()
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=False)
            mock_client.get = AsyncMock(return_value=error_resp)
            mock_client_cls.return_value = mock_client

            result = await service._sync_strava(
                db=mock_db,
                user_id="user-123",
                access_token="bad-token",
            )

        assert result.get("error") is not None

    @pytest.mark.asyncio
    async def test_sync_strava_incremental_passes_after_param(self):
        """When after_timestamp is supplied, it is forwarded to the Strava API."""
        empty_resp = MagicMock()
        empty_resp.status_code = 200
        empty_resp.json.return_value = []

        service = SyncService()
        mock_db = AsyncMock()

        with patch("httpx.AsyncClient") as mock_client_cls:
            mock_client = AsyncMock()
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=False)
            mock_client.get = AsyncMock(return_value=empty_resp)
            mock_client_cls.return_value = mock_client

            await service._sync_strava(
                db=mock_db,
                user_id="user-123",
                access_token="valid-token",
                after_timestamp=1700000000,
            )

        call_kwargs = mock_client.get.call_args
        assert call_kwargs.kwargs["params"]["after"] == 1700000000

    @pytest.mark.asyncio
    async def test_sync_strava_paginates_multiple_pages(self):
        """Fetches page 2 when page 1 is fully new."""

        def _activity(aid: int) -> dict:
            return {
                "id": aid,
                "type": "Run",
                "distance": 5000.0,
                "elapsed_time": 1800,
                "start_date": "2026-02-25T07:00:00Z",
            }

        page1_resp = MagicMock()
        page1_resp.status_code = 200
        page1_resp.json.return_value = [_activity(1), _activity(2)]

        page2_resp = MagicMock()
        page2_resp.status_code = 200
        page2_resp.json.return_value = [_activity(3)]

        empty_resp = MagicMock()
        empty_resp.status_code = 200
        empty_resp.json.return_value = []

        service = SyncService()
        mock_db = AsyncMock()
        mock_db.execute.return_value = MagicMock(scalar_one_or_none=MagicMock(return_value=None))

        with patch("httpx.AsyncClient") as mock_client_cls:
            mock_client = AsyncMock()
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=False)
            mock_client.get = AsyncMock(side_effect=[page1_resp, page2_resp, empty_resp])
            mock_client_cls.return_value = mock_client

            result = await service._sync_strava(
                db=mock_db,
                user_id="user-123",
                access_token="valid-token",
            )

        assert result["activities_synced"] == 3
        assert mock_client.get.call_count == 3


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
