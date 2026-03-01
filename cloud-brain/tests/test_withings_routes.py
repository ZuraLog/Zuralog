"""
Zuralog Cloud Brain — Withings Integration Route Tests.

Tests for the /api/v1/integrations/withings/* endpoints.
"""

from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi.testclient import TestClient

from app.api.v1.auth import _get_auth_service
from app.database import get_db
from app.main import app
from app.services.auth_service import AuthService


@pytest.fixture
def client_with_auth():
    """TestClient with mocked AuthService, DB, and Withings token service."""
    mock_auth_service = AsyncMock(spec=AuthService)
    mock_db = AsyncMock()
    mock_token_service = AsyncMock()
    mock_sig_service = AsyncMock()

    app.dependency_overrides[_get_auth_service] = lambda: mock_auth_service
    app.dependency_overrides[get_db] = lambda: mock_db

    with TestClient(app, raise_server_exceptions=False) as c:
        original_token_service = getattr(app.state, "withings_token_service", None)
        original_sig_service = getattr(app.state, "withings_signature_service", None)
        app.state.withings_token_service = mock_token_service
        app.state.withings_signature_service = mock_sig_service
        yield c, mock_auth_service, mock_token_service, mock_sig_service
        if original_token_service is not None:
            app.state.withings_token_service = original_token_service
        elif hasattr(app.state, "withings_token_service"):
            del app.state.withings_token_service
        if original_sig_service is not None:
            app.state.withings_signature_service = original_sig_service
        elif hasattr(app.state, "withings_signature_service"):
            del app.state.withings_signature_service

    app.dependency_overrides.clear()


_AIOREDIS_PATCH = "app.api.v1.withings_routes.aioredis"


class TestWithingsAuthorize:
    def test_returns_auth_url_and_state(self, client_with_auth):
        """GET /authorize returns a Withings auth_url and state token."""
        c, mock_auth, mock_token_service, _ = client_with_auth
        mock_auth.get_user.return_value = {"id": "user-abc"}
        mock_token_service.store_state = AsyncMock()
        mock_token_service.build_auth_url = MagicMock(
            return_value="https://account.withings.com/oauth2_user/authorize2?response_type=code&state=xxx"
        )

        mock_redis_instance = AsyncMock()
        mock_redis_instance.aclose = AsyncMock()

        with patch(_AIOREDIS_PATCH) as mock_aioredis:
            mock_aioredis.from_url.return_value = mock_redis_instance
            response = c.get(
                "/api/v1/integrations/withings/authorize",
                headers={"Authorization": "Bearer test-jwt"},
            )

        assert response.status_code == 200
        data = response.json()
        assert "auth_url" in data
        assert "state" in data
        assert "withings.com" in data["auth_url"]

    def test_stores_state_with_user_id(self, client_with_auth):
        """store_state is called with user_id (not '1')."""
        c, mock_auth, mock_token_service, _ = client_with_auth
        mock_auth.get_user.return_value = {"id": "user-xyz"}
        mock_token_service.store_state = AsyncMock()
        mock_token_service.build_auth_url = MagicMock(return_value="https://example.com/auth")

        mock_redis_instance = AsyncMock()
        mock_redis_instance.aclose = AsyncMock()

        with patch(_AIOREDIS_PATCH) as mock_aioredis:
            mock_aioredis.from_url.return_value = mock_redis_instance
            c.get(
                "/api/v1/integrations/withings/authorize",
                headers={"Authorization": "Bearer test-jwt"},
            )

        mock_token_service.store_state.assert_called_once()
        call_args = mock_token_service.store_state.call_args[0]
        # call_args: (state, user_id, redis_client)
        assert call_args[1] == "user-xyz"

    def test_requires_auth(self, client_with_auth):
        """GET /authorize without Bearer token returns 401."""
        c, _, _, _ = client_with_auth
        response = c.get("/api/v1/integrations/withings/authorize")
        assert response.status_code == 401


