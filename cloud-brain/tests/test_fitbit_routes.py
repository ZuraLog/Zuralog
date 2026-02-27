"""
Zuralog Cloud Brain — Fitbit Integration Route Tests.

Tests for the /api/v1/integrations/fitbit/* endpoints.
"""

from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi.testclient import TestClient

from app.api.v1.auth import _get_auth_service
from app.database import get_db
from app.main import app
from app.services.auth_service import AuthService


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture
def client_with_auth():
    """TestClient with mocked AuthService, DB, and Fitbit token service.

    Patches app.state.fitbit_token_service after lifespan startup so the
    endpoints use the mock rather than the real service.

    Yields:
        tuple: (TestClient, mock_auth_service, mock_fitbit_token_service)
    """
    mock_auth_service = AsyncMock(spec=AuthService)
    mock_db = AsyncMock()
    mock_token_service = AsyncMock()

    app.dependency_overrides[_get_auth_service] = lambda: mock_auth_service
    app.dependency_overrides[get_db] = lambda: mock_db

    with TestClient(app, raise_server_exceptions=False) as c:
        original_token_service = getattr(app.state, "fitbit_token_service", None)
        app.state.fitbit_token_service = mock_token_service
        yield c, mock_auth_service, mock_token_service
        if original_token_service is not None:
            app.state.fitbit_token_service = original_token_service

    app.dependency_overrides.clear()


# ---------------------------------------------------------------------------
# GET /authorize
# ---------------------------------------------------------------------------


_AIOREDIS_PATCH = "app.api.v1.fitbit_routes.aioredis"


class TestFitbitAuthorize:
    def test_returns_auth_url_and_state(self, client_with_auth):
        """GET /authorize returns a Fitbit auth_url with PKCE params and a state."""
        c, mock_auth, mock_token_service = client_with_auth
        mock_auth.get_user.return_value = {"id": "user-abc"}

        # generate_pkce_pair and build_auth_url are sync methods — use MagicMock.
        mock_token_service.generate_pkce_pair = MagicMock(
            return_value=("test_verifier_abc", "test_challenge_abc")
        )
        mock_token_service.store_pkce_verifier = AsyncMock()
        mock_token_service.build_auth_url = MagicMock(
            return_value=(
                "https://www.fitbit.com/oauth2/authorize"
                "?code_challenge=test_challenge_abc&state=teststate"
            )
        )

        mock_redis_instance = AsyncMock()
        mock_redis_instance.aclose = AsyncMock()

        with patch(_AIOREDIS_PATCH) as mock_aioredis:
            mock_aioredis.from_url.return_value = mock_redis_instance
            response = c.get(
                "/api/v1/integrations/fitbit/authorize",
                headers={"Authorization": "Bearer fake-jwt"},
            )

        assert response.status_code == 200
        data = response.json()
        assert "auth_url" in data
        assert "state" in data
        assert isinstance(data["state"], str)
        assert len(data["state"]) > 0

    def test_auth_url_contains_fitbit_domain(self, client_with_auth):
        """The auth_url must point to Fitbit's authorization endpoint."""
        c, mock_auth, mock_token_service = client_with_auth
        mock_auth.get_user.return_value = {"id": "user-abc"}

        mock_token_service.generate_pkce_pair = MagicMock(return_value=("verifier", "challenge"))
        mock_token_service.store_pkce_verifier = AsyncMock()
        mock_token_service.build_auth_url = MagicMock(
            return_value="https://www.fitbit.com/oauth2/authorize?response_type=code"
        )

        mock_redis_instance = AsyncMock()
        mock_redis_instance.aclose = AsyncMock()

        with patch(_AIOREDIS_PATCH) as mock_aioredis:
            mock_aioredis.from_url.return_value = mock_redis_instance
            response = c.get(
                "/api/v1/integrations/fitbit/authorize",
                headers={"Authorization": "Bearer fake-jwt"},
            )

        assert response.status_code == 200
        data = response.json()
        assert "fitbit.com" in data["auth_url"]


# ---------------------------------------------------------------------------
# POST /exchange
# ---------------------------------------------------------------------------


