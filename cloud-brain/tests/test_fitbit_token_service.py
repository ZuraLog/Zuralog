# tests/test_fitbit_token_service.py
"""Tests for FitbitTokenService — PKCE, token exchange, and DB lifecycle."""

import base64
import hashlib
from datetime import datetime, timedelta, timezone
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.fitbit_token_service import FitbitTokenService


@pytest.fixture
def mock_db():
    """Create an AsyncMock for SQLAlchemy AsyncSession."""
    db = AsyncMock()
    db.execute = AsyncMock()
    db.commit = AsyncMock()
    db.refresh = AsyncMock()
    return db


@pytest.fixture
def service():
    return FitbitTokenService()


# ---------------------------------------------------------------------------
# PKCE
# ---------------------------------------------------------------------------


class TestGeneratePkcePair:
    """Tests for PKCE verifier/challenge generation."""

    def test_verifier_is_url_safe_base64(self, service):
        """Verifier contains only URL-safe base64 characters (no padding)."""
        verifier, _ = service.generate_pkce_pair()
        allowed = set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")
        assert all(c in allowed for c in verifier), f"Invalid chars in verifier: {verifier}"

    def test_verifier_length_in_range(self, service):
        """Verifier length is between 43 and 128 characters (RFC 7636)."""
        verifier, _ = service.generate_pkce_pair()
        assert 43 <= len(verifier) <= 128

    def test_challenge_is_sha256_of_verifier(self, service):
        """Challenge equals base64url(sha256(verifier)) without padding."""
        verifier, challenge = service.generate_pkce_pair()
        digest = hashlib.sha256(verifier.encode("ascii")).digest()
        expected = base64.urlsafe_b64encode(digest).rstrip(b"=").decode()
        assert challenge == expected

    def test_pairs_are_unique(self, service):
        """Each call produces a different verifier/challenge pair."""
        pair1 = service.generate_pkce_pair()
        pair2 = service.generate_pkce_pair()
        assert pair1 != pair2


# ---------------------------------------------------------------------------
# Redis PKCE storage
# ---------------------------------------------------------------------------


class TestStorePkceVerifier:
    """Tests for storing / retrieving PKCE verifiers via Redis."""

    @pytest.mark.asyncio
    async def test_store_sets_key_with_ttl(self, service):
        """store_pkce_verifier calls redis.set with correct key and 600s TTL."""
        redis = AsyncMock()
        await service.store_pkce_verifier("state-abc", "verifier-xyz", redis)
        redis.set.assert_called_once_with("fitbit:pkce:state-abc", "verifier-xyz", ex=600)

    @pytest.mark.asyncio
    async def test_get_returns_verifier_and_deletes_key(self, service):
        """get_pkce_verifier retrieves the value and removes it (single-use)."""
        redis = AsyncMock()
        redis.getdel.return_value = b"verifier-xyz"

        result = await service.get_pkce_verifier("state-abc", redis)

        redis.getdel.assert_called_once_with("fitbit:pkce:state-abc")
        assert result == "verifier-xyz"

    @pytest.mark.asyncio
    async def test_get_returns_none_when_not_found(self, service):
        """get_pkce_verifier returns None when key has expired or never existed."""
        redis = AsyncMock()
        redis.getdel.return_value = None

        result = await service.get_pkce_verifier("state-missing", redis)
        assert result is None

    @pytest.mark.asyncio
    async def test_get_decodes_bytes(self, service):
        """get_pkce_verifier decodes bytes response to str."""
        redis = AsyncMock()
        redis.getdel.return_value = b"my-verifier"
        result = await service.get_pkce_verifier("s", redis)
        assert result == "my-verifier"
        assert isinstance(result, str)


# ---------------------------------------------------------------------------
# Authorization URL
# ---------------------------------------------------------------------------


