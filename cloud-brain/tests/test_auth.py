"""
Life Logger Cloud Brain — Auth Endpoint Tests.

Tests for the /api/v1/auth/* endpoints. Uses FastAPI dependency_overrides
to inject mocked services without needing live Supabase or a database.
"""

from unittest.mock import AsyncMock, patch

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
def client():
    """Create a TestClient with mocked AuthService and DB dependencies."""
    mock_auth_service = AsyncMock(spec=AuthService)
    mock_db = AsyncMock()

    app.dependency_overrides[_get_auth_service] = lambda: mock_auth_service
    app.dependency_overrides[get_db] = lambda: mock_db

    with TestClient(app, raise_server_exceptions=False) as c:
        yield c, mock_auth_service

    app.dependency_overrides.clear()


# ---------------------------------------------------------------------------
# Registration Tests
# ---------------------------------------------------------------------------


def test_register_success(client):
    """Successful registration returns 200 with auth tokens."""
    c, mock_auth = client
    mock_auth.sign_up.return_value = {
        "user_id": "user-123",
        "access_token": "at-abc",
        "refresh_token": "rt-xyz",
        "expires_in": 3600,
    }

    with patch("app.api.v1.auth.sync_user_to_db", new_callable=AsyncMock):
        response = c.post(
            "/api/v1/auth/register",
            json={"email": "test@example.com", "password": "Test1234!"},
        )

    assert response.status_code == 200
    data = response.json()
    assert data["user_id"] == "user-123"
    assert data["access_token"] == "at-abc"
    assert data["refresh_token"] == "rt-xyz"
    assert data["expires_in"] == 3600
    mock_auth.sign_up.assert_called_once_with("test@example.com", "Test1234!")


def test_register_invalid_email(client):
    """Registration with invalid email returns 422 (Pydantic validation)."""
    c, _ = client
    response = c.post(
        "/api/v1/auth/register",
        json={"email": "not-an-email", "password": "Test1234!"},
    )
    assert response.status_code == 422


# ---------------------------------------------------------------------------
# Login Tests
# ---------------------------------------------------------------------------


def test_login_success(client):
    """Successful login returns 200 with auth tokens."""
    c, mock_auth = client
    mock_auth.sign_in.return_value = {
        "user_id": "user-123",
        "access_token": "at-abc",
        "refresh_token": "rt-xyz",
        "expires_in": 3600,
    }

    with patch("app.api.v1.auth.sync_user_to_db", new_callable=AsyncMock):
        response = c.post(
            "/api/v1/auth/login",
            json={"email": "test@example.com", "password": "Test1234!"},
        )

    assert response.status_code == 200
    data = response.json()
    assert data["user_id"] == "user-123"
    assert data["access_token"] == "at-abc"
    mock_auth.sign_in.assert_called_once_with("test@example.com", "Test1234!")


# ---------------------------------------------------------------------------
# Logout Tests
# ---------------------------------------------------------------------------


def test_logout_success(client):
    """Successful logout returns 200 with message."""
    c, mock_auth = client
    mock_auth.sign_out.return_value = None

    response = c.post(
        "/api/v1/auth/logout",
        headers={"Authorization": "Bearer test-access-token"},
    )

    assert response.status_code == 200
    assert response.json()["message"] == "Logged out successfully"
    mock_auth.sign_out.assert_called_once_with("test-access-token")


def test_logout_no_token(client):
    """Logout without bearer token returns 401 (HTTPBearer auto-error)."""
    c, _ = client
    response = c.post("/api/v1/auth/logout")
    assert response.status_code in (401, 403)


# ---------------------------------------------------------------------------
# Refresh Tests
# ---------------------------------------------------------------------------


def test_refresh_success(client):
    """Successful token refresh returns 200 with new tokens."""
    c, mock_auth = client
    mock_auth.refresh_session.return_value = {
        "user_id": "user-123",
        "access_token": "at-new",
        "refresh_token": "rt-new",
        "expires_in": 3600,
    }

    response = c.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": "rt-old"},
    )

    assert response.status_code == 200
    data = response.json()
    assert data["access_token"] == "at-new"
    assert data["refresh_token"] == "rt-new"
    mock_auth.refresh_session.assert_called_once_with("rt-old")


# ---------------------------------------------------------------------------
# Health Check (regression)
# ---------------------------------------------------------------------------


def test_health_still_works(client):
    """Health endpoint should still return healthy after auth changes."""
    c, _ = client
    response = c.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "healthy"}
