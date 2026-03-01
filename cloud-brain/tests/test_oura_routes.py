"""
Zuralog Cloud Brain — Oura Ring Integration Route Tests.

Tests for the /api/v1/integrations/oura/* endpoints.
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
    """TestClient with mocked AuthService, DB, and Oura token service.

    Patches app.state.oura_token_service after lifespan startup so the
    endpoints use the mock rather than the real service.

    Yields:
        tuple: (TestClient, mock_auth_service, mock_oura_token_service)
    """
    mock_auth_service = AsyncMock(spec=AuthService)
    mock_db = AsyncMock()
    mock_token_service = AsyncMock()

    app.dependency_overrides[_get_auth_service] = lambda: mock_auth_service
    app.dependency_overrides[get_db] = lambda: mock_db

    with TestClient(app, raise_server_exceptions=False) as c:
        original_token_service = getattr(app.state, "oura_token_service", None)
        app.state.oura_token_service = mock_token_service
        yield c, mock_auth_service, mock_token_service
        if original_token_service is not None:
            app.state.oura_token_service = original_token_service
        elif hasattr(app.state, "oura_token_service"):
            del app.state.oura_token_service

    app.dependency_overrides.clear()


_AIOREDIS_PATCH = "app.api.v1.oura_routes.aioredis"


# ---------------------------------------------------------------------------
# GET /authorize
# ---------------------------------------------------------------------------


class TestOuraAuthorize:
    def test_returns_auth_url_and_state(self, client_with_auth):
        """GET /authorize returns an Oura auth_url and state token."""
        c, mock_auth, mock_token_service = client_with_auth
        mock_auth.get_user.return_value = {"id": "user-abc"}

        # build_auth_url is a sync method — use MagicMock
        mock_token_service.store_state = AsyncMock()
        mock_token_service.build_auth_url = MagicMock(
            return_value=(
                "https://cloud.ouraring.com/oauth/authorize?response_type=code&client_id=test&state=teststate"
            )
        )

        mock_redis_instance = AsyncMock()
        mock_redis_instance.aclose = AsyncMock()

        with patch(_AIOREDIS_PATCH) as mock_aioredis:
            mock_aioredis.from_url.return_value = mock_redis_instance
            response = c.get(
                "/api/v1/integrations/oura/authorize",
                headers={"Authorization": "Bearer fake-jwt"},
            )

        assert response.status_code == 200
        data = response.json()
        assert "auth_url" in data
        assert "state" in data
        assert isinstance(data["state"], str)
        assert len(data["state"]) > 0

    def test_auth_url_contains_oura_domain(self, client_with_auth):
        """The auth_url must point to the Oura authorization endpoint."""
        c, mock_auth, mock_token_service = client_with_auth
        mock_auth.get_user.return_value = {"id": "user-abc"}

        mock_token_service.store_state = AsyncMock()
        mock_token_service.build_auth_url = MagicMock(
            return_value="https://cloud.ouraring.com/oauth/authorize?response_type=code"
        )

        mock_redis_instance = AsyncMock()
        mock_redis_instance.aclose = AsyncMock()

        with patch(_AIOREDIS_PATCH) as mock_aioredis:
            mock_aioredis.from_url.return_value = mock_redis_instance
            response = c.get(
                "/api/v1/integrations/oura/authorize",
                headers={"Authorization": "Bearer fake-jwt"},
            )

        assert response.status_code == 200
        data = response.json()
        assert "ouraring.com" in data["auth_url"]

    def test_state_is_random_each_call(self, client_with_auth):
        """Each call to /authorize generates a unique state token."""
        c, mock_auth, mock_token_service = client_with_auth
        mock_auth.get_user.return_value = {"id": "user-abc"}
        mock_token_service.store_state = AsyncMock()
        mock_token_service.build_auth_url = MagicMock(return_value="https://cloud.ouraring.com/oauth/authorize")

        mock_redis_instance = AsyncMock()
        mock_redis_instance.aclose = AsyncMock()

        states = []
        with patch(_AIOREDIS_PATCH) as mock_aioredis:
            mock_aioredis.from_url.return_value = mock_redis_instance
            for _ in range(3):
                response = c.get(
                    "/api/v1/integrations/oura/authorize",
                    headers={"Authorization": "Bearer fake-jwt"},
                )
                states.append(response.json()["state"])

        assert len(set(states)) == 3, "Each state should be unique"


# ---------------------------------------------------------------------------
# POST /exchange
# ---------------------------------------------------------------------------


class TestOuraExchange:
    def _make_mock_integration(self, oura_user_id="OUR123"):
        integration = MagicMock()
        integration.provider_metadata = {"oura_user_id": oura_user_id, "email": "test@example.com"}
        return integration

    def test_valid_code_and_state_returns_success(self, client_with_auth):
        """Valid code + state exchanges tokens and returns oura_user_id."""
        c, mock_auth, mock_token_service = client_with_auth
        mock_auth.get_user.return_value = {"id": "user-xyz"}

        mock_token_service.validate_state = AsyncMock(return_value=True)
        mock_token_service.exchange_code = AsyncMock(
            return_value={
                "access_token": "oura_access_token",
                "refresh_token": "oura_refresh_token",
                "expires_in": 86400,
            }
        )
        integration = self._make_mock_integration()
        mock_token_service.save_tokens = AsyncMock(return_value=integration)

        mock_redis_instance = AsyncMock()
        mock_redis_instance.aclose = AsyncMock()

        with patch(_AIOREDIS_PATCH) as mock_aioredis, patch("app.tasks.oura_sync.backfill_oura_data_task") as mock_task:
            mock_aioredis.from_url.return_value = mock_redis_instance
            mock_task.delay = MagicMock()

            # Note: no user_id param — user_id is derived from the JWT only
            response = c.post(
                "/api/v1/integrations/oura/exchange",
                params={"code": "auth-code-abc", "state": "valid-state"},
                headers={"Authorization": "Bearer fake-jwt"},
            )

        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert data["oura_user_id"] == "OUR123"

    def test_user_id_derived_from_jwt_not_query_param(self, client_with_auth):
        """CRIT-1 regression: user_id is always from the JWT, never a query param.

        Passing an arbitrary user_id in the query string must not cause
        tokens to be stored under a different account (IDOR).  The endpoint
        ignores any caller-supplied user_id and always uses the JWT sub.
        """
        c, mock_auth, mock_token_service = client_with_auth
        # JWT resolves to "jwt-user"
        mock_auth.get_user.return_value = {"id": "jwt-user"}

        mock_token_service.validate_state = AsyncMock(return_value=True)
        mock_token_service.exchange_code = AsyncMock(
            return_value={
                "access_token": "access",
                "refresh_token": "refresh",
                "expires_in": 86400,
            }
        )
        integration = self._make_mock_integration()
        mock_token_service.save_tokens = AsyncMock(return_value=integration)

        mock_redis_instance = AsyncMock()
        mock_redis_instance.aclose = AsyncMock()

        with patch(_AIOREDIS_PATCH) as mock_aioredis, patch("app.tasks.oura_sync.backfill_oura_data_task"):
            mock_aioredis.from_url.return_value = mock_redis_instance

            # Attacker passes a different user_id in the query string
            response = c.post(
                "/api/v1/integrations/oura/exchange",
                params={"code": "auth-code", "state": "valid-state", "user_id": "attacker-user"},
                headers={"Authorization": "Bearer fake-jwt"},
            )

        assert response.status_code == 200
        # save_tokens must be called with the JWT user ("jwt-user"), not "attacker-user"
        save_call_user_id = mock_token_service.save_tokens.call_args[0][1]
        assert save_call_user_id == "jwt-user", (
            f"Expected save_tokens to be called with JWT user 'jwt-user' "
            f"but got '{save_call_user_id}' — IDOR protection is broken"
        )

    def test_invalid_state_returns_400(self, client_with_auth):
        """Expired/invalid state returns HTTP 400."""
        c, mock_auth, mock_token_service = client_with_auth
        mock_auth.get_user.return_value = {"id": "user-xyz"}

        mock_token_service.validate_state = AsyncMock(return_value=False)

        mock_redis_instance = AsyncMock()
        mock_redis_instance.aclose = AsyncMock()

        with patch(_AIOREDIS_PATCH) as mock_aioredis:
            mock_aioredis.from_url.return_value = mock_redis_instance

            response = c.post(
                "/api/v1/integrations/oura/exchange",
                params={"code": "some-code", "state": "bad-state"},
                headers={"Authorization": "Bearer fake-jwt"},
            )

        assert response.status_code == 400
        assert "Invalid or expired state" in response.json()["detail"]

    def test_oura_api_error_returns_400(self, client_with_auth):
        """Oura rejecting the code exchange returns HTTP 400."""
        import httpx as _httpx

        c, mock_auth, mock_token_service = client_with_auth
        mock_auth.get_user.return_value = {"id": "user-xyz"}

        mock_token_service.validate_state = AsyncMock(return_value=True)

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
                "/api/v1/integrations/oura/exchange",
                params={"code": "bad-code", "state": "valid-state"},
                headers={"Authorization": "Bearer fake-jwt"},
            )

        assert response.status_code == 400
        assert "Oura token exchange failed" in response.json()["detail"]
        # Oura's raw error text must NOT appear in the response (CRIT-2)
        assert "invalid_grant" not in response.json()["detail"]

    def test_oura_error_detail_is_sanitized(self, client_with_auth):
        """CRIT-2 regression: Oura error body is never reflected to the caller."""
        import httpx as _httpx

        c, mock_auth, mock_token_service = client_with_auth
        mock_auth.get_user.return_value = {"id": "user-xyz"}

        mock_token_service.validate_state = AsyncMock(return_value=True)

        mock_http_response = MagicMock()
        mock_http_response.status_code = 400
        mock_http_response.text = "sensitive_oura_error_details_including_client_id=abc123"
        http_error = _httpx.HTTPStatusError(
            "400",
            request=MagicMock(),
            response=mock_http_response,
        )
        mock_token_service.exchange_code = AsyncMock(side_effect=http_error)

        mock_redis_instance = AsyncMock()
        mock_redis_instance.aclose = AsyncMock()

        with patch(_AIOREDIS_PATCH) as mock_aioredis:
            mock_aioredis.from_url.return_value = mock_redis_instance

            response = c.post(
                "/api/v1/integrations/oura/exchange",
                params={"code": "bad-code", "state": "valid-state"},
                headers={"Authorization": "Bearer fake-jwt"},
            )

        assert response.status_code == 400
        response_text = response.text
        assert "sensitive_oura_error" not in response_text
        assert "client_id" not in response_text
        assert "abc123" not in response_text

    def test_network_error_returns_503(self, client_with_auth):
        """Network failure during code exchange returns HTTP 503."""
        import httpx as _httpx

        c, mock_auth, mock_token_service = client_with_auth
        mock_auth.get_user.return_value = {"id": "user-xyz"}

        mock_token_service.validate_state = AsyncMock(return_value=True)
        mock_token_service.exchange_code = AsyncMock(side_effect=_httpx.RequestError("Network Down"))

        mock_redis_instance = AsyncMock()
        mock_redis_instance.aclose = AsyncMock()

        with patch(_AIOREDIS_PATCH) as mock_aioredis:
            mock_aioredis.from_url.return_value = mock_redis_instance

            response = c.post(
                "/api/v1/integrations/oura/exchange",
                params={"code": "some-code", "state": "valid-state"},
                headers={"Authorization": "Bearer fake-jwt"},
            )

        assert response.status_code == 503
        assert "Could not reach Oura API" in response.json()["detail"]

    def test_exchange_backfill_failure_still_returns_success(self, client_with_auth):
        """Backfill task failure doesn't break the exchange response."""
        c, mock_auth, mock_token_service = client_with_auth
        mock_auth.get_user.return_value = {"id": "user-xyz"}

        mock_token_service.validate_state = AsyncMock(return_value=True)
        mock_token_service.exchange_code = AsyncMock(
            return_value={
                "access_token": "oura_access_token",
                "refresh_token": "oura_refresh_token",
                "expires_in": 86400,
            }
        )
        integration = self._make_mock_integration()
        mock_token_service.save_tokens = AsyncMock(return_value=integration)

        mock_redis_instance = AsyncMock()
        mock_redis_instance.aclose = AsyncMock()

        # Simulate the entire oura_sync module being unavailable
        with patch(_AIOREDIS_PATCH) as mock_aioredis, patch.dict("sys.modules", {"app.tasks.oura_sync": None}):
            mock_aioredis.from_url.return_value = mock_redis_instance

            response = c.post(
                "/api/v1/integrations/oura/exchange",
                params={"code": "auth-code", "state": "valid-state"},
                headers={"Authorization": "Bearer fake-jwt"},
            )

        assert response.status_code == 200
        assert response.json()["success"] is True