class TestFitbitExchange:
    def _make_mock_integration(self, fitbit_user_id="FIT123", display_name="Jane Doe"):
        integration = MagicMock()
        integration.provider_metadata = {
            "fitbit_user_id": fitbit_user_id,
            "display_name": display_name,
        }
        return integration

    def test_valid_code_and_state_returns_success(self, client_with_auth):
        """Valid code + state exchanges tokens and returns fitbit_user_id."""
        c, mock_auth, mock_token_service = client_with_auth
        mock_auth.get_user.return_value = {"id": "user-xyz"}

        mock_token_service.get_pkce_verifier = AsyncMock(return_value="my_verifier")
        mock_token_service.exchange_code = AsyncMock(
            return_value={
                "access_token": "fit_access_token",
                "refresh_token": "fit_refresh_token",
                "expires_in": 28800,
                "user_id": "FIT123",
            }
        )
        integration = self._make_mock_integration()
        mock_token_service.save_tokens = AsyncMock(return_value=integration)

        mock_redis_instance = AsyncMock()
        mock_redis_instance.aclose = AsyncMock()

        with patch(_AIOREDIS_PATCH) as mock_aioredis:
            mock_aioredis.from_url.return_value = mock_redis_instance

            response = c.post(
                "/api/v1/integrations/fitbit/exchange",
                params={"code": "auth-code-abc", "state": "valid-state", "user_id": "user-xyz"},
                headers={"Authorization": "Bearer fake-jwt"},
            )

        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert data["fitbit_user_id"] == "FIT123"

    def test_invalid_state_returns_400(self, client_with_auth):
        """Expired/invalid state returns HTTP 400."""
        c, mock_auth, mock_token_service = client_with_auth
        mock_auth.get_user.return_value = {"id": "user-xyz"}

        # Simulate verifier not found in Redis
        mock_token_service.get_pkce_verifier = AsyncMock(return_value=None)

        mock_redis_instance = AsyncMock()
        mock_redis_instance.aclose = AsyncMock()

        with patch(_AIOREDIS_PATCH) as mock_aioredis:
            mock_aioredis.from_url.return_value = mock_redis_instance

            response = c.post(
                "/api/v1/integrations/fitbit/exchange",
                params={"code": "some-code", "state": "bad-state", "user_id": "user-xyz"},
                headers={"Authorization": "Bearer fake-jwt"},
            )

        assert response.status_code == 400
        assert "Invalid or expired state" in response.json()["detail"]

    def test_fitbit_api_error_returns_400(self, client_with_auth):
        """Fitbit rejecting the code exchange returns HTTP 400."""
        import httpx as _httpx

        c, mock_auth, mock_token_service = client_with_auth
        mock_auth.get_user.return_value = {"id": "user-xyz"}

        mock_token_service.get_pkce_verifier = AsyncMock(return_value="my_verifier")

        mock_http_response = MagicMock()
        mock_http_response.status_code = 401
        mock_http_response.text = "invalid_grant"
        http_error = _httpx.HTTPStatusError(
            "401",
            request=MagicMock(),
            response=mock_http_response,
        )
        mock_token_service.exchange_code = AsyncMock(side_effect=http_error)

        mock_redis_instance = AsyncMock()
        mock_redis_instance.aclose = AsyncMock()

        with patch(_AIOREDIS_PATCH) as mock_aioredis:
            mock_aioredis.from_url.return_value = mock_redis_instance

            response = c.post(
                "/api/v1/integrations/fitbit/exchange",
                params={"code": "bad-code", "state": "valid-state", "user_id": "user-xyz"},
                headers={"Authorization": "Bearer fake-jwt"},
            )

        assert response.status_code == 400
        assert "Fitbit token exchange failed" in response.json()["detail"]

    def test_network_error_returns_503(self, client_with_auth):
        """Network failure during code exchange returns HTTP 503."""
        import httpx as _httpx

        c, mock_auth, mock_token_service = client_with_auth
        mock_auth.get_user.return_value = {"id": "user-xyz"}

        mock_token_service.get_pkce_verifier = AsyncMock(return_value="my_verifier")
        mock_token_service.exchange_code = AsyncMock(
            side_effect=_httpx.RequestError("Network Down")
        )

        mock_redis_instance = AsyncMock()
        mock_redis_instance.aclose = AsyncMock()

        with patch(_AIOREDIS_PATCH) as mock_aioredis:
            mock_aioredis.from_url.return_value = mock_redis_instance

            response = c.post(
                "/api/v1/integrations/fitbit/exchange",
                params={"code": "some-code", "state": "valid-state", "user_id": "user-xyz"},
                headers={"Authorization": "Bearer fake-jwt"},
            )

        assert response.status_code == 503
        assert "Could not reach Fitbit API" in response.json()["detail"]


