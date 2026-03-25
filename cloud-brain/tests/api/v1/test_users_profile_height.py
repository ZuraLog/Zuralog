"""Tests for PATCH /api/v1/users/me/profile — height_cm validation.

Uses the same mock-based TestClient pattern as the rest of the test suite.
No live database — all DB calls are replaced by AsyncMock so tests run
fast and deterministically.
"""

from __future__ import annotations

from datetime import datetime, timezone
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi.testclient import TestClient

from app.api.deps import _get_auth_service, get_authenticated_user_id
from app.api.v1.users import _get_storage_service
from app.database import get_db
from app.main import app
from app.services.auth_service import AuthService
from app.services.storage_service import StorageService

TEST_USER_ID = "profile-test-user-001"
AUTH_HEADER = {"Authorization": "Bearer test-token"}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _make_user(user_id: str = TEST_USER_ID, height_cm: float | None = None) -> MagicMock:
    """Build a minimal mock User ORM object that satisfies UserProfileResponse."""
    user = MagicMock()
    user.id = user_id
    user.email = "test@example.com"
    user.display_name = "Test User"
    user.nickname = "Testy"
    user.birthday = None
    user.gender = None
    user.height_cm = height_cm
    user.avatar_url = None
    user.onboarding_complete = False
    user.created_at = datetime(2026, 1, 1, tzinfo=timezone.utc)
    return user


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture
def client_with_auth():
    """TestClient with mocked auth and database — no real DB required."""
    mock_auth = AsyncMock(spec=AuthService)
    mock_auth.get_user = AsyncMock(return_value={"id": TEST_USER_ID})

    fake_user = _make_user(height_cm=None)

    mock_db = AsyncMock()
    mock_db.add = MagicMock()
    mock_db.commit = AsyncMock()
    mock_db.refresh = AsyncMock(return_value=None)

    # The update_profile endpoint runs: result = await db.execute(select(User)...)
    # then db_user = result.scalars().first()
    mock_scalars = MagicMock()
    mock_scalars.first.return_value = fake_user
    mock_result = MagicMock()
    mock_result.scalars.return_value = mock_scalars
    mock_db.execute = AsyncMock(return_value=mock_result)

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
            yield c, mock_db, fake_user

    app.dependency_overrides.clear()


# ---------------------------------------------------------------------------
# Test 1: Valid height_cm returns 200
# ---------------------------------------------------------------------------


def test_update_profile_height_valid(client_with_auth):
    """PATCH /me/profile with a valid height_cm (175.0) returns 200."""
    client, _, fake_user = client_with_auth

    # After setattr(db_user, "height_cm", 175.0) the refresh mock will replay
    # the same object, so we manually set the expected value here.
    fake_user.height_cm = 175.0

    response = client.patch(
        "/api/v1/users/me/profile",
        json={"height_cm": 175.0},
        headers=AUTH_HEADER,
    )

    assert response.status_code == 200
    data = response.json()
    assert data["height_cm"] == 175.0


# ---------------------------------------------------------------------------
# Test 2: height_cm below minimum (ge=30) returns 422
# ---------------------------------------------------------------------------


def test_update_profile_height_too_low(client_with_auth):
    """PATCH /me/profile with height_cm=20.0 (below 30) returns 422."""
    client, _, _ = client_with_auth

    response = client.patch(
        "/api/v1/users/me/profile",
        json={"height_cm": 20.0},
        headers=AUTH_HEADER,
    )

    assert response.status_code == 422


# ---------------------------------------------------------------------------
# Test 3: height_cm above maximum (le=300) returns 422
# ---------------------------------------------------------------------------


def test_update_profile_height_too_high(client_with_auth):
    """PATCH /me/profile with height_cm=310.0 (above 300) returns 422."""
    client, _, _ = client_with_auth

    response = client.patch(
        "/api/v1/users/me/profile",
        json={"height_cm": 310.0},
        headers=AUTH_HEADER,
    )

    assert response.status_code == 422
