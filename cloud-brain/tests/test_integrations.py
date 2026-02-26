"""
Zuralog Cloud Brain — Integrations Endpoint Tests.

Tests for the /api/v1/integrations/* endpoints.
"""

from unittest.mock import AsyncMock, MagicMock, patch

import httpx
import pytest
from fastapi.testclient import TestClient

from app.api.v1.auth import _get_auth_service
from app.main import app
from app.services.auth_service import AuthService


@pytest.fixture
def client_with_auth():
    """Create a TestClient with mocked AuthService."""
    mock_auth_service = AsyncMock(spec=AuthService)
    app.dependency_overrides[_get_auth_service] = lambda: mock_auth_service

    with TestClient(app, raise_server_exceptions=False) as c:
        yield c, mock_auth_service

    app.dependency_overrides.clear()


def test_strava_authorize():
    """Verify the authorize endpoint returns a valid Strava OAuth URL."""
    with TestClient(app) as client:
        response = client.get("/api/v1/integrations/strava/authorize")
        assert response.status_code == 200
        data = response.json()
        assert "auth_url" in data
        assert "https://www.strava.com/oauth/authorize" in data["auth_url"]
        assert "response_type=code" in data["auth_url"]
        assert "scope=read%2Cactivity%3Aread_all%2Cactivity%3Awrite%2Cprofile%3Aread_all" in data["auth_url"]


@patch("httpx.AsyncClient.post")
def test_strava_exchange_success(mock_post: AsyncMock, client_with_auth):
    """Verify successful code exchange stores the token."""
    c, mock_auth = client_with_auth
    mock_auth.get_user.return_value = {"id": "test-user-123"}

    mock_response = MagicMock()
    mock_response.status_code = 200
    mock_response.json.return_value = {
        "access_token": "test-access-token",
        "refresh_token": "test-refresh",
    }
    mock_post.return_value = mock_response

    response = c.post(
        "/api/v1/integrations/strava/exchange",
        params={"code": "auth-code-123"},
        headers={"Authorization": "Bearer fake-jwt"},
    )

    assert response.status_code == 200
    assert response.json() == {"success": True, "message": "Strava connected!"}

    # Verify token was saved in the in-memory MCP server registry
    registry = app.state.mcp_registry
    strava_server = registry.get("strava")
    assert strava_server is not None
    assert strava_server._tokens.get("test-user-123") == "test-access-token"

    mock_auth.get_user.assert_called_once_with("fake-jwt")


@patch("httpx.AsyncClient.post")
def test_strava_exchange_failure(mock_post: AsyncMock, client_with_auth):
    """Verify backend handles Strava API rejection correctly."""
    c, mock_auth = client_with_auth
    mock_auth.get_user.return_value = {"id": "test-user-123"}

    mock_response = MagicMock()
    mock_response.status_code = 400
    mock_response.text = "Bad Request"
    mock_post.return_value = mock_response

    response = c.post(
        "/api/v1/integrations/strava/exchange",
        params={"code": "bad-code"},
        headers={"Authorization": "Bearer fake-jwt"},
    )

    assert response.status_code == 400
    assert "Strava token exchange failed" in response.json()["detail"]


@patch("httpx.AsyncClient.post")
def test_strava_exchange_network_error(mock_post: AsyncMock, client_with_auth):
    """Verify backend handles network unreachable errors correctly."""
    mock_post.side_effect = httpx.RequestError("Network Down")

    c, mock_auth = client_with_auth
    mock_auth.get_user.return_value = {"id": "test-user-123"}

    response = c.post(
        "/api/v1/integrations/strava/exchange",
        params={"code": "auth-code-123"},
        headers={"Authorization": "Bearer fake-jwt"},
    )

    assert response.status_code == 503
    assert "Could not reach Strava API" in response.json()["detail"]


def test_strava_authorize_includes_expanded_scopes():
    """Verify auth URL includes activity:read_all and profile:read_all."""
    with TestClient(app) as client:
        response = client.get("/api/v1/integrations/strava/authorize")
        auth_url = response.json()["auth_url"]
        assert "activity%3Aread_all" in auth_url or "activity:read_all" in auth_url
        assert "profile%3Aread_all" in auth_url or "profile:read_all" in auth_url
