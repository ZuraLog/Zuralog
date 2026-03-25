"""Tests for POST /api/v1/users/me/avatar (avatar image upload).

Uses the same mock-based TestClient pattern as the rest of the test suite.
No live Supabase Storage or database — all external calls are replaced with fakes.
"""

from __future__ import annotations

from io import BytesIO
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi.testclient import TestClient

from app.api.deps import get_authenticated_user_id
from app.api.v1.users import _get_storage_service
from app.database import get_db
from app.main import app
from app.services.storage_service import StorageService

TEST_USER_ID = "avatar-test-user-001"
AUTH_HEADER = {"Authorization": "Bearer test-token"}

# Minimal valid JPEG — real magic bytes (FF D8 FF E0) followed by padding.
# The `filetype` library identifies this as image/jpeg from the first 4 bytes.
TINY_JPEG = bytes([0xFF, 0xD8, 0xFF, 0xE0]) + b"\x00" * 100

# A file that is one byte over the 5 MB limit.
OVERSIZED_JPEG = bytes([0xFF, 0xD8, 0xFF, 0xE0]) + b"\x00" * (5 * 1024 * 1024 + 1)

# Plain text bytes — not an image.
TEXT_FILE = b"hello this is not an image"

FAKE_SUPABASE_URL = "https://fake.supabase.co"
FAKE_AVATAR_BUCKET = "avatars"


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture
def client_with_auth():
    """TestClient with mocked auth, storage, and database.

    Also patches settings.supabase_url and settings.avatar_bucket so the
    URL built by the endpoint starts with 'https://' and passes the sanity check.
    """
    mock_storage = AsyncMock(spec=StorageService)
    mock_storage.upload_file = AsyncMock(return_value=None)
    mock_storage.delete_file = AsyncMock(return_value=None)

    mock_db = AsyncMock()
    mock_db.add = MagicMock()
    mock_db.commit = AsyncMock()
    mock_db.refresh = AsyncMock()
    mock_db.execute = AsyncMock(return_value=MagicMock())

    app.dependency_overrides[get_authenticated_user_id] = lambda: TEST_USER_ID
    app.dependency_overrides[get_db] = lambda: mock_db
    app.dependency_overrides[_get_storage_service] = lambda: mock_storage

    # Patch RateLimiter so the lifespan does not try to connect to a real Redis URL.
    # The mock instance needs an awaitable `close` method for the shutdown hook.
    mock_rl_instance = MagicMock()
    mock_rl_instance.close = AsyncMock(return_value=None)

    with patch("app.main.RateLimiter") as mock_rl_cls:
        mock_rl_cls.return_value = mock_rl_instance
        with (
            patch("app.api.v1.users.settings") as mock_settings,
            TestClient(app, raise_server_exceptions=False) as c,
        ):
            mock_settings.supabase_url = FAKE_SUPABASE_URL
            mock_settings.avatar_bucket = FAKE_AVATAR_BUCKET
            yield c, mock_storage

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
# Test 1: Valid JPEG upload returns 200 with an avatar_url
# ---------------------------------------------------------------------------


def test_avatar_upload_success_jpeg(client_with_auth):
    """POST /me/avatar with a valid JPEG returns 200 and an avatar_url."""
    client, mock_storage = client_with_auth

    response = client.post(
        "/api/v1/users/me/avatar",
        files={"file": ("avatar.jpg", BytesIO(TINY_JPEG), "image/jpeg")},
        headers=AUTH_HEADER,
    )

    assert response.status_code == 200
    data = response.json()
    assert "avatar_url" in data
    assert data["avatar_url"].startswith("https://")
    assert TEST_USER_ID in data["avatar_url"]
    mock_storage.upload_file.assert_called_once()


# ---------------------------------------------------------------------------
# Test 2: Oversized file returns 413
# ---------------------------------------------------------------------------


def test_avatar_upload_oversized(client_with_auth):
    """POST /me/avatar with a file over 5 MB returns 413."""
    client, _ = client_with_auth

    response = client.post(
        "/api/v1/users/me/avatar",
        files={"file": ("big.jpg", BytesIO(OVERSIZED_JPEG), "image/jpeg")},
        headers=AUTH_HEADER,
    )

    assert response.status_code == 413


# ---------------------------------------------------------------------------
# Test 3: Non-image file returns 415
# ---------------------------------------------------------------------------


def test_avatar_upload_non_image(client_with_auth):
    """POST /me/avatar with a plain text file returns 415."""
    client, _ = client_with_auth

    response = client.post(
        "/api/v1/users/me/avatar",
        files={"file": ("notes.txt", BytesIO(TEXT_FILE), "text/plain")},
        headers=AUTH_HEADER,
    )

    assert response.status_code == 415


# ---------------------------------------------------------------------------
# Test 4: No Authorization header returns 401 or 403
# ---------------------------------------------------------------------------


def test_avatar_upload_no_token(client_no_auth):
    """POST /me/avatar without an Authorization header returns 401 or 403."""
    response = client_no_auth.post(
        "/api/v1/users/me/avatar",
        files={"file": ("avatar.jpg", BytesIO(TINY_JPEG), "image/jpeg")},
    )

    assert response.status_code in {401, 403}
