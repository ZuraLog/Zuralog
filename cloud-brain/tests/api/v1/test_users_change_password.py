"""Tests for POST /api/v1/users/me/password (change password).

Uses the same mock-based TestClient pattern as the rest of the test suite.
No live database or Supabase — all external calls are replaced with fakes.
"""

from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient

from app.api.deps import _get_auth_service, get_authenticated_user_id
from app.api.v1.users import _get_storage_service
from app.database import get_db
from app.main import app
from app.services.auth_service import AuthService
from app.services.storage_service import StorageService

TEST_USER_ID = "password-test-user-001"
TEST_EMAIL = "test@example.com"
AUTH_HEADER = {"Authorization": "Bearer test-token"}


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture
def client_with_auth():
    """TestClient with mocked auth and database — no real external calls.

    The database mock is pre-configured to return a fake email address
    when the endpoint looks up the user's current email.
    """
    mock_auth = AsyncMock(spec=AuthService)
    mock_auth.sign_in = AsyncMock(return_value=MagicMock())
    mock_auth.update_user_password = AsyncMock(return_value=None)

    mock_db = AsyncMock()
    mock_db.add = MagicMock()
    mock_db.commit = AsyncMock()
    mock_db.refresh = AsyncMock()

    # The change_password endpoint runs: result = await db.execute(select(User.email)...)
    # then email = result.scalar_one_or_none()
    mock_email_result = MagicMock()
    mock_email_result.scalar_one_or_none.return_value = TEST_EMAIL
    mock_db.execute = AsyncMock(return_value=mock_email_result)

    mock_storage = AsyncMock(spec=StorageService)

    app.dependency_overrides[_get_auth_service] = lambda: mock_auth
    app.dependency_overrides[get_authenticated_user_id] = lambda: TEST_USER_ID
    app.dependency_overrides[get_db] = lambda: mock_db
    app.dependency_overrides[_get_storage_service] = lambda: mock_storage

    # Patch RateLimiter so the lifespan does not try to connect to a real Redis URL.
    # The mock instance needs an awaitable `close` method for the shutdown hook.
    mock_rl_instance = MagicMock()
    mock_rl_instance.close = AsyncMock(return_value=None)

    with patch("app.main.RateLimiter") as mock_rl_cls:
        mock_rl_cls.return_value = mock_rl_instance
        with TestClient(app, raise_server_exceptions=False) as c:
            yield c, mock_auth, mock_db

    app.dependency_overrides.clear()


@pytest.fixture
def client_no_auth():
    """TestClient with NO auth override — lets the real dependency reject the request."""
    mock_storage = AsyncMock(spec=StorageService)
    app.dependency_overrides[_get_storage_service] = lambda: mock_storage

    mock_rl_instance = MagicMock()
    mock_rl_instance.close = AsyncMock(return_value=None)

    with patch("app.main.RateLimiter") as mock_rl_cls:
        mock_rl_cls.return_value = mock_rl_instance
        with TestClient(app, raise_server_exceptions=False) as c:
            yield c

    app.dependency_overrides.clear()


# ---------------------------------------------------------------------------
# Test 1: Success
# ---------------------------------------------------------------------------


def test_change_password_success(client_with_auth):
    """POST /me/password with correct credentials returns 200 and a success message."""
    client, mock_auth, _ = client_with_auth

    response = client.post(
        "/api/v1/users/me/password",
        json={"current_password": "oldpass123", "new_password": "newpass123"},
        headers=AUTH_HEADER,
    )

    assert response.status_code == 200
    data = response.json()
    assert data["message"] == "Password updated successfully."
    mock_auth.sign_in.assert_called_once_with(TEST_EMAIL, "oldpass123")
    mock_auth.update_user_password.assert_called_once()


# ---------------------------------------------------------------------------
# Test 2: Wrong current password returns 401
# ---------------------------------------------------------------------------


def test_change_password_wrong_current(client_with_auth):
    """POST /me/password with the wrong current password returns 401."""
    client, mock_auth, _ = client_with_auth

    mock_auth.sign_in = AsyncMock(
        side_effect=HTTPException(status_code=401, detail="invalid credentials")
    )

    response = client.post(
        "/api/v1/users/me/password",
        json={"current_password": "wrongpassword", "new_password": "newpass123"},
        headers=AUTH_HEADER,
    )

    assert response.status_code == 401
    data = response.json()
    assert data["detail"] == "Current password is incorrect."


# ---------------------------------------------------------------------------
# Test 3: New password too short triggers Pydantic validation error
# ---------------------------------------------------------------------------


def test_change_password_short_new(client_with_auth):
    """POST /me/password with a new password under 8 characters returns 422."""
    client, _, _ = client_with_auth

    response = client.post(
        "/api/v1/users/me/password",
        json={"current_password": "oldpass123", "new_password": "short"},
        headers=AUTH_HEADER,
    )

    assert response.status_code == 422


# ---------------------------------------------------------------------------
# Test 4: Correct payload returns 200 (verifies endpoint is reachable)
# ---------------------------------------------------------------------------


def test_change_password_rate_limit_format_only(client_with_auth):
    """POST /me/password with correct payload returns 200 (rate limiting is disabled in tests)."""
    client, _, _ = client_with_auth

    response = client.post(
        "/api/v1/users/me/password",
        json={"current_password": "oldpass123", "new_password": "newpass456"},
        headers=AUTH_HEADER,
    )

    assert response.status_code == 200
    assert response.json()["message"] == "Password updated successfully."