class TestBuildAuthUrl:
    """Tests for Fitbit OAuth authorization URL construction."""

    def test_contains_all_required_scopes(self, service):
        """Auth URL includes every required Fitbit scope."""
        url = service.build_auth_url(
            state="state123",
            code_challenge="challenge123",
            client_id="my-client-id",
            redirect_uri="zuralog://oauth/fitbit",
        )
        required_scopes = [
            "activity", "heartrate", "sleep", "oxygen_saturation",
            "respiratory_rate", "temperature", "cardio_fitness",
            "electrocardiogram", "weight", "nutrition", "profile", "settings",
        ]
        for scope in required_scopes:
            assert scope in url, f"Scope '{scope}' missing from auth URL"

    def test_contains_pkce_params(self, service):
        """Auth URL includes code_challenge and S256 method."""
        url = service.build_auth_url("s", "ch123", "cid", "zuralog://oauth/fitbit")
        assert "code_challenge=ch123" in url
        assert "code_challenge_method=S256" in url

    def test_contains_state(self, service):
        """Auth URL includes the state parameter."""
        url = service.build_auth_url("my-state", "ch", "cid", "zuralog://oauth/fitbit")
        assert "state=my-state" in url

    def test_response_type_is_code(self, service):
        """Auth URL uses response_type=code."""
        url = service.build_auth_url("s", "c", "cid", "r")
        assert "response_type=code" in url


# ---------------------------------------------------------------------------
# Code exchange
# ---------------------------------------------------------------------------


class TestExchangeCode:
    """Tests for exchanging an authorization code for tokens."""

    @pytest.mark.asyncio
    @patch("httpx.AsyncClient.post")
    async def test_uses_basic_auth_header(self, mock_post, service):
        """exchange_code sends Authorization: Basic header, not POST body creds."""
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.raise_for_status = MagicMock()
        mock_response.json.return_value = {
            "access_token": "at",
            "refresh_token": "rt",
            "expires_in": 28800,
        }
        mock_post.return_value = mock_response

        await service.exchange_code(
            code="code123",
            code_verifier="verifier123",
            client_id="client-id",
            client_secret="client-secret",
            redirect_uri="zuralog://oauth/fitbit",
        )

        call_kwargs = mock_post.call_args
        headers = call_kwargs.kwargs.get("headers", {})
        assert "Authorization" in headers
        assert headers["Authorization"].startswith("Basic ")

        # Verify the encoded credentials are correct
        encoded = headers["Authorization"][len("Basic "):]
        decoded = base64.b64decode(encoded).decode()
        assert decoded == "client-id:client-secret"

    @pytest.mark.asyncio
    @patch("httpx.AsyncClient.post")
    async def test_client_id_not_in_body(self, mock_post, service):
        """Client credentials must NOT appear as plain client_secret in POST body."""
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.raise_for_status = MagicMock()
        mock_response.json.return_value = {
            "access_token": "at",
            "refresh_token": "rt",
            "expires_in": 28800,
        }
        mock_post.return_value = mock_response

        await service.exchange_code("c", "v", "cid", "csecret", "uri")

        call_kwargs = mock_post.call_args
        data = call_kwargs.kwargs.get("data", {})
        assert "client_secret" not in data

    @pytest.mark.asyncio
    @patch("httpx.AsyncClient.post")
    async def test_returns_token_dict(self, mock_post, service):
        """exchange_code returns the parsed JSON response dict."""
        token_data = {"access_token": "at-123", "refresh_token": "rt-456", "expires_in": 28800}
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.raise_for_status = MagicMock()
        mock_response.json.return_value = token_data
        mock_post.return_value = mock_response

        result = await service.exchange_code("c", "v", "cid", "cs", "uri")
        assert result == token_data


# ---------------------------------------------------------------------------
# Save tokens
# ---------------------------------------------------------------------------


class TestSaveTokens:
    """Tests for persisting Fitbit OAuth tokens."""

    @pytest.mark.asyncio
    async def test_creates_new_integration(self, service, mock_db):
        """Creates a new row when no existing Fitbit integration exists."""
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = None
        mock_db.execute.return_value = mock_result

        token_response = {
            "access_token": "at-abc",
            "refresh_token": "rt-xyz",
            "expires_in": 28800,
            "user_id": "FITBIT-USR-1",
        }

        await service.save_tokens(mock_db, "user-123", token_response)

        mock_db.add.assert_called_once()
        mock_db.commit.assert_called_once()

    @pytest.mark.asyncio
    async def test_stores_fitbit_user_id_in_metadata(self, service, mock_db):
        """Stores the Fitbit user_id in provider_metadata."""
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = None
        mock_db.execute.return_value = mock_result

        # db.add is an AsyncMock; track calls via call_args instead of side_effect
        mock_db.add = MagicMock()

        token_response = {
            "access_token": "at",
            "refresh_token": "rt",
            "expires_in": 28800,
            "user_id": "FITBIT-ABC",
        }

        await service.save_tokens(mock_db, "user-123", token_response)

        mock_db.add.assert_called_once()
        added = mock_db.add.call_args[0][0]
        assert added.provider_metadata == {"fitbit_user_id": "FITBIT-ABC"}

    @pytest.mark.asyncio
    async def test_updates_existing_integration(self, service, mock_db):
        """Updates tokens in place when integration already exists."""
        existing = MagicMock()
        existing.access_token = "old-at"
        existing.provider_metadata = {}
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = existing
        mock_db.execute.return_value = mock_result

        token_response = {
            "access_token": "new-at",
            "refresh_token": "new-rt",
            "expires_in": 28800,
            "user_id": "FITBIT-ABC",
        }

        await service.save_tokens(mock_db, "user-123", token_response)

        assert existing.access_token == "new-at"
        assert existing.refresh_token == "new-rt"
        mock_db.commit.assert_called_once()