# ---------------------------------------------------------------------------
# GET /status
# ---------------------------------------------------------------------------


class TestOuraStatus:
    def test_connected(self, client_with_auth):
        """Returns connected=True with Oura metadata when integration exists."""
        c, mock_auth, mock_token_service = client_with_auth
        mock_auth.get_user.return_value = {"id": "user-123"}

        integration = MagicMock()
        integration.is_active = True
        integration.last_synced_at = None
        integration.sync_status = "idle"
        integration.provider_metadata = {
            "oura_user_id": "OUR456",
            "email": "user@example.com",
        }
        mock_token_service.get_integration = AsyncMock(return_value=integration)

        response = c.get(
            "/api/v1/integrations/oura/status",
            headers={"Authorization": "Bearer fake-jwt"},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["connected"] is True
        assert data["oura_user_id"] == "OUR456"
        assert data["email"] == "user@example.com"
        assert data["sync_status"] == "idle"
        assert data["last_synced_at"] is None

    def test_not_connected(self, client_with_auth):
        """Returns connected=False when no integration exists."""
        c, mock_auth, mock_token_service = client_with_auth
        mock_auth.get_user.return_value = {"id": "user-999"}

        mock_token_service.get_integration = AsyncMock(return_value=None)

        response = c.get(
            "/api/v1/integrations/oura/status",
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
            "/api/v1/integrations/oura/status",
            headers={"Authorization": "Bearer fake-jwt"},
        )

        assert response.status_code == 200
        assert response.json()["connected"] is False

    def test_status_with_last_synced_at(self, client_with_auth):
        """last_synced_at is serialized as ISO string when set."""
        from datetime import datetime, timezone

        c, mock_auth, mock_token_service = client_with_auth
        mock_auth.get_user.return_value = {"id": "user-123"}

        synced_dt = datetime(2026, 2, 28, 12, 0, 0, tzinfo=timezone.utc)
        integration = MagicMock()
        integration.is_active = True
        integration.last_synced_at = synced_dt
        integration.sync_status = "synced"
        integration.provider_metadata = {"oura_user_id": "OUR789"}
        mock_token_service.get_integration = AsyncMock(return_value=integration)

        response = c.get(
            "/api/v1/integrations/oura/status",
            headers={"Authorization": "Bearer fake-jwt"},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["connected"] is True
        assert data["last_synced_at"] == "2026-02-28T12:00:00+00:00"


# ---------------------------------------------------------------------------
# DELETE /disconnect
# ---------------------------------------------------------------------------


class TestOuraDisconnect:
    def test_disconnect_success(self, client_with_auth):
        """Disconnects Oura integration and returns success=True."""
        c, mock_auth, mock_token_service = client_with_auth
        mock_auth.get_user.return_value = {"id": "user-123"}

        mock_token_service.disconnect = AsyncMock(return_value=True)

        response = c.delete(
            "/api/v1/integrations/oura/disconnect",
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
            "/api/v1/integrations/oura/disconnect",
            headers={"Authorization": "Bearer fake-jwt"},
        )

        assert response.status_code == 200
        assert response.json()["success"] is False
