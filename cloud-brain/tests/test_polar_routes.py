"""
Zuralog Cloud Brain — Polar AccessLink Integration Route Tests.

Tests for the /api/v1/integrations/polar/* endpoints.
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
    """TestClient with mocked AuthService, DB, and Polar token service.

    Patches app.state.polar_token_service after lifespan startup so the
    endpoints use the mock rather than the real service.

    Yields:
        tuple: (TestClient, mock_auth_service, mock_polar_token_service)
    """
    mock_auth_service = AsyncMock(spec=AuthService)
    mock_db = AsyncMock()
    mock_token_service = AsyncMock()

    app.dependency_overrides[_get_auth_service] = lambda: mock_auth_service
    app.dependency_overrides[get_db] = lambda: mock_db

    with TestClient(app, raise_server_exceptions=False) as c:
        original_token_service = getattr(app.state, "polar_token_service", None)
        app.state.polar_token_service = mock_token_service
        yield c, mock_auth_service, mock_token_service
        if original_token_service is not None:
            app.state.polar_token_service = original_token_service
        elif hasattr(app.state, "polar_token_service"):
            del app.state.polar_token_service

    app.dependency_overrides.clear()


_AIOREDIS_PATCH = "app.api.v1.polar_routes.aioredis"


# ---------------------------------------------------------------------------
# GET /authorize
# ---------------------------------------------------------------------------


class TestAuthorize:
    def test_returns_auth_url_and_state(self, client_with_auth):
        """GET /authorize returns a Polar auth_url and state token."""
        c, mock_auth, mock_token_service = client_with_auth
        mock_auth.get_user.return_value = {"id": "user-abc"}

        # build_auth_url is a sync method — use MagicMock
        mock_token_service.store_state = AsyncMock()
        mock_token_service.build_auth_url = MagicMock(
            return_value=(
                "https://flow.polar.com/oauth2/authorization?response_type=code&client_id=test&state=teststate"
            )
        )

        mock_redis_instance = AsyncMock()
        mock_redis_instance.aclose = AsyncMock()

        with patch(_AIOREDIS_PATCH) as mock_aioredis:
            mock_aioredis.from_url.return_value = mock_redis_instance
            response = c.get(
                "/api/v1/integrations/polar/authorize",
                headers={"Authorization": "Bearer fake-jwt"},
            )

        assert response.status_code == 200
        data = response.json()
        assert "auth_url" in data
        assert "state" in data
        assert isinstance(data["state"], str)
        assert len(data["state"]) > 0

    def test_auth_url_contains_polar_domain(self, client_with_auth):
        """The auth_url must point to the Polar authorization endpoint."""
        c, mock_auth, mock_token_service = client_with_auth
        mock_auth.get_user.return_value = {"id": "user-abc"}

        mock_token_service.store_state = AsyncMock()
        mock_token_service.build_auth_url = MagicMock(
            return_value="https://flow.polar.com/oauth2/authorization?response_type=code"
        )

        mock_redis_instance = AsyncMock()
        mock_redis_instance.aclose = AsyncMock()

        with patch(_AIOREDIS_PATCH) as mock_aioredis:
            mock_aioredis.from_url.return_value = mock_redis_instance
            response = c.get(
                "/api/v1/integrations/polar/authorize",
                headers={"Authorization": "Bearer fake-jwt"},
            )

        assert response.status_code == 200
        data = response.json()
        assert "polar.com" in data["auth_url"]

    def test_stores_state_with_user_id(self, client_with_auth):
        """store_state is called with user_id as 3rd arg (Polar-specific signature)."""
        c, mock_auth, mock_token_service = client_with_auth
        mock_auth.get_user.return_value = {"id": "user-xyz"}
        mock_token_service.store_state = AsyncMock()
        mock_token_service.build_auth_url = MagicMock(return_value="https://flow.polar.com/oauth2/authorization")

        mock_redis_instance = AsyncMock()
        mock_redis_instance.aclose = AsyncMock()

        with patch(_AIOREDIS_PATCH) as mock_aioredis:
            mock_aioredis.from_url.return_value = mock_redis_instance
            c.get(
                "/api/v1/integrations/polar/authorize",
                headers={"Authorization": "Bearer fake-jwt"},
            )

        mock_token_service.store_state.assert_called_once()
        call_args = mock_token_service.store_state.call_args[0]
        # call signature: (state, user_id, redis_client)
        assert call_args[1] == "user-xyz"

    def test_requires_auth(self, client_with_auth):
        """GET /authorize without Bearer token returns 401 or 403."""
        c, _, _ = client_with_auth
        response = c.get("/api/v1/integrations/polar/authorize")
        assert response.status_code in (401, 403)


# ---------------------------------------------------------------------------
# POST /exchange
# ---------------------------------------------------------------------------


class TestExchange:
    def _make_token_response(self, polar_user_id=12345):
        return {
            "access_token": "polar_access_token",
            "token_type": "Bearer",
            "expires_in": 31535999,
            "x_user_id": polar_user_id,
        }

    def _make_polar_sync_module(self):
        """Create a mock polar_sync module with task stubs."""
        mock_module = MagicMock()
        mock_module.backfill_polar_data_task = MagicMock()
        mock_module.backfill_polar_data_task.delay = MagicMock()
        mock_module.create_polar_webhook_task = MagicMock()
        mock_module.create_polar_webhook_task.delay = MagicMock()
        return mock_module

    def test_exchanges_code_and_saves_tokens(self, client_with_auth):
        """Valid code + state exchanges tokens and returns success + polar_user_id."""
        c, mock_auth, mock_token_service = client_with_auth
        mock_auth.get_user.return_value = {"id": "user-xyz"}

        token_response = self._make_token_response(polar_user_id=99999)
        mock_token_service.validate_state = AsyncMock(return_value="user-xyz")
        mock_token_service.exchange_code = AsyncMock(return_value=token_response)
        mock_token_service.register_user = AsyncMock(return_value={"polar-user-id": 99999})
        mock_token_service.save_tokens = AsyncMock(return_value=MagicMock())

        mock_redis_instance = AsyncMock()
        mock_redis_instance.aclose = AsyncMock()

        mock_polar_sync = self._make_polar_sync_module()

        with (
            patch(_AIOREDIS_PATCH) as mock_aioredis,
            patch.dict("sys.modules", {"app.tasks.polar_sync": mock_polar_sync}),
        ):
            mock_aioredis.from_url.return_value = mock_redis_instance

            response = c.post(
                "/api/v1/integrations/polar/exchange",
                params={"code": "auth-code-abc", "state": "valid-state"},
                headers={"Authorization": "Bearer fake-jwt"},
            )

        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert data["polar_user_id"] == 99999

    def test_rejects_invalid_state(self, client_with_auth):
        """Expired/invalid state returns HTTP 400."""
        c, mock_auth, mock_token_service = client_with_auth
        mock_auth.get_user.return_value = {"id": "user-xyz"}

        mock_token_service.validate_state = AsyncMock(return_value=None)

        mock_redis_instance = AsyncMock()
        mock_redis_instance.aclose = AsyncMock()

        with patch(_AIOREDIS_PATCH) as mock_aioredis:
            mock_aioredis.from_url.return_value = mock_redis_instance

            response = c.post(
                "/api/v1/integrations/polar/exchange",
                params={"code": "some-code", "state": "bad-state"},
                headers={"Authorization": "Bearer fake-jwt"},
            )

        assert response.status_code == 400
        assert "Invalid or expired state" in response.json()["detail"]

    def test_rejects_state_user_id_mismatch(self, client_with_auth):
        """State contains different user_id than JWT — IDOR prevention returns 400."""
        c, mock_auth, mock_token_service = client_with_auth
        mock_auth.get_user.return_value = {"id": "jwt-user"}

        # State was issued for a different user — attacker replaying another user's state
        mock_token_service.validate_state = AsyncMock(return_value="other-user")

        mock_redis_instance = AsyncMock()
        mock_redis_instance.aclose = AsyncMock()

        with patch(_AIOREDIS_PATCH) as mock_aioredis:
            mock_aioredis.from_url.return_value = mock_redis_instance

            response = c.post(
                "/api/v1/integrations/polar/exchange",
                params={"code": "code-abc", "state": "stolen-state"},
                headers={"Authorization": "Bearer fake-jwt"},
            )

        assert response.status_code == 400

    def test_requires_auth(self, client_with_auth):
        """POST /exchange without Bearer token returns 401 or 403."""
        c, _, _ = client_with_auth
        response = c.post(
            "/api/v1/integrations/polar/exchange",
            params={"code": "code", "state": "state"},
        )
        assert response.status_code in (401, 403)

    def test_dispatches_backfill_task(self, client_with_auth):
        """exchange dispatches the backfill Celery task after successful token save."""
        c, mock_auth, mock_token_service = client_with_auth
        mock_auth.get_user.return_value = {"id": "user-task"}

        token_response = self._make_token_response()
        mock_token_service.validate_state = AsyncMock(return_value="user-task")
        mock_token_service.exchange_code = AsyncMock(return_value=token_response)
        mock_token_service.register_user = AsyncMock(return_value={})
        mock_token_service.save_tokens = AsyncMock(return_value=MagicMock())

        mock_redis_instance = AsyncMock()
        mock_redis_instance.aclose = AsyncMock()

        mock_polar_sync = self._make_polar_sync_module()

        with (
            patch(_AIOREDIS_PATCH) as mock_aioredis,
            patch.dict("sys.modules", {"app.tasks.polar_sync": mock_polar_sync}),
        ):
            mock_aioredis.from_url.return_value = mock_redis_instance

            response = c.post(
                "/api/v1/integrations/polar/exchange",
                params={"code": "auth-code", "state": "valid-state"},
                headers={"Authorization": "Bearer fake-jwt"},
            )

        assert response.status_code == 200
        mock_polar_sync.backfill_polar_data_task.delay.assert_called_once_with(user_id="user-task")

    def test_polar_api_error_returns_400(self, client_with_auth):
        """Polar rejecting the code exchange returns HTTP 400."""
        import httpx as _httpx

        c, mock_auth, mock_token_service = client_with_auth
        mock_auth.get_user.return_value = {"id": "user-xyz"}

        mock_token_service.validate_state = AsyncMock(return_value="user-xyz")

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
                "/api/v1/integrations/polar/exchange",
                params={"code": "bad-code", "state": "valid-state"},
                headers={"Authorization": "Bearer fake-jwt"},
            )

        assert response.status_code == 400
        assert "Polar token exchange failed" in response.json()["detail"]
        # Polar's raw error text must NOT appear in the response
        assert "invalid_grant" not in response.json()["detail"]

    def test_network_error_returns_503(self, client_with_auth):
        """Network failure during code exchange returns HTTP 503."""
        import httpx as _httpx

        c, mock_auth, mock_token_service = client_with_auth
        mock_auth.get_user.return_value = {"id": "user-xyz"}

        mock_token_service.validate_state = AsyncMock(return_value="user-xyz")
        mock_token_service.exchange_code = AsyncMock(side_effect=_httpx.RequestError("Network Down"))

        mock_redis_instance = AsyncMock()
        mock_redis_instance.aclose = AsyncMock()

        with patch(_AIOREDIS_PATCH) as mock_aioredis:
            mock_aioredis.from_url.return_value = mock_redis_instance

            response = c.post(
                "/api/v1/integrations/polar/exchange",
                params={"code": "some-code", "state": "valid-state"},
                headers={"Authorization": "Bearer fake-jwt"},
            )

        assert response.status_code == 503
        assert "Could not reach Polar API" in response.json()["detail"]

    def test_register_user_failure_is_swallowed(self, client_with_auth):
        """Registration failure (best-effort) doesn't break the exchange response."""
        c, mock_auth, mock_token_service = client_with_auth
        mock_auth.get_user.return_value = {"id": "user-xyz"}

        token_response = self._make_token_response()
        mock_token_service.validate_state = AsyncMock(return_value="user-xyz")
        mock_token_service.exchange_code = AsyncMock(return_value=token_response)
        mock_token_service.register_user = AsyncMock(side_effect=Exception("registration failed"))
        mock_token_service.save_tokens = AsyncMock(return_value=MagicMock())

        mock_redis_instance = AsyncMock()
        mock_redis_instance.aclose = AsyncMock()

        mock_polar_sync = self._make_polar_sync_module()

        with (
            patch(_AIOREDIS_PATCH) as mock_aioredis,
            patch.dict("sys.modules", {"app.tasks.polar_sync": mock_polar_sync}),
        ):
            mock_aioredis.from_url.return_value = mock_redis_instance

            response = c.post(
                "/api/v1/integrations/polar/exchange",
                params={"code": "auth-code", "state": "valid-state"},
                headers={"Authorization": "Bearer fake-jwt"},
            )

        assert response.status_code == 200
        assert response.json()["success"] is True

    def test_backfill_failure_still_returns_success(self, client_with_auth):
        """Backfill task failure doesn't break the exchange response."""
        c, mock_auth, mock_token_service = client_with_auth
        mock_auth.get_user.return_value = {"id": "user-xyz"}

        token_response = self._make_token_response()
        mock_token_service.validate_state = AsyncMock(return_value="user-xyz")
        mock_token_service.exchange_code = AsyncMock(return_value=token_response)
        mock_token_service.register_user = AsyncMock(return_value={})
        mock_token_service.save_tokens = AsyncMock(return_value=MagicMock())

        mock_redis_instance = AsyncMock()
        mock_redis_instance.aclose = AsyncMock()

        # Simulate the entire polar_sync module being unavailable
        with patch(_AIOREDIS_PATCH) as mock_aioredis, patch.dict("sys.modules", {"app.tasks.polar_sync": None}):
            mock_aioredis.from_url.return_value = mock_redis_instance

            response = c.post(
                "/api/v1/integrations/polar/exchange",
                params={"code": "auth-code", "state": "valid-state"},
                headers={"Authorization": "Bearer fake-jwt"},
            )

        assert response.status_code == 200
        assert response.json()["success"] is True