class TestWithingsCallback:
    def test_success_redirects_to_deep_link(self, client_with_auth):
        """GET /callback with valid code+state redirects to zuralog://oauth/withings?success=true."""
        c, _, mock_token_service, mock_sig_service = client_with_auth
        mock_token_service.validate_state = AsyncMock(return_value="user-abc")
        mock_token_service.exchange_code = AsyncMock(
            return_value={
                "userid": "12345",
                "access_token": "access",
                "refresh_token": "refresh",
                "expires_in": 10800,
                "scope": "user.metrics,user.activity",
            }
        )
        mock_token_service.save_tokens = AsyncMock(return_value=MagicMock())

        mock_redis_instance = AsyncMock()
        mock_redis_instance.aclose = AsyncMock()

        with (
            patch(_AIOREDIS_PATCH) as mock_aioredis,
            patch("app.api.v1.withings_routes.backfill_withings_data_task", create=True),
            patch("app.api.v1.withings_routes.create_withings_webhook_subscriptions_task", create=True),
        ):
            mock_aioredis.from_url.return_value = mock_redis_instance
            response = c.get(
                "/api/v1/integrations/withings/callback?code=testcode&state=teststate",
                follow_redirects=False,
            )

        assert response.status_code == 302
        assert "zuralog://oauth/withings" in response.headers["location"]
        assert "success=true" in response.headers["location"]

    def test_invalid_state_redirects_failure(self, client_with_auth):
        """GET /callback with invalid state redirects with success=false."""
        c, _, mock_token_service, _ = client_with_auth
        mock_token_service.validate_state = AsyncMock(return_value=None)

        mock_redis_instance = AsyncMock()
        mock_redis_instance.aclose = AsyncMock()

        with patch(_AIOREDIS_PATCH) as mock_aioredis:
            mock_aioredis.from_url.return_value = mock_redis_instance
            response = c.get(
                "/api/v1/integrations/withings/callback?code=testcode&state=badstate",
                follow_redirects=False,
            )

        assert response.status_code == 302
        assert "success=false" in response.headers["location"]

    def test_error_param_redirects_failure(self, client_with_auth):
        """GET /callback with error param redirects with success=false."""
        c, _, _, _ = client_with_auth

        response = c.get(
            "/api/v1/integrations/withings/callback?error=access_denied&state=teststate",
            follow_redirects=False,
        )

        assert response.status_code == 302
        assert "success=false" in response.headers["location"]

    def test_missing_code_redirects_failure(self, client_with_auth):
        """GET /callback with no code redirects with success=false."""
        c, _, _, _ = client_with_auth

        response = c.get(
            "/api/v1/integrations/withings/callback?state=teststate",
            follow_redirects=False,
        )

        assert response.status_code == 302
        assert "success=false" in response.headers["location"]


class TestWithingsStatus:
    def test_connected_returns_details(self, client_with_auth):
        """GET /status returns connected=True when integration is active."""
        c, mock_auth, mock_token_service, _ = client_with_auth
        mock_auth.get_user.return_value = {"id": "user-abc"}

        mock_integration = MagicMock()
        mock_integration.is_active = True
        mock_integration.sync_status = "idle"
        mock_integration.last_synced_at = None
        mock_integration.provider_metadata = {"withings_user_id": "12345"}
        mock_token_service.get_integration = AsyncMock(return_value=mock_integration)

        response = c.get(
            "/api/v1/integrations/withings/status",
            headers={"Authorization": "Bearer test-jwt"},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["connected"] is True
        assert data["withings_user_id"] == "12345"

    def test_not_connected_returns_false(self, client_with_auth):
        """GET /status returns connected=False when no integration exists."""
        c, mock_auth, mock_token_service, _ = client_with_auth
        mock_auth.get_user.return_value = {"id": "user-abc"}
        mock_token_service.get_integration = AsyncMock(return_value=None)

        response = c.get(
            "/api/v1/integrations/withings/status",
            headers={"Authorization": "Bearer test-jwt"},
        )

        assert response.status_code == 200
        assert response.json()["connected"] is False


class TestWithingsDisconnect:
    def test_disconnect_success(self, client_with_auth):
        """DELETE /disconnect returns success=True when integration exists."""
        c, mock_auth, mock_token_service, _ = client_with_auth
        mock_auth.get_user.return_value = {"id": "user-abc"}
        mock_token_service.disconnect = AsyncMock(return_value=True)

        response = c.delete(
            "/api/v1/integrations/withings/disconnect",
            headers={"Authorization": "Bearer test-jwt"},
        )

        assert response.status_code == 200
        assert response.json()["success"] is True

    def test_disconnect_no_integration(self, client_with_auth):
        """DELETE /disconnect returns success=False when no integration."""
        c, mock_auth, mock_token_service, _ = client_with_auth
        mock_auth.get_user.return_value = {"id": "user-abc"}
        mock_token_service.disconnect = AsyncMock(return_value=False)

        response = c.delete(
            "/api/v1/integrations/withings/disconnect",
            headers={"Authorization": "Bearer test-jwt"},
        )

        assert response.status_code == 200
        assert response.json()["success"] is False
