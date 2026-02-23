"""
Zuralog Cloud Brain — Social Auth Endpoint Tests.

Tests for the POST /api/v1/auth/social endpoint, covering Google and Apple
sign-in flows. Uses FastAPI dependency_overrides to inject mocked services
without needing live Supabase or a real database connection.
"""

from unittest.mock import AsyncMock, patch

import pytest
from fastapi import HTTPException, status
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
# Helpers
# ---------------------------------------------------------------------------

_GOOGLE_SUCCESS = {
    "user_id": "supabase-user-abc",
    "email": "user@gmail.com",
    "access_token": "at-google",
    "refresh_token": "rt-google",
    "expires_in": 3600,
}

_APPLE_SUCCESS = {
    "user_id": "supabase-user-xyz",
    "email": "user@privaterelay.appleid.com",
    "access_token": "at-apple",
    "refresh_token": "rt-apple",
    "expires_in": 3600,
}


# ---------------------------------------------------------------------------
# Google Sign-In Tests
# ---------------------------------------------------------------------------


def test_google_social_login_success(client):
    """Successful Google login returns 200 with standard AuthResponse."""
    c, mock_auth = client
    mock_auth.sign_in_with_id_token.return_value = _GOOGLE_SUCCESS

    with patch("app.api.v1.auth.sync_user_to_db", new_callable=AsyncMock):
        response = c.post(
            "/api/v1/auth/social",
            json={
                "provider": "google",
                "id_token": "google-id-token-jwt",
                "access_token": "google-access-token",
            },
        )

    assert response.status_code == 200
    data = response.json()
    assert data["user_id"] == "supabase-user-abc"
    assert data["access_token"] == "at-google"
    assert data["refresh_token"] == "rt-google"
    assert data["expires_in"] == 3600

    mock_auth.sign_in_with_id_token.assert_called_once_with(
        provider="google",
        id_token="google-id-token-jwt",
        access_token="google-access-token",
        nonce=None,
    )


def test_google_social_login_without_access_token(client):
    """Google login without access_token is still accepted (validation is
    on Supabase's side). The endpoint should not 422 this request."""
    c, mock_auth = client
    mock_auth.sign_in_with_id_token.return_value = _GOOGLE_SUCCESS

    with patch("app.api.v1.auth.sync_user_to_db", new_callable=AsyncMock):
        response = c.post(
            "/api/v1/auth/social",
            json={
                "provider": "google",
                "id_token": "google-id-token-jwt",
            },
        )

    # The request schema allows missing access_token (optional field).
    # Supabase may reject it, but our schema does not enforce it here.
    assert response.status_code == 200


def test_google_social_login_invalid_token(client):
    """Supabase rejects an invalid Google ID token — expect 401 forwarded."""
    c, mock_auth = client
    mock_auth.sign_in_with_id_token.side_effect = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Social sign-in failed: Invalid Compact JWS",
    )

    response = c.post(
        "/api/v1/auth/social",
        json={
            "provider": "google",
            "id_token": "bad-token",
            "access_token": "bad-access",
        },
    )

    assert response.status_code == 401
    assert "Social sign-in failed" in response.json()["detail"]


# ---------------------------------------------------------------------------
# Apple Sign-In Tests
# ---------------------------------------------------------------------------


def test_apple_social_login_success(client):
    """Successful Apple login returns 200 with nonce forwarded to Supabase."""
    c, mock_auth = client
    mock_auth.sign_in_with_id_token.return_value = _APPLE_SUCCESS

    with patch("app.api.v1.auth.sync_user_to_db", new_callable=AsyncMock):
        response = c.post(
            "/api/v1/auth/social",
            json={
                "provider": "apple",
                "id_token": "apple-identity-token-jwt",
                "nonce": "raw-nonce-value",
            },
        )

    assert response.status_code == 200
    data = response.json()
    assert data["user_id"] == "supabase-user-xyz"
    assert data["access_token"] == "at-apple"

    mock_auth.sign_in_with_id_token.assert_called_once_with(
        provider="apple",
        id_token="apple-identity-token-jwt",
        access_token=None,
        nonce="raw-nonce-value",
    )


def test_apple_social_login_hide_my_email(client):
    """Apple 'Hide My Email' users get a relay email — synced to local DB."""
    c, mock_auth = client
    relay_email = "xyz123@privaterelay.appleid.com"
    mock_auth.sign_in_with_id_token.return_value = {
        "user_id": "apple-uid",
        "email": relay_email,
        "access_token": "at",
        "refresh_token": "rt",
        "expires_in": 3600,
    }

    with patch("app.api.v1.auth.sync_user_to_db", new_callable=AsyncMock) as mock_sync:
        response = c.post(
            "/api/v1/auth/social",
            json={
                "provider": "apple",
                "id_token": "apple-id-token",
                "nonce": "nonce",
            },
        )

    assert response.status_code == 200
    # Verify sync was called with the relay email — not a fallback.
    mock_sync.assert_called_once()
    call_args = mock_sync.call_args
    assert call_args.args[2] == relay_email


def test_apple_social_login_empty_email_fallback(client):
    """When Supabase returns no email (edge case), sync uses provider fallback."""
    c, mock_auth = client
    mock_auth.sign_in_with_id_token.return_value = {
        "user_id": "apple-uid-no-email",
        "email": "",  # Empty email edge case
        "access_token": "at",
        "refresh_token": "rt",
        "expires_in": 3600,
    }

    with patch("app.api.v1.auth.sync_user_to_db", new_callable=AsyncMock) as mock_sync:
        response = c.post(
            "/api/v1/auth/social",
            json={
                "provider": "apple",
                "id_token": "apple-id-token",
                "nonce": "nonce",
            },
        )

    assert response.status_code == 200
    # Fallback email should be "apple:<user_id>"
    call_args = mock_sync.call_args
    assert call_args.args[2] == "apple:apple-uid-no-email"


# ---------------------------------------------------------------------------
# Schema Validation Tests
# ---------------------------------------------------------------------------


def test_social_login_invalid_provider(client):
    """Unknown provider value fails Pydantic Literal validation — 422."""
    c, _ = client
    response = c.post(
        "/api/v1/auth/social",
        json={
            "provider": "facebook",  # Not in Literal["apple", "google"]
            "id_token": "some-token",
        },
    )
    assert response.status_code == 422


def test_social_login_missing_id_token(client):
    """Missing id_token fails Pydantic required field validation — 422."""
    c, _ = client
    response = c.post(
        "/api/v1/auth/social",
        json={"provider": "google"},
    )
    assert response.status_code == 422


# ---------------------------------------------------------------------------
# User Sync Tests
# ---------------------------------------------------------------------------


def test_social_login_syncs_user_to_db(client):
    """After successful social auth, sync_user_to_db is called with correct args."""
    c, mock_auth = client
    mock_auth.sign_in_with_id_token.return_value = _GOOGLE_SUCCESS

    with patch("app.api.v1.auth.sync_user_to_db", new_callable=AsyncMock) as mock_sync:
        c.post(
            "/api/v1/auth/social",
            json={
                "provider": "google",
                "id_token": "google-id-token",
                "access_token": "access",
            },
        )

    mock_sync.assert_called_once()
    # Verify user_id and email args match the Supabase response.
    call_args = mock_sync.call_args
    assert call_args.args[1] == "supabase-user-abc"
    assert call_args.args[2] == "user@gmail.com"