# ---------------------------------------------------------------------------
# GET /status
# ---------------------------------------------------------------------------


class TestStatus:
    def test_returns_connected_status(self, client_with_auth):
        """Returns connected=True with Polar metadata when integration exists."""
        c, mock_auth, mock_token_service = client_with_auth
        mock_auth.get_user.return_value = {"id": "user-123"}

        integration = MagicMock()
        integration.is_active = True
        integration.last_synced_at = None
        integration.sync_status = "idle"
        integration.token_expires_at = None
        integration.provider_metadata = {"polar_user_id": 12345}
        mock_token_service.get_integration = AsyncMock(return_value=integration)

        response = c.get(
            "/api/v1/integrations/polar/status",
            headers={"Authorization": "Bearer fake-jwt"},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["connected"] is True
        assert data["polar_user_id"] == 12345
        assert data["sync_status"] == "idle"
        assert data["last_synced_at"] is None
        assert data["token_expires_at"] is None

    def test_returns_not_connected(self, client_with_auth):
        """Returns connected=False when no integration exists."""
        c, mock_auth, mock_token_service = client_with_auth
        mock_auth.get_user.return_value = {"id": "user-999"}

        mock_token_service.get_integration = AsyncMock(return_value=None)

        response = c.get(
            "/api/v1/integrations/polar/status",
            headers={"Authorization": "Bearer fake-jwt"},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["connected"] is False

    def test_inactive_integration_returns_not_connected(self, client_with_auth):
        """Returns connected=False when integration exists but is inactive."""
        c, mock_auth, mock_token_service = client_with_auth
        mock_auth.get_user.return_value = {"id": "user-123"}

        integration = MagicMock()
        integration.is_active = False
        mock_token_service.get_integration = AsyncMock(return_value=integration)

        response = c.get(
            "/api/v1/integrations/polar/status",
            headers={"Authorization": "Bearer fake-jwt"},
        )

        assert response.status_code == 200
        assert response.json()["connected"] is False

    def test_status_with_last_synced_at_and_token_expires_at(self, client_with_auth):
        """last_synced_at and token_expires_at are serialized as ISO strings when set."""
        from datetime import datetime, timezone

        c, mock_auth, mock_token_service = client_with_auth
        mock_auth.get_user.return_value = {"id": "user-123"}

        synced_dt = datetime(2026, 2, 28, 12, 0, 0, tzinfo=timezone.utc)
        expires_dt = datetime(2027, 1, 1, 0, 0, 0, tzinfo=timezone.utc)
        integration = MagicMock()
        integration.is_active = True
        integration.last_synced_at = synced_dt
        integration.sync_status = "synced"
        integration.token_expires_at = expires_dt
        integration.provider_metadata = {"polar_user_id": 99999}
        mock_token_service.get_integration = AsyncMock(return_value=integration)

        response = c.get(
            "/api/v1/integrations/polar/status",
            headers={"Authorization": "Bearer fake-jwt"},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["connected"] is True
        assert data["last_synced_at"] == "2026-02-28T12:00:00+00:00"
        assert data["token_expires_at"] == "2027-01-01T00:00:00+00:00"


# ---------------------------------------------------------------------------
# DELETE /disconnect
# ---------------------------------------------------------------------------


class TestDisconnect:
    def test_disconnects_integration(self, client_with_auth):
        """Disconnects Polar integration and returns success=True."""
        c, mock_auth, mock_token_service = client_with_auth
        mock_auth.get_user.return_value = {"id": "user-123"}

        mock_token_service.disconnect = AsyncMock(return_value=True)

        response = c.delete(
            "/api/v1/integrations/polar/disconnect",
            headers={"Authorization": "Bearer fake-jwt"},
        )

        assert response.status_code == 200
        assert response.json()["success"] is True

    def test_returns_success_false_when_not_connected(self, client_with_auth):
        """Returns success=False when no integration to disconnect."""
        c, mock_auth, mock_token_service = client_with_auth
        mock_auth.get_user.return_value = {"id": "user-999"}

        mock_token_service.disconnect = AsyncMock(return_value=False)

        response = c.delete(
            "/api/v1/integrations/polar/disconnect",
            headers={"Authorization": "Bearer fake-jwt"},
        )

        assert response.status_code == 200
        assert response.json()["success"] is False