# ---------------------------------------------------------------------------
# GET /status
# ---------------------------------------------------------------------------


class TestFitbitStatus:
    def test_connected(self, client_with_auth):
        """Returns connected=True with Fitbit metadata when integration exists."""
        c, mock_auth, mock_token_service = client_with_auth
        mock_auth.get_user.return_value = {"id": "user-123"}

        integration = MagicMock()
        integration.is_active = True
        integration.last_synced_at = None
        integration.sync_status = "idle"
        integration.provider_metadata = {
            "fitbit_user_id": "FIT456",
            "display_name": "John Doe",
            "devices": [{"id": "tracker-1", "type": "TRACKER"}],
        }
        mock_token_service.get_integration = AsyncMock(return_value=integration)

        response = c.get(
            "/api/v1/integrations/fitbit/status",
            headers={"Authorization": "Bearer fake-jwt"},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["connected"] is True
        assert data["fitbit_user_id"] == "FIT456"
        assert data["display_name"] == "John Doe"
        assert data["sync_status"] == "idle"
        assert data["last_synced_at"] is None
        assert len(data["devices"]) == 1

    def test_not_connected(self, client_with_auth):
        """Returns connected=False when no integration exists."""
        c, mock_auth, mock_token_service = client_with_auth
        mock_auth.get_user.return_value = {"id": "user-999"}

        mock_token_service.get_integration = AsyncMock(return_value=None)

        response = c.get(
            "/api/v1/integrations/fitbit/status",
            headers={"Authorization": "Bearer fake-jwt"},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["connected"] is False

    def test_inactive_integration_returns_not_connected(self, client_with_auth):
        """Returns connected=False when integration is inactive."""
        c, mock_auth, mock_token_service = client_with_auth
        mock_auth.get_user.return_value = {"id": "user-123"}

        integration = MagicMock()
        integration.is_active = False
        mock_token_service.get_integration = AsyncMock(return_value=integration)

        response = c.get(
            "/api/v1/integrations/fitbit/status",
            headers={"Authorization": "Bearer fake-jwt"},
        )

        assert response.status_code == 200
        assert response.json()["connected"] is False


# ---------------------------------------------------------------------------
# DELETE /disconnect
# ---------------------------------------------------------------------------


class TestFitbitDisconnect:
    def test_disconnect_success(self, client_with_auth):
        """Disconnects Fitbit integration and returns success=True."""
        c, mock_auth, mock_token_service = client_with_auth
        mock_auth.get_user.return_value = {"id": "user-123"}

        mock_token_service.disconnect = AsyncMock(return_value=True)

        response = c.delete(
            "/api/v1/integrations/fitbit/disconnect",
            headers={"Authorization": "Bearer fake-jwt"},
        )

        assert response.status_code == 200
        assert response.json()["success"] is True

    def test_disconnect_no_integration(self, client_with_auth):
        """Returns success=False when no integration to disconnect."""
        c, mock_auth, mock_token_service = client_with_auth
        mock_auth.get_user.return_value = {"id": "user-999"}

        mock_token_service.disconnect = AsyncMock(return_value=False)

        response = c.delete(
            "/api/v1/integrations/fitbit/disconnect",
            headers={"Authorization": "Bearer fake-jwt"},
        )

        assert response.status_code == 200
        assert response.json()["success"] is False
