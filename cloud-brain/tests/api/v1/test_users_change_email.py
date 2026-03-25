"""Tests for POST /api/v1/users/me/email (change email address).

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

TEST_USER_ID = "email-test-user-001"
AUTH_HEADER = {"Authorization": "Bearer test-token"}


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture
def client_with_auth():
    """TestClient with mocked auth and database — no real external calls."""
    mock_auth = AsyncMock(spec=AuthService)
    mock_auth.update_user_email = AsyncMock(return_value=None)

    mock_db = AsyncMock()
    mock_db.add = MagicMock()
    mock_db.commit = AsyncMock()
    mock_db.refresh = AsyncMock()

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


def test_change_email_success(client_with_auth):
    """POST /me/email with a valid new email returns 200 and the confirmation message."""
    client, mock_auth, _ = client_with_auth

    response = client.post(
        "/api/v1/users/me/email",
        json={"new_email": "new@example.com"},
        headers=AUTH_HEADER,
    )

    assert response.status_code == 200
    data = response.json()
    assert data["message"] == "Check your new inbox to confirm."
    mock_auth.update_user_email.assert_called_once()


# ---------------------------------------------------------------------------
# Test 2: Invalid email format triggers Pydantic validation error
# ---------------------------------------------------------------------------


def test_change_email_invalid_format(client_with_auth):
    """POST /me/email with a malformed email returns 422 (Pydantic rejects it)."""
    client, _, _ = client_with_auth

    response = client.post(
        "/api/v1/users/me/email",
        json={"new_email": "notanemail"},
        headers=AUTH_HEADER,
    )

    assert response.status_code == 422


# ---------------------------------------------------------------------------
# Test 3: No Authorization header returns 401 or 403
# ---------------------------------------------------------------------------


def test_change_email_no_token(client_no_auth):
    """POST /me/email without an Authorization header returns 401 or 403."""
    response = client_no_auth.post(
        "/api/v1/users/me/email",
        json={"new_email": "new@example.com"},
    )

    assert response.status_code in {401, 403}


# ---------------------------------------------------------------------------
# Test 4: Supabase rejects the email change — error propagates
# ---------------------------------------------------------------------------


def test_change_email_supabase_error(client_with_auth):
    """POST /me/email when Supabase raises a 400 — the 400 is returned to the client."""
    client, mock_auth, _ = client_with_auth

    mock_auth.update_user_email = AsyncMock(
        side_effect=HTTPException(status_code=400, detail="Email already in use")
    )

    response = client.post(
        "/api/v1/users/me/email",
        json={"new_email": "taken@example.com"},
        headers=AUTH_HEADER,
    )

    assert response.status_code == 400