# ---------------------------------------------------------------------------
# Get access token (with auto-refresh)
# ---------------------------------------------------------------------------


class TestGetAccessToken:
    """Tests for retrieving a valid access token."""

    @pytest.mark.asyncio
    async def test_returns_token_when_not_expiring(self, service, mock_db):
        """Returns access_token directly when well within expiry window."""
        future = datetime.now(timezone.utc) + timedelta(hours=4)
        integration = MagicMock()
        integration.access_token = "valid-token"
        integration.token_expires_at = future
        integration.is_active = True

        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = integration
        mock_db.execute.return_value = mock_result

        token = await service.get_access_token(mock_db, "user-123")
        assert token == "valid-token"

    @pytest.mark.asyncio
    async def test_returns_none_when_no_integration(self, service, mock_db):
        """Returns None when user has no active Fitbit integration."""
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = None
        mock_db.execute.return_value = mock_result

        token = await service.get_access_token(mock_db, "user-999")
        assert token is None

    @pytest.mark.asyncio
    @patch("app.services.fitbit_token_service.FitbitTokenService.refresh_access_token")
    async def test_refreshes_within_10min_buffer(self, mock_refresh, service, mock_db):
        """Triggers refresh when token is within the 10-minute expiry buffer."""
        # Expiring in 5 minutes — within the 10-minute buffer
        near_expiry = datetime.now(timezone.utc) + timedelta(minutes=5)
        integration = MagicMock()
        integration.access_token = "expiring-token"
        integration.token_expires_at = near_expiry
        integration.is_active = True

        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = integration
        mock_db.execute.return_value = mock_result
        mock_refresh.return_value = "refreshed-token"

        token = await service.get_access_token(mock_db, "user-123")
        assert token == "refreshed-token"
        mock_refresh.assert_called_once()

    @pytest.mark.asyncio
    @patch("app.services.fitbit_token_service.FitbitTokenService.refresh_access_token")
    async def test_does_not_refresh_outside_buffer(self, mock_refresh, service, mock_db):
        """Does NOT refresh when token still has more than 10 minutes remaining."""
        future = datetime.now(timezone.utc) + timedelta(minutes=15)
        integration = MagicMock()
        integration.access_token = "fresh-token"
        integration.token_expires_at = future
        integration.is_active = True

        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = integration
        mock_db.execute.return_value = mock_result

        token = await service.get_access_token(mock_db, "user-123")
        assert token == "fresh-token"
        mock_refresh.assert_not_called()


# ---------------------------------------------------------------------------
# Refresh access token
# ---------------------------------------------------------------------------


class TestRefreshAccessToken:
    """Tests for the Fitbit single-use refresh token flow."""

    @pytest.mark.asyncio
    @patch("httpx.AsyncClient.post")
    async def test_refresh_saves_new_tokens_atomically(self, mock_post, service, mock_db):
        """On success, new access AND refresh tokens are saved before returning."""
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "access_token": "new-at",
            "refresh_token": "new-rt",
            "expires_in": 28800,
        }
        mock_post.return_value = mock_response

        integration = MagicMock()
        integration.refresh_token = "old-rt"
        integration.user_id = "user-123"

        result = await service.refresh_access_token(mock_db, integration)

        assert result == "new-at"
        assert integration.access_token == "new-at"
        # Critical: new refresh token must be saved (single-use requirement)
        assert integration.refresh_token == "new-rt"
        mock_db.commit.assert_called_once()

    @pytest.mark.asyncio
    @patch("httpx.AsyncClient.post")
    async def test_refresh_uses_basic_auth_header(self, mock_post, service, mock_db):
        """Refresh request uses Authorization: Basic header."""
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "access_token": "at",
            "refresh_token": "rt",
            "expires_in": 28800,
        }
        mock_post.return_value = mock_response

        integration = MagicMock()
        integration.refresh_token = "rt"
        integration.user_id = "user-123"

        with patch("app.services.fitbit_token_service.settings") as mock_settings:
            mock_settings.fitbit_client_id = "my-client"
            mock_settings.fitbit_client_secret = "my-secret"
            await service.refresh_access_token(mock_db, integration)

        call_kwargs = mock_post.call_args
        headers = call_kwargs.kwargs.get("headers", {})
        assert headers.get("Authorization", "").startswith("Basic ")

    @pytest.mark.asyncio
    @patch("httpx.AsyncClient.post")
    async def test_401_marks_integration_error(self, mock_post, service, mock_db):
        """On 401 response, integration is marked sync_status='error' and None returned."""
        mock_response = MagicMock()
        mock_response.status_code = 401
        mock_response.text = "Unauthorized"
        mock_post.return_value = mock_response

        integration = MagicMock()
        integration.refresh_token = "bad-rt"
        integration.user_id = "user-123"

        result = await service.refresh_access_token(mock_db, integration)

        assert result is None
        assert integration.sync_status == "error"
        mock_db.commit.assert_called_once()

    @pytest.mark.asyncio
    @patch("httpx.AsyncClient.post")
    async def test_non_401_failure_marks_error(self, mock_post, service, mock_db):
        """Non-401 failures also mark integration error and return None."""
        mock_response = MagicMock()
        mock_response.status_code = 500
        mock_response.text = "Server Error"
        mock_post.return_value = mock_response

        integration = MagicMock()
        integration.refresh_token = "rt"
        integration.user_id = "user-123"

        result = await service.refresh_access_token(mock_db, integration)

        assert result is None
        assert integration.sync_status == "error"

    @pytest.mark.asyncio
    @patch("httpx.AsyncClient.post", side_effect=__import__("httpx").RequestError("timeout"))
    async def test_network_error_returns_none(self, mock_post, service, mock_db):
        """Network-level errors return None without touching the DB."""
        integration = MagicMock()
        integration.refresh_token = "rt"
        integration.user_id = "user-123"

        result = await service.refresh_access_token(mock_db, integration)

        assert result is None
        mock_db.commit.assert_not_called()


# ---------------------------------------------------------------------------
# Disconnect
# ---------------------------------------------------------------------------


class TestDisconnect:
    """Tests for revoking a Fitbit integration."""

    @pytest.mark.asyncio
    async def test_disconnect_deactivates_integration(self, service, mock_db):
        """disconnect sets is_active=False and commits."""
        integration = MagicMock()
        integration.is_active = True
        integration.access_token = "some-token"
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = integration
        mock_db.execute.return_value = mock_result

        with patch("httpx.AsyncClient.post", new_callable=AsyncMock):
            result = await service.disconnect(mock_db, "user-123")

        assert result is True
        assert integration.is_active is False
        mock_db.commit.assert_called_once()

    @pytest.mark.asyncio
    async def test_disconnect_returns_false_when_not_found(self, service, mock_db):
        """disconnect returns False when no integration exists."""
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = None
        mock_db.execute.return_value = mock_result

        result = await service.disconnect(mock_db, "user-999")
        assert result is False

    @pytest.mark.asyncio
    async def test_disconnect_revokes_token(self, service, mock_db):
        """disconnect calls Fitbit revoke endpoint with the access token."""
        integration = MagicMock()
        integration.access_token = "token-to-revoke"
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = integration
        mock_db.execute.return_value = mock_result

        with patch("httpx.AsyncClient.post", new_callable=AsyncMock) as mock_post:
            await service.disconnect(mock_db, "user-123")

        mock_post.assert_called_once()
        call_kwargs = mock_post.call_args
        # The revoke URL should be the first positional argument
        revoke_url = call_kwargs.args[0] if call_kwargs.args else call_kwargs.kwargs.get("url", "")
        assert "revoke" in revoke_url
